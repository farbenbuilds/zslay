import asyncio
import base64
import hashlib
import struct
import unittest

import benchmark_echo


class EchoBenchmarkTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.corrupt = False
        self.bad_accept = False
        self.server = await asyncio.start_server(self.handle, "127.0.0.1", 0)
        self.port = self.server.sockets[0].getsockname()[1]

    async def asyncTearDown(self):
        self.server.close()
        await self.server.wait_closed()

    async def handle(self, reader, writer):
        try:
            request = (await reader.readuntil(b"\r\n\r\n")).decode("ascii")
            key = next(line.split(":", 1)[1].strip() for line in request.split("\r\n")
                       if line.lower().startswith("sec-websocket-key:"))
            accept = base64.b64encode(hashlib.sha1(key.encode() + benchmark_echo.GUID).digest()).decode()
            if self.bad_accept:
                accept = "invalid"
            writer.write(("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n"
                          "Connection: Upgrade\r\nSec-WebSocket-Accept: " + accept + "\r\n\r\n").encode())
            await writer.drain()
            while True:
                head = await reader.readexactly(2)
                if head[0] != 0x82 or not head[1] & 0x80:
                    return
                size = head[1] & 0x7F
                if size == 126:
                    size = struct.unpack("!H", await reader.readexactly(2))[0]
                elif size == 127:
                    size = struct.unpack("!Q", await reader.readexactly(8))[0]
                mask = await reader.readexactly(4)
                encoded = await reader.readexactly(size)
                payload = bytes(value ^ mask[index & 3] for index, value in enumerate(encoded))
                if self.corrupt:
                    payload = bytes((payload[0] ^ 1,)) + payload[1:]
                header = bytes((0x82, size)) if size < 126 else bytes((0x82, 126)) + struct.pack("!H", size)
                writer.write(header + payload)
                await writer.drain()
        except (asyncio.IncompleteReadError, ConnectionError):
            pass
        finally:
            writer.close()
            await writer.wait_closed()

    async def test_valid_echo_reports_three_samples(self):
        result = await benchmark_echo.run(self.port, 2, 128, 0.02, 0.02)
        self.assertEqual(result["benchmark"], "zslay-echo")
        self.assertEqual(len(result["samples"]), 3)
        self.assertEqual(result["errors"], 0)
        self.assertTrue(all(item["operations"] > 0 for item in result["samples"]))
        self.assertTrue(result["rtt_ns"]["p99"] >= result["rtt_ns"]["p50"])

    async def test_rejects_invalid_accept(self):
        self.bad_accept = True
        with self.assertRaisesRegex(ValueError, "Sec-WebSocket-Accept"):
            await benchmark_echo.run(self.port, 1, 128, 0.01, 0.01)

    async def test_rejects_corrupted_echo(self):
        self.corrupt = True
        with self.assertRaisesRegex(ValueError, "failed or empty warmup"):
            await benchmark_echo.run(self.port, 1, 128, 0.01, 0.01)


if __name__ == "__main__":
    unittest.main()
