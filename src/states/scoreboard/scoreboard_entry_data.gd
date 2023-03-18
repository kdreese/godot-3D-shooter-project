class_name ScoreboardEntryData
extends Resource

enum EntryType {
	TEAM_TOTAL,
	TEAM_PLAYER,
	FFA_PLAYER
}

@export var id: int = 0
@export var name: String = ""
@export var color: Color = Color.WHITE
@export var score: int = 0
@export var type: EntryType = EntryType.FFA_PLAYER
