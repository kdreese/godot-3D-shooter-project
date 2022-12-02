extends KinematicBody


const MOUSE_SENS = Vector2(0.0025, 0.0025)
const GRAVITY = 30.0
const MOVE_SPEED = 10.0
const JUMP_POWER = 12.0
const RESPAWN_TIME = 3.0
const IFRAME_TIME = 4.0

var velocity := Vector3.ZERO
var respawn_timer := 0.0
var iframe_timer := 0.0
var is_active = true
var is_vulnerable = true

onready var camera := $"%Camera" as Camera
onready var hitscan := $"%Hitscan" as RayCast


func should_control() -> bool:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	if get_tree().network_peer == null:
		return true
	return is_network_master()


func _unhandled_input(event: InputEvent) -> void:
	if not should_control():
		return
	if event is InputEventMouseMotion:
		var mm_event := event as InputEventMouseMotion
		var relative := mm_event.relative

		var window_size := OS.get_window_size()
		var base_size := Vector2(
				ProjectSettings.get_setting("display/window/size/width"),
				ProjectSettings.get_setting("display/window/size/height")
		)

		# Because of the 2D scaling mode, the game "scales" our mouse input to match the current window size. That means
		# if you make the window bigger, your mouse inputs will be relatively smaller. We don't want this, since that
		# doesn't make sense for 3D mouse look. So here, we "un-scale" it back to normal
		var scale := min(
				float(window_size.x) / float(base_size.x),
				float(window_size.y) / float(base_size.y)
		)
		relative *= scale
		# Correct any rounding error
		relative.x = round(relative.x)
		relative.y = round(relative.y)

		rotation.y = wrapf(rotation.y - relative.x * MOUSE_SENS.x, 0, TAU)
		camera.rotation.x = clamp(camera.rotation.x - relative.y * MOUSE_SENS.y, -PI / 2, PI / 2)
		get_tree().set_input_as_handled()
	elif event.is_action_pressed("shoot"):
		if is_active:
			shoot()
		get_tree().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if iframe_timer > 0.0:
		iframe_timer -= delta
		if iframe_timer <= 0.0:
			is_vulnerable = true
	if respawn_timer > 0.0:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			is_active = true
	else:
		var wishdir := Vector2.ZERO
		var jump_pressed := false
		if should_control():
			wishdir = Input.get_vector("move_left", "move_right", "move_backwards", "move_forwards")
			jump_pressed = Input.is_action_just_pressed("jump")

		var forward_vector := Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
		var right_vector := Vector3.FORWARD.rotated(Vector3.UP, rotation.y - PI / 2)

		var move_vector := wishdir.x * right_vector + wishdir.y * forward_vector

		velocity.x = move_vector.x * MOVE_SPEED
		velocity.z = move_vector.z * MOVE_SPEED

		var jumping = false

		if is_on_floor() and jump_pressed:
			jumping = true
			velocity.y = JUMP_POWER

		velocity.y -= delta * GRAVITY
		velocity = move_and_slide_with_snap(velocity, Vector3.ZERO if jumping else Vector3.DOWN, Vector3.UP, true)

	if get_tree().network_peer and is_network_master():
		rpc_unreliable("set_network_transform", translation, rotation)


remote func set_network_transform(new_translation: Vector3, new_rotation: Vector3):
	translation = new_translation
	rotation = new_rotation


func on_raycast_hit():
	if is_vulnerable:
		rpc("ive_been_hit")
		ive_been_hit()


remote func ive_been_hit():
	$Blood.emitting = true
	translation = get_tree().get_root().get_node("Game/Level/PlayerSpawnPoint").translation
	respawn_timer = RESPAWN_TIME
	iframe_timer = IFRAME_TIME
	is_active = false
	is_vulnerable = false


func shoot():
	hitscan.set_enabled(true)
	hitscan.force_raycast_update()
	if hitscan.is_colliding():
		var hit = hitscan.get_collider()
		if hit.has_method("on_raycast_hit"):
			hit.on_raycast_hit()
	hitscan.set_enabled(false)
