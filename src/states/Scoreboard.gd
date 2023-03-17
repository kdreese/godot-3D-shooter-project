class_name Scoreboard
extends Control


const COLOR_NAMES = [
	"Red",
	"Orange",
	"Yellow",
	"Green",
	"Light3D Blue",
	"Blue",
	"Purple",
	"Pink"
]

var individual_score = {}

@onready var score_grid := $"%ScoreGrid" as GridContainer


func _ready() -> void:
	update_display()


@rpc("any_peer") func update_score(new_score: Dictionary) -> void:
	for id in individual_score.keys():
		if id in new_score:
			individual_score[id] = new_score[id]
	update_display()


func update_display() -> void:
	# Delete any existing nodes from the grid.
	for node in score_grid.get_children():
		score_grid.remove_child(node)
		node.queue_free()

	var display_score := {}
	if Multiplayer.game_mode == Multiplayer.GameMode.FFA:
		display_score = individual_score
	else:
		display_score = calculate_team_score()

	# Create the new grid.
	for id in display_score.keys():
		var player_label := Label.new()
		if Multiplayer.game_mode == Multiplayer.GameMode.FFA:
			var player_info = Multiplayer.player_info[id]
			player_label.set("custom_colors/font_color", player_info["color"])
			player_label.text = player_info["name"]
		else:
			player_label.set("custom_colors/font_color", Lobby.COLORS[id])
			player_label.text = COLOR_NAMES[id] + " Team"
		score_grid.add_child(player_label)
		var score_label := Label.new()
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_label.text = str(display_score[id])
		score_grid.add_child(score_label)


# Calculates the current team scores.
# :return: A dictionary from color ID to team score.
func calculate_team_score() -> Dictionary:
	var result := {}
	for player_id in individual_score.keys():
		var team_id := Multiplayer.player_info[player_id]["team_id"] as int
		if team_id in result.keys():
			result[team_id] += individual_score[player_id]
		else:
			result[team_id] = individual_score[player_id]
	return result


func add_player(id: int) -> void:
	if not individual_score.has(id):
		individual_score[id] = 0
	update_display()


func remove_player(id: int) -> void:
	if individual_score.has(id):
		individual_score.erase(id)
	update_display()


func record_score() -> void:
	var id := Multiplayer.get_player_id() as int
	individual_score[id] = individual_score[id] + 1
	update_display()
	if get_multiplayer().has_multiplayer_peer():
		rpc("update_score", individual_score)
