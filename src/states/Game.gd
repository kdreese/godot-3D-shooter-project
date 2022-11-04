extends Node


onready var pause_menu := $"%PauseMenu" as Control

var target_transforms = []
var target_id = 0


func _ready() -> void:
	randomize()
	var curr_level := preload("res://src/levels/Level.tscn").instance() as Spatial
	add_child(curr_level)
	store_target_data()

	spawn_targets_if_host()

	spawn_player()
	for player_id in MultiplayerInfo.player_info.keys():
		spawn_peer_player(player_id)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		pause_menu.open_menu()


func spawn_targets_if_host() -> void:
	var targets = []
	if not get_tree().network_peer or get_tree().is_network_server():
		targets = select_targets()

	spawn_targets(targets)
	if get_tree().network_peer:
		rpc("spawn_targets", targets)


func on_target_destroy() -> void:
	var targets = get_tree().get_nodes_in_group("Targets")
	var num_targets = len(targets)
	if num_targets <= 1:
		# This is the last target that was hit (will be freed during this frame).
		spawn_targets_if_host()


func store_target_data() -> void:
	var targets = get_tree().get_nodes_in_group("Targets")
	for target in targets:
		# Copy the target's position and then queue it for deletion.
		target_transforms.append(target.transform)
		target.queue_free()


func select_targets() -> Array:
	# Generate a list of indices into the transform list corresponding to targets to spawn.
	var num_targets = randi() % 3 + 2 # Random integer in [2, 5]
	var indices = []
	var transforms = []
	for _i in range(num_targets):
		var index = randi() % len(target_transforms)
		# If we get a duplicate, try again
		while index in indices:
			index = randi() % len(target_transforms)
		indices.append(index)
		transforms.append(target_transforms[index])
	return transforms


# Spawn a few targets spread throughout the level.
remote func spawn_targets(transforms: Array) -> void:
	for transform in transforms:
		var target := preload("res://src/objects/Target.tscn").instance() as Area
		target.transform = transform
		target.set_name(str(target_id))
		var error = target.connect("target_destroyed", self, "on_target_destroy")
		assert(not error)
		get_node("Level/Targets").add_child(target)
		target_id += 1


func spawn_player() -> void:
	var my_player := preload("res://src/objects/Player.tscn").instance() as KinematicBody
	my_player.get_node("Nameplate").hide()
	if get_tree().network_peer:
		var self_peer_id = get_tree().get_network_unique_id()
		my_player.set_name(str(self_peer_id))
		my_player.set_network_master(self_peer_id)
	my_player.get_node("Camera").current = true
	my_player.translation = get_node("Level/PlayerSpawnPoint").translation
	get_node("Players").add_child(my_player)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


remote func spawn_peer_player(player_id) -> void:
	var player = preload("res://src/objects/Player.tscn").instance() as KinematicBody
	player.set_name(str(player_id))
	player.get_node("Nameplate").text = MultiplayerInfo.player_info[player_id].name
	player.set_network_master(player_id)
	get_node("Players").add_child(player)
