class_name MultiplayerInfoClass
extends Node


signal latency_updated


const DEFAULT_NAME := "Guest"
const DEFAULT_COLOR := Color8(255, 255, 255)


enum GameMode {
	FFA, # Free-for-all.
	TEAM # Team battle.
}

# Player info, associate ID to data
var player_info := {}
# Map from player ID to latency.
var player_latency := {}
# Map from player ID to time a ping was sent, for outstanding pings.
var outstanding_pings := {}

# Variable holding the current game mode, as an ID.
var game_mode := GameMode.FFA as int
var dedicated_server := false


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
	if OS.has_feature("Server") or "--dedicated" in OS.get_cmdline_args():
		run_dedicated_server()


func run_dedicated_server() -> void:
	dedicated_server = true
	print("Starting dedicated server")
	var args := OS.get_cmdline_args()
	for i in range(args.size()):
		if args[i] == "--port":
			if i == args.size() - 1:
				print("Error, please specify a port number after --port")
				get_tree().quit(1)
				return
			var port_arg := args[i + 1]
			if not port_arg.is_valid_integer():
				print("Error, \"%s\" is not a valid integer" % port_arg)
				get_tree().quit(1)
				return
			var new_port := int(port_arg)
			if new_port < 0 or new_port > 65535:
				print("Error, port must be between 0 and 65535, found %d" % new_port)
				get_tree().quit(1)
				return
			Global.config.port = new_port
		elif args[i] == "--max-players":
			if i == args.size() - 1:
				print("Error, please specify a max player number after --max-players")
				get_tree().quit(1)
				return
			var max_players_arg := args[i + 1]
			if not max_players_arg.is_valid_integer():
				print("Error, \"%s\" is not a valid integer" % max_players_arg)
				get_tree().quit(1)
				return
			var new_max_players := int(max_players_arg)
			if new_max_players < 2 or new_max_players > 8:
				print("Error, max_players must be between 2 and 8, found %d" % new_max_players)
				get_tree().quit(1)
				return
			Global.config.max_players = new_max_players
	var error := host_server()
	if error:
		print("Error, unable to host a server")
		get_tree().quit(1)
		return
	print("Hosting a dedicated server on port %d" % Global.config.port)
	get_tree().change_scene("res://src/states/Lobby.tscn")


# Attempts to create a server and sets the network peer if successful
func host_server() -> int:
	var peer := NetworkedMultiplayerENet.new()
	var error := peer.create_server(Global.config.port, Global.config.max_players)
	if not error:
		get_tree().set_network_peer(peer)
	return error


# Attempts to create a client peer and join a server
func join_server() -> int:
	var peer := NetworkedMultiplayerENet.new()
	var error := peer.create_client(Global.config.address, Global.config.port)
	if not error:
		get_tree().set_network_peer(peer)
	return error


func _player_connected(id: int):
	# Called on both clients and server when a peer connects. Send my info to it.
	print("Player id %d connected" % [id])
	if not dedicated_server:
		rpc_id(id, "register_player", Global.config.name)


func _player_disconnected(id: int):
	print("Player id %d disconnected" % [id])
	player_info.erase(id) # Erase player from info.

	# Call function to update lobby UI here
	var lobby := get_tree().get_root().get_node_or_null("Lobby") as Node
	if lobby != null:
		lobby.player_disconnected(id)

	var game := get_tree().get_root().get_node_or_null("Game") as Node
	if game:
		game.remove_peer_player(id)
		if player_info.size() == 0:
			game.end_of_match()


func _connected_ok():
	print("Connected ok")
	# Only called on clients, not server
	var menu := get_tree().get_root().get_node_or_null("Menu") as Node
	if menu:
		menu.session_joined()


func _server_disconnected():
	OS.alert("Server disconnected")
	player_info = {}
	var error := get_tree().change_scene("res://src/states/Menu.tscn")
	assert(not error)
	call_deferred("_cleanup_network_peer")


func _connected_fail():
	OS.alert("Could not connect to server!")
	var menu := get_tree().get_root().get_node_or_null("Menu") as Node
	if menu:
		menu.enable_play_buttons()
	call_deferred("_cleanup_network_peer")


func _cleanup_network_peer() -> void:
	get_tree().set_network_peer(null)


# Initiate a ping handshake.
func send_ping(id: int) -> void:
	var send_time = OS.get_system_time_msecs()
	outstanding_pings[id] = send_time
	rpc_id(id, "ping")


# Send a ping response back to the server.
remote func ping() -> void:
	rpc_id(get_tree().get_rpc_sender_id(), "pong")


# Handle a ping response from a client.
remote func pong() -> void:
	var id = get_tree().get_rpc_sender_id()
	if not (id in outstanding_pings):
		return
	var receive_time = OS.get_system_time_msecs()
	player_latency[id] = (receive_time - outstanding_pings[id]) / 2.0
	outstanding_pings.erase(id)
	emit_signal("latency_updated")


remote func register_player(name: String):
	# Get the id of the RPC sender.
	var id := get_tree().get_rpc_sender_id()
	# Store the info
	player_info[id] = {
		"id": id,
		"name": name,
		"latest_score": null,
	}
	print("Player info: ", player_info)

	# Call function to update lobby UI here
	var lobby := get_tree().get_root().get_node_or_null("Lobby") as Node
	if lobby != null:
		lobby.player_connected(id, player_info[id])

	var game := get_tree().get_root().get_node_or_null("Game") as Node
	if game != null:
		game.spawn_peer_player(id)


# Disconnect from the session.
func disconnect_from_session() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cleanup_network_peer()
	player_info = {}
	if dedicated_server:
		get_tree().quit()
	else:
		var error := get_tree().change_scene("res://src/states/Menu.tscn")
		assert(not error)


# Get the player id for this instance. If connected to a server, this is equivalent to the unique
# network id. If in free play, this will always return 1.
func get_player_id() -> int:
	if get_tree().has_network_peer():
		return get_tree().get_network_unique_id()
	else:
		return 1
