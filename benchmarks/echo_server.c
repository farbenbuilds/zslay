#define _POSIX_C_SOURCE 200809L

#include "zslay.h"

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

#ifdef MSG_NOSIGNAL
#define SEND_FLAGS MSG_NOSIGNAL
#else
#define SEND_FLAGS 0
#endif

enum {
    MAX_CLIENTS = 128,
    MAX_MESSAGE = 4096,
    MAX_HANDSHAKE = 4096,
    WS_INPUT_SIZE = 8192,
    ACCEPT_BUDGET = 16,
    POLL_TIMEOUT_MS = 1000,
    IDLE_TIMEOUT_SECONDS = 30,
};

enum client_phase {
    PHASE_UNUSED,
    PHASE_REQUEST,
    PHASE_RESPONSE,
    PHASE_WEBSOCKET,
};

struct client {
    int fd;
    enum client_phase phase;
    void *conn_mem;
    void *node_mem;
    void *tx_mem;
    void *conn;
    char handshake[MAX_HANDSHAKE];
    size_t handshake_len;
    uint8_t ws_in[WS_INPUT_SIZE];
    size_t ws_in_len;
    size_t ws_in_off;
    time_t last_active;
    char response[256];
    size_t response_len;
    size_t response_sent;
    uint8_t message[MAX_MESSAGE];
    size_t message_len;
    uint8_t control[125];
    size_t control_len;
    int pending;
    int pending_binary;
    int close_after_send;
    int failed;
    int recv_blocked;
    int send_blocked;
};

static struct client clients[MAX_CLIENTS];

static void service_websocket(struct client *client);
static size_t find_handshake_end(const char *buf, size_t len, size_t start);

static uint32_t rotate_left(uint32_t value, unsigned int count)
{
    return (value << count) | (value >> (32 - count));
}

static void sha1_60(const uint8_t input[60], uint8_t output[20])
{
    uint8_t padded[128] = {0};
    uint32_t state[5] = {
        0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0,
    };
    memcpy(padded, input, 60);
    padded[60] = 0x80;
    padded[126] = 0x01;
    padded[127] = 0xe0;

    for (size_t block = 0; block < 2; block++) {
        uint32_t words[80];
        for (size_t i = 0; i < 16; i++) {
            const uint8_t *bytes = padded + block * 64 + i * 4;
            words[i] = ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) |
                       ((uint32_t)bytes[2] << 8) | bytes[3];
        }
        for (size_t i = 16; i < 80; i++)
            words[i] = rotate_left(words[i - 3] ^ words[i - 8] ^ words[i - 14] ^ words[i - 16], 1);

        uint32_t a = state[0], b = state[1], c = state[2], d = state[3], e = state[4];
        for (size_t i = 0; i < 80; i++) {
            uint32_t function, constant;
            if (i < 20) {
                function = (b & c) | (~b & d);
                constant = 0x5a827999;
            } else if (i < 40) {
                function = b ^ c ^ d;
                constant = 0x6ed9eba1;
            } else if (i < 60) {
                function = (b & c) | (b & d) | (c & d);
                constant = 0x8f1bbcdc;
            } else {
                function = b ^ c ^ d;
                constant = 0xca62c1d6;
            }
            uint32_t next = rotate_left(a, 5) + function + e + constant + words[i];
            e = d;
            d = c;
            c = rotate_left(b, 30);
            b = a;
            a = next;
        }
        state[0] += a;
        state[1] += b;
        state[2] += c;
        state[3] += d;
        state[4] += e;
    }
    for (size_t i = 0; i < 5; i++) {
        output[i * 4] = (uint8_t)(state[i] >> 24);
        output[i * 4 + 1] = (uint8_t)(state[i] >> 16);
        output[i * 4 + 2] = (uint8_t)(state[i] >> 8);
        output[i * 4 + 3] = (uint8_t)state[i];
    }
}

static int base64_digit(unsigned char value)
{
    if (value >= 'A' && value <= 'Z')
        return value - 'A';
    if (value >= 'a' && value <= 'z')
        return value - 'a' + 26;
    if (value >= '0' && value <= '9')
        return value - '0' + 52;
    if (value == '+')
        return 62;
    if (value == '/')
        return 63;
    return -1;
}

static int valid_websocket_key(const char *key, size_t key_len)
{
    if (key_len != 24 || key[22] != '=' || key[23] != '=')
        return 0;
    for (size_t i = 0; i < 22; i++) {
        int digit = base64_digit((unsigned char)key[i]);
        if (digit < 0 || (i == 21 && (digit & 15) != 0))
            return 0;
    }
    return 1;
}

