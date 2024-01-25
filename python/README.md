## Master Server Script

To run the master server, create a virtual environment, and install the dependencies using
`pip install -r requirements.txt`. After this, run `python main.py` from this folder.

The Godot code assumes that this server is hosted at api.admoore.xyz/godot-3d-shooter. To modify this, edit the
`HOST` field in `src/autoload/gmp_client.gd`

By default this server will run on port 6789, and the Godot processes it spawns will listen on ports 42000-42010.
