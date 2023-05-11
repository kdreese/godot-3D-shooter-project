extends Node


# What states our game can be in
enum GameState {
	WAITING, # Waiting for all players to be joined
	COUNTDOWN, # After all players are in, countdown to game begin
	PLAYING, # In-game
	ENDED, # End screen scores
}

# Player won't spawn at the current point if another player is within radius
const SPAWN_DISABLE_RADIUS := 3
const BASE_SHOT_SPEED := 5.0
const MAX_SHOT_SPEED := 50.0
const MAX_ARROWS_LOADED := 30
const DRAWBACK_INDICATOR_START_SIZE := Vector2(0.0, 10.0)
const DRAWBACK_INDICATOR_FINAL_SIZE := Vector2(60.0, 10.0)

const Arrow = preload("res://src/objects/arrow.tscn")
const ArrowPickup = preload("res://src/objects/arrow_pickup.tscn")

@onready var pause_menu: Control = %PauseMenu
@onready var scoreboard: Scoreboard = %Scoreboard
@onready var arrows: Node = %Arrows
@onready var match_timer: Label = %MatchTimer
@onready var spawn_countdown: Label = %SpawnCountdown
@onready var power_indicator: Control = %PowerIndicator
@onready var quiver_display: Label = %QuiverDisplay

var curr_level: Node3D

# A list of all the possible target locations within the current level.
var target_transforms := []
# The ID of the most recently spawned target. Each target has a unique ID to to synchronization between clients.
var target_id := 0
# A list of the indices into target_transforms for the last group of spawned targets.
var last_spawned_target_group: Array[int] = []
# A list of all the possible spawn locations within the current level.
var spawn_points: Array[Node] = []

# A reference to the player controlled by this instance.
var my_player: Player

# The current state of the match
var game_state := GameState.WAITING
# Countdown timer for match length
var time_remaining := 120.0


func _ready() -> void:
	randomize()

	curr_level = preload("res://src/levels/arena.tscn").instantiate() as Node3D
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
	for player_id in Multiplayer.player_info.keys():
		if player_id != get_multiplayer().get_unique_id():
			spawn_peer_player(player_id)

	if is_multiplayer_authority():
		for player_id in Multiplayer.player_info.keys():
			assign_spawn_point(player_id)

	Multiplayer.player_disconnected.connect(player_disconnected)
	Multiplayer.server_disconnected.connect(server_disconnected)

	if is_multiplayer_authority():
		Multiplayer.all_players_ready.connect(self.rpc.bind("set_state", GameState.PLAYING))
	Multiplayer.rpc_id(1, "player_is_ready")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and game_state != GameState.ENDED:
		pause_menu.open_menu()
		if my_player.is_drawing_back:
			my_player.release(true)


func _physics_process(delta: float) -> void:
	if game_state == GameState.WAITING:
		match_timer.text = "Waiting for players..."
		return
	power_indicator.value = my_player.get_shot_power()
	power_indicator.queue_redraw()
	quiver_display.text = str(my_player.num_arrows)
	if time_remaining > 0:
		time_remaining -= delta
		if time_remaining < 0:
			time_remaining = 0
		match_timer.text = Utils.format_time(time_remaining, true)
	else: # time_remaining <= 0
		if get_multiplayer().is_server():
			rpc("end_of_match")
			end_of_match()


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


@rpc("authority", "call_local")
func set_state(new_state: GameState) -> void:
	if new_state == GameState.PLAYING:
		my_player.state = Player.PlayerState.NORMAL
	game_state = new_state


# Spawn the player that we are controlling.
func spawn_player() -> void:
	my_player = preload("res://src/objects/player.tscn").instantiate() as CharacterBody3D
	my_player.get_node("Nameplate").hide()
	var self_peer_id := get_multiplayer().get_unique_id()
	my_player.set_name(str(self_peer_id))
	my_player.set_multiplayer_authority(self_peer_id)
	my_player.get_node("BodyMesh").hide()
	my_player.get_node("Head/HeadMesh").hide()
	my_player.get_node("Camera3D").current = true
	$Players.add_child(my_player)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	my_player.shoot.connect(self.i_would_like_to_shoot.bind(my_player.name))
	my_player.melee_attack.connect(self.melee_attack.bind(my_player.name))
	if is_multiplayer_authority():
		my_player.player_death.connect(assign_spawn_point.bind(self_peer_id))
		my_player.player_spawn.connect(clear_spawn_point.bind(self_peer_id))


# Spawn a player controlled by another person.
@rpc("any_peer")
func spawn_peer_player(player_id: int) -> void:
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
	if is_multiplayer_authority():
		player.player_death.connect(assign_spawn_point.bind(player_id))
		player.player_spawn.connect(clear_spawn_point.bind(player_id))