static void base64_sha1(const uint8_t digest[20], char output[29])
{
    static const char alphabet[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    for (size_t i = 0; i < 18; i += 3) {
        uint32_t value = ((uint32_t)digest[i] << 16) |
                         ((uint32_t)digest[i + 1] << 8) | digest[i + 2];
        output[(i / 3) * 4] = alphabet[value >> 18];
        output[(i / 3) * 4 + 1] = alphabet[(value >> 12) & 63];
        output[(i / 3) * 4 + 2] = alphabet[(value >> 6) & 63];
        output[(i / 3) * 4 + 3] = alphabet[value & 63];
    }
    output[24] = alphabet[digest[18] >> 2];
    output[25] = alphabet[((digest[18] & 3) << 4) | (digest[19] >> 4)];
    output[26] = alphabet[(digest[19] & 15) << 2];
    output[27] = '=';
    output[28] = 0;
}

static int nonblocking(int fd)
{
    int flags = fcntl(fd, F_GETFL, 0);
    return flags < 0 ? -1 : fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

static int configure_client_socket(int fd)
{
    int enabled = 1;
    if (nonblocking(fd) != 0 ||
        setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &enabled, sizeof(enabled)) != 0)
        return -1;
#ifdef SO_NOSIGPIPE
    if (setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &enabled, sizeof(enabled)) != 0)
        return -1;
#endif
    return 0;
}

static void retire_client(struct client *client)
{
    if (client->fd >= 0)
        close(client->fd);
    client->fd = -1;
    client->phase = PHASE_UNUSED;
    client->conn = NULL;
}

static ptrdiff_t recv_frame(uint8_t *buf, size_t len, void *user_data)
{
    struct client *client = user_data;

    if (client->ws_in_off == client->ws_in_len) {
        client->ws_in_off = 0;
        client->ws_in_len = 0;

        ssize_t got = recv(client->fd, client->ws_in, sizeof(client->ws_in), 0);
        if (got > 0) {
            client->ws_in_len = (size_t)got;
        } else if (got == 0) {
            client->failed = 1;
            return -1;
        } else if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
            client->recv_blocked = 1;
            return 0;
        } else {
            client->failed = 1;
            return -1;
        }
    }

    size_t available = client->ws_in_len - client->ws_in_off;
    size_t count = len < available ? len : available;
    memcpy(buf, client->ws_in + client->ws_in_off, count);
    client->ws_in_off += count;
    return (ptrdiff_t)count;
}

static ptrdiff_t send_frame(const uint8_t *buf, size_t len, void *user_data)
{
    struct client *client = user_data;
    ssize_t sent = send(client->fd, buf, len, SEND_FLAGS);
    if (sent > 0)
        return sent;
    if (sent < 0 && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)) {
        client->send_blocked = 1;
        return 0;
    }
    client->failed = 1;
    return -1;
}

static void queue_frame(struct client *client, uint8_t opcode,
                        const uint8_t *payload, size_t payload_len)
{
    if (client->pending || client->failed) {
        client->failed = 1;
        return;
    }
    if (zslay_conn_prepare_frame(client->conn, client->node_mem, 1, opcode,
                                 payload, payload_len, 0) != ZSLAY_OK ||
        zslay_conn_queue_frame(client->conn, client->node_mem) != ZSLAY_OK) {
        client->failed = 1;
        return;
    }
    client->pending = 1;
    client->pending_binary = opcode == 2;
}

static void on_frame(uint8_t opcode, uint8_t fin, const uint8_t *payload,
                     size_t len, uint64_t payload_offset, uint64_t frame_len,
                     uint8_t end_of_frame, void *user_data)
{
    struct client *client = user_data;
    (void)payload_offset;
    (void)frame_len;
    if (client->failed)
        return;
    if (opcode == 2 || opcode == 0) {
        if (len > MAX_MESSAGE - client->message_len) {
            client->failed = 1;
            return;
        }
        if (len)
            memcpy(client->message + client->message_len, payload, len);
        client->message_len += len;
        if (end_of_frame && fin)
            queue_frame(client, 2, client->message, client->message_len);
        return;
    }
    if (opcode == 10)
        return;
    if (opcode != 9 && opcode != 8) {
        client->failed = 1;
        return;
    }
    if (len > sizeof(client->control) - client->control_len) {
        client->failed = 1;
        return;
    }
    if (len)
        memcpy(client->control + client->control_len, payload, len);
    client->control_len += len;
    if (!end_of_frame)
        return;
    queue_frame(client, opcode == 9 ? 10 : 8, client->control, client->control_len);
    if (opcode == 8)
        client->close_after_send = 1;
}

