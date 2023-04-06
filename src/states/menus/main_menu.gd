extends Control

signal change_menu


@onready var name_line_edit: LineEdit = $"%NameLineEdit"
@onready var address_line_edit: LineEdit = $"%IpLineEdit"
@onready var port_spin_box: SpinBox = $"%PortSpinBox"

@onready var host_button: Button = $"%HostButton"
@onready var join_button: Button = $"%JoinButton"
@onready var free_play_button: Button = $"%FreePlayButton"
@onready var credits_button: Button = $"%CreditsButton"

@onready var popup: AcceptDialog = $"%Popup"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Get the values from the multiplayer info singleton.
	name_line_edit.text = Global.config.name
	address_line_edit.text = Global.config.address
	port_spin_box.value = Global.config.port
	# TODO center text in popup.
	Multiplayer.connection_failed.connect(connection_failed)
	Multiplayer.connection_successful.connect(connection_successful)
	Multiplayer.server_disconnected.connect(show_popup.bind("Server disconnected."))


func show_popup(text: String) -> void:
	popup.dialog_text = text
	popup.popup_centered()


# Enter the level scene and start playing the game.
func play() -> void:
	var error := get_tree().change_scene_to_file("res://src/states/game.tscn")
	assert(not error)


# Go to the multiplayer lobby.
func go_to_lobby() -> void:
	emit_signal("change_menu", "lobby")


# Create and host a multiplayer session. Triggered by the "Host" button.
func host_session() -> void:
	var error := Multiplayer.host_server()
	if error:
		show_popup("Could not create server. (Error %d)" % error)
		return

	# The server always has ID 1.
	var my_info := {
		"id": 1,
		"name": Global.config.name,
		"latest_score": null,
	}
	Multiplayer.player_info[1] = my_info
	go_to_lobby()


func connection_failed(reason: String) -> void:
	show_popup("Could not connect to server.\n\n" + reason)
	enable_play_buttons()


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
	if not name_line_edit.text.is_valid_identifier():
		show_popup("Invalid username. Please use only letters, numbers, and underscores.")
		return
	var error := Multiplayer.join_server()
	if error:
		show_popup("Could not create client. (Error %d)" % error)
		return
	disable_play_buttons()
	# Wait until Multiplayer gets a connection_ok to join, at which point the Multiplayer
	# class calls "session_joined".
	# TODO: figure out how to shorten the timeout


# Called upon successful connection to a host server.
func connection_successful() -> void:
	enable_play_buttons()
	go_to_lobby()


# Start the game without connecting to a server.
func free_play_session() -> void:
	var my_info := {
		"id": 1,
		"name": Global.config.name,
		"color": Color(1.0, 1.0, 1.0),
		"team_id": 1
	}
	Multiplayer.player_info[1] = my_info
	play()


func go_to_credits() -> void:
	emit_signal("change_menu", "credits_menu")


func quit_game() -> void:
	get_tree().get_root().propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)


func name_text_changed(new_text: String) -> void:
	Global.config.name = new_text


func address_text_changed(new_text: String) -> void:
	Global.config.address = new_text


func port_value_changed(new_value: float) -> void:
	Global.config.port = int(new_value)
