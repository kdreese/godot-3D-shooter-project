"""
API for creating and managing games.
"""
import json
import pathlib
import subprocess
import time
from typing import Any, Dict, Tuple


AVAILABLE_PORTS = range(42000, 42011)
ROOT_FOLDER = pathlib.Path(__file__).parent.parent


class Game:
    """
    Class for holding game information. See also multiplayer.gd:GameParams.
    """

    def __init__(self, process: subprocess.Popen, game_id: int, name: str, max_players: int, host: str,
                 port: int) -> None:
        self.process = process
        self.game_id = game_id
        self.name = name
        self.max_players = max_players
        self.current_players = 0
        self.private = False
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

    def is_running(self) -> bool:
        poll = self.process.poll()
        if poll is None:
            # No return code has been sent, so the process is still running.
            return True


class GameManager:

    def __init__(self, ip: str) -> None:
        self.games = []
        self.ip = ip
        self.next_game_id = 1


    def create_game(self, data: Dict[str, Any]) -> Tuple[int, dict]:
        """
        Create a new game.
        """
        if not data.keys() >= {"server_name", "max_players"}:
            return 400, {"error": "Missing required fields."}

        server_name = data["server_name"]
        max_players = int(data["max_players"])

        port = None
        for test_port in AVAILABLE_PORTS:
            if any(game.port == test_port for game in self.games):
                continue
            else:
                port = test_port
                break

        if port is None:
            return 400, {"error": "No available ports."}

        # Create the godot process.
        print(f"Creating process on port {port}.")
        try:
            (ROOT_FOLDER / "server_logs").mkdir(exist_ok=True)
            fp = open((ROOT_FOLDER / "server_logs" / f"godot_{self.next_game_id}.log").as_posix(), "w")
            args = [
                    ".exports/linux_server/godot-3d-shooter.x86_64", "--headless", "--",
                    "--dedicated",
                    "--server-name", f"{server_name}",
                    "--port", f"{port}",
                    "--max-players", f"{max_players}",
                    "--game-id", f"{self.next_game_id}"
            ],

            if data["password_hash"]:
                args += ["--password-hash", data["password_hash"]]

            process = subprocess.Popen(
                args, cwd=ROOT_FOLDER.as_posix(),
                stdout=fp, stderr=fp, stdin=subprocess.PIPE
            )
        except Exception as e:
            print(e)
            return 400, {"error": "Exception occurred creating Godot process."}
        time.sleep(1.0)
        ret = process.poll()
        if ret is None:
            game = Game(process, self.next_game_id, server_name, max_players, self.ip, port)
            if data["password_hash"]:
                game.private = True
            self.next_game_id += 1
            self.games.append(game)
            response = {
                "host": self.ip,
                "port": port
            }
            return 200, response
        elif ret == 1:
            return 400, {"error": "Exception occurred creating Godot process."}

    def list_games(self) -> Tuple[int, dict]:
        """
        List all the current games.
        """
        games = []
        games_to_remove = []
        for game in self.games:
            if game.is_running():
                games.append(game.serialize())
            else:
                games_to_remove.append(game)

        for game in games_to_remove:
            self.games.remove(game)

        output = {
            "num_games": len(games),
            "games": games
        }

        return 200, output

    def update_player_count(self, data: Dict[str, Any]) -> Tuple[int, dict]:
        """
        Update the number of currently connected players.
        """
        if not data.keys() >= {"game_id", "new_player_count"}:
            return 400, {"error": "Missing required fields."}

        game_id = int(data["game_id"])
        new_player_count = int(data["new_player_count"])

        for game in self.games:
            if game.game_id == game_id:
                game.current_players = new_player_count
                return 200, {}

        return 400, {"error": "No game with that ID exists."}

    def stop_game(self, data: Dict[str, Any]) -> Tuple[int, dict]:
        """
        Stop a game.
        """
        if not data.keys() >= {"game_id"}:
            return 400, {"error": "Missing required fields."}

        game_id = int(data["game_id"])

        idx_to_remove = None
        for idx, game in enumerate(self.games):
            if game.game_id == game_id:
                idx_to_remove = idx

        if idx_to_remove is not None:
            self.games.pop(idx)
            return 200, {}
        else:
            return 400, {"error": "No game with that ID exists."}
