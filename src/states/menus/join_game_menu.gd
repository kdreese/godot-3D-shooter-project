extends Control


signal error(text: String)
signal join_game(host: String, port: int)


enum JoinMode {
	JOIN_REMOTE = 0,
	JOIN_LOCAL = 1,
}


@onready var server_list: ScrollContainer = %ServerList
@onready var server_grid: VBoxContainer = %ServerGrid
@onready var no_games_label: Label = %NoGamesLabel
@onready var mode_select_button: OptionButton = %ModeSelectButton
@onready var join_button: Button = %JoinButton
@onready var refresh_button: Button = %RefreshButton
@onready var manual_options: CenterContainer = %ManualOptions
@onready var host_line_edit: LineEdit = %HostLineEdit
@onready var port_spin_box: SpinBox = %PortSpinBox
@onready var button_group := ButtonGroup.new()


var row: Control
var games: Array[GMPClient.GameParams] = []
var mode: JoinMode = JoinMode.JOIN_REMOTE



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mode = Global.config.get("join_mode", 0) as JoinMode
	mode_select_button.select(mode)

	port_spin_box.value = Global.config.get("port", 0)
	var host = Global.config.get("address", "")
	if host != "":
		host_line_edit.placeholder_text = ""
		host_line_edit.text = host
	else:
		host_line_edit.placeholder_text = "www.example.com"
	# Get the first row to preserve formatting.
	row = server_grid.get_child(0)
	server_grid.remove_child(row)
	# Remove the second row.
	server_grid.remove_child(server_grid.get_child(0))
	button_group.pressed.connect(on_radio_button_pressed)


func on_back_button_pressed() -> void:
	hide()


func on_mode_changed(index: int) -> void:
	mode = index as JoinMode
	Global.config["join_mode"] = int(mode)
	if index == JoinMode.JOIN_REMOTE:
		populate_remote()
	else:
		populate_local()


## Update the disabled state of the button when the text box is changed.
func on_text_changed(text: String) -> void:
	Global.config.address = text
	join_button.disabled = (text == "")


func on_port_value_changed(new_value: float) -> void:
	Global.config.port = int(new_value)


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


func populate_local() -> void:
	server_list.hide()
	refresh_button.hide()
	no_games_label.hide()
	manual_options.show()
	join_button.disabled = (host_line_edit.text == "")


func populate_remote() -> void:
	games.clear()
	manual_options.hide()
	server_list.hide()
	no_games_label.hide()

	refresh_button.show()

	var response := await GMPClient.get_game_info(games)

	if response[0]:
		# There was an error.
		error.emit(response[1]["error"])
		return

	# Clear out existing children.
	while server_grid.get_child_count() > 0:
		var old_row := server_grid.get_child(0)
		server_grid.remove_child(old_row)
		old_row.button_group = null
		old_row.queue_free()

	# Show either the game list or a no games found message.
	if len(games) == 0:
		no_games_label.show()
	else:
		server_list.show()
		var game_idx = 1
		for game in games:
			var new_row = row.duplicate()
			new_row.get_node("M/H/ServerName").text = game.server_name
			new_row.get_node("M/H/Players").text = "%d/%d" % [game.current_players, game.max_players]
			new_row.button_group = button_group
			if game_idx % 2 == 0:
				new_row.theme_type_variation = "EvenRow"
			game_idx += 1
			server_grid.add_child(new_row)



	join_button.disabled = true


func populate() -> void:
	if mode == JoinMode.JOIN_LOCAL:
		populate_local()
	else:
		populate_remote()
