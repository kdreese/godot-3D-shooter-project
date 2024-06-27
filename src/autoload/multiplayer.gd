class_name MultiplayerInfoClass
extends Node


signal latency_updated()
signal connection_failed(reason: String)
signal connection_successful()
signal session_joined()
signal player_connected(id: int)
signal player_disconnected(id: int)
signal leader_changed(new_id: int)
signal server_disconnected()
signal all_players_loaded()


const DEFAULT_NAME := "Guest"
const DEFAULT_COLOR := Color8(255, 255, 255)

## Number of seconds after which a dedicated server created by the main server will exit if there
## are no players connected.
const QUIT_TIMEOUT := 300


# What gamemodes are available
enum GameMode {
	SHOWDOWN,  # 2v2 one arrow each
	TARGETS,  # Most targets hit wins
}

enum TeamMode {
	FFA, # Free-for-all.
	TEAM, # Team battle.
}


## Player information
class PlayerInfo:
	var id: int
	var username: String
	var latest_score: int
	var latency: float
	var color: Color
	var team_id: int
	var leader: bool

	func _init(_id: int = -1, _username: String = "") -> void:
		id = _id
		username = _username
		latest_score = -1
		latency = 0.0
		color = Color.WHITE
		team_id = -1
		leader = false

	func serialize() -> Dictionary:
		return {
			"id": id,
			"username": username,
			"latest_score": latest_score,
			"latency": latency,
			"color": str(color),
			"team_id": team_id,
		}

	func deserialize(data: Dictionary) -> void:
		id = data.get("id", -1)
		username = data.get("username", "")
		latest_score = data.get("latest_score", -1)
		latency = data.get("latency", 0.0)
		color = Color.from_string(data.get("color", ""), Color.WHITE)
		team_id = data.get("team_id", -1)


## Game information, shared between players.
class GameInfo:
	var server_name: String = ""
	var game_mode: GameMode = GameMode.SHOWDOWN
	var team_mode: TeamMode = TeamMode.FFA
	var max_players: int = 8
	var players: Dictionary = {}
	## The player_id of the leader.
	var leader: int = 1

	func has_player_with_name(name: String) -> bool:
		return players.values().any(func same_name(x): return x.username == name)

	func serialize() -> Dictionary:
		var output := {
			"server_name": server_name,
			"game_mode": int(game_mode),
			"team_mode": int(team_mode),
			"max_players": max_players,
			"leader": leader,
		}

		var serialized_player_info: Dictionary = {}
		for player in players.values():
			serialized_player_info[player.id] = player.serialize()

		output["player_info"] = serialized_player_info
		return output

	func deserialize(data: Dictionary) -> void:
		server_name = data.get("server_name", "")
		game_mode = data.get("game_mode", 0) as GameMode
		team_mode = data.get("team_mode", 0) as TeamMode
		max_players = data.get("max_players", 8)
		leader = data.get("leader", 1)
		players = {}
		for serialized_player_info in data.get("player_info", {}).values():
			var player := PlayerInfo.new()
			player.deserialize(serialized_player_info)
			players[player.id] = player

# Player IDs that are not yet marked as loaded by the server.
var unloaded_player_ids := []

# Variable holding the current game mode, as an ID.
var game_info := GameInfo.new()
var dedicated_server := false

var exit_timer := Timer.new()

# Plaintext password for authentication attempts. Set by the join_game signal.
var server_password: String = ""

# If set, the SHA256 hash of the password for the server this instance is hosting.
var server_password_hash: String = ""

func _ready():
	get_multiplayer().peer_connected.connect(_player_connected)
	get_multiplayer().peer_disconnected.connect(_player_disconnected)
	get_multiplayer().connected_to_server.connect(_connected_ok)
	get_multiplayer().connection_failed.connect(_connected_fail)
	get_multiplayer().server_disconnected.connect(_server_disconnected)
	add_child(exit_timer)
	exit_timer.timeout.connect(quit_dedicated_server)

	if OS.has_feature("Server") or ArgParse.args["dedicated"]:
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
func request_update_state(new_game_info: Dictionary) -> void:
	if is_hosting() and multiplayer.get_remote_sender_id() == game_info.leader:
		update_state.rpc(new_game_info)


@rpc("authority", "call_local")
func update_state(_game_info: Dictionary) -> void:
	game_info.deserialize(_game_info)
	latency_updated.emit()


