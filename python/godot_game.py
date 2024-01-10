"""
API for creating and managing games.
"""
import pathlib
import subprocess
import time


AVAILABLE_PORTS = range(42000, 42011)
ROOT_FOLDER = pathlib.Path(__file__).parent.parent


def create_game(max_players: int) -> int:
    global processes
    for port in AVAILABLE_PORTS:
        # Create the godot process.
        print("Creating process.")
        try:
            p = subprocess.Popen(["/Applications/Godot.app/Contents/MacOS/Godot", "--dedicated", "--port", f"{port}", "--max_players", f"{max_players}"], cwd=ROOT_FOLDER.as_posix(), stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE)
        except Exception as e:
            print(e)
        time.sleep(1.0)
        ret = p.poll()
        if ret is None:
            return port
        elif ret == 1:
            print("Bad arguments passed into godot process.")
            break

    return 0
