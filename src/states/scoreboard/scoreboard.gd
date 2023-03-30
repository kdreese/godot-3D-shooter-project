class_name Scoreboard
extends Control


const COLOR_NAMES = [
	"Red",
	"Orange",
	"Yellow",
	"Green",
	"Light Blue",
	"Blue",
	"Purple",
	"Pink"
]

const ScoreboardEntryScene = preload("res://src/states/scoreboard/scoreboard_entry.tscn")

var individual_score = {}

@onready var scoreboard_list = %ScoreboardList

# For now, rpc-ing with this being typed causes a Godot error
var scoreboard_data: ScoreboardData = ScoreboardData.new()


func _ready() -> void:
	create_scoreboard()
	update_display()


# Populate the scoreboard's initial state using the data in the Multiplayer class.
func create_scoreboard() -> void:
	if Multiplayer.game_mode == Multiplayer.GameMode.FFA:
		create_ffa_scoreboard()
	else:
		create_team_scoreboard()


func create_ffa_scoreboard():
	for player in Multiplayer.player_info.values():
		var entry = ScoreboardEntryData.new_ffa_player(player.id, player.name, player.color)
		scoreboard_data.entries.append(entry)


func create_team_scoreboard():
	var teams: Array[int] = []
	for player in Multiplayer.player_info.values():
		if player.team_id not in teams:
			teams.append(player.team_id)

	for team_id in teams:
		# Create an entry for the team.
		var team_entry := ScoreboardEntryData.new_team(
			team_id,
			"%s Team" % COLOR_NAMES[team_id],
			Lobby.COLORS[team_id]
		)
		scoreboard_data.entries.append(team_entry)
		for player in Multiplayer.player_info.values():
			if player.team_id == team_id:
				var player_entry := ScoreboardEntryData.new_team_player(
					player.id,
					team_id,
					player.name,
					Color.WHITE
				)
				scoreboard_data.entries.append(player_entry)


@rpc
func update_score(new_score) -> void:
	scoreboard_data = ScoreboardData.deserialize(new_score)
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


# Only called on the server.
func record_score(player_id: int) -> void:
	scoreboard_data.record_score(player_id)
	update_display()
	if get_multiplayer().has_multiplayer_peer():
		rpc("update_score", scoreboard_data.serialize())


func get_score(id: int):
	return scoreboard_data.get_player_entry(id).score


func remove_player(id: int) -> void:
	scoreboard_data.remove_player(id)
	update_display()