static int header_value(const char *request, const char *name,
                        const char **value, size_t *value_len)
{
    const char *line = strstr(request, "\r\n");
    size_t name_len = strlen(name);
    if (!line)
        return -1;
    line += 2;
    while (*line && !(line[0] == '\r' && line[1] == '\n')) {
        const char *end = strstr(line, "\r\n");
        const char *start;
        if (!end)
            return -1;
        if ((size_t)(end - line) > name_len &&
            line[name_len] == ':' && strncasecmp(line, name, name_len) == 0) {
            start = line + name_len + 1;
            while (start < end && (*start == ' ' || *start == '\t'))
                start++;
            while (end > start && (end[-1] == ' ' || end[-1] == '\t'))
                end--;
            *value = start;
            *value_len = (size_t)(end - start);
            return 0;
        }
        line = end + 2;
    }
    return -1;
}

static int has_token(const char *value, size_t value_len, const char *token)
{
    size_t token_len = strlen(token);
    while (value_len) {
        const char *part_start = value;
        const char *comma = memchr(value, ',', value_len);
        size_t part_len = comma ? (size_t)(comma - value) : value_len;
        while (part_len && (*value == ' ' || *value == '\t')) {
            value++;
            part_len--;
        }
        while (part_len && (value[part_len - 1] == ' ' || value[part_len - 1] == '\t'))
            part_len--;
        if (part_len == token_len && strncasecmp(value, token, token_len) == 0)
            return 1;
        if (!comma)
            return 0;
        value_len -= (size_t)(comma - part_start) + 1;
        value = comma + 1;
    }
    return 0;
}

static int prepare_handshake(struct client *client)
{
    static const char guid[] = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    const char *value;
    size_t value_len;
    char material[24 + sizeof(guid) - 1];
    uint8_t digest[20];
    char accept[29];
    int response_len;

    if (strncmp(client->handshake, "GET ", 4) != 0 ||
        !strstr(client->handshake, " HTTP/1.1\r\n"))
        return -1;
    if (header_value(client->handshake, "Upgrade", &value, &value_len) != 0 ||
        !has_token(value, value_len, "websocket"))
        return -1;
    if (header_value(client->handshake, "Connection", &value, &value_len) != 0 ||
        !has_token(value, value_len, "Upgrade"))
        return -1;
    if (header_value(client->handshake, "Sec-WebSocket-Version", &value, &value_len) != 0 ||
        value_len != 2 || memcmp(value, "13", 2) != 0)
        return -1;
    if (header_value(client->handshake, "Sec-WebSocket-Key", &value, &value_len) != 0 ||
        !valid_websocket_key(value, value_len))
        return -1;
    memcpy(material, value, 24);
    memcpy(material + 24, guid, sizeof(guid) - 1);
    sha1_60((const uint8_t *)material, digest);
    base64_sha1(digest, accept);
    response_len = snprintf(client->response, sizeof(client->response),
                            "HTTP/1.1 101 Switching Protocols\r\n"
                            "Upgrade: websocket\r\nConnection: Upgrade\r\n"
                            "Sec-WebSocket-Accept: %s\r\n\r\n", accept);
    if (response_len < 0 || (size_t)response_len >= sizeof(client->response))
        return -1;
    client->response_len = (size_t)response_len;
    client->response_sent = 0;
    client->phase = PHASE_RESPONSE;
    return 0;
}

static int self_test(void)
{
    struct client client = {0};
    static const char request[] =
        "GET /chat HTTP/1.1\r\n"
        "Host: server.example.com\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
        "Sec-WebSocket-Version: 13\r\n\r\n";
    memcpy(client.handshake, request, sizeof(request));
    if (prepare_handshake(&client) != 0 ||
        !strstr(client.response, "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n"))
        return -1;

    static const char split_first[] = "GET / HTTP/1.1\r\nSec-WebSocket-Version: 13\r";
    static const char split_second[] = "\n\r\n";
    char split[sizeof(split_first) + sizeof(split_second)];
    size_t first_len = sizeof(split_first) - 1;
    memcpy(split, split_first, first_len);
    if (find_handshake_end(split, first_len, 0) != 0)
        return -1;
    memcpy(split + first_len, split_second, sizeof(split_second) - 1);
    if (find_handshake_end(split, first_len + sizeof(split_second) - 1, first_len) == 0)
        return -1;
    return 0;
}

static size_t find_handshake_end(const char *buf, size_t len, size_t start)
{
    if (len < 4)
        return 0;
    if (start > len)
        start = len;
    start = start > 3 ? start - 3 : 0;

    for (size_t i = start; i + 4 <= len; i++) {
        if (memcmp(buf + i, "\r\n\r\n", 4) == 0)
            return i + 4;
    }
    return 0;
}

