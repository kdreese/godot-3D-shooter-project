extends Node

# Player won't spawn at the current point if another player is within radius
const SPAWN_DISABLE_RADIUS := 3
const SHOT_SPEED := 100.0
const MAX_ARROWS_LOADED := 30

const Arrow = preload("res://src/objects/arrow.tscn")

@onready var pause_menu := $"%PauseMenu" as Control
@onready var arrows: Node = $"%Arrows"

# A list of all the possible target locations within the current level.
var target_transforms := []
# The ID of the most recently spawned target. Each target has a unique ID to to synchronization between clients.
var target_id := 0
# A list of all the possible spawn locations within the current level.
var spawn_points := []

# Countdown timer for match length
var time_remaining := 120.0


func _ready() -> void:
	randomize()

	var curr_level := preload("res://src/levels/level.tscn").instantiate() as Node3D
	add_child(curr_level)
	spawn_points = get_tree().get_nodes_in_group("SpawnPoints")
	store_target_data()

	spawn_new_targets_if_host()

	if Multiplayer.dedicated_server:
		var camera := curr_level.get_node_or_null("SpectatorCamera") as Camera3D
		if camera:
			camera.current = true
		find_child("Reticle").hide()
	else:
		spawn_player()
		# Add the current player to the scoreboard.
		$UI/Scoreboard.add_player(Multiplayer.get_player_id())
	for player_id in Multiplayer.player_info.keys():
		if player_id != Multiplayer.get_player_id():
			spawn_peer_player(player_id)

	Multiplayer.player_disconnected.connect(player_disconnected)
	Multiplayer.server_disconnected.connect(server_disconnected)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		pause_menu.open_menu()


func _process(delta: float) -> void:
	if time_remaining > 0:
		time_remaining -= delta
		get_node("UI/CountdownTimer").text = "Time Remaining: %d" % floor(time_remaining)
	else: # time_remaining <= 0
		if get_multiplayer().is_server():
			rpc("end_of_match")
			end_of_match()
		elif not get_multiplayer().has_multiplayer_peer():
			var error := get_tree().change_scene_to_file("res://src/states/menus/menu.tscn")
			assert(not error)


func player_disconnected(id: int) -> void:
	remove_peer_player(id)
	if Multiplayer.player_info.size() == 0:
		end_of_match()


func server_disconnected() -> void:
	Global.server_kicked = true
	Global.menu_to_load = "main_menu"
	get_tree().change_scene_to_file("res://src/states/menus/menu.tscn")


# Get all targets not about to be deleted
func get_targets() -> Array:
	var targets := []
	var all_targets := get_tree().get_nodes_in_group("Targets")
	for target in all_targets:
		if not target.is_queued_for_deletion():
			targets.append(target)
	return targets


# Called when a target is destroyed.
# :param player_id: The ID of the player that destroyed the target.
func on_target_destroy(player_id: int) -> void:
	if player_id == Multiplayer.get_player_id():
		get_node("UI/Scoreboard").record_score()
	var num_targets := len(get_targets())
	if num_targets <= 0:
		# This is the last target that was hit (will be freed during this frame).
		spawn_new_targets_if_host()


# Get the position of every target in the level, then delete them. Used when the level loads in to get target positions.
func store_target_data() -> void:
	var targets := get_targets()
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
@rpc("any_peer") func spawn_targets(transforms: Dictionary) -> void:
	# Destroy any existing targets
	var targets := get_targets()
	for target in targets:
		target.queue_free()

	# Spawn the new ones
	for id in transforms.keys():
		var target := preload("res://src/objects/target.tscn").instantiate() as Area3D
		target.transform = transforms[id]
		target.set_name(str(id))
		target.target_destroyed.connect(on_target_destroy)
		get_node("Level/Targets").add_child(target)


# Spawn a few targets, only if we are the network host.
func spawn_new_targets_if_host() -> void:
	var targets := select_targets()
	if not get_multiplayer().has_multiplayer_peer():
		spawn_targets(targets)
	elif get_multiplayer().is_server():
		spawn_targets(targets)
		sync_targets()


# Synchronize the current targets between clients. Used when clients join to populate the initial state.
# :param player_id: The player ID to send information to, or -1 to send information to all players. Defaults to -1.
func sync_targets(player_id: int = -1) -> void:
	# Get all the current targets.
	var targets := get_targets()
	# An output dictionary, to pass into spawn_targets()
	var output := {}
	for target in targets:
		var id := int(str(target.name))
		output[id] = target.transform

	if player_id == -1:
		rpc("spawn_targets", output)
	else:
		rpc_id(player_id, "spawn_targets", output)


