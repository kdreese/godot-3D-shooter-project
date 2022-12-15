extends ColorRect


onready var disconnect_button := $"%DisconnectButton" as Button


func _ready() -> void:
	if get_tree().is_network_server():
		disconnect_button.text = "Stop Hosting"
	if not get_tree().network_peer:
		disconnect_button.text = "Quit Free Play"


func open_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()


func close_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hide()


func disconnect_from_server() -> void:
	MultiplayerInfo.disconnect_from_session()
