extends Gamemode


# A list of all the possible target locations within the current level.
var target_transforms := []
# The ID of the most recently spawned target. Each target has a unique ID to to synchronization between clients.
var target_id := 0
# A list of the indices into target_transforms for the last group of spawned targets.
var last_spawned_target_group: Array[int] = []
# Countdown timer for match length
var time_remaining := 120.0


func _ready() -> void:
	curr_level = preload("res://src/levels/arena.tscn").instantiate() as Node3D
	add_child(curr_level)

	store_target_data()

	super._ready()

	quiver_display.hide()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if game_state == GameState.ENDED:
		match_timer.text = "Time's up!"
		return

	if time_remaining > 0:
		time_remaining -= delta
		if time_remaining < 0:
			time_remaining = 0
		match_timer.text = Utils.format_time(time_remaining, true)
	else: # time_remaining <= 0
		if get_multiplayer().is_server():
			rpc("end_of_match")


# Spawn the player that we are controlling.
func spawn_player() -> void:
	super.spawn_player()
	if is_multiplayer_authority():
		my_player.player_death.connect(assign_spawn_point.bind(get_multiplayer().get_unique_id()))


# Spawn a player controlled by another person.
@rpc("any_peer")
func spawn_peer_player(player_id: int) -> void:
	super.spawn_peer_player(player_id)
	if is_multiplayer_authority():
		$Players.get_node(str(player_id)).player_death.connect(assign_spawn_point.bind(player_id))


func on_all_players_ready() -> void:
	spawn_new_targets_if_host()
	super.on_all_players_ready()


# Called when a target is destroyed.
# :param player_id: The ID of the player that destroyed the target.
func on_target_destroy(player_id: int) -> void:
	if get_multiplayer().is_server():
		scoreboard.record_score(player_id)
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
	var indices: Array[int] = []
	var transforms := {}
	for _i in range(num_targets):
		var index := randi() % len(target_transforms)
		# If we get a duplicate or one of the targets in the last group, try again
		while index in indices + last_spawned_target_group:
			index = randi() % len(target_transforms)
		indices.append(index)
		transforms[target_id] = target_transforms[index]
		target_id += 1
	last_spawned_target_group = indices
	return transforms


# Spawn targets given their IDs and locations.
# :param transforms: A dictionary from ID to transform matrix for each target to spawn.
@rpc("any_peer")
func spawn_targets(transforms: Dictionary) -> void:
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
		curr_level.get_node("Targets").add_child(target)


# Spawn a few targets, only if we are the network host.
func spawn_new_targets_if_host() -> void:
	var targets := select_targets()
	if get_multiplayer().is_server():
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
