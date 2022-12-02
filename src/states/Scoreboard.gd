class_name Scoreboard
extends Control


var data = {}

onready var score_grid := $"%ScoreGrid" as GridContainer


func _ready() -> void:
	update_display()

func update_display() -> void:
	# Delete any existing nodes from the grid.
	for node in score_grid.get_children():
		score_grid.remove_child(node)
		node.queue_free()

	# Create the new grid.
	for id in data.keys():
		var player_label = Label.new()
		player_label.set("custom_colors/font_color", data[id]["color"])
		player_label.text = data[id]["name"]
		score_grid.add_child(player_label)
		var score_label = Label.new()
		score_label.set_align(Label.ALIGN_RIGHT)
		score_label.text = str(data[id]["score"])
		score_grid.add_child(score_label)

func add_player(id: int, name: String, color: Color) -> void:
	if not data.has(id):
		data[id] = {}
		data[id]["name"] = name
		data[id]["color"] = color
		data[id]["score"] = 0
	update_display()


func remove_player(id: int) -> void:
	if data.has(id):
		data.erase(id)
	update_display()


func record_score(id: int) -> void:
	if data.has(id):
		data[id]["score"] = data[id]["score"] + 1
	update_display()
