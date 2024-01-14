class_name MultiplayerInfoClass
extends Node


signal latency_updated
signal connection_failed
signal connection_successful
signal session_joined
signal player_connected
signal player_disconnected
signal server_disconnected
signal all_players_ready


const DEFAULT_NAME := "Guest"
const DEFAULT_COLOR := Color8(255, 255, 255)


enum GameMode {
	FFA, # Free-for-all.
	TEAM # Team battle.
}

## Game information, shared between players.
class GameInfo:
	var server_name: String = ""
	var mode: GameMode = GameMode.FFA

	func serialize() -> Dictionary:
		return {
			"server_name": server_name,
			"mode": mode as int
		}

	func deserialize(data: Dictionary) -> void:
		server_name = data.get("server_name", "")
		mode = data.get("mode", 0) as GameMode


# Player info, associate ID to data
var player_info := {}
# Map from player ID to latency.
var player_latency := {}

# Variable holding the current game mode, as an ID.
var game_info: GameInfo
var dedicated_server := false


func _ready():
	get_multiplayer().peer_connected.connect(self._player_connected)
	get_multiplayer().peer_disconnected.connect(self._player_disconnected)
	get_multiplayer().connected_to_server.connect(self._connected_ok)
	get_multiplayer().connection_failed.connect(self._connected_fail)
	get_multiplayer().server_disconnected.connect(self._server_disconnected)

	if OS.has_feature("Server") or "--dedicated" in OS.get_cmdline_user_args():
		run_dedicated_server()


# By default, the MultiplayerPeer assigned to the SceneTree is of the type OfflineMultiplayerPeer.
# this type always returns true when get_server() is called. This can lead to some undesired
# behavior. Use this function when you want to know if this instance of the game is currently
# hosting a server.
func is_hosting() -> bool:
	return (get_multiplayer().get_multiplayer_peer().get_class() != "OfflineMultiplayerPeer"
			and get_multiplayer().is_server())


# For the same reason, this is a helper function to determine if this instance of the game is a
# client connected to a server
func is_client() -> bool:
	return get_multiplayer().get_multiplayer_peer().get_class() != "OfflineMultiplayerPeer"


@rpc("any_peer", "call_local")
func update_state(_player_info: Dictionary, _game_info: Dictionary, _player_latency: Dictionary) -> void:
	player_info = _player_info
	game_info.deserialize(_game_info)
	player_latency = _player_latency


func run_dedicated_server() -> void:
	dedicated_server = true
	print("Starting dedicated server")
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--server-name":
			if i == args.size() - 1:
				print("Error, please specify a server name after --server-name")
				get_tree().quit(1)
				return
			game_info.server_name = args[i + 1]
		if args[i] == "--port":
			if i == args.size() - 1:
				print("Error, please specify a port number after --port")
				get_tree().quit(1)
				return
			var port_arg := args[i + 1]
			if not port_arg.is_valid_int():
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
			if not max_players_arg.is_valid_int():
				print("Error, \"%s\" is not a valid integer" % max_players_arg)
				get_tree().quit(1)
				return
			var new_max_players := int(max_players_arg)
			if new_max_players < 2 or new_max_players > 8:
				print("Error, max_players must be between 2 and 8, found %d" % new_max_players)
				get_tree().quit(1)
				return
			Global.config.max_players = new_max_players
	var error := host_server(Global.config.port, Global.config.max_players)
	if error:
		print("Error, unable to host a server")
		get_tree().quit(1)
		return
	print("Hosting a dedicated server on port %d" % Global.config.port)
	Global.menu_to_load = "lobby"
	get_tree().change_scene_to_file("res://src/states/menus/menu.tscn")


# Attempts to create a server and sets the network peer if successful
func host_server(port: int, max_players: int) -> int:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_players)
	if not error:
		get_multiplayer().set_multiplayer_peer(peer)
	player_latency[1] = 0.0
	return error


# Attempts to create a client peer and join a server
func join_server(host: String, port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host, port)
	if not error:
		get_multiplayer().set_multiplayer_peer(peer)
	return error


# Called on existing peers with the ID of the newly connected player.
# Called on the newly-connected peer for each of the IDs of the existing peers.
func _player_connected(id: int):
	# Ignore this for every player that is not the server.
	if not is_multiplayer_authority():
		return
	print("Player id %d attempting to connect..." % [id])
	# TODO: fix behavior allowing joining in the middle of a match?
	if get_tree().get_current_scene().name != "Menu":
		print("Currently in a game. Denying connection.")
		rpc_id(id, "deny_connection", "Cannot join server while game is in progress.")
		force_disconnect(id, 1.0)
	rpc_id(id, "query")