static void read_handshake(struct client *client)
{
    while (client->handshake_len < MAX_HANDSHAKE - 1) {
        size_t space = MAX_HANDSHAKE - 1 - client->handshake_len;
        size_t old_len = client->handshake_len;
        ssize_t got = recv(client->fd, client->handshake + client->handshake_len, space, 0);
        if (got > 0) {
            client->handshake_len += (size_t)got;
            client->handshake[client->handshake_len] = 0;

            size_t header_len = find_handshake_end(client->handshake, client->handshake_len, old_len);
            if (header_len == 0)
                continue;

            size_t leftover = client->handshake_len - header_len;
            if (leftover > 0) {
                memcpy(client->ws_in, client->handshake + header_len, leftover);
                client->ws_in_len = leftover;
                client->ws_in_off = 0;
            }
            client->handshake_len = header_len;
            client->handshake[header_len] = 0;

            if (prepare_handshake(client) != 0)
                retire_client(client);
            return;
        }
        if (got < 0 && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR))
            return;
        retire_client(client);
        return;
    }
    retire_client(client);
}

static void write_handshake(struct client *client)
{
    while (client->response_sent < client->response_len) {
        ssize_t sent = send(client->fd, client->response + client->response_sent,
                            client->response_len - client->response_sent, SEND_FLAGS);
        if (sent > 0) {
            client->response_sent += (size_t)sent;
            continue;
        }
        if (sent < 0 && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR))
            return;
        retire_client(client);
        return;
    }
    client->phase = PHASE_WEBSOCKET;
    if (client->ws_in_off < client->ws_in_len)
        service_websocket(client);
}

static void service_websocket(struct client *client)
{
    for (int round = 0; round < MAX_HANDSHAKE; round++) {
        size_t pending = 0;
        if (client->pending) {
            client->send_blocked = 0;
            int status = zslay_conn_send(client->conn);
            if (client->failed || (status != ZSLAY_OK && status != ZSLAY_PROGRESS)) {
                retire_client(client);
                return;
            }
            if (client->send_blocked)
                return;
            if (zslay_conn_tx_pending(client->conn, &pending) != ZSLAY_OK) {
                retire_client(client);
                return;
            }
            if (pending != 0)
                return;
            client->pending = 0;
            if (client->pending_binary)
                client->message_len = 0;
            client->control_len = 0;
            if (client->close_after_send) {
                retire_client(client);
                return;
            }
        }

        int progressed = 0;
        for (int i = 0; i < 64; i++) {
            client->recv_blocked = 0;
            int status = zslay_conn_recv(client->conn);
            if (status < 0 || client->failed) {
                retire_client(client);
                return;
            }
            if (status == ZSLAY_OK || client->recv_blocked)
                return;
            progressed = 1;
            if (client->pending)
                return;
        }

        if (!progressed || client->ws_in_off == client->ws_in_len)
            return;
    }
}

static void free_client_storage(void)
{
    for (int i = 0; i < MAX_CLIENTS; i++) {
        free(clients[i].conn_mem);
        free(clients[i].node_mem);
        free(clients[i].tx_mem);
        clients[i].conn_mem = NULL;
        clients[i].node_mem = NULL;
        clients[i].tx_mem = NULL;
    }
}

static int init_client_storage(void)
{
    size_t conn_size = zslay_conn_get_size();
    size_t node_size = zslay_frame_node_get_size();
    size_t conn_align = zslay_conn_get_align();
    size_t node_align = zslay_frame_node_get_align();

    if (!conn_size || !node_size || !conn_align || !node_align)
        return -1;
    for (int i = 0; i < MAX_CLIENTS; i++) {
        clients[i].fd = -1;
        clients[i].conn_mem = NULL;
        clients[i].node_mem = NULL;
        clients[i].tx_mem = NULL;
        if (posix_memalign(&clients[i].conn_mem, conn_align < sizeof(void *) ? sizeof(void *) : conn_align,
                           conn_size) != 0 ||
            posix_memalign(&clients[i].node_mem, node_align < sizeof(void *) ? sizeof(void *) : node_align,
                           node_size) != 0 ||
            posix_memalign(&clients[i].tx_mem, node_align < sizeof(void *) ? sizeof(void *) : node_align,
                           node_size) != 0) {
            free_client_storage();
            return -1;
        }
    }
    return 0;
}

