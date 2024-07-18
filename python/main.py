"""
Godot 3D Shooter Project Server Manager

This will handle incoming requests to create games and spawn Godot processes to handle them.
"""
from functools import partial
import json
from typing import Any
import requests
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs
import ssl

from godot_game import GameManager


## The GMP protocol version.
PROTOCOL_VERSION = 1


class APIHandler(BaseHTTPRequestHandler):
    def __init__(self, game_manager: GameManager, *args, **kwargs) -> None:
        self.game_manager = game_manager
        super().__init__(*args, **kwargs)

    # Ignore log messages so they don't pollute stdout.
    def log_message(self, format: str, *args: Any) -> None:
        pass

    def do_GET(self):
        # Check if this request comes from a godot game (not secure).
        user_agent = self.headers.get("User-Agent", "")
        if user_agent != "Godot":
            self.send_complete_error(400, "Invalid User-Agent")
            return

        parse_result = urlparse(self.path)
        query = parse_qs(parse_result.query)

        # Ensure protocol version matches.
        protocol_version = int(query.get("protocol_version", [0])[0])
        if protocol_version != PROTOCOL_VERSION:
            self.send_complete_error(400, f"Protocol version mismatch (server: {PROTOCOL_VERSION}, client: {protocol_version})")
            return

        if parse_result.path == "/games":
            code, response = self.game_manager.list_games()
            self.send_complete_response(code, response)
        else:
            self.send_complete_error(400, "Invalid request.")

    def do_POST(self):
        # Check if this request comes from a godot game (not secure).
        user_agent = self.headers.get("User-Agent", "")
        if user_agent != "Godot":
            self.send_complete_error(400, "Invalid User-Agent")
            return

        # Get the body of the POST request.
        data = self.get_dict()
        if data is None:
            self.send_complete_error(400, "Invalid JSON format.")
            return

        # Ensure protocol version match.
        protocol_version = data.get("protocol_version", 0)
        if protocol_version != PROTOCOL_VERSION:
            self.send_complete_error(400, f"Protocol version mismatch (server: {PROTOCOL_VERSION}, client: {protocol_version})")
            return

        action = data.get("action", "")
        if action == "create_game":
            code, response = self.game_manager.create_game(data)
            self.send_complete_response(code, response)
        elif action == "update_player_count":
            code, response = self.game_manager.update_player_count(data)
            self.send_complete_response(code, response)
        elif action == "stop_game":
            code, response = self.game_manager.stop_game(data)
            self.send_complete_response(code, response)
        else:
            self.send_complete_error(400, "Invalid action type")


    # Helper to parse request bodies.
    def get_dict(self) -> dict:
        length = int(self.headers.get('content-length', 0))
        field_data = self.rfile.read(length)
        try:
            return json.loads(str(field_data, "utf-8"))
        except json.JSONDecodeError:
            return None

    def send_complete_error(self, code: int, error: str):
        self.send_complete_response(code, {"error": error})

    def send_complete_response(self, code: int, message: dict):
        message_bytes = json.dumps(message).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-type", "application/json")
        self.send_header("Content-length", len(message_bytes))
        self.end_headers()
        self.wfile.write(message_bytes)


def main():
    # TODO: this might stop working if the DHCP lease on my router expires and I get a new one.
    response = requests.get("https://ipinfo.io/json", verify=True)
    if response.status_code != 200:
        print("Could not get local IP.")
        return

    ip_str = response.json()['ip']
    game_manager = GameManager(ip_str)

    # Hack to add state to handler.
    # https://stackoverflow.com/questions/21631799/how-can-i-pass-parameters-to-a-requesthandler
    handler = partial(APIHandler, game_manager)

    api_server = HTTPServer(("0.0.0.0", 6789), handler)

    print("Serving on port 6789")

    try:
        api_server.serve_forever()
    except KeyboardInterrupt:
        pass

    api_server.server_close()


if __name__ == "__main__":
    main()
