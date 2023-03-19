class_name ScoreboardData
extends Resource

@export var entries: Array[ScoreboardEntryData] = []


func serialize() -> Array:
	var out := []
	for entry in entries:
		out.append(entry.serialize())
	return out


static func deserialize(from: Array) -> ScoreboardData:
	var out := ScoreboardData.new()
	for entry_dict in from as Array[Dictionary]:
		out.entries.append(ScoreboardEntryData.deserialize(entry_dict))
	return out


# Get the entry for the player with the specific ID.
func get_player_entry(id: int) -> ScoreboardEntryData:
	var filter_func = func(x):
		return x.id == id and x.type != ScoreboardEntryData.EntryType.TEAM_TOTAL
	var matching_entries = entries.filter(filter_func)
	if len(matching_entries) != 1:
		push_error(
			"Badly formatted scoreboard data (found %d matching entries for single player)" %
			len(matching_entries)
		)
		return null

	return matching_entries[0]


func get_team_entry(team_id: int) -> ScoreboardEntryData:
	if team_id == -1:
		push_error("Team ID -1 is invalid. Cannot get socreboard entry.")
		return null

	var filter_func = func(x):
		return x.team_id == team_id and x.type == ScoreboardEntryData.EntryType.TEAM_TOTAL
	var matching_entries = entries.filter(filter_func)
	if len(matching_entries) != 1:
		push_error(
			"Badly formatted scoreboard data (found %d matching entries for team total)" %
			len(matching_entries)
		)
		return null

	return matching_entries[0]


func record_score(id: int) -> void:
	var player_entry := get_player_entry(id)
	player_entry.score += 1
	if player_entry.team_id != -1:
		var team_entry = get_team_entry(player_entry.team_id)
		team_entry.score += 1


func remove_player(id: int) -> void:
	var entry := get_player_entry(id)
	entries.erase(entry)

	# Check to see if the player was the last in their team to leave. If so, delete the team entry.
	var team_id := entry.team_id as int
	# Look for only player entries with the same team ID.
	var filter_func = func(x):
		return x.team_id == team_id and x.type != ScoreboardEntryData.EntryType.TEAM_TOTAL
	if entry.team_id != -1 and not entries.any(filter_func):
		var team_entry := get_team_entry(team_id)
		entries.erase(team_entry)
