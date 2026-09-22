/*
 * Standalone smoke test for the installed zslay C ABI.
 * Build: zig cc -std=c11 -Wall -Wextra -I include -c src/c_api_smoke.c
 * Link the object against the static zslay library and run it; exit code 0
 * means every checked contract held.
 */

#include "zslay.h"

#define ZSLAY_SMOKE_ALIGN 64

static _Alignas(ZSLAY_SMOKE_ALIGN) unsigned char conn_mem[1024];
static _Alignas(ZSLAY_SMOKE_ALIGN) unsigned char node_mem[256];

/* Single static state shared by all three callbacks. */
struct smoke_state {
    size_t recv_offset;
    size_t sent_len;
    unsigned char sent[64];

    uint8_t opcode;
    size_t payload_len;
    uint8_t end_of_frame;
    uint8_t frame_seen;
};

static struct smoke_state state;

/* Serves one masked zero-length ping frame: 0x89 0x80 plus a four-byte key. */
static ptrdiff_t smoke_recv(uint8_t *buf, size_t len, void *user_data) {
    static const uint8_t wire[] = { 0x89, 0x80, 0x01, 0x02, 0x03, 0x04 };
    struct smoke_state *st = user_data;
    size_t remaining = sizeof(wire) - st->recv_offset;
    size_t count = len < remaining ? len : remaining;

    for (size_t i = 0; i < count; i++) buf[i] = wire[st->recv_offset + i];
    st->recv_offset += count;
    return (ptrdiff_t)count;
}

/* Appends into the static capture buffer and reports the full length. */
static ptrdiff_t smoke_send(const uint8_t *buf, size_t len, void *user_data) {
    struct smoke_state *st = user_data;

    if (len > sizeof(st->sent) - st->sent_len) return -1;
    for (size_t i = 0; i < len; i++) st->sent[st->sent_len + i] = buf[i];
    st->sent_len += len;
    return (ptrdiff_t)len;
}

/* Records the boundary summary of the last delivered frame. */
static void smoke_on_frame(uint8_t opcode, uint8_t fin, const uint8_t *payload, size_t len,
    uint64_t payload_offset, uint64_t frame_len, uint8_t end_of_frame, void *user_data) {
    struct smoke_state *st = user_data;

    (void)fin;
    (void)payload;
    (void)payload_offset;
    (void)frame_len;

    st->opcode = opcode;
    st->payload_len = len;
    st->end_of_frame = end_of_frame;
    st->frame_seen = 1;
}

int main(void) {
    if (zslay_conn_get_size() > sizeof(conn_mem)) return 1;
    if (zslay_conn_get_align() > ZSLAY_SMOKE_ALIGN) return 2;
    if (zslay_frame_node_get_size() > sizeof(node_mem)) return 3;
    if (zslay_frame_node_get_align() > ZSLAY_SMOKE_ALIGN) return 4;

    void *conn = zslay_conn_init(conn_mem, &state, smoke_recv, smoke_send,
        smoke_on_frame, NULL, node_mem, sizeof(node_mem) / zslay_frame_node_get_size(),
        ZSLAY_ROLE_SERVER, 1024, 1024);
    if (conn == NULL) return 5;

    for (unsigned attempt = 0; attempt < 16 && state.frame_seen == 0; attempt++) {
        int result = zslay_conn_recv(conn);
        if (result != ZSLAY_PROGRESS && result != ZSLAY_OK) return 6;
    }
    if (state.frame_seen == 0) return 7;
    if (state.opcode != 0x9) return 8;
    if (state.payload_len != 0) return 9;
    if (state.end_of_frame != 1) return 10;

    static const uint8_t text[] = { 'h', 'i' };
    if (zslay_conn_prepare_frame(conn, node_mem, 1, 0x1, text, sizeof(text), 0) != ZSLAY_OK) return 11;
    if (zslay_conn_queue_frame(conn, node_mem) != ZSLAY_OK) return 12;
    if (zslay_conn_send(conn) != ZSLAY_OK) return 13;

    if (state.sent_len != 4) return 14;
    if (state.sent[0] != 0x81 || state.sent[1] != 0x02) return 15;
    if (state.sent[2] != 'h' || state.sent[3] != 'i') return 16;

    if (zslay_conn_reset(conn) != ZSLAY_OK) return 17;
    if (zslay_conn_reset(NULL) != ZSLAY_ERR_INVALID_ARGUMENT) return 18;
    if (zslay_conn_reset((void *)(conn_mem + 1)) != ZSLAY_ERR_INVALID_ARGUMENT) return 19;

    return 0;
}
