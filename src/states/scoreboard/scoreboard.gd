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

const ScoreboardEntryScene = preload("res://src/states/scoreboard/scoreboard_entry.tscn")

var individual_score = {}

@onready var scoreboard_list = %ScoreboardList


var scoreboard_data: ScoreboardData


func _ready() -> void:
	scoreboard_data = preload("res://src/states/scoreboard/test_ffa_scoreboard.tres")
	update_display()


# Populate the scoreboard's initial state using the data in the Multiplayer class.
func create_scoreboard() -> void:
	if Multiplayer.game_mode == Multiplayer.GameMode.FFA:
		create_ffa_scoreboard()
	else:
		create_team_scoreboard()

func create_ffa_scoreboard():
	pass

func create_team_scoreboard():
	pass


@rpc("any_peer") func update_score(new_score: Dictionary) -> void:
	for id in individual_score.keys():
		if id in new_score:
			individual_score[id] = new_score[id]
	update_display()


func update_display() -> void:
	# Remove existing children.
	for entry in scoreboard_list.get_children():
		scoreboard_list.remove_child(entry)
		entry.queue_free()
	for data in scoreboard_data.entries:
		var scoreboard_entry = ScoreboardEntryScene.instantiate() as ScoreboardEntry
		scoreboard_list.add_child(scoreboard_entry)
		scoreboard_entry.update(data)


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
