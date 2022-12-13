extends Node


const SPAWN_CAMP_REPELLANT_RADIUS := 3

onready var pause_menu := $"%PauseMenu" as Control

# A list of all the possible target locations within the current level.
var target_transforms := []
# The ID of the most recently spawned target. Each target has a unique ID to to synchronization between clients.
var target_id := 0
# A list of all the possible spawn locations within the current level.
var spawn_transforms := []


func _ready() -> void:
	randomize()

	# Add the current player to the scoreboard.
	$UI/Scoreboard.add_player(MultiplayerInfo.get_player_id())

	var curr_level := preload("res://src/levels/Level.tscn").instance() as Spatial
	add_child(curr_level)
	spawn_transforms = get_tree().get_nodes_in_group("SpawnPoints")
	store_target_data()

	spawn_new_targets_if_host()

	spawn_player()
	for player_id in MultiplayerInfo.player_info.keys():
		spawn_peer_player(player_id)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		pause_menu.open_menu()


# Called when a target is destroyed.
# :param player_id: The ID of the player that destroyed the target.
func on_target_destroy(player_id: int) -> void:
	if player_id == MultiplayerInfo.get_player_id():
		get_node("UI/Scoreboard").record_score()
	var num_targets := len(get_tree().get_nodes_in_group("Targets"))
	if num_targets <= 1:
		# This is the last target that was hit (will be freed during this frame).
		spawn_new_targets_if_host()


# Get the position of every target in the level, then delete them. Used when the level loads in to get target positions.
func store_target_data() -> void:
	var targets = get_tree().get_nodes_in_group("Targets")
	for target in targets:
		# Copy the target's position and then queue it for deletion.
		target_transforms.append(target.transform)
		target.queue_free()


# Get a list of candidate targets to spawn. Returns a dictionary from target ID to position, with 2-5 entries.
func select_targets() -> Dictionary:
	# Generate a list of indices into the transform list corresponding to targets to spawn.
	var num_targets := randi() % 3 + 2 # Random integer in [2, 5]
	var indices := []
	var transforms := {}
	for _i in range(num_targets):
		var index := randi() % len(target_transforms)
		# If we get a duplicate, try again
		while index in indices:
			index = randi() % len(target_transforms)
		indices.append(index)
		transforms[target_id] = target_transforms[index]
		target_id += 1
	return transforms


# Spawn targets given their IDs and locations.
# :param transforms: A dictionary from ID to transform matrix for each target to spawn.
remote func spawn_targets(transforms: Dictionary) -> void:
	for id in transforms.keys():
		var target := preload("res://src/objects/Target.tscn").instance() as Area
		target.transform = transforms[id]
		target.set_name(str(id))
		var error := target.connect("target_destroyed", self, "on_target_destroy")
		assert(not error)
		get_node("Level/Targets").add_child(target)


# Spawn a few targets, only if we are the network host.
func spawn_new_targets_if_host() -> void:
	var targets := select_targets()
	if not get_tree().network_peer:
		spawn_targets(targets)
	elif get_tree().is_network_server():
		spawn_targets(targets)
		sync_targets()


# Synchronize the current targets between clients. Used when clients join to populate the initial state.
# :param player_id: The player ID to send information to, or -1 to send information to all players. Defaults to -1.
func sync_targets(player_id: int = -1) -> void:
	# Get all the current targets.
	var targets := get_tree().get_nodes_in_group("Targets")
	# An output dictionary, to pass into spawn_targets()
	var output := {}
	for target in targets:
		var id := int(target.name)
		output[id] = target.transform

	if player_id == -1:
		rpc("spawn_targets", output)
	else:
		rpc_id(player_id, "spawn_targets", output)


# Spawn the player that we are controlling.
func spawn_player() -> void:
	var my_player := preload("res://src/objects/Player.tscn").instance() as KinematicBody
	var error := my_player.connect("respawn", self, "set_spawn_point", [my_player])
	assert(not error)
	my_player.get_node("Nameplate").hide()
	if get_tree().network_peer:
		var self_peer_id := get_tree().get_network_unique_id()
		my_player.set_name(str(self_peer_id))
		my_player.set_network_master(self_peer_id)
	my_player.get_node("Camera").current = true
	set_spawn_point(my_player)
	$Players.add_child(my_player)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# Spawn a player controlled by another person.
remote func spawn_peer_player(player_id: int) -> void:
	var player := preload("res://src/objects/Player.tscn").instance() as KinematicBody
	var player_info = MultiplayerInfo.player_info[player_id]
	player.set_name(str(player_id))
	player.get_node("Nameplate").text = player_info.name
	var mesh_instance := player.get_node("MeshInstance") as MeshInstance
	var material := mesh_instance.mesh.surface_get_material(0) as SpatialMaterial
	material.albedo_color = player_info.favorite_color
	mesh_instance.mesh.surface_set_material(0, material)
	player.set_network_master(player_id)
	$Players.add_child(player)

	if get_tree().is_network_server():
		sync_targets(player_id)


func set_spawn_point(my_player) -> void:
	var i := 0
	var spawn_transforms_available := []
	var num_open := 0
	for p in spawn_transforms:
		var num_adj_players := 0
		for player in get_tree().get_nodes_in_group("Players"):
			if player == my_player:
				continue
			if player.translation.distance_to(p.translation) < SPAWN_CAMP_REPELLANT_RADIUS:
				num_adj_players += 1
		if num_adj_players <= 0:
			spawn_transforms_available.append(spawn_transforms[i])
			num_open += 1
		i += 1
	var rand_spawn: Position3D
	if num_open > 0:
		var rand := randi() % num_open
		rand_spawn = spawn_transforms_available[rand]
	else:
		push_warning("Couldn't find available spawn point")
		rand_spawn = spawn_transforms[randi() % len(spawn_transforms)]
	my_player.translation = rand_spawn.translation
	my_player.rotation = rand_spawn.rotation


# De-spawn a player controlled by another person.
# :param player_id: The ID of the player to de-spawn.
func remove_peer_player(player_id: int) -> void:
	var player := $Players.get_node(str(player_id))
	if player:
		$Players.remove_child(player)
	$UI/Scoreboard.remove_player(player_id)
