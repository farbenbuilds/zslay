#ifndef ZSLAY_H
#define ZSLAY_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define ZSLAY_ABI_VERSION 1

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
    ZSLAY_ERR_REENTRANT = -5,
    ZSLAY_ERR_INVALID_UTF8 = -6,
};

enum zslay_opcode {
    ZSLAY_OPCODE_CONTINUATION = 0x0,
    ZSLAY_OPCODE_TEXT = 0x1,
    ZSLAY_OPCODE_BINARY = 0x2,
    ZSLAY_OPCODE_CLOSE = 0x8,
    ZSLAY_OPCODE_PING = 0x9,
    ZSLAY_OPCODE_PONG = 0xa,
};

/*
 * Callbacks run synchronously on the thread that calls zslay_conn_recv or
 * zslay_conn_send. A callback must not retain the buffer it receives. Do not
 * call recv, send, reset, reset_tx, init, or deinit from a callback. on_frame may
 * call prepare_frame and queue_frame to enqueue a response.
 */
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

/* Must fill exactly len bytes from a cryptographically secure source. */
typedef int (*zslay_gen_mask_callback)(
    uint8_t *buf,
    size_t len,
    void *user_data
);

/*
 * Delivers one transient payload chunk. payload is NULL only when len is zero.
 * payload_offset is relative to the current frame payload, frame_len is the
 * current frame payload length, and end_of_frame marks the final chunk. The
 * WebSocket fin bit describes message fragmentation only.
 */
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
uint32_t zslay_abi_version(void);

/*
 * mem must provide zslay_conn_get_size() bytes at zslay_conn_get_align().
 * tx_buffer must provide tx_node_count frame nodes at
 * zslay_frame_node_get_align(). tx_buffer may be NULL when tx_node_count is
 * zero. The two storage regions must not overlap. Both regions are owned by
 * zslay until zslay_conn_deinit or reinitialization.
 *
 * Clients must provide gen_mask_fn. max_frame_len and max_message_len must not
 * exceed 2^63 - 1. Returns NULL on invalid arguments.
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
 * Invalidates the handle without releasing caller-owned storage. Returns
 * ZSLAY_ERR_INVALID_ARGUMENT for a null, misaligned, or already retired handle.
 */
int zslay_conn_deinit(void *conn);

/*
 * Performs at most one transport read and one frame callback. ZSLAY_PROGRESS
 * means bytes were consumed or a callback ran; call again to continue.
 * ZSLAY_OK means no transport data was available.
 */
int zslay_conn_recv(void *conn);

/*
 * Sends queued frames with bounded work per call. ZSLAY_PROGRESS means the
 * callback budget expired while frames remain; call again. ZSLAY_OK means the
 * queue drained or the transport would block. Use zslay_conn_tx_pending to
 * decide when borrowed payload memory may be released.
 */
int zslay_conn_send(void *conn);

/*
 * Abandons partial receive state, including an active fragmented message. The
 * transport is not touched. Use this only at a frame boundary or when the
 * connection is being discarded, because unconsumed bytes cannot be resynced.
 */
int zslay_conn_reset(void *conn);

/* Drops queued transmit frames and any open transmit fragment. */
int zslay_conn_reset_tx(void *conn);

/* Stores the number of frames whose borrowed payloads remain live. */
int zslay_conn_tx_pending(void *conn, size_t *pending);

/*
 * node must provide zslay_frame_node_get_size() bytes at
 * zslay_frame_node_get_align(). Node storage is opaque: initialize it only
 * with this function and do not reuse it while the frame is queued.
 *
 * payload remains borrowed and must stay immutable until the queued node has
 * been fully sent. Clients must mask; servers must not mask. Generates an
 * error if the frame direction or frame/message limits are invalid. Close
 * payloads are validated before the header is written.
 *
 * Returns ZSLAY_ERR_INVALID_ARGUMENT for invalid opcodes, mask direction,
 * limits, or close length/code; ZSLAY_ERR_INVALID_UTF8 for a bad close reason;
 * and ZSLAY_ERR_PROTOCOL for an invalid frame state. ZSLAY_ERR_CALLBACK is
 * returned when the mask generator fails.
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

/*
 * Validates and appends a node produced by zslay_conn_prepare_frame. Returns
 * ZSLAY_ERR_INVALID_ARGUMENT for a malformed node, mask direction, or limit;
 * ZSLAY_ERR_PROTOCOL for invalid fragment ordering; and ZSLAY_ERR_QUEUE_FULL
 * when the caller-provided ring is full.
 */
int zslay_conn_queue_frame(void *conn, void *node);

/*
 * Validates a close frame payload. Returns ZSLAY_OK, ZSLAY_ERR_PROTOCOL for a
 * bad length or status code, ZSLAY_ERR_INVALID_UTF8 for a bad reason, or
 * ZSLAY_ERR_INVALID_ARGUMENT for a null pointer with nonzero length.
 */
int zslay_validate_close_payload(const uint8_t *payload, size_t payload_len);

#ifdef __cplusplus
}
#endif

#endif
