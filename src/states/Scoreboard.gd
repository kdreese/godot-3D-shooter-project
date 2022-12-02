class_name Scoreboard
extends Control


var current_score = {}

onready var score_grid := $"%ScoreGrid" as GridContainer


func _ready() -> void:
	update_display()


remote func update_score(new_score: Dictionary) -> void:
	for id in current_score.keys():
		if id in new_score:
			current_score[id] = new_score[id]
	update_display()


func update_display() -> void:
	# Delete any existing nodes from the grid.
	for node in score_grid.get_children():
		score_grid.remove_child(node)
		node.queue_free()

	# Create the new grid.
	for id in current_score.keys():
		var player_info
		if id == get_tree().get_network_unique_id():
			player_info = MultiplayerInfo.my_info
		else:
			player_info = MultiplayerInfo.player_info[id]
		var player_label := Label.new()
		player_label.set("custom_colors/font_color", player_info["favorite_color"])
		player_label.text = player_info["name"]
		score_grid.add_child(player_label)
		var score_label := Label.new()
		score_label.set_align(Label.ALIGN_RIGHT)
		score_label.text = str(current_score[id])
		score_grid.add_child(score_label)

func add_player(id: int) -> void:
	if not current_score.has(id):
		current_score[id] = 0
	update_display()


func remove_player(id: int) -> void:
	if current_score.has(id):
		current_score.erase(id)
	update_display()


func record_score() -> void:
	var id := get_tree().get_network_unique_id()
	current_score[id] = current_score[id] + 1
	update_display()
	rpc("update_score", current_score)
