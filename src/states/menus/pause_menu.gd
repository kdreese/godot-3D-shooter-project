extends ColorRect


@onready var disconnect_button: Button = %DisconnectButton
@onready var mouse_sens_slider: HSlider = %MouseSensSlider
@onready var sfx_volume_slider: HSlider = %SFXVolumeSlider
@onready var back_to_lobby_button: Button = %BackToLobbyButton
@onready var back_to_lobby_confirmation: ConfirmationDialog = %BackToLobbyConfirmation


func _ready() -> void:
	if Multiplayer.is_hosting():
		disconnect_button.text = "Stop Hosting"
	elif Multiplayer.is_client():
		disconnect_button.text = "Disconnect"
	else:
		disconnect_button.text = "Quit Free Play"
		back_to_lobby_button.hide()
	mouse_sens_slider.value = Global.config["mouse_sensitivity"]
	sfx_volume_slider.value = Global.config["sfx_volume"]


func open_menu() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()


func close_menu() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hide()


func show_back_to_lobby_confirmation():
	back_to_lobby_confirmation.popup_centered()


func go_back_to_lobby() -> void:
	var game := get_tree().get_root().get_node("Game")
	game.end_of_match.rpc()


func disconnect_from_server() -> void:
	Multiplayer.disconnect_from_session()
	Global.menu_to_load = "main_menu"
	get_tree().change_scene_to_file("res://src/states/menus/menu.tscn")


func on_mouse_sens_change(value: float) -> void:
	Global.config["mouse_sensitivity"] = value


func on_sfx_volume_change(value: float) -> void:
	Global.config["sfx_volume"] = value
	Global.update_volume()