func run_dedicated_server() -> void:
	dedicated_server = true
	print("Starting dedicated server")
	if ArgParse.args["server_name"] == "":
		push_error("Please specify a server name for dedicated servers.")
		get_tree().quit(1)

	game_info.server_name = ArgParse.args["server_name"]

	var port = ArgParse.args["port"]
	if not (port is int) or port < 0 or port > 65535:
		push_error("Invalid port number (%d)." % port)
		get_tree().quit(1)

	Global.config.port = port

	var max_players = ArgParse.args["max_players"]
	if max_players < 2 or max_players > 8:
		push_error("Error, max_players must be between 2 and 8, found %d" % max_players)
		get_tree().quit(1)

	game_info.max_players = max_players

	server_password_hash = ArgParse.args["password_hash"]

	var error := host_server(Global.config.port, game_info.max_players)
	if error:
		push_error("Unable to host a server")
		get_tree().quit(1)
		return
	print("Hosting a dedicated server on port %d" % Global.config.port)
	Global.menu_to_load = "lobby"
	get_tree().change_scene_to_file("res://src/states/menus/menu.tscn")


# Attempts to create a server and sets the network peer if successful
func host_server(port: int, max_players: int) -> int:
	var peer := ENetMultiplayerPeer.new()
	game_info.max_players = max_players
	var error := peer.create_server(port, max_players)
	if not error:
		get_multiplayer().set_multiplayer_peer(peer)
	return error


# Attempts to create a client peer and join a server
func join_server(host: String, port: int, password: String = "") -> Error:
	var peer := ENetMultiplayerPeer.new()
	server_password = password
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
		"version": Global.VERSION,
	}
	if server_password != "":
		info["password_hash"] = server_password.sha256_text()
	rpc_id(1, "query_response", info)


# Response from the player attempting to join, including their info.
@rpc("any_peer")
func query_response(info: Dictionary) -> void:
	var sender_id := get_multiplayer().get_remote_sender_id()
	# Make sure the versions match.
	if info.version != Global.VERSION:
		rpc_id(sender_id, "deny_connection",
			"Cannot connect to server, versions are mismatched. (Server: %s, Client: %s)" % [Global.VERSION, info.version])
		force_disconnect(sender_id, 1.0)
		return

	if get_players().size() == game_info.max_players:
		rpc_id(sender_id, "deny_connection", "The server you tried to join is full. Please wait to try again.")
		force_disconnect(sender_id, 1.0)
		return

	# If this game has a password, make sure the hashes match.
	if server_password_hash != "":
		var password_hash := info.get("password_hash", "") as String
		if password_hash != server_password_hash:
			rpc_id(sender_id, "deny_connection", "Incorrect password.")
			force_disconnect(sender_id, 1.0)
			return

	# Make sure everybody has a unique username
	var actual_username = null
	if not game_info.has_player_with_name(info.name):
		actual_username = info.name
	else:
		for i in range(1, 10):
			var new_name: String = info.name + str(i)
			if not game_info.has_player_with_name(new_name):
				actual_username = new_name
				break
	# Very unlikely to be hit on accident
	if not actual_username:
		rpc_id(sender_id, "deny_connection",
			"Too many players in the server have this name, please choose a new one.")
		force_disconnect(sender_id, 1.0)
		return
	if not exit_timer.is_stopped():
		exit_timer.stop()
	print("Player id %d connected." % sender_id)
	# Populate the new player's info.
	game_info.players[sender_id] = PlayerInfo.new(sender_id, actual_username)
	# Is this player the leader?
	if game_info.players.size() == 1:
		game_info.leader = sender_id
	# Sync the player info to everyone.
	update_state.rpc(game_info.serialize())
	# Emit the signal to update the lobby.
	new_player.rpc()
	# Let the client know the connection was accepted, sync the multiplayer state.
	rpc_id(sender_id, "accept_connection")
	get_current_latency()
	if ArgParse.args["game_id"] != 0:
		print("Updating player count")
		var response := await GMPClient.update_player_count(ArgParse.args["game_id"], game_info.players.size())
		if response[0]:
			push_error(response[1]["error"])


func force_disconnect(id: int, timeout: float) -> void:
	await get_tree().create_timer(timeout).timeout
	var peer := get_multiplayer().get_multiplayer_peer() as ENetMultiplayerPeer
	if id in get_multiplayer().get_peers():
		peer.disconnect_peer(id)


# The information has already been sycned. Use this to emit a signal to let other scenes know to update.
@rpc("call_local")
func new_player() -> void:
	player_connected.emit()


