extends ColorRect


@onready var disconnect_button: Button = $"%DisconnectButton"
@onready var mouse_sens_slider: HSlider = $"%MouseSensSlider"
@onready var sfx_volume_slider: HSlider = $"%SFXVolumeSlider"
@onready var back_to_lobby_button: Button = $"%BackToLobbyButton"
@onready var back_to_lobby_confirmation: ConfirmationDialog = $"%BackToLobbyConfirmation"


func _ready() -> void:
	if get_multiplayer().is_server():
		disconnect_button.text = "Stop Hosting"
	if not get_multiplayer().has_multiplayer_peer():
		disconnect_button.text = "Quit Free Play"
		back_to_lobby_button.hide()
	mouse_sens_slider.value = Global.config["mouse_sensitivity"]
	sfx_volume_slider.value = Global.config["sfx_volume"]


func open_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()


func close_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hide()


func show_back_to_lobby_confirmation():
	back_to_lobby_confirmation.popup_centered()


func go_back_to_lobby() -> void:
	var game := get_tree().get_root().get_node("Game")
	game.rpc("end_of_match")
	game.end_of_match()


func disconnect_from_server() -> void:
	Multiplayer.disconnect_from_session()
	Global.menu_to_load = "main_menu"
	get_tree().change_scene_to_file("res://src/states/menu.tscn")


func on_mouse_sens_change(value: float) -> void:
	Global.config["mouse_sensitivity"] = value


func on_sfx_volume_change(value: float) -> void:
	Global.config["sfx_volume"] = value
	Global.update_volume()
