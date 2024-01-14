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


class APIHandler(BaseHTTPRequestHandler):
    def __init__(self, game_manager: GameManager, *args, **kwargs) -> None:
        self.game_manager = game_manager
        super().__init__(*args, **kwargs)

    def do_GET(self):
        self.do_POST()
        pass

    def do_POST(self):
        data = self.get_dict()
        if data is None:
            self.send_complete_error(400, "Invalid JSON format.")
            return

        code, response = self.game_manager.create_game(data["server_name"], data["max_players"])
        self.send_complete_response(code, response)


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
        message_bytes = str(message).encode("utf-8")
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
