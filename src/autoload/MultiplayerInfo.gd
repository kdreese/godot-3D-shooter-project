extends Node


func _ready():
	var error := get_tree().connect("network_peer_connected", self, "_player_connected")
	assert(not error)
	error = get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	assert(not error)
	error = get_tree().connect("connected_to_server", self, "_connected_ok")
	assert(not error)
	error = get_tree().connect("connection_failed", self, "_connected_fail")
	assert(not error)
	error = get_tree().connect("server_disconnected", self, "_server_disconnected")
	assert(not error)


# Player info, associate ID to data
var player_info := {}
# Info we send to other players
var my_info := { name = "Johnson Magenta", favorite_color = Color8(255, 0, 255) }


func _player_connected(id):
	# Called on both clients and server when a peer connects. Send my info to it.
	print("Player id %d connected" % [id])
	rpc_id(id, "register_player", my_info)


func _player_disconnected(id):
	print("Player id %d disconnected" % [id])
	# warning-ignore:return_value_discarded
	player_info.erase(id) # Erase player from info.
	# Call function to update lobby UI here
	var game := get_tree().get_root().get_node_or_null("Game") as Node
	if game != null:
		var scoreboard := game.get_node("UI/Scoreboard") as Scoreboard
		scoreboard.remove_player(id)


func _connected_ok():
	print("Connected ok")
	# Only called on clients, not server. Will go unused; not useful here.


func _server_disconnected():
	print("Server disconnected")
	pass # Server kicked us; show error and abort.


func _connected_fail():
	print("Connection failed")
	pass # Could not even connect to server; abort.


remote func register_player(info):
	# Get the id of the RPC sender.
	var id = get_tree().get_rpc_sender_id()
	# Store the info
	player_info[id] = info
	print("Player %d has info %s" % [id, info])

	# Call function to update lobby UI here
	var game := get_tree().get_root().get_node_or_null("Game") as Node
	if game != null:
		game.spawn_peer_player(id)
		var scoreboard := game.get_node("UI/Scoreboard") as Scoreboard
		scoreboard.add_player(id)
		if get_tree().is_network_server():
			scoreboard.rpc("update_score", scoreboard.current_score)
