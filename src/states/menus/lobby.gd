class_name Lobby
extends Control


class Sorter:
	static func sort_by_name(a, b):
		return a.name.to_lower() < b.name.to_lower()


signal change_menu

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


@onready var button_circle: Control = %ButtonCircle
@onready var table: VBoxContainer = %Table
@onready var server_name: Label = %ServerName
@onready var back_button: Button = %BackButton
@onready var start_button: Button = %StartButton
@onready var mode_drop_down: MenuButton = %ModeDropDown
@onready var ping_timer: Timer = %PingTimer


# Dictionary from player_id to button/color index.
var chosen_colors := {}


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Multiplayer.latency_updated.connect(on_latency_update)
	Multiplayer.player_connected.connect(player_connected)
	Multiplayer.player_disconnected.connect(player_disconnected)
	Multiplayer.server_disconnected.connect(server_disconnected)
	mode_drop_down.get_popup().id_pressed.connect(on_mode_select)
	ping_timer.timeout.connect(Multiplayer.get_current_latency)
	if not Multiplayer.dedicated_server:
		generate_button_grid()


func show_menu() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# If colors are already selected (like if a match just ended) preserve them.
	for player_id in Multiplayer.player_info.keys():
		if "team_id" in Multiplayer.player_info[player_id]:
			chosen_colors[player_id] = Multiplayer.player_info[player_id].team_id
	update_display()


@rpc("any_peer", "call_local")
func sync_colors(_chosen_colors: Dictionary):
	chosen_colors = _chosen_colors

# Called on servers and clients when a player connects. Make the server sync the colors.
func player_connected() -> void:
	if is_multiplayer_authority():
		Multiplayer.rpc("update_state", Multiplayer.player_info, Multiplayer.game_mode, Multiplayer.player_latency)
		rpc("sync_colors", chosen_colors)
		rpc("update_display")


# Called on the server when a player disconnects.
func player_disconnected(player_id: int) -> void:
	if is_multiplayer_authority():
		chosen_colors.erase(player_id)
		rpc("sync_colors", chosen_colors)
		rpc("update_display")


func server_disconnected() -> void:
	Global.server_kicked = true
	emit_signal("change_menu", "main_menu")


# Disconnect from the lobby.
func on_back_button_press() -> void:
	Multiplayer.disconnect_from_session()
	emit_signal("change_menu", "main_menu")


# The start button was pressed. Change scene for all players to be the game scene.
@rpc("any_peer")
func on_start_button_press() -> void:
	if is_multiplayer_authority():
		Multiplayer.unready_players()
		rpc("start_game")
	else:
		rpc_id(1, "on_start_button_press")


# Start the game
@rpc("authority", "call_local")
func start_game() -> void:
	for player_id in chosen_colors.keys():
		Multiplayer.player_info[player_id].color = COLORS[chosen_colors[player_id]]
		Multiplayer.player_info[player_id].team_id = chosen_colors[player_id]
	var error := get_tree().change_scene_to_file("res://src/states/game.tscn")
	assert(not error)


# Called whenever someone selects a mode from the drop-down.
# :param new_mode_id: The ID of the selected mode.
func on_mode_select(new_mode_id: int) -> void:
	# If we select the same game mode we have already selected, do nothing.
	if new_mode_id == Multiplayer.game_mode:
		return
	if new_mode_id == Multiplayer.GameMode.FFA:
		rpc("sync_colors", {})
	Multiplayer.rpc("update_state", Multiplayer.player_info, new_mode_id, Multiplayer.player_latency)
	rpc("update_display")


# Called when we press a color button.
# :param idx: The index of the button/color pressed.
func on_color_button_press(idx: int) -> void:
	chosen_colors[get_multiplayer().get_unique_id()] = idx
	rpc("sync_colors", chosen_colors)
	rpc("update_display")


# Called on the server when it receives a ping response.
func on_latency_update() -> void:
	update_display()


# Called in clients to update the ping values of players.
# :param pings: A map from player ID to ping in ms.
@rpc("any_peer")
func sync_pings(pings: Dictionary) -> void:
	Multiplayer.player_latency = pings
	update_table()


# Generate a circle of buttons inside of the ButtonGrid node.
func generate_button_grid() -> void:
	for angle_idx in range(len(COLORS)):
		var angle := (2 * PI / len(COLORS)) * angle_idx
		var button := preload("res://src/objects/color_button.tscn").instantiate() as ColorButton
		button.set_button_color(COLORS[angle_idx])
		button_circle.add_child(button)
		button.position = Vector2(BUTTON_CIRCLE_RADIUS, 0).rotated(angle - PI/2) - button.custom_minimum_size / 2.0
		# Set the properties (name, text, color)
		button.name = str(angle_idx)
		button.get_node("Button").button_down.connect(on_color_button_press.bind(angle_idx))


# Update all the visual elements
@rpc("any_peer", "call_local")
func update_display() -> void:
	update_buttons()
	update_table()
	mode_drop_down.text = mode_drop_down.get_popup().get_item_text(Multiplayer.game_mode)
	#server_name.text = Multiplayer.player_info[1].name + "'s Server"
	if Multiplayer.is_hosting():
		back_button.text = "Stop Hosting"
	else:
		back_button.text = "Disconnect"


# Update the information stored in the table.
func update_table() -> void:
	var info := Multiplayer.player_info.values()
	info.sort_custom(Callable(Sorter,"sort_by_name"))
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
				name_label.add_theme_color_override("font_color", COLORS[chosen_colors[player_info.id]])
			else:
				name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
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
			if not (get_multiplayer().get_unique_id() in chosen_colors):
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
