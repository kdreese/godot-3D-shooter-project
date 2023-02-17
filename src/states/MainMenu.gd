extends Control

signal change_menu

onready var name_line_edit: LineEdit = $"%NameLineEdit"
onready var address_line_edit: LineEdit = $"%IpLineEdit"
onready var port_spin_box: SpinBox = $"%PortSpinBox"

onready var host_button: Button = $"%HostButton"
onready var join_button: Button = $"%JoinButton"
onready var free_play_button: Button = $"%FreePlayButton"
onready var credits_button: Button = $"%CreditsButton"

onready var disconnect_popup: AcceptDialog = $"%DisconnectPopup"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Get the values from the multiplayer info singleton.
	name_line_edit.text = Global.config.name
	address_line_edit.text = Global.config.address
	port_spin_box.value = Global.config.port
	Multiplayer.connect("connection_failed", self, "enable_play_buttons")
	Multiplayer.connect("session_joined", self, "session_joined")
	Multiplayer.connect("server_disconnected", disconnect_popup, "popup_centered")


# Enter the level scene and start playing the game.
func play() -> void:
	var error := get_tree().change_scene("res://src/states/Game.tscn")
	assert(not error)


# Go to the multiplayer lobby.
func go_to_lobby() -> void:
	emit_signal("change_menu", "lobby")


# Create and host a multiplayer session. Triggered by the "Host" button.
func host_session() -> void:
	var error := Multiplayer.host_server()
	if error:
		OS.alert("Could not create server!")
		return

	# The server always has ID 1.
	var my_info := {
		"id": 1,
		"name": Global.config.name,
		"latest_score": null,
	}
	Multiplayer.player_info[1] = my_info
	go_to_lobby()


func show_disconnect_popup() -> void:
	disconnect_popup.popup_centered()


func disable_play_buttons() -> void:
	host_button.disabled = true
	join_button.disabled = true
	free_play_button.disabled = true
	credits_button.disabled = true


func enable_play_buttons() -> void:
	host_button.disabled = false
	join_button.disabled = false
	free_play_button.disabled = false
	credits_button.disabled = false


# Join a session that someone else is hosting. Triggered by the "Join" button.
func join_session() -> void:
	var error := Multiplayer.join_server()
	if error:
		OS.alert("Could not create client!")
		return
	disable_play_buttons()
	# Wait until Multiplayer gets a connection_ok to join, at which point the Multiplayer
	# class calls "session_joined".
	# TODO: figure out how to shorten the timeout


# Called upon successful connection to a host server.
func session_joined() -> void:
	var my_id = Multiplayer.get_player_id()
	var my_info := {
		"id": my_id,
		"name": Global.config.name,
		"latest_score": null,
	}
	Multiplayer.player_info[my_id] = my_info
	enable_play_buttons()
	go_to_lobby()


# Start the game without connecting to a server.
func free_play_session() -> void:
	var my_info := {
		"id": 1,
		"name": Global.config.name,
		"color": Color(1.0, 1.0, 1.0)
	}
	Multiplayer.player_info[1] = my_info
	play()


func go_to_credits() -> void:
	emit_signal("change_menu", "credits_menu")


func quit_game() -> void:
	get_tree().notification(NOTIFICATION_WM_QUIT_REQUEST)


func name_text_changed(new_text: String) -> void:
	Global.config.name = new_text


func color_changed(new_color: Color) -> void:
	Global.config.favorite_color = new_color


func address_text_changed(new_text: String) -> void:
	Global.config.address = new_text


func port_value_changed(new_value: float) -> void:
	Global.config.port = int(new_value)
