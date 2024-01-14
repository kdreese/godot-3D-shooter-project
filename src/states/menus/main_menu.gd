extends Control

signal change_menu

const HOVER_OFFSET = Vector2(10.0, 0.0)


@onready var name_line_edit: LineEdit = %NameLineEdit
@onready var address_line_edit: LineEdit = %IpLineEdit
@onready var port_spin_box: SpinBox = %PortSpinBox

@onready var create_button: FancyButton = %CreateButton
@onready var join_button: FancyButton = %JoinButton
@onready var free_play_button: FancyButton = %FreePlayButton
@onready var credits_button: FancyButton = %CreditsButton

@onready var popup: AcceptDialog = %Popup
@onready var create_game_menu: Control = %CreateGameMenu


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
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


func disable_play_buttons() -> void:
	create_button.set_enabled(false)
	join_button.set_enabled(false)
	free_play_button.set_enabled(false)
	credits_button.set_enabled(false)


func enable_play_buttons() -> void:
	create_button.set_enabled(true)
	join_button.set_enabled(true)
	free_play_button.set_enabled(true)
	credits_button.set_enabled(true)


func open_create_window() -> void:
	create_game_menu.show()


func create_session(server_name: String, max_players: int) -> void:
	var game_params := GMPClient.GameParams.new()
	game_params.server_name = server_name
	game_params.max_players = max_players

	var response := await GMPClient.request_game(game_params)

	if response[0]:
		# There were errors.
		show_popup(response[1]["error"])
		return

	print(game_params.host, ":", game_params.port)
	var error = Multiplayer.join_server(game_params.host, game_params.port)
	if error:
		show_popup("Could not create client. (Error %d)" % error)
		return
	disable_play_buttons()
	# Wait until Multiplayer gets a connection_ok to join, at which point the Multiplayer
	# class calls "session_joined".
	# TODO: figure out how to shorten the timeout


# Create and host a multiplayer session. Triggered by the "Host" button.
func host_session(port: int, max_players: int) -> void:
	var error := Multiplayer.host_server(port, max_players)
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


# Join a session that someone else is hosting. Triggered by the "Join" button.
func join_session() -> void:
	if not name_line_edit.text.is_valid_identifier():
		show_popup("Invalid username. Please use only letters, numbers, and underscores.")
		return
	var error := Multiplayer.join_server(address_line_edit.text, int(port_spin_box.value))
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


# Go to the multiplayer lobby.
func go_to_lobby() -> void:
	emit_signal("change_menu", "lobby")


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


# Enter the level scene and start playing the game.
func play() -> void:
	var error := get_tree().change_scene_to_file("res://src/states/game.tscn")
	assert(not error)


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