# Assign a spawn point to a player, if one does not exist. Called only on the server.
func assign_spawn_point(player_id: int) -> void:
	if not is_multiplayer_authority():
		return
	print("Assigning spawn point to player %d" % player_id)
	var spawn_point: SpawnPoint
	# Check if there are any pre-assigned spawn points for this player.
	var assigned_spawn_points := spawn_points.filter(
		func(x): return x.assigned_player_id == player_id
	)
	if len(assigned_spawn_points) > 0:
		spawn_point = assigned_spawn_points.pick_random()
	else:
		var available_spawn_points := spawn_points.filter(func(x): return x.available(player_id))
		if len(available_spawn_points) == 0:
			available_spawn_points = spawn_points
		spawn_point = available_spawn_points.pick_random() as SpawnPoint
	spawn_point.assigned_player_id = player_id
	rpc_id(player_id, "move_to_spawn_point", spawn_point.transform)


func clear_spawn_point(player_id: int) -> void:
	if not is_multiplayer_authority():
		return
	if Multiplayer.game_mode == Multiplayer.GameMode.FFA:
		var assigned_spawn_points := spawn_points.filter(
			func(x): return x.assigned_player_id == player_id
		)
		for spawn_point in assigned_spawn_points:
			spawn_point.assigned_player_id = -1


@rpc("authority", "call_local")
func move_to_spawn_point(transform: Transform3D) -> void:
	my_player.transform = transform
	my_player.camera.basis = transform.basis
	#my_player.get_node("Camera3D").reset_physics_interpolation()
	my_player.previous_global_position = transform.origin


func melee_attack(id: String) -> void:
	rpc("enable_melee_hitbox", id)


@rpc("any_peer", "call_local")
func enable_melee_hitbox(id: String):
	var player = $Players.get_node(id)
	player.do_melee_attack()


func i_would_like_to_shoot(power: float, id: String) -> void:
	if power == 0.0:
		return
	if is_multiplayer_authority():
		everyone_gets_an_arrow(id, power)
	else:
		rpc_id(1, "everyone_gets_an_arrow", id, power)


@rpc("any_peer")
func everyone_gets_an_arrow(id: String, power: float) -> void:
	if not is_multiplayer_authority():
		return
	var player := $Players.get_node(id)
	if player.state == Player.PlayerState.NORMAL and player.num_arrows > 0: # if player meets the requirements to be able to shoot
		rpc("spawn_arrow", id, power)
		player.num_arrows -= 1
		rpc_id(int(id), "update_quiver_amt", player.num_arrows)


@rpc("any_peer", "call_local")
func spawn_arrow(id: String, power: float) -> void:
	var new_arrow := Arrow.instantiate()
	new_arrow.archer = $Players.get_node(id)
	var player_head := new_arrow.archer.get_node("Head") as Node3D
	new_arrow.transform = player_head.get_global_transform()
	var shot_speed := BASE_SHOT_SPEED + (MAX_SHOT_SPEED - BASE_SHOT_SPEED) * power
	new_arrow.velocity = shot_speed * -player_head.get_global_transform().basis.z.normalized()
	new_arrow.spawn_pickup.connect(self.on_arrow_pickup_spawn)
	arrows.add_child(new_arrow)
	if arrows.get_child_count() > MAX_ARROWS_LOADED:
		arrows.get_child(0).queue_free()
	new_arrow.archer.shooting_sound()


func on_arrow_pickup_spawn(spawn_transform: Transform3D) -> void:
	if get_multiplayer().is_server():
		rpc("spawn_arrow_pickup", spawn_transform)


@rpc("authority", "call_local")
func spawn_arrow_pickup(spawn_transform: Transform3D) -> void:
	var new_arrow_pickup := ArrowPickup.instantiate()
	new_arrow_pickup.position = spawn_transform.origin
	new_arrow_pickup.arrow_collected.connect(self.arrow_collected)
	$ArrowPickups.add_child(new_arrow_pickup)


@rpc("authority", "call_local")
func arrow_collected(id: String) -> void:
	if get_multiplayer().is_server():
		var player := $Players.get_node(id)
		player.num_arrows += 1
		rpc_id(int(id), "update_quiver_amt", player.num_arrows)


@rpc("authority", "call_local")
func update_quiver_amt(amt: int) -> void:
	my_player.num_arrows = amt


@rpc("any_peer")
func end_of_match() -> void:
	if not Multiplayer.dedicated_server:
		# Stop players from shooting
		my_player.state = Player.PlayerState.FROZEN
	# TODO - Display final scores/winner before going back to lobby
	# Send back to lobby with updated scores
	for id in Multiplayer.player_info.keys():
		Multiplayer.player_info[id].latest_score = scoreboard.get_score(id)
	var error := get_tree().change_scene_to_file("res://src/states/menus/menu.tscn")
	assert(not error)


# De-spawn a player controlled by another person.
# :param player_id: The ID of the player to de-spawn.
func remove_peer_player(player_id: int) -> void:
	var player := $Players.get_node_or_null(str(player_id))
	if player:
		$Players.remove_child(player)
		scoreboard.remove_player(player_id)
