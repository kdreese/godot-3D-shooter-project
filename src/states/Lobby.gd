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


onready var button_circle := $"%ButtonGrid" as Control
onready var table := $"%Table" as VBoxContainer
onready var server_name := $"%ServerName" as Label
onready var server_url := $"%ServerURL" as Label

var selected_button_idx := -1

# Dictionary from player_id to button idx.
var chosen_buttons := {}


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


# Update the information stored in the table.
func update_table() -> void:
	var info := MultiplayerInfo.get_all_info().values()
	info.sort_custom(Sorter, "sort_by_name")
	var player_idx := 0
	for player_info in info:
		var row := table.get_node("Row" + str(player_idx + 1)) as PanelContainer
		row.get_node("HBoxContainer/Name").text = player_info.name
		player_idx += 1
	if get_tree().is_network_server():
		rpc("set_chosen_buttons", chosen_buttons.values())


# Called when we press a button.
func on_color_button_press(idx: int) -> void:
	rpc("player_selected_button", MultiplayerInfo.get_player_id(), idx)
	player_selected_button(MultiplayerInfo.get_player_id(), idx)


# Called whenever anyone presses a button.
remote func player_selected_button(player_id: int, button_idx: int) -> void:
	if get_tree().is_network_server():
		chosen_buttons[player_id] = button_idx
		rpc("sync_chosen_buttons", chosen_buttons)
		disable_chosen_buttons()


# Disable buttons based on which are selected by players.
remote func sync_chosen_buttons(buttons: Dictionary) -> void:
	chosen_buttons = buttons
	disable_chosen_buttons()


func disable_chosen_buttons() -> void:
	print(chosen_buttons)
	for button_idx in range(8):
		button_circle.get_node(str(button_idx)).disabled = (button_idx in chosen_buttons.values())


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if 1 in MultiplayerInfo.get_all_info():
		server_name.text = MultiplayerInfo.get_all_info()[1].name + "'s Server"
	generate_button_grid()
	update_table()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass
