"""
Godot 3D Shooter Project Server Manager

This will handle incoming requests to create games and spawn Godot processes to handle them.
"""
import asyncio
import pathlib
import signal
import socket
import subprocess
import sys
import time

from typing import List

import gmp



async def main():
    server = await asyncio.start_server(handle_request, 'localhost', 6789)

    server.sockets[0].setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

    addr = server.sockets[0].getsockname()
    print(f'Serving on {addr}')

    async with server:
        await server.serve_forever()


async def handle_request(reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
    data = await reader.read(2)

    # Subtract 2 to account for the header size.
    remaining_length = gmp.get_packet_length(data) - 2

    data += await reader.read(remaining_length)

    response = gmp.handle_request(data)

    writer.write(response)

    await writer.drain()


if __name__ == "__main__":
    asyncio.run(main())
