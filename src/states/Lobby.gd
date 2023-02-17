class_name Lobby
extends Control


class Sorter:
	static func sort_by_name(a, b):
		return a.name.to_lower() < b.name.to_lower()


# The radius of the circle of buttons.
const BUTTON_CIRCLE_RADIUS := 120
# The size of each button.
const BUTTON_SIZE := 40
# The available colors.
const COLORS := [
	Color(1.0, 0.0, 0.0),
	Color(1.0, 0.5, 0.0),
	Color(1.0, 1.0, 0.0),
	Color(0.0, 1.0, 0.0),
	Color(0.0, 1.0, 1.0),
	Color(0.0, 0.5, 1.0),
	Color(0.5, 0.0, 1.0),
	Color(1.0, 0.0, 1.0)
]
# The number of rows in the table
const NUM_ROWS = 8


onready var button_circle: Control = $"%ButtonCircle"
onready var table: VBoxContainer = $"%Table"
onready var server_name: Label = $"%ServerName"
onready var back_button: Button = $"%BackButton"
onready var start_button: Button = $"%StartButton"
onready var mode_drop_down: MenuButton = $"%ModeDropDown"
onready var ping_timer: Timer = $"%PingTimer"


# Dictionary from player_id to button/color index.
var chosen_colors := {}
# Dictionary from player_id to row in the table.
var player_id_to_row := {}


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if 1 in Multiplayer.player_info:
		server_name.text = Multiplayer.player_info[1].name + "'s Server"
	if get_tree().is_network_server():
		Multiplayer.player_latency[1] = 0
	if not Multiplayer.dedicated_server:
		generate_button_grid()
	sync_mode(Multiplayer.game_mode)
	# If colors are already selected (like if a match just ended) preserve them.
	for player_id in Multiplayer.player_info.keys():
		if "team_id" in Multiplayer.player_info[player_id]:
			chosen_colors[player_id] = Multiplayer.player_info[player_id].team_id
	update_table()
	update_buttons()
	var error = Multiplayer.connect("latency_updated", self, "on_latency_update")
	assert(not error)
	error = mode_drop_down.get_popup().connect("id_pressed", self, "on_mode_select")
	assert(not error)
	error = ping_timer.connect("timeout", Multiplayer, "send_ping_to_all")


# Called for everyone when a player connects.
func player_connected(player_id: int, info: Dictionary) -> void:
	if player_id == 1:
		# The player connecting to us is the server.
		server_name.text = info.name + "'s Server"
	elif get_tree().is_network_server():
		# Sync initial state.
		Multiplayer.send_ping(player_id)
		rpc_id(player_id, "sync_mode", Multiplayer.game_mode)
		rpc_id(player_id, "sync_chosen_colors", chosen_colors)
		rpc_id(player_id, "sync_pings", Multiplayer.player_latency)
	update_table()
	update_buttons()


# Called for everyone when a player disconnects.
func player_disconnected(player_id: int) -> void:
	update_table()
	if get_tree().is_network_server():
		chosen_colors.erase(player_id)
		update_buttons()
		rpc("sync_chosen_colors", chosen_colors)


# Disconnect from the lobby.
func on_back_button_press() -> void:
	Multiplayer.disconnect_from_session()


# The start button was pressed. Change scene for all players to be the game scene.
func on_start_button_press() -> void:
	rpc("start_game")
	start_game()


# Start the game
remote func start_game() -> void:
	for player_id in chosen_colors.keys():
		Multiplayer.player_info[player_id].color = COLORS[chosen_colors[player_id]]
		Multiplayer.player_info[player_id].team_id = chosen_colors[player_id]
	var error := get_tree().change_scene("res://src/states/Game.tscn")
	assert(not error)


# Called whenever someone selects a mode from the drop-down.
# :param new_mode_id: The ID of the selected mode.
func on_mode_select(new_mode_id: int) -> void:
	# If we select the same game mode we have already selected, do nothing.
	if new_mode_id == Multiplayer.game_mode:
		return
	sync_mode(new_mode_id)
	rpc("sync_mode", Multiplayer.game_mode)


# Set the game mode to the specified value.
# :param new_mode_id: The ID of the mode to set.
remote func sync_mode(new_mode_id: int) -> void:
	Multiplayer.game_mode = new_mode_id
	mode_drop_down.text = mode_drop_down.get_popup().get_item_text(new_mode_id)
	# Because the mode changed, color selections are probably no longer valid. Reset them.
	chosen_colors = {}
	update_buttons()
	update_table()


