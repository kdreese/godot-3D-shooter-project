class_name MultiplayerInfoClass
extends Node


signal latency_updated


const DEFAULT_NAME := "Guest"
const DEFAULT_COLOR := Color8(255, 255, 255)


# Player info, associate ID to data
var player_info := {}
# Map from player ID to latency.
var player_latency := {}
# Map from player ID to time a ping was sent, for outstanding pings.
var outstanding_pings := {}


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


func _player_connected(id: int):
	# Called on both clients and server when a peer connects. Send my info to it.
	print("Player id %d connected" % [id])
	rpc_id(id, "register_player", Global.config.name)


func _player_disconnected(id: int):
	print("Player id %d disconnected" % [id])
	# warning-ignore:return_value_discarded
	player_info.erase(id) # Erase player from info.

	# Call function to update lobby UI here
	var lobby := get_tree().get_root().get_node_or_null("Lobby") as Node
	if lobby != null:
		lobby.player_disconnected(id)

	var game := get_tree().get_root().get_node_or_null("Game") as Node
	if game:
		game.remove_peer_player(id)


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
	if get_tree().network_peer:
		get_tree().network_peer = null


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
	get_tree().network_peer = null
	player_info = {}
	var error := get_tree().change_scene("res://src/states/Menu.tscn")
	assert(not error)


# Get the player id for this instance. If connected to a server, this is equivalent to the unique
# network id. If in free play, this will always return 1.
func get_player_id() -> int:
	if get_tree().network_peer:
		return get_tree().get_network_unique_id()
	else:
		return 1
