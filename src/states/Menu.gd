extends Control


onready var name_line_edit := $"%NameLineEdit" as LineEdit
onready var address_line_edit := $"%IpLineEdit" as LineEdit
onready var port_spin_box := $"%PortSpinBox" as SpinBox
onready var color_picker_button := $"%ColorPickerButton" as ColorPickerButton

onready var host_button := $"%HostButton" as Button
onready var join_button := $"%JoinButton" as Button
onready var free_play_button := $"%FreePlayButton" as Button
onready var credits_button := $"%CreditsButton" as Button



func play() -> void:
	var error := get_tree().change_scene("res://src/states/Game.tscn")
	assert(not error)


func host_session() -> void:
	MultiplayerInfo.my_info.name = name_line_edit.text
	MultiplayerInfo.my_info.favorite_color = color_picker_button.color
	var peer := NetworkedMultiplayerENet.new()
	# warning-ignore:narrowing_conversion
	var error := peer.create_server(port_spin_box.value, 4)
	if error:
		OS.alert("Could not create server!")
		return
	get_tree().network_peer = peer
	play()


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


func join_session() -> void:
	MultiplayerInfo.my_info.name = name_line_edit.text
	MultiplayerInfo.my_info.favorite_color = color_picker_button.color
	var peer := NetworkedMultiplayerENet.new()
	# warning-ignore:narrowing_conversion
	var error := peer.create_client(address_line_edit.text, port_spin_box.value)
	if error:
		OS.alert("Could not create client!")
		return
	disable_play_buttons()
	get_tree().network_peer = peer
	# Wait until MultiplayerInfo gets a connection_ok to join, at which point call "session_joined"


func session_joined() -> void:
	play()
	rpc("Game.spawn_peer_player", get_tree().get_network_unique_id())


func free_play_session() -> void:
	MultiplayerInfo.my_info.name = name_line_edit.text
	MultiplayerInfo.my_info.favorite_color = color_picker_button.color
	play()


func go_to_credits() -> void:
	var error := get_tree().change_scene("res://src/states/CreditsMenu.tscn")
	assert(not error)


func quit_game() -> void:
	get_tree().notification(NOTIFICATION_WM_QUIT_REQUEST)
