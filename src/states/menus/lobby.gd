class_name Lobby
extends Control


class Sorter:
	static func sort_by_name(a, b):
		return a.username.to_lower() < b.username.to_lower()


signal change_menu(to_menu: String)

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


@onready var button_circle: Control = %ButtonCircle
@onready var table: VBoxContainer = %Table
@onready var server_name: Label = %ServerName
@onready var back_button: Button = %BackButton
@onready var start_button: Button = %StartButton
@onready var mode_drop_down: MenuButton = %ModeDropDown
@onready var game_mode_drop_down: MenuButton = %GameModeDropDown
@onready var ping_timer: Timer = %PingTimer
@onready var player_table_row_template: PanelContainer = %Row.duplicate()

var player_table_rows: Array[PanelContainer] = []

# Dictionary from player_id to button/color index.
var chosen_colors := {}

# Dictionary from player_id to ready status.
var players_ready := {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Multiplayer.latency_updated.connect(on_latency_update)
	Multiplayer.player_connected.connect(player_connected)
	Multiplayer.player_disconnected.connect(player_disconnected)
	Multiplayer.server_disconnected.connect(server_disconnected)
	mode_drop_down.get_popup().id_pressed.connect(on_mode_select)
	game_mode_drop_down.get_popup().id_pressed.connect(on_game_mode_select)
	ping_timer.timeout.connect(Multiplayer.get_current_latency)
	if not Multiplayer.dedicated_server:
		generate_button_grid()


func show_menu() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	generate_player_table()

	# If colors are already selected (like if a match just ended) preserve them.
	for player in Multiplayer.get_players():
		players_ready[player.id] = false
		if player.team_id != -1:
			chosen_colors[player.id] = player.team_id
	update_display()


@rpc("any_peer", "call_local")
func sync_colors(_chosen_colors: Dictionary):
	chosen_colors = _chosen_colors


# Called on the server when someone says they are ready.
@rpc("any_peer", "call_local")
func player_ready(state: bool):
	players_ready[multiplayer.get_remote_sender_id()] = state
	sync_ready_status.rpc(players_ready)
	update_display()


# Called for everyone when the server updates ready status.
@rpc("call_local")
func sync_ready_status(ready_status: Dictionary):
	players_ready = ready_status
	update_display()


# Called on servers and clients when a player connects. Make the server sync the colors.
func player_connected() -> void:
	if is_multiplayer_authority():
		sync_colors.rpc(chosen_colors)
		update_display.rpc()


# Called on the server when a player disconnects.
func player_disconnected(player_id: int) -> void:
	if is_multiplayer_authority():
		chosen_colors.erase(player_id)
		sync_colors.rpc(chosen_colors)
		update_display.rpc()


func server_disconnected() -> void:
	Global.server_kicked = true
	change_menu.emit("main_menu")


# Disconnect from the lobby.
func on_back_button_press() -> void:
	Multiplayer.disconnect_from_session()
	change_menu.emit("main_menu")


# The start button was pressed. Change scene for all players to be the game scene.
@rpc("any_peer")
func on_start_button_press() -> void:
	if is_multiplayer_authority():
		Multiplayer.unready_players()
		start_game.rpc()
	else:
		rpc_id(1, "on_start_button_press")


# Start the game
@rpc("authority", "call_local")
func start_game() -> void:
	for player_id in chosen_colors.keys():
		var player := Multiplayer.get_player_by_id(player_id)
		player.color = COLORS[chosen_colors[player_id]]
		player.team_id = chosen_colors[player_id]
	if Multiplayer.game_info.game_mode == Multiplayer.GameMode.SHOWDOWN:
		var error := get_tree().change_scene_to_file("res://src/states/showdown_gamemode.tscn")
		assert(not error)
	elif Multiplayer.game_info.game_mode == Multiplayer.GameMode.TARGETS:
		var error := get_tree().change_scene_to_file("res://src/states/targets_gamemode.tscn")
		assert(not error)


# Called whenever someone selects a mode from the drop-down.
# :param new_mode_id: The ID of the selected mode.
func on_mode_select(new_mode_id: Multiplayer.TeamMode) -> void:
	# If we select the same game mode we have already selected, do nothing.
	if new_mode_id == Multiplayer.game_info.team_mode:
		return
	if new_mode_id == Multiplayer.TeamMode.FFA:
		sync_colors.rpc({})
	Multiplayer.game_info.team_mode = new_mode_id as Multiplayer.TeamMode
	Multiplayer.update_state.rpc(Multiplayer.game_info.serialize())
	update_display.rpc()


# Called whenever someone selects a game mode from the drop-down.
# :param new_game_mode_id: The ID of the selected game mode.
func on_game_mode_select(new_game_mode_id: Multiplayer.GameMode) -> void:
	# If we select the same game mode we have already selected, do nothing.
	if new_game_mode_id == Multiplayer.game_info.game_mode:
		return
	Multiplayer.game_info.game_mode = new_game_mode_id as Multiplayer.GameMode
	Multiplayer.update_state.rpc(Multiplayer.game_info.serialize())
	update_display.rpc()


# Called when we press a color button.
# :param idx: The index of the button/color pressed.
func on_color_button_press(idx: int) -> void:
	chosen_colors[get_multiplayer().get_unique_id()] = idx
	sync_colors.rpc(chosen_colors)
	update_display.rpc()
	if not %ReadyPanel.visible:
		%ReadyPanel.show()


func on_ready_checkbox_update(state: bool) -> void:
	player_ready.rpc_id(1, state)


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


# Create the player list structure.
func generate_player_table() -> void:
	for child in %Table.get_children():
		if child.name == "Header" or child.name == "Footer":
			continue
		%Table.remove_child(child)
		child.queue_free()

	player_table_rows.clear()

	for idx in range(Multiplayer.game_info.max_players):
		var new_row: PanelContainer = player_table_row_template.duplicate()
		if idx % 2 == 0:
			new_row.add_theme_stylebox_override("panel", preload("res://resources/ui_themes/table_row_1.tres"))
		else:
			new_row.add_theme_stylebox_override("panel", preload("res://resources/ui_themes/table_row_2.tres"))

		player_table_rows.append(new_row)
		%Table.add_child(new_row)

	# Since we added all the player rows, we need to shift the footer back down.
	var footer = %Table.find_child("Footer")
	%Table.move_child(footer, %Table.get_child_count() - 1)


# Update all the visual elements
@rpc("any_peer", "call_local")
func update_display() -> void:
	update_buttons()
	update_table()
	mode_drop_down.text = mode_drop_down.get_popup().get_item_text(Multiplayer.game_info.team_mode)
	game_mode_drop_down.text = game_mode_drop_down.get_popup().get_item_text(Multiplayer.game_info.game_mode)
	server_name.text = Multiplayer.game_info.server_name
	if Multiplayer.is_hosting():
		back_button.text = "Stop Hosting"
	else:
		back_button.text = "Disconnect"


# Update the information stored in the table.
func update_table() -> void:
	var info := Multiplayer.get_players()
	info.sort_custom(Callable(Sorter,"sort_by_name"))
	var row_idx = 0
	for player_row in player_table_rows:
		if row_idx >= info.size():
			clear_table_row(player_row)
		else:
			var player_info = info[row_idx]
			update_table_row(player_row, player_info)
		row_idx += 1


func update_table_row(row: PanelContainer, player_info: Multiplayer.PlayerInfo):
	var name_label := row.get_node("HBoxContainer/Name") as Label
	var score_label := row.get_node("HBoxContainer/Score") as Label
	var ping_label := row.get_node("HBoxContainer/Ping") as Label
	var ready_icon := row.get_node("HBoxContainer/ReadyIcon") as TextureRect
	name_label.text = player_info.username
	if player_info.latest_score >= 0:
		score_label.text = str(player_info.latest_score)
	if player_info.id in chosen_colors:
		name_label.add_theme_color_override("font_color", COLORS[chosen_colors[player_info.id]])
	else:
		name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	ping_label.text = "%dms" % player_info.latency
	if players_ready.get(player_info.id, false):
		ready_icon.modulate = Color.WHITE
	else:
		ready_icon.modulate = Color.TRANSPARENT


func clear_table_row(row: PanelContainer):
	var name_label := row.get_node("HBoxContainer/Name") as Label
	var score_label := row.get_node("HBoxContainer/Score") as Label
	var ping_label := row.get_node("HBoxContainer/Ping") as Label
	var ready_icon := row.get_node("HBoxContainer/ReadyIcon") as TextureRect
	name_label.text = ""
	score_label.text = ""
	ping_label.text = ""
	ready_icon.modulate = Color.TRANSPARENT


# Update the enabled/disabled state for all buttons.
func update_buttons() -> void:
	if not Multiplayer.dedicated_server:
		for idx in range(len(COLORS)):
			var button := button_circle.get_node(str(idx)) as ColorButton
			# Do not allow multiple people to select the same color in free-for-all mode.
			if Multiplayer.game_info.team_mode == Multiplayer.TeamMode.FFA:
				button.get_node("Button").disabled = (idx in chosen_colors.values())
			else:
				button.get_node("Button").disabled = false
			# If we are not selecting a button (e.g. after a mode change), clear focus for all buttons.
			if not (get_multiplayer().get_unique_id() in chosen_colors):
				button.get_node("Button").focus_mode = Control.FOCUS_NONE
	var all_players_selected := true
	var selected_colors := []
	for player_id in Multiplayer.get_player_ids():
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
		start_button.disabled = len(selected_colors) <= 1 and Multiplayer.game_info.team_mode != Multiplayer.TeamMode.FFA