# Called on clients when attempting to join a server. Send our info to the server.
@rpc("authority")
func query() -> void:
	var info := {
		"name": Global.config.name,
		"version": Global.VERSION
	}
	rpc_id(1, "query_response", info)


# Response from the player attempting to join, including their info.
# The master and mastersync rpc behavior is not officially supported anymore. Try using another keyword or making custom logic using get_multiplayer().get_remote_sender_id()
@rpc("any_peer")
func query_response(info: Dictionary) -> void:
	var sender_id := get_multiplayer().get_remote_sender_id()
	# Make sure the versions match.
	if info.version != Global.VERSION:
		rpc_id(sender_id, "deny_connection",
			"Cannot connect to server, versions are mismatched. (Server: %s, Client: %s)" % [Global.VERSION, info.version])
		force_disconnect(sender_id, 1.0)
		return
	# Make sure no one else with the same username exists.
	for existing_player in player_info.values():
		if existing_player.name == info.name:
			rpc_id(sender_id, "deny_connection",
				"Another player with that name is already in the server, please choose a new one.")
			force_disconnect(sender_id, 1.0)
			return
	print("Player id %d connected." % sender_id)
	# Populate the new player's info.
	player_info[sender_id] = {
		"id": sender_id,
		"name": info.name,
		"latest_score": null
	}
	# Sync the player info to everyone.
	rpc("update_state", player_info, game_info.serialize(), player_latency)
	# Emit the signal to update the lobby.
	rpc("new_player")
	# Let the client know the connection was accepted, sync the multiplayer state.
	rpc_id(sender_id, "accept_connection")
	get_current_latency()


func force_disconnect(id: int, timeout: float) -> void:
	await get_tree().create_timer(timeout).timeout
	var peer := get_multiplayer().get_multiplayer_peer() as ENetMultiplayerPeer
	if id in get_multiplayer().get_peers():
		peer.disconnect_peer(id)


# The information has already been sycned. Use this to emit a signal to let other scenes know to update.
@rpc("call_local")
func new_player() -> void:
	emit_signal("player_connected")


@rpc("authority")
func deny_connection(reason: String) -> void:
	emit_signal("connection_failed", reason)
	call_deferred("_cleanup_network_peer")


@rpc("authority")
func accept_connection() -> void:
	emit_signal("connection_successful")


func _player_disconnected(id: int):
	print("Player id %d disconnected" % [id])
	player_info.erase(id) # Erase player from info.

	# Call function to update lobby UI here
	emit_signal("player_disconnected", id)


func _connected_ok():
	print("Connected ok")
	# Only called on clients, not server
	emit_signal("session_joined")


func _server_disconnected():
	player_info = {}
	Global.menu_to_load = "main_menu"
	emit_signal("server_disconnected")
	call_deferred("_cleanup_network_peer")


func _connected_fail():
	emit_signal("connection_failed", "Could not connect to server.")
	call_deferred("_cleanup_network_peer")


func _cleanup_network_peer() -> void:
	get_multiplayer().set_multiplayer_peer(OfflineMultiplayerPeer.new())


# Send a ping to all connected players.
func get_current_latency() -> void:
	if not is_hosting() or len(get_multiplayer().get_peers()) == 0:
		return
	var my_peer := get_multiplayer().get_multiplayer_peer() as ENetMultiplayerPeer
	for peer_id in player_info.keys():
		if peer_id == 1:
			continue
		var other_peer := my_peer.get_peer(peer_id)
		player_latency[peer_id] = other_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
	rpc("update_latency", player_latency)


@rpc("call_local")
func update_latency(new_latency: Dictionary) -> void:
	player_latency = new_latency
	emit_signal("latency_updated")


@rpc("any_peer")
func register_player(player_name: String):
	# Get the id of the RPC sender.
	var id := get_multiplayer().get_remote_sender_id()
	# Store the info
	player_info[id] = {
		"id": id,
		"name": player_name,
		"latest_score": null,
	}
	print("Player info: ", player_info)

	# Call function to update lobby UI here
	emit_signal("player_connected", id)


# Disconnect from the session.
func disconnect_from_session() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cleanup_network_peer()
	player_info = {}
	if dedicated_server:
		get_tree().quit()


# Mark all players as not ready on the server
func unready_players() -> void:
	for id in player_info.keys():
		player_info[id].is_ready = false


# Mark a player as ready
@rpc("any_peer", "call_local")
func player_is_ready() -> void:
	var id := get_multiplayer().get_remote_sender_id()
	if id not in player_info.keys():
		return
	player_info[id].is_ready = true

	# Check if all players are ready
	for new_id in player_info.keys():
		if not player_info[new_id].is_ready:
			return
	all_players_ready.emit()