# Called when we press a color button.
# :param idx: The index of the button/color pressed.
func on_color_button_press(idx: int) -> void:
	if get_tree().is_network_server():
		# We are the server, so update chosen_buttons ourselves. The server always has ID 1.
		player_selected_color(1, idx)
	else:
		# Let the server know that we selected a color.
		rpc_id(1, "player_selected_color", Multiplayer.get_player_id(), idx)


# Called on the server whenever anyone presses a button.
# :param player_id: The ID of the player that pressed the button.
# :param idx: The index of the button/color pressed.
remote func player_selected_color(player_id: int, idx: int) -> void:
	chosen_colors[player_id] = idx
	rpc("sync_chosen_colors", chosen_colors)
	update_buttons()
	update_table()


# Called in clients to disable the buttons that have been selected by people already.
# :param colors: A map from player ID to button/color index.
remote func sync_chosen_colors(colors: Dictionary) -> void:
	chosen_colors = colors
	update_buttons()
	update_table()


# Called on the server when it receives a ping response.
func on_latency_update() -> void:
	update_table()
	rpc("sync_pings", Multiplayer.player_latency)


# Called in clients to update the ping values of players.
# :param pings: A map from player ID to ping in ms.
remote func sync_pings(pings: Dictionary) -> void:
	Multiplayer.player_latency = pings
	update_table()


# Generate a circle of buttons inside of the ButtonGrid node.
func generate_button_grid() -> void:
	for angle_idx in range(len(COLORS)):
		var angle := (2 * PI / len(COLORS)) * angle_idx
		var button := preload("res://src/objects/ColorButton.tscn").instance() as ColorButton
		button.set_button_color(COLORS[angle_idx])
		button_circle.add_child(button)
		button.rect_position = Vector2(BUTTON_CIRCLE_RADIUS, 0).rotated(angle - PI/2) - button.rect_min_size / 2.0
		# Set the properties (name, text, color)
		button.name = str(angle_idx)
		var error := button.get_node("Button").connect("button_down", self, "on_color_button_press", [angle_idx])
		assert(not error)


# Update the information stored in the table.
func update_table() -> void:
	var info := Multiplayer.player_info.values()
	info.sort_custom(Sorter, "sort_by_name")
	for row_idx in range(NUM_ROWS):
		var row := table.get_node("Row" + str(row_idx + 1)) as PanelContainer
		if row_idx < len(info):
			var name_label := row.get_node("HBoxContainer/Name") as Label
			var score_label := row.get_node("HBoxContainer/Score") as Label
			var player_info = info[row_idx]
			name_label.text = player_info.name
			if player_info.latest_score != null:
				score_label.text = str(player_info.latest_score)
			if player_info.id in chosen_colors:
				name_label.add_color_override("font_color", COLORS[chosen_colors[player_info.id]])
			else:
				name_label.add_color_override("font_color", Color(1.0, 1.0, 1.0))
			var ping_label := row.get_node("HBoxContainer/Ping") as Label
			if player_info.id in Multiplayer.player_latency:
				ping_label.text = "%dms" % int(Multiplayer.player_latency[player_info.id])
			else:
				ping_label.text = ""
		else:
			row.get_node("HBoxContainer/Name").text = ""
			row.get_node("HBoxContainer/Score").text = ""
			row.get_node("HBoxContainer/Ping").text = ""


# Update the enabled/disabled state for all buttons.
func update_buttons() -> void:
	if not Multiplayer.dedicated_server:
		for idx in range(len(COLORS)):
			var button := button_circle.get_node(str(idx)) as ColorButton
			# Do not allow multiple people to select the same color in free-for-all mode.
			if Multiplayer.game_mode == Multiplayer.GameMode.FFA:
				button.get_node("Button").disabled = (idx in chosen_colors.values())
			else:
				button.get_node("Button").disabled = false
			# If we are not selecting a button (e.g. after a mode change), clear focus for all buttons.
			if not (Multiplayer.get_player_id() in chosen_colors):
				button.get_node("Button").focus_mode = Control.FOCUS_NONE
	var all_players_selected := true
	var selected_colors := []
	for player_id in Multiplayer.player_info:
		if player_id in chosen_colors:
			if not (chosen_colors[player_id] in selected_colors):
				selected_colors.append(chosen_colors[player_id])
		else:
			all_players_selected = false

	# Do not allow the game to start unless all players have selected colors and there is more than one team in
	# total.
	if not all_players_selected:
		start_button.disabled = true
	else:
		start_button.disabled = len(selected_colors) <= 1 and Multiplayer.game_mode != Multiplayer.GameMode.FFA
