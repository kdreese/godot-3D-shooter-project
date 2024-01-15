"""
API for creating and managing games.
"""
import json
import pathlib
import subprocess
import time
from typing import Tuple


AVAILABLE_PORTS = range(42000, 42011)
ROOT_FOLDER = pathlib.Path(__file__).parent.parent

class Game:
    def __init__(self, game_id: int, name: str, max_players: int, host: str, port: int) -> None:
        self.game_id = game_id
        self.name = name
        self.max_players = max_players
        self.current_players = 0
        self.host = host
        self.port = port

    def serialize(self) -> dict:
        return {
            "game_id": self.game_id,
            "server_name": self.name,
            "max_players": self.max_players,
            "current_players": self.current_players,
            "host": self.host,
            "port": self.port
        }


class GameManager:

    def __init__(self, ip: str) -> None:
        self.games = []
        self.ip = ip
        self.next_game_id = 1


    def create_game(self, server_name: str, max_players: int) -> Tuple[int, dict]:
        """
        Create a new games.
        """
        for port in AVAILABLE_PORTS:
            # Create the godot process.
            print("Creating process.")
            try:
                fp = open("/opt/godot/logs/godot.log", "w")
                p = subprocess.Popen(
                    [
                        "/opt/godot/godot", "--headless", "--",
                        "--dedicated",
                        "--server-name", f"{server_name}",
                        "--port", f"{port}",
                        "--max_players", f"{max_players}"
                    ],
                    cwd=ROOT_FOLDER.as_posix(),
                    stdout=fp, stderr=fp, stdin=subprocess.PIPE
                )
            except Exception as e:
                print(e)
                return 400, {"error": "Exception occurred creating Godot process."}
            time.sleep(1.0)
            ret = p.poll()
            if ret is None:
                game = Game(self.next_game_id, server_name, max_players, self.ip, port)
                self.games.append(game)
                response = {
                    "host": "192.168.1.4", #self.ip
                    "port": port
                }
                return 200, json.dumps(response)
            elif ret == 1:
                print("Bad arguments passed into godot process.")
                return 400, {"error": "Exception occurred creating Godot process."}

        return 400, {"error": "No available ports."}

    def list_games(self) -> Tuple[int, dict]:
        """
        List all the current games.
        """
        games = []
        for game in self.games:
            games.append(game.serialize())

        output = {
            "num_games": len(games),
            "games": games
        }

        return 200, output

    def update_player_count(self, game_id: int, new_player_count: int) -> Tuple[int, dict]:
        for game in self.games:
            if game.game_id == game_id:
                game.current_players == new_player_count
                return 200, {}

        return 400, {"error": "No game with that ID exists."}
