class_name ScoreboardEntry
extends Control


const LARGE_FONT_SIZE := 24
const SMALL_FONT_SIZE := 16
const INDENT_SIZE := 25


@onready var indent: Control = $Indent
@onready var name_label: Label = %NameLabel
@onready var score_label: Label = %ScoreLabel


func update(data: ScoreboardEntryData) -> void:
	name_label.text = data.name
	score_label.text = str(data.score)
	if data.type == ScoreboardEntryData.EntryType.TEAM_PLAYER:
		indent.show()
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.add_theme_font_size_override("font_size", SMALL_FONT_SIZE)
		score_label.add_theme_font_size_override("font_size", SMALL_FONT_SIZE)
	else:
		indent.hide()
		name_label.add_theme_color_override("font_color", data.color)
		name_label.add_theme_font_size_override("font_size", LARGE_FONT_SIZE)
		score_label.add_theme_font_size_override("font_size", LARGE_FONT_SIZE)
