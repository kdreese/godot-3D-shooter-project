class_name Lobby
extends Control


class Sorter:
	static func sort_by_name(a, b):
		return a.name < b.name

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

var selected_button_idx := -1

# Dictionary from player_id to button/color index.
var chosen_colors := {}
# Dictionary from player_id to row in the table.
var player_id_to_row := {}


# Called for everyone when a player connects.
func player_connected(player_id: int, info: Dictionary) -> void:
	update_table()
	update_buttons()
	if player_id == 1:
		# The player connecting to us is the server.
		server_name.text = info.name + "'s Server"
	elif get_tree().is_network_server():
		rpc_id(player_id, "sync_chosen_colors", chosen_colors)


# Called for everyone when a player disconnects.
func player_disconnected(player_id: int) -> void:
	print(MultiplayerInfo.get_all_info())
	update_table()
	if get_tree().is_network_server():
		# warning-ignore:return_value_discarded
		chosen_colors.erase(player_id)
		update_buttons()
		rpc("sync_chosen_colors", chosen_colors)


# Disconnect from the lobby.
func on_back_button_press() -> void:
	MultiplayerInfo.disconnect_from_session()


# The start button was pressed. Change scene for all players to be the game scene.
func on_start_button_press() -> void:
	rpc("start_game")
	start_game()


# Start the game
remote func start_game() -> void:
	for player_id in chosen_colors.keys():
		if player_id == MultiplayerInfo.get_player_id():
			MultiplayerInfo.my_info.favorite_color = COLORS[chosen_colors[player_id]]
		else:
			MultiplayerInfo.player_info[player_id].favorite_color = COLORS[chosen_colors[player_id]]
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
		rpc_id(1, "player_selected_color", MultiplayerInfo.get_player_id(), idx)


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


# Generate a circle of buttons inside of the ButtonGrid node.
func generate_button_grid() -> void:
	for angle_idx in range(8):
		var angle := PI/4 * angle_idx
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
	var info := MultiplayerInfo.get_all_info().values()
	info.sort_custom(Sorter, "sort_by_name")
	for row_idx in range(8):
		var row := table.get_node("Row" + str(row_idx + 1)) as PanelContainer
		if row_idx < len(info):
			var name_label := row.get_node("HBoxContainer/Name") as Label
			var player_info = info[row_idx]
			name_label.text = player_info.name
			if player_info.id in chosen_colors:
				name_label.add_color_override("font_color", COLORS[chosen_colors[player_info.id]])
		else:
			row.get_node("HBoxContainer/Name").text = ""


# Update the enabled/disabled state for all buttons.
func update_buttons() -> void:
	for idx in range(8):
		button_circle.get_node(str(idx)).disabled = (idx in chosen_colors.values())
	if not get_tree().is_network_server():
		start_button.disabled = true
	else:
		var all_players_selected := true
		for player_id in MultiplayerInfo.get_all_info().keys():
			if not (player_id in chosen_colors):
				all_players_selected = false
		start_button.disabled = not all_players_selected and len(chosen_colors.keys()) > 1


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if 1 in MultiplayerInfo.get_all_info():
		server_name.text = MultiplayerInfo.get_all_info()[1].name + "'s Server"
	generate_button_grid()
	update_table()
