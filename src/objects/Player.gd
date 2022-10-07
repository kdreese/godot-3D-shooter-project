extends KinematicBody


const MOUSE_SENS = Vector2(0.0025, 0.0025)
const GRAVITY = 30.0
const MOVE_SPEED = 10.0
const JUMP_POWER = 10.0

var velocity := Vector3.ZERO

onready var camera := $"%Camera" as Camera
onready var hitscan := $"%Hitscan" as RayCast


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		var mm_event := event as InputEventMouseMotion
		rotation.y -= mm_event.relative.x * MOUSE_SENS.x
		camera.rotation.x -= mm_event.relative.y * MOUSE_SENS.y
		get_tree().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().set_input_as_handled()
	elif event.is_action_pressed("shoot"):
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_tree().set_input_as_handled()
		else:
			shoot()


func _physics_process(delta: float) -> void:
	var forward_vector := Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	var right_vector := Vector3.FORWARD.rotated(Vector3.UP, rotation.y - PI / 2)

	var wishdir := Input.get_vector("move_left", "move_right", "move_backwards", "move_forwards")

	var move_vector := wishdir.x * right_vector + wishdir.y * forward_vector

	velocity.x = move_vector.x * MOVE_SPEED
	velocity.z = move_vector.z * MOVE_SPEED

	var jumping = false

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		jumping = true
		velocity.y = JUMP_POWER

	velocity.y -= delta * GRAVITY
	velocity = move_and_slide_with_snap(velocity, Vector3.ZERO if jumping else Vector3.DOWN, Vector3.UP, true)


func shoot():
	hitscan.set_enabled(true)
	hitscan.force_raycast_update()
	if hitscan.is_colliding():
		var hit = hitscan.get_collider()
		if hit.has_method("on_raycast_hit"):
			hit.on_raycast_hit()
	hitscan.set_enabled(false)
