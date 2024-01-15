"""
Godot 3D Shooter Project Server Manager

This will handle incoming requests to create games and spawn Godot processes to handle them.
"""
from functools import partial
import json
import requests
from http.server import BaseHTTPRequestHandler, HTTPServer

from godot_game import GameManager
import gmp


PROTOCOL_VERSION = 1


class APIHandler(BaseHTTPRequestHandler):
    def __init__(self, game_manager: GameManager, *args, **kwargs) -> None:
        self.game_manager = game_manager
        super().__init__(*args, **kwargs)

    def do_GET(self):
        data = self.get_dict()
        if data is None:
            self.send_complete_error(400, "Invalid JSON format.")
            return

        protocol_version = data.get("protocol_version", 0)
        if protocol_version != PROTOCOL_VERSION:
            self.send_complete_error(400, f"Protocol version mismatch (server: {PROTOCOL_VERSION}, client: {protocol_version})")
            return

        request = data.get("request", "")
        if request == "list_games":
            code, response = self.game_manager.list_games()
            self.send_complete_response(code, response)
        else:
            self.send_complete_error(400, "Invalid request.")

    def do_POST(self):
        data = self.get_dict()
        if data is None:
            self.send_complete_error(400, "Invalid JSON format.")
            return

        protocol_version = data.get("protocol_version", 0)
        if protocol_version != PROTOCOL_VERSION:
            self.send_complete_error(400, f"Protocol version mismatch (server: {PROTOCOL_VERSION}, client: {protocol_version})")
            return

        action = data.get("action", "")
        if action == "create_game":
            if "server_name" not in data or "max_players" not in data:
                self.send_complete_error(400, "Missing required fields.")
                return
            code, response = self.game_manager.create_game(data["server_name"], data["max_players"])
            self.send_complete_response(code, response)
        elif action == "update_player_count":
            if "game_id" not in data or "new_player_count" not in data:
                self.send_complete_error(400, "Missing required fields.")
                return
            code, response = self.game_manager.update_player_count(data["game_id"], data["new_player_count"])
            self.send_complete_response(code, response)
        else:
            self.send_complete_error(400, "Invalid action type")


    def get_dict(self) -> dict:
        length = int(self.headers.get('content-length'))
        field_data = self.rfile.read(length)
        try:
            return json.loads(str(field_data, "utf-8"))
        except json.JSONDecodeError:
            return None

    def send_complete_error(self, code: int, error: str):
        self.send_complete_response(code, {"error": error})

    def send_complete_response(self, code: int, message: dict):
        print(message)
        message_bytes = json.dumps(message).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-type", "application/json")
        self.send_header("Content-length", len(message_bytes))
        self.end_headers()
        self.wfile.write(message_bytes)


def main():
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

    print("Serving on localhost:6789")

    try:
        api_server.serve_forever()
    except KeyboardInterrupt:
        pass

    api_server.server_close()


if __name__ == "__main__":
    main()
