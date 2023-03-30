class_name ScoreboardEntryData
extends Resource

enum EntryType {
	TEAM_TOTAL,
	TEAM_PLAYER,
	FFA_PLAYER
}

@export var id: int = -1
@export var team_id: int = -1
@export var name: String = ""
@export var color: Color = Color.WHITE
@export var score: int = 0
@export var type: EntryType = EntryType.FFA_PLAYER


func _init(_id: int, _team_id: int, _name: String, _color: Color, _score: int, _type: EntryType):
	id = _id
	team_id = _team_id
	name = _name
	color = _color
	score = _score
	type = _type


static func new_ffa_player(_id: int, _name: String, _color: Color) -> ScoreboardEntryData:
	return ScoreboardEntryData.new(_id, -1, _name, _color, 0, EntryType.FFA_PLAYER)


static func new_team_player(_id: int, _team_id: int, _name: String, _color: Color) -> ScoreboardEntryData:
	return ScoreboardEntryData.new(_id, _team_id, _name, _color, 0, EntryType.TEAM_PLAYER)


static func new_team(_team_id: int, _name: String, _color: Color) -> ScoreboardEntryData:
	return ScoreboardEntryData.new(-1, _team_id, _name, _color, 0, EntryType.TEAM_TOTAL)


func serialize() -> Dictionary:
	return {
		"id": id,
		"team_id": team_id,
		"name": name,
		"color": color,
		"score": score,
		"type": type
	}


static func deserialize(from: Dictionary) -> ScoreboardEntryData:
	return ScoreboardEntryData.new(
		from["id"],
		from["team_id"],
		from["name"],
		from["color"],
		from["score"],
		from["type"]
	)