static void accept_clients(int listen_fd)
{
    for (int accepted = 0; accepted < ACCEPT_BUDGET; accepted++) {
        int fd = accept(listen_fd, NULL, NULL);
        struct client *client = NULL;
        if (fd < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)
                return;
            return;
        }
        if (configure_client_socket(fd) != 0) {
            close(fd);
            continue;
        }
        for (int i = 0; i < MAX_CLIENTS; i++) {
            if (clients[i].phase == PHASE_UNUSED) {
                client = &clients[i];
                break;
            }
        }
        if (!client) {
            close(fd);
            return;
        }
        client->fd = fd;
        client->phase = PHASE_REQUEST;
        client->handshake_len = 0;
        client->ws_in_len = 0;
        client->ws_in_off = 0;
        client->message_len = 0;
        client->control_len = 0;
        client->pending = 0;
        client->pending_binary = 0;
        client->close_after_send = 0;
        client->failed = 0;
        client->recv_blocked = 0;
        client->send_blocked = 0;
        client->last_active = time(NULL);
        client->conn = zslay_conn_init(client->conn_mem, client, recv_frame, send_frame,
                                       on_frame, NULL, client->tx_mem, 1,
                                       ZSLAY_ROLE_SERVER, MAX_MESSAGE, MAX_MESSAGE);
        if (!client->conn)
            retire_client(client);
    }
}

int main(int argc, char **argv)
{
    struct sockaddr_in address = {0};
    struct pollfd fds[MAX_CLIENTS + 1];
    char *end;
    long port;
    int listen_fd;

    if (argc == 2 && strcmp(argv[1], "--self-test") == 0) {
        if (self_test() != 0) {
            fprintf(stderr, "RFC 6455 handshake self-test failed\n");
            return 1;
        }
        puts("RFC 6455 handshake self-test passed");
        return 0;
    }
    if ((argc == 2 && strcmp(argv[1], "--help") == 0)) {
        fprintf(stdout, "usage: %s [--port] PORT\n", argv[0]);
        return 0;
    }
    if (argc != 2 && !(argc == 3 && strcmp(argv[1], "--port") == 0)) {
        fprintf(stderr, "usage: %s [--port] PORT\n", argv[0]);
        return 2;
    }
    port = strtol(argv[argc - 1], &end, 10);
    if (*end || port < 1 || port > 65535) {
        fprintf(stderr, "invalid port\n");
        return 2;
    }
    if (init_client_storage() != 0) {
        fprintf(stderr, "failed to allocate connection storage\n");
        return 1;
    }
    signal(SIGPIPE, SIG_IGN);
    listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (listen_fd < 0 || nonblocking(listen_fd) != 0)
        return 1;
    int reuse = 1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = htons((uint16_t)port);
    if (bind(listen_fd, (struct sockaddr *)&address, sizeof(address)) != 0 ||
        listen(listen_fd, MAX_CLIENTS) != 0) {
        perror("listen");
        return 1;
    }
    printf("READY %ld\n", port);
    fflush(stdout);
    for (;;) {
        time_t now = time(NULL);
        fds[0].fd = listen_fd;
        fds[0].events = POLLIN;
        for (int i = 0; i < MAX_CLIENTS; i++) {
            struct client *client = &clients[i];
            fds[i + 1].fd = client->fd;
            fds[i + 1].events = client->phase == PHASE_RESPONSE ||
                                (client->phase == PHASE_WEBSOCKET && client->pending) ? POLLOUT : POLLIN;
        }
        if (poll(fds, MAX_CLIENTS + 1, POLL_TIMEOUT_MS) < 0) {
            if (errno == EINTR)
                continue;
            perror("poll");
            return 1;
        }
        if (fds[0].revents & POLLIN)
            accept_clients(listen_fd);
        for (int i = 0; i < MAX_CLIENTS; i++) {
            struct client *client = &clients[i];
            if (client->phase == PHASE_UNUSED)
                continue;
            if (now - client->last_active >= IDLE_TIMEOUT_SECONDS) {
                retire_client(client);
                continue;
            }
            if (!fds[i + 1].revents)
                continue;
            client->last_active = now;
            if (fds[i + 1].revents & (POLLERR | POLLNVAL)) {
                retire_client(client);
                continue;
            }
            if (client->phase == PHASE_REQUEST && (fds[i + 1].revents & POLLIN))
                read_handshake(client);
            else if (client->phase == PHASE_RESPONSE && (fds[i + 1].revents & POLLOUT))
                write_handshake(client);
            else if (client->phase == PHASE_WEBSOCKET &&
                     (fds[i + 1].revents & (POLLIN | POLLOUT)))
                service_websocket(client);
            if (client->phase != PHASE_UNUSED && (fds[i + 1].revents & POLLHUP))
                retire_client(client);
        }
    }
}
