extends ColorRect


onready var disconnect_button: Button = $"%DisconnectButton"
onready var mouse_sens_slider: HSlider := $"%MouseSensSlider"
onready var back_to_lobby_button: Button = $"%BackToLobbyButton"


func _ready() -> void:
	if get_tree().is_network_server():
		disconnect_button.text = "Stop Hosting"
	if not get_tree().has_network_peer():
		disconnect_button.text = "Quit Free Play"
	mouse_sens_slider.value = Global.config["mouse_sensitivity"]


func open_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()


func close_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hide()


func go_back_to_lobby() -> void:
	var game := get_tree().get_root().get_node("Game")
	game.rpc("end_of_match")
	game.end_of_match()


func disconnect_from_server() -> void:
	Multiplayer.disconnect_from_session()


func on_mouse_sens_change(value: float) -> void:
	Global.config["mouse_sensitivity"] = value
