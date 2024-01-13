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


class GameManager:

    def __init__(self, ip: str) -> None:
        self.ip = ip


    def create_game(self, server_name: str, max_players: int) -> Tuple[int, str]:
        for port in AVAILABLE_PORTS:
            # Create the godot process.
            print("Creating process.")
            try:
                p = subprocess.Popen(["/Applications/Godot.app/Contents/MacOS/Godot", "--headless", "--dedicated", "--port", f"{port}", "--max_players", f"{max_players}"], cwd=ROOT_FOLDER.as_posix(), stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE)
            except Exception as e:
                print(e)
                return 400, "Exception occured creating Godot process."
            time.sleep(1.0)
            ret = p.poll()
            if ret is None:
                response = {
                    "host": "localhost", #self.ip
                    "port": port
                }
                return 200, json.dumps(response)
            elif ret == 1:
                print("Bad arguments passed into godot process.")
                return 400, "Exception occured creating Godot process."

        return 400, "No available ports."
