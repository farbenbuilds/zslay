#ifndef ZSLAY_H
#define ZSLAY_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum zslay_endpoint_role {
    ZSLAY_ROLE_CLIENT = 0,
    ZSLAY_ROLE_SERVER = 1,
};

enum zslay_result {
    ZSLAY_OK = 0,
    ZSLAY_PROGRESS = 1,
    ZSLAY_ERR_PROTOCOL = -1,
    ZSLAY_ERR_CALLBACK = -2,
    ZSLAY_ERR_INVALID_ARGUMENT = -3,
    ZSLAY_ERR_QUEUE_FULL = -4,
};

typedef ptrdiff_t (*zslay_recv_callback)(
    uint8_t *buf,
    size_t len,
    void *user_data
);

typedef ptrdiff_t (*zslay_send_callback)(
    const uint8_t *buf,
    size_t len,
    void *user_data
);

typedef int (*zslay_gen_mask_callback)(
    uint8_t *buf,
    size_t len,
    void *user_data
);

typedef void (*zslay_on_frame_callback)(
    uint8_t opcode,
    uint8_t fin,
    const uint8_t *payload,
    size_t len,
    uint64_t payload_offset,
    uint64_t frame_len,
    uint8_t end_of_frame,
    void *user_data
);

size_t zslay_conn_get_size(void);
size_t zslay_conn_get_align(void);
size_t zslay_frame_node_get_size(void);
size_t zslay_frame_node_get_align(void);

/*
 * mem must provide zslay_conn_get_size() bytes at zslay_conn_get_align().
 * tx_buffer must provide tx_node_count frame nodes at the reported alignment.
 * Both storage regions are exclusively owned by zslay until the connection is retired.
 * max_frame_len and max_message_len must not exceed 2^63 - 1.
 */
void *zslay_conn_init(
    void *mem,
    void *user_data,
    zslay_recv_callback recv_fn,
    zslay_send_callback send_fn,
    zslay_on_frame_callback on_frame_fn,
    zslay_gen_mask_callback gen_mask_fn,
    void *tx_buffer,
    size_t tx_node_count,
    uint8_t role,
    uint64_t max_frame_len,
    uint64_t max_message_len
);

/*
 * Performs at most one transport read and one frame callback. ZSLAY_PROGRESS means
 * state advanced; call again to continue. Callback payload is valid only for
 * the duration of on_frame_fn. end_of_frame, not fin, marks the final chunk.
 */
int zslay_conn_recv(void *conn);

int zslay_conn_send(void *conn);

/*
 * Abandons partial receive state, including an active fragmented message.
 * The transport is not touched. Returns ZSLAY_ERR_INVALID_ARGUMENT for a null
 * or misaligned handle.
 */
int zslay_conn_reset(void *conn);

/*
 * payload remains borrowed and must stay immutable until the queued node has
 * been fully sent. Clients must mask; servers must not mask. The mask callback
 * must fill exactly len random bytes and return zero on success.
 */
int zslay_conn_prepare_frame(
    void *conn,
    void *node,
    uint8_t fin,
    uint8_t opcode,
    const uint8_t *payload,
    size_t payload_len,
    uint8_t is_masked
);

int zslay_conn_queue_frame(void *conn, void *node);

#ifdef __cplusplus
}
#endif

#endif
