extends Control


signal error(text: String)
signal join_game(host: String, port: int)


enum JoinMode {
	JOIN_REMOTE = 0,
	JOIN_LOCAL = 1,
}


@onready var server_list: ScrollContainer = %ServerList
@onready var server_grid: VBoxContainer = %ServerGrid
@onready var join_button: Button = %JoinButton
@onready var manual_options: CenterContainer = %ManualOptions
@onready var host_line_edit: LineEdit = %HostLineEdit
@onready var port_spin_box: SpinBox = %PortSpinBox
@onready var button_group := ButtonGroup.new()


var row: Node
var games: Array[GMPClient.GameParams] = []
var mode: JoinMode = JoinMode.JOIN_REMOTE



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get the first row to preserve formatting.
	row = server_grid.get_child(1)
	server_grid.remove_child(row)
	button_group.pressed.connect(on_radio_button_pressed)


func on_back_button_pressed() -> void:
	hide()


func on_mode_changed(index: int) -> void:
	mode = index as JoinMode
	if index == JoinMode.JOIN_REMOTE:
		server_list.show()
		manual_options.hide()
		populate()
	else:
		server_list.hide()
		manual_options.show()
		join_button.disabled = (host_line_edit.text == "")


## Update the disabled state of the button when the text box is changed.
func on_text_changed(text: String) -> void:
	join_button.disabled = (text == "")


func on_radio_button_pressed(_button: BaseButton) -> void:
	join_button.disabled = button_group.get_pressed_button() == null


func on_join_button_pressed():
	if mode == JoinMode.JOIN_REMOTE:
		var buttons = button_group.get_buttons()
		var button_idx = buttons.find(button_group.get_pressed_button())
		var game = games[button_idx]
		print(game.host, ":", game.port)
		join_game.emit(game.host, game.port)
	else:
		join_game.emit(host_line_edit.text, port_spin_box.value)
	hide()


func populate() -> void:
	games.clear()


	var response := await GMPClient.get_game_info(games)

	if response[0]:
		# There was an error.
		error.emit(response[1]["error"])
		return

	# Clear out existing children.
	for idx in range(1, server_grid.get_child_count()):
		var old_row := server_grid.get_child(idx)
		server_grid.remove_child(old_row)
		old_row.queue_free()


	for game in games:
		var new_row = row.duplicate()
		new_row.get_node("ServerName").text = game.server_name
		new_row.get_node("Players").text = "%d/%d" % [game.current_players, game.max_players]
		new_row.get_node("CheckBox").button_group = button_group
		server_grid.add_child(new_row)

	join_button.disabled = true