# Spawn the player that we are controlling.
func spawn_player() -> void:
	var my_player := preload("res://src/objects/player.tscn").instantiate() as CharacterBody3D
	my_player.player_death.connect(move_to_spawn_point.bind(my_player))
	my_player.get_node("Nameplate").hide()
	if get_multiplayer().has_multiplayer_peer():
		var self_peer_id := get_multiplayer().get_unique_id()
		my_player.set_name(str(self_peer_id))
		my_player.set_multiplayer_authority(self_peer_id)
	else:
		my_player.set_name("1")
	my_player.get_node("BodyMesh").hide()
	my_player.get_node("Head/HeadMesh").hide()
	my_player.get_node("Camera3D").current = true
	move_to_spawn_point(my_player)
	$Players.add_child(my_player)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	my_player.shoot.connect(self.i_would_like_to_shoot.bind(my_player.name))


# Spawn a player controlled by another person.
@rpc("any_peer") func spawn_peer_player(player_id: int) -> void:
	var player := preload("res://src/objects/player.tscn").instantiate() as CharacterBody3D
	var player_info = Multiplayer.player_info[player_id]
	player.set_name(str(player_id))
	player.get_node("Nameplate").text = player_info.name
	var material := preload("res://resources/materials/player_material.tres").duplicate() as StandardMaterial3D
	material.albedo_color = player_info.color
	player.get_node("BodyMesh").set_material_override(material)
	player.get_node("Head/HeadMesh").set_material_override(material)
	player.set_multiplayer_authority(player_id)
	$Players.add_child(player)

	$UI/Scoreboard.add_player(player_id)
	if get_multiplayer().is_server():
		$UI/Scoreboard.rpc("update_score", $UI/Scoreboard.individual_score)


func move_to_spawn_point(my_player: CharacterBody3D) -> void:
	# A list of the spawn locations that can currently be spawned into
	var spawn_points_available := []
	for p in spawn_points:
		var num_adj_players := 0
		for player in get_tree().get_nodes_in_group("Players"):
			if player == my_player:
				continue
			if player.position.distance_to(p.position) < SPAWN_DISABLE_RADIUS:
				num_adj_players += 1
		if num_adj_players == 0:
			spawn_points_available.append(p)
	if len(spawn_points_available) == 0:
		push_warning("Couldn't find available spawn point")
		spawn_points_available = spawn_points
	var rand_spawn := spawn_points_available[randi() % len(spawn_points_available)] as Marker3D
	my_player.transform = rand_spawn.transform
	#my_player.get_node("Camera3D").reset_physics_interpolation()


func i_would_like_to_shoot(id: String) -> void:
	if get_multiplayer().has_multiplayer_peer() and not is_multiplayer_authority():
		rpc_id(1, "everyone_gets_an_arrow", id)
	else:
		everyone_gets_an_arrow(id)


@rpc("any_peer") func everyone_gets_an_arrow(id: String) -> void:		# master
	var my_player := $Players.get_node(id)
	if my_player.is_active:		# if player meets the requirements to be able to shoot
		if get_multiplayer().has_multiplayer_peer():
			rpc("spawn_arrow", id)
		else:
			spawn_arrow(id)


@rpc("any_peer", "call_local") func spawn_arrow(id: String) -> void:
	var new_arrow := Arrow.instantiate()
	new_arrow.archer = $Players.get_node(id)
	var player_head := new_arrow.archer.get_node("Head") as Node3D
	new_arrow.transform = player_head.global_transform
	new_arrow.velocity = player_head.get_global_transform().basis.z.normalized() * -SHOT_SPEED
	arrows.add_child(new_arrow)
	if arrows.get_child_count() > MAX_ARROWS_LOADED:
		arrows.get_child(0).queue_free()
	new_arrow.archer.shooting_sound()


@rpc("any_peer") func end_of_match() -> void:
	var player_id := Multiplayer.get_player_id()
	if not Multiplayer.dedicated_server:
		var my_player := $Players.get_node(str(player_id))
		# Stop players from shooting
		my_player.is_active = false
	# TODO - Display final scores/winner before going back to lobby
	# Send back to lobby with updated scores
	for id in Multiplayer.player_info.keys():
		Multiplayer.player_info[id].latest_score = $UI/Scoreboard.individual_score[id]
	var error := get_tree().change_scene_to_file("res://src/states/menus/menu.tscn")
	assert(not error)


# De-spawn a player controlled by another person.
# :param player_id: The ID of the player to de-spawn.
func remove_peer_player(player_id: int) -> void:
	var player := $Players.get_node(str(player_id))
	if player:
		$Players.remove_child(player)
	$UI/Scoreboard.remove_player(player_id)
