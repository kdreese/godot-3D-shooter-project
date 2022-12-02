extends Control


onready var name_line_edit := $"%NameLineEdit" as LineEdit
onready var address_line_edit := $"%IpLineEdit" as LineEdit
onready var port_spin_box := $"%PortSpinBox" as SpinBox
onready var color_picker_button = $"%ColorPickerButton" as ColorPickerButton


func play() -> void:
	var error := get_tree().change_scene("res://src/states/Game.tscn")
	assert(not error)


func host_session() -> void:
	MultiplayerInfo.my_info.name = name_line_edit.text
	MultiplayerInfo.my_info.favorite_color = color_picker_button.color
	var peer := NetworkedMultiplayerENet.new()
	peer.create_server(port_spin_box.value, 4)
	get_tree().network_peer = peer
	play()


func join_session() -> void:
	MultiplayerInfo.my_info.name = name_line_edit.text
	MultiplayerInfo.my_info.favorite_color = color_picker_button.color
	var peer := NetworkedMultiplayerENet.new()
	peer.create_client(address_line_edit.text, port_spin_box.value)
	get_tree().network_peer = peer
	play()
	rpc("Game.spawn_peer_player", get_tree().get_network_unique_id())


func go_to_credits() -> void:
	var error := get_tree().change_scene("res://src/states/CreditsMenu.tscn")
	assert(not error)


func quit_game() -> void:
	get_tree().notification(NOTIFICATION_WM_QUIT_REQUEST)
