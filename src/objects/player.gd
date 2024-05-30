extends CharacterBody3D
class_name Player


signal melee_attack()
signal shoot(shot_power: float)
signal player_spawn()
signal player_death()

enum PlayerState {
	FROZEN, # Can't move at all, including camera
	SPAWNING, # Can't move except for camera
	NORMAL, # Normal state
	DEAD, # Same as frozen with visuals coming from alive teammate(s)
	SPECTATOR, # Same as spawning with an overhead spectator angle
}

const MOUSE_SENS = Vector2(0.0025, 0.0025)
const GRAVITY = 12.0
const MOVE_SPEED = 5.0
const DRAWBACK_SPEED_MOD = 0.3
const JUMP_POWER = 5.0
const RESPAWN_TIME = 5.0
const IFRAME_TIME = 2.5
const FOOTSTEP_OFFSET = 1.5
const DRAWBACK_MIN = 0.25
const DRAWBACK_MAX = 1.5
const DRAWBACK_FOV_OFFSET = -30

const Arrow = preload("res://src/objects/arrow.tscn")

var state := PlayerState.FROZEN
var is_vulnerable := true
var last_footstep_pos: Vector3 = Vector3.ZERO
var is_drawing_back := false
var drawback_time := 0.0
var quiver_capacity := 1
var num_arrows := 1

# Network values for updating remote player positions
var has_next_transform := false
var next_position := Vector3.ZERO
var next_rotation := Vector3.ZERO

var fov_tween: Tween
var normal_fov: float

# TODO: revert this when Godot 4 supports physics interpolation
var previous_global_position: Vector3


@onready var head: Node3D = %Head
@onready var hitscan: RayCast3D = %Hitscan
@onready var melee_attack_hitbox: CollisionShape3D = %MeleeAttackHitbox
@onready var camera: Camera3D = %Camera3D
@onready var footsteps: Node = %Footsteps
@onready var shooting: Node = %Shooting
@onready var punching = %Punching


func _ready() -> void:
	# We want finer control of the camera node, so it gets set as a top level node with interpolation disabled
	camera.set_as_top_level(true)
	normal_fov = camera.fov
	# camera.set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)


# Determine whther or not we should use keypresses to control this instance. Will return true if
# this player object is our own. Will return false otherwise, or if we are in a menu.
func should_control() -> bool:
	if not is_multiplayer_authority():
		return false
	if state == PlayerState.FROZEN:
		return false
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not should_control():
		return
	if event is InputEventMouseMotion:
		handle_mouse_movement(event as InputEventMouseMotion)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("shoot") and num_arrows > 0:
		draw_back()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("shoot") and is_drawing_back:
		release()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("melee_attack"):
		if is_drawing_back:
			release(true)
		else:
			melee_attack.emit()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if has_next_transform:
		position = next_position
		rotation = Vector3(0, next_rotation.y, 0)
		head.rotation = Vector3(next_rotation.x, 0, 0)
		has_next_transform = false

	previous_global_position = get_global_position()
	if state == PlayerState.NORMAL:
		if is_multiplayer_authority():
			var wishdir := Vector2.ZERO
			var jump_pressed := false
			if should_control():
				wishdir = Input.get_vector("move_left", "move_right", "move_backwards", "move_forwards")
				jump_pressed = Input.is_action_just_pressed("jump")

			var forward_vector := Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
			var right_vector := Vector3.FORWARD.rotated(Vector3.UP, rotation.y - PI / 2)

			var move_vector := wishdir.x * right_vector + wishdir.y * forward_vector

			var curr_speed := MOVE_SPEED
			if is_drawing_back:
				curr_speed *= DRAWBACK_SPEED_MOD
			velocity.x = move_vector.x * curr_speed
			velocity.z = move_vector.z * curr_speed

			var jumping := false

			if is_on_floor() and jump_pressed:
				jumping = true
				velocity.y = JUMP_POWER

			velocity.y -= delta * GRAVITY
			set_velocity(velocity)
			set_floor_snap_length(0.0 if jumping else 1.0)
			set_up_direction(Vector3.UP)
			set_floor_stop_on_slope_enabled(true)
			move_and_slide()
			velocity = velocity

	if is_drawing_back:
		drawback_time += delta

	if is_on_floor() and (position - last_footstep_pos).length() > FOOTSTEP_OFFSET:
		last_footstep_pos = position
		var stream_player := footsteps.get_children()[randf_range(0, footsteps.get_child_count())] as AudioStreamPlayer3D
		stream_player.play()

	if is_multiplayer_authority():
		set_network_transform.rpc(position, head.global_rotation)


func _process(_delta: float) -> void:
	# Manually set the camera's position to the interpolated position of the player, but don't change the rotation
	var interp_position := lerp(
		previous_global_position,
		get_global_position(),
		Engine.get_physics_interpolation_fraction()
	) as Vector3
	camera.global_position = interp_position + head.position


