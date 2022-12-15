extends Node

# Player won't spawn at the current point if another player is within radius
const SPAWN_DISABLE_RADIUS := 3

onready var pause_menu := $"%PauseMenu" as Control

# A list of all the possible target locations within the current level.
var target_transforms := []
# The ID of the most recently spawned target. Each target has a unique ID to to synchronization between clients.
var target_id := 0
# A list of all the possible spawn locations within the current level.
var spawn_points := []


func _ready() -> void:
	randomize()

	# Add the current player to the scoreboard.
	$UI/Scoreboard.add_player(Multiplayer.get_player_id())

	var curr_level := preload("res://src/levels/Level.tscn").instance() as Spatial
	add_child(curr_level)
	spawn_points = get_tree().get_nodes_in_group("SpawnPoints")
	store_target_data()

	spawn_new_targets_if_host()

	spawn_player()
	for player_id in Multiplayer.player_info.keys():
		if player_id != Multiplayer.get_player_id():
			spawn_peer_player(player_id)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		pause_menu.open_menu()


# Called when a target is destroyed.
# :param player_id: The ID of the player that destroyed the target.
func on_target_destroy(player_id: int) -> void:
	if player_id == Multiplayer.get_player_id():
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
		target.get_parent().remove_child(target)
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
	# Destroy any existing targets
	var targets := get_tree().get_nodes_in_group("Targets")
	for target in targets:
		target.queue_free()

	# Spawn the new ones
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
	var error := my_player.connect("player_death", self, "move_to_spawn_point", [my_player])
	assert(not error)
	my_player.get_node("Nameplate").hide()
	if get_tree().network_peer:
		var self_peer_id := get_tree().get_network_unique_id()
		my_player.set_name(str(self_peer_id))
		my_player.set_network_master(self_peer_id)
	my_player.get_node("BodyMesh").hide()
	my_player.get_node("Head/HeadMesh").hide()
	my_player.get_node("Camera").current = true
	move_to_spawn_point(my_player)
	$Players.add_child(my_player)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# Spawn a player controlled by another person.
remote func spawn_peer_player(player_id: int) -> void:
	var player := preload("res://src/objects/Player.tscn").instance() as KinematicBody
	var player_info = Multiplayer.player_info[player_id]
	player.set_name(str(player_id))
	player.get_node("Nameplate").text = player_info.name
	var material := preload("res://resources/materials/player_material.tres").duplicate() as SpatialMaterial
	material.albedo_color = player_info.color
	player.get_node("BodyMesh").set_material_override(material)
	player.get_node("Head/HeadMesh").set_material_override(material)
	player.set_network_master(player_id)
	$Players.add_child(player)

	$UI/Scoreboard.add_player(player_id)
	if get_tree().is_network_server():
		$UI/Scoreboard.rpc("update_score", $UI/Scoreboard.current_score)


func move_to_spawn_point(my_player: KinematicBody) -> void:
	# A list of the spawn locations that can currently be spawned into
	var spawn_points_available := []
	for p in spawn_points:
		var num_adj_players := 0
		for player in get_tree().get_nodes_in_group("Players"):
			if player == my_player:
				continue
			if player.translation.distance_to(p.translation) < SPAWN_DISABLE_RADIUS:
				num_adj_players += 1
		if num_adj_players == 0:
			spawn_points_available.append(p)
	if len(spawn_points_available) == 0:
		push_warning("Couldn't find available spawn point")
		spawn_points_available = spawn_points
	var rand_spawn := spawn_points_available[randi() % len(spawn_points_available)] as Position3D
	my_player.transform = rand_spawn.transform
	my_player.reset_physics_interpolation()


# De-spawn a player controlled by another person.
# :param player_id: The ID of the player to de-spawn.
func remove_peer_player(player_id: int) -> void:
	var player := $Players.get_node(str(player_id))
	if player:
		$Players.remove_child(player)
	$UI/Scoreboard.remove_player(player_id)
