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


onready var button_circle := $"%ButtonCircle" as Control
onready var table := $"%Table" as VBoxContainer
onready var server_name := $"%ServerName" as Label
onready var server_url := $"%ServerURL" as Label
onready var back_button := $"%BackButton" as Button
onready var start_button := $"%StartButton" as Button


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
	generate_button_grid()
	update_table()
	var error = Multiplayer.connect("latency_updated", self, "on_latency_update")
	assert(not error)


# Called for everyone when a player connects.
func player_connected(player_id: int, info: Dictionary) -> void:
	if player_id == 1:
		# The player connecting to us is the server.
		server_name.text = info.name + "'s Server"
	elif get_tree().is_network_server():
		Multiplayer.send_ping(player_id)
		rpc_id(player_id, "sync_chosen_colors", chosen_colors)
		rpc_id(player_id, "sync_pings", Multiplayer.player_latency)
	update_table()
	update_buttons()


# Called for everyone when a player disconnects.
func player_disconnected(player_id: int) -> void:
	update_table()
	if get_tree().is_network_server():
		# warning-ignore:return_value_discarded
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
	var error := get_tree().change_scene("res://src/states/Game.tscn")
	assert(not error)


# Called when we press a button.
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
	for player_id in chosen_colors.keys():
		if player_id in Multiplayer.player_info:
			Multiplayer.player_info[player_id]["color"] = COLORS[chosen_colors[player_id]]
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
		var button := Button.new()
		button_circle.add_child(button)
		# Set the properties (name, text, color)
		button.name = str(angle_idx)
		button.text = "X"
		button.add_color_override("font_color", COLORS[angle_idx])
		button.rect_min_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
		# Center it at a distance BUTTON_CIRCLE_RADIUS away from the center of the container.
		var center := 0.5 * (button_circle.rect_size - Vector2(BUTTON_SIZE, BUTTON_SIZE))
		button.rect_position = center - BUTTON_CIRCLE_RADIUS * Vector2(-sin(angle), cos(angle))
		var error := button.connect("button_down", self, "on_color_button_press", [angle_idx])
		assert(not error)
	update_buttons()


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
			row.get_node("HBoxContainer/Ping").text = ""


# Update the enabled/disabled state for all buttons.
func update_buttons() -> void:
	for idx in range(len(COLORS)):
		button_circle.get_node(str(idx)).disabled = (idx in chosen_colors.values())
	if not get_tree().is_network_server():
		start_button.disabled = true
	else:
		var all_players_selected := true
		for player_id in Multiplayer.player_info.keys():
			if not (player_id in chosen_colors):
				all_players_selected = false
		start_button.disabled = not (all_players_selected and len(chosen_colors.keys()) > 1)