@rpc("unreliable_ordered", "any_peer")
func set_network_transform(new_position: Vector3, new_rotation: Vector3):
	has_next_transform = true
	next_position = new_position
	next_rotation = new_rotation


func handle_mouse_movement(event: InputEventMouseMotion) -> void:
	var relative := event.relative

	var window_size := get_window().get_size()
	var base_size := Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height")
	)

	# Because of the 2D scaling mode, the game "scales" our mouse input to match the current window size. That means
	# if you make the window bigger, your mouse inputs will be relatively smaller. We don't want this, since that
	# doesn't make sense for 3D mouse look. So here, we "un-scale" it back to normal
	var input_scale = min(
			float(window_size.x) / float(base_size.x),
			float(window_size.y) / float(base_size.y)
	)
	relative *= input_scale
	# Correct any rounding error
	relative.x = round(relative.x)
	relative.y = round(relative.y)

	# Get the mouse sensitivity from the config.
	var mouse_sensitivity := (Global.config["mouse_sensitivity"] * MOUSE_SENS) as Vector2

	# Contstrain the y rotation to be within one full rotation.
	rotation.y = wrapf(rotation.y - relative.x * mouse_sensitivity.x, 0, TAU)
	# Constrain the x rotation to be between looking directly down and directly up.
	head.rotation.x = clamp(camera.rotation.x - relative.y * mouse_sensitivity.y, -0.99 * PI / 2, 0.99 * PI / 2)
	# Update the camera's rotation immediately - since it's not interpolated, the player will see the effects of these
	# changes without needing to wait for the next physics tick (less input lag)
	camera.rotation.y = rotation.y
	camera.rotation.x = head.rotation.x


func do_melee_attack():
	melee_attack_hitbox.disabled = false
	punching.get_children().pick_random().play()
	get_tree().create_timer(0.5).timeout.connect(melee_attack_hitbox.set.bind("disabled", true))


func draw_back():
	is_drawing_back = true
	if fov_tween:
		fov_tween.kill()
	fov_tween = create_tween()
	fov_tween.tween_property(camera, "fov", normal_fov + DRAWBACK_FOV_OFFSET, 2.0)


func get_shot_power() -> float:
	if drawback_time >= DRAWBACK_MAX:
		return 1.0
	elif drawback_time < DRAWBACK_MIN:
		return 0.0
	else:
		return (drawback_time - DRAWBACK_MIN) / (DRAWBACK_MAX - DRAWBACK_MIN)


func release(is_cancel := false):
	if not is_drawing_back:
		return
	is_drawing_back = false
	if fov_tween:
		fov_tween.kill()
	fov_tween = create_tween()
	fov_tween.tween_property(camera, "fov", normal_fov, 0.2)
	if not is_cancel:
		shoot.emit(get_shot_power())
	var duration := 0.25 * pow(get_shot_power(), 0.25)
	create_tween().tween_property(self, "drawback_time", 0.0, duration)


func on_raycast_hit(peer_id: int):
	var shooter_team_id := Multiplayer.get_player_by_id(peer_id).team_id as int
	# The player ID of this instance (the one that got shot) should just be its name.
	if is_vulnerable and Multiplayer.get_player_by_id(int(name)).team_id != shooter_team_id:
		ive_been_hit.rpc()
		ive_been_hit()


@rpc("any_peer", "call_local")
func ive_been_hit():
	$Blood.emitting = true
	state = PlayerState.DEAD
	player_death.emit()
	set_vulnerable(false)


func respawn():
	set_vulnerable(false)
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(on_respawn)
	state = PlayerState.SPAWNING


func shooting_sound():
	shooting.get_children().pick_random().play()


# _on_Hurtbox_body_entered
func on_shot(body:Node) -> void:
	if not get_multiplayer().is_server():
		return
	if body.is_in_group("Arrow") and body.archer != self:
		var shooter_team := Multiplayer.get_player_by_id(body.archer.name.to_int()).team_id
		var my_team := Multiplayer.get_player_by_id(name.to_int()).team_id
		if shooter_team == my_team or not is_vulnerable:
			body.queue_free()
			get_parent().get_parent().arrow_collected(name)
		else:
			ive_been_hit.rpc()
			body.become_pickup()


func on_punched(area: Node) -> void:
	var player_team = Multiplayer.get_player_by_id(area.get_parent().get_parent().name.to_int()).team_id
	var my_team := Multiplayer.get_player_by_id(name.to_int()).team_id
	if is_vulnerable and player_team != my_team:
		ive_been_hit.rpc()


func on_death_barrier() -> void:
	ive_been_hit.rpc()


func on_respawn() -> void:
	player_spawn.emit()
	state = PlayerState.NORMAL
	get_tree().create_timer(IFRAME_TIME).timeout.connect(set_vulnerable.bind(true))


func set_vulnerable(vulnerable: bool):
	is_vulnerable = vulnerable
	var overlay = null if vulnerable else preload("res://resources/materials/player_invincibility_material.tres")
	for obj in [$BodyMesh, $Head/HeadMesh]:
		obj.set_material_overlay(overlay)
