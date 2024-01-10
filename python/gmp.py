"""
Game Management Protocol (GMP) Implementation
"""

PROTOCOL_VERSION = 1 ## GMP version.


def get_packet_length(header: bytes) -> int:
    """
    Get the total packet length (including the 2 byte header).
    """
    return ((header[0] & 0xF) << 8) | header[1]


def handle_request(packet: bytes) -> bytes:
    """
    Handle an incoming GMP request.
    """

    # Check for version mismatch
    version = packet[0] >> 4

    if version != PROTOCOL_VERSION:
        print(f"Version mismatch: expected {PROTOCOL_VERSION}, received {version}.")
        return complete_packet(b"\0")

    message = packet[2:].decode('ascii')

    print(f"Received: '{message}'")

    new_message = message[::-1]

    print(f"Sending: {new_message}")

    return complete_packet(bytes(new_message.encode('ascii')))


def complete_packet(packet: bytes) -> bytes:
    """
    Complete a packet by adding the header.
    """
    # Need to add 2 to account for the header.
    length = len(packet) + 2

    output = []
    output.append(((PROTOCOL_VERSION & 0xF) << 4) | ((length & 0xF00) >> 8))
    output.append(length & 0xFF)
    output += packet

    return bytes(output)
