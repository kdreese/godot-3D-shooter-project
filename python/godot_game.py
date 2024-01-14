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
                fp = open("/var/log/godot.log", "w")
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
                response = {
                    "host": "192.168.1.4", #self.ip
                    "port": port
                }
                return 200, json.dumps(response)
            elif ret == 1:
                print("Bad arguments passed into godot process.")
                return 400, {"error": "Exception occurred creating Godot process."}

        return 400, {"error": "No available ports."}
