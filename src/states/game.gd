class_name Gamemode
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
@onready var animation_player: AnimationPlayer = %AnimationPlayer

var curr_level: Node3D

# A list of all the possible spawn locations within the current level.
var spawn_points: Array[Node] = []

# A reference to the player controlled by this instance.
var my_player: Player

# The current state of the match
var game_state := GameState.WAITING

# The number of players on each team
var team_roster: Dictionary = {}


func _ready() -> void:
	name = "Game"

	randomize()

	spawn_points = get_tree().get_nodes_in_group("SpawnPoints")

	if Multiplayer.dedicated_server:
		var camera := curr_level.get_node_or_null("SpectatorCamera") as Camera3D
		if camera:
			camera.current = true
		find_child("Reticle").hide()
	else:
		spawn_player()
	for player_id in Multiplayer.get_player_ids():
		if player_id != get_multiplayer().get_unique_id():
			spawn_peer_player(player_id)

	if is_multiplayer_authority():
		for player_id in Multiplayer.get_player_ids():
			assign_spawn_point(player_id)

	Multiplayer.player_disconnected.connect(player_disconnected)
	Multiplayer.server_disconnected.connect(server_disconnected)

	if is_multiplayer_authority():
		Multiplayer.all_players_loaded.connect(on_all_players_loaded)
	Multiplayer.player_is_loaded.rpc_id(1)

	for player in Multiplayer.get_players():
		if player.team_id in team_roster:
			team_roster[player.team_id].append(player)
		else:
			team_roster[player.team_id] = [player]


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and game_state != GameState.ENDED:
		pause_menu.open_menu()
		if my_player.is_drawing_back:
			my_player.release(true)


func _physics_process(_delta: float) -> void:
	if game_state == GameState.WAITING:
		match_timer.text = "Waiting for players..."
		return
	elif game_state == GameState.COUNTDOWN:
		match_timer.text = ""
		# Countdown animation handles this state
		return

	if not Multiplayer.dedicated_server:
		power_indicator.value = my_player.get_shot_power()
		power_indicator.queue_redraw()
		quiver_display.text = str(my_player.num_arrows)


func player_disconnected(id: int) -> void:
	remove_peer_player(id)
	if Multiplayer.get_players().size() == 0:
		get_tree().change_scene_to_file("res://src/states/menus/menu.tscn")


func server_disconnected() -> void:
	Global.server_kicked = true
	Global.menu_to_load = "main_menu"
	get_tree().change_scene_to_file("res://src/states/menus/menu.tscn")


func on_all_players_loaded() -> void:
	set_state.rpc(GameState.COUNTDOWN)


@rpc("authority", "call_local")
func set_state(new_state: GameState) -> void:
	if new_state == GameState.COUNTDOWN:
		animation_player.play("countdown")
		for player in get_tree().get_nodes_in_group("Players"):
			player.state = Player.PlayerState.SPAWNING
	elif new_state == GameState.PLAYING:
		animation_player.play("go")
		for player in get_tree().get_nodes_in_group("Players"):
			player.state = Player.PlayerState.NORMAL
	game_state = new_state


func end_countdown() -> void:
	if is_multiplayer_authority():
		set_state.rpc(GameState.PLAYING)


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
	my_player.shoot.connect(i_would_like_to_shoot.bind(my_player.name))
	my_player.melee_attack.connect(melee_attack.bind(my_player.name))
	if is_multiplayer_authority():
		my_player.player_spawn.connect(clear_spawn_point.bind(self_peer_id))


# Spawn a player controlled by another person.
@rpc("any_peer")
func spawn_peer_player(player_id: int) -> void:
	var player := preload("res://src/objects/player.tscn").instantiate() as CharacterBody3D
	var player_info = Multiplayer.get_player_by_id(player_id)
	player.set_name(str(player_id))
	player.get_node("Nameplate").text = player_info.username
	if DisplayServer.get_name() != "headless":
		var material := preload("res://resources/materials/player_material.tres").duplicate() as StandardMaterial3D
		material.albedo_color = player_info.color
		player.get_node("BodyMesh").set_material_override(material)
		player.get_node("Head/HeadMesh").set_material_override(material)
	player.set_multiplayer_authority(player_id)
	$Players.add_child(player)
	if is_multiplayer_authority():
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
	respawn_player.rpc(player_id)


@rpc("authority", "call_local")
func respawn_player(player_id: int):
	$Players.get_node(str(player_id)).respawn()


func clear_spawn_point(player_id: int) -> void:
	if not is_multiplayer_authority():
		return
	if Multiplayer.game_info.team_mode == Multiplayer.TeamMode.FFA:
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


# Get all targets not about to be deleted
func get_targets() -> Array:
	return get_tree().get_nodes_in_group("Targets").filter(func(x): return not x.is_queued_for_deletion())


func melee_attack(id: String) -> void:
	enable_melee_hitbox.rpc(id)


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
		spawn_arrow.rpc(id, power)


@rpc("any_peer", "call_local")
func spawn_arrow(id: String, power: float) -> ArrowObject:
	var new_arrow := Arrow.instantiate()
	new_arrow.archer = $Players.get_node(id)
	var player_head := new_arrow.archer.get_node("Head") as Node3D
	new_arrow.transform = player_head.get_global_transform()
	var shot_speed := BASE_SHOT_SPEED + (MAX_SHOT_SPEED - BASE_SHOT_SPEED) * power
	new_arrow.velocity = shot_speed * -player_head.get_global_transform().basis.z.normalized()
	arrows.add_child(new_arrow)
	if arrows.get_child_count() > MAX_ARROWS_LOADED:
		arrows.get_child(0).queue_free()
	new_arrow.archer.shooting_sound()
	return new_arrow


func on_arrow_pickup_spawn(spawn_transform: Transform3D) -> void:
	if get_multiplayer().is_server():
		spawn_arrow_pickup.rpc(spawn_transform)


@rpc("authority", "call_local")
func spawn_arrow_pickup(spawn_transform: Transform3D) -> void:
	var new_arrow_pickup := ArrowPickup.instantiate()
	new_arrow_pickup.position = spawn_transform.origin
	new_arrow_pickup.arrow_collected.connect(arrow_collected)
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


@rpc("any_peer", "call_local")
func request_end_of_match() -> void:
	if Multiplayer.is_id_leader(multiplayer.get_remote_sender_id()):
		end_of_match.rpc()


@rpc("authority", "call_local")
func end_of_match() -> void:
	if not Multiplayer.dedicated_server:
		# Stop players from shooting
		my_player.state = Player.PlayerState.FROZEN
	# Update scores
	for player in Multiplayer.get_players():
		player.latest_score = scoreboard.get_score(player.id)
	game_state = GameState.ENDED
	await get_tree().create_timer(3).timeout
	var error := get_tree().change_scene_to_file("res://src/states/menus/menu.tscn")
	assert(not error)


# De-spawn a player controlled by another person.
# :param player_id: The ID of the player to de-spawn.
func remove_peer_player(player_id: int) -> void:
	var player := $Players.get_node_or_null(str(player_id))
	if player:
		$Players.remove_child(player)
		scoreboard.remove_player(player_id)
