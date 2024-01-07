"""
Godot 3D Shooter Project Server Manager

This will handle incoming requests to create games and spawn Godot processes to handle them.
"""
import asyncio


async def handle_request(reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
    data = await reader.read()
    message = data.decode("ascii")

    print(f"Received '{message}'")


async def main():
    server = await asyncio.start_server(handle_request, 'localhost', 6969)

    addr = server.sockets[0].getsockname()
    print(f'Serving on {addr}')

    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