@rpc("authority")
func deny_connection(reason: String) -> void:
	connection_failed.emit(reason)
	_cleanup_network_peer.call_deferred()


@rpc("authority")
func accept_connection() -> void:
	connection_successful.emit()


func _player_disconnected(id: int):
	print("Player id %d disconnected" % [id])
	if id not in game_info.players:
		return

	var was_leader: bool = game_info.leader == id
	game_info.players.erase(id) # Erase player from info.
	if is_hosting() and was_leader and not game_info.players.is_empty():
		# Congrats bucko you got promoted!
		var new_leader: PlayerInfo = game_info.players.values()[0]
		game_info.leader = new_leader.id
		set_new_leader.rpc(game_info.leader)
	# Call function to update lobby UI here
	player_disconnected.emit(id)
	if dedicated_server and ArgParse.args["game_id"] != 0:
		print("Updating player count")
		var response := await GMPClient.update_player_count(ArgParse.args["game_id"], game_info.players.size())
		if response[0]:
			push_error(response[1]["error"])
		if game_info.players.is_empty():
			# If this is a game created by the main server, start a timer to quit.
			exit_timer.start(QUIT_TIMEOUT)
	if is_hosting() and id in unloaded_player_ids:
		unloaded_player_ids.erase(id)
		if len(unloaded_player_ids) == 0:
			all_players_loaded.emit()


func _connected_ok():
	print("Connected ok")
	# Only called on clients, not server
	session_joined.emit()


func _server_disconnected():
	game_info.players = {}
	Global.menu_to_load = "main_menu"
	server_disconnected.emit()
	_cleanup_network_peer.call_deferred()


func _connected_fail():
	connection_failed.emit("Could not connect to server.")
	_cleanup_network_peer.call_deferred()


func _cleanup_network_peer() -> void:
	get_multiplayer().set_multiplayer_peer(OfflineMultiplayerPeer.new())


func quit_dedicated_server() -> void:
	if ArgParse.args["game_id"] != 0:
		var response := await GMPClient.stop_game(ArgParse.args["game_id"])
		if response[0]:
			push_error(response[1]["error"])
		get_tree().quit()


# Send a ping to all connected players.
func get_current_latency() -> void:
	if not is_hosting() or len(get_multiplayer().get_peers()) == 0:
		return
	var my_peer := get_multiplayer().get_multiplayer_peer() as ENetMultiplayerPeer
	for player in game_info.players.values():
		if player.id == 1:
			player.latency = 0.0
			continue
		var other_peer := my_peer.get_peer(player.id)
		player.latency = other_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
	update_state.rpc(game_info.serialize())


@rpc("any_peer")
func register_player(player_name: String):
	# Get the id of the RPC sender.
	var id := get_multiplayer().get_remote_sender_id()
	# Store the info
	game_info.players[id] = PlayerInfo.new(id, player_name)

	# Call function to update lobby UI here
	player_connected.emit(id)


@rpc("authority", "call_local")
func set_new_leader(leader_id: int) -> void:
	game_info.leader = leader_id
	leader_changed.emit(leader_id)


# Disconnect from the session.
func disconnect_from_session() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cleanup_network_peer()
	game_info.players = {}
	if dedicated_server:
		get_tree().quit()


# Mark all players as not loaded on the server
func mark_players_as_unloaded() -> void:
	unloaded_player_ids = game_info.players.keys()


# Mark a player as loaded
@rpc("any_peer", "call_local")
func player_is_loaded() -> void:
	var id := get_multiplayer().get_remote_sender_id()
	unloaded_player_ids.erase(id)

	if len(unloaded_player_ids) == 0:
		all_players_loaded.emit()


func get_players() -> Array[PlayerInfo]:
	var array: Array[PlayerInfo] = []
	array.assign(game_info.players.values())
	return array


func get_player_ids() -> Array[int]:
	var array: Array[int] = []
	array.assign(game_info.players.keys())
	return array


func get_player_by_id(id: int) -> PlayerInfo:
	if id in game_info.players:
		return game_info.players[id] as PlayerInfo
	else:
		return null


func get_my_player() -> PlayerInfo:
	return get_player_by_id(multiplayer.get_unique_id())


func is_id_leader(id: int) -> bool:
	return game_info.leader == id


func is_leader() -> bool:
	var player := get_my_player()
	return game_info.leader == player.id


func requestor_is_leader() -> bool:
	var player_id := multiplayer.get_remote_sender_id()
	return player_id == 0 or is_id_leader(player_id)
