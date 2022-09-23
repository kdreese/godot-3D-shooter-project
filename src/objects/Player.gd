extends KinematicBody


const MOUSE_SENS = Vector2(0.0025, 0.0025)

onready var camera := $"%Camera" as Camera


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		var mm_event := event as InputEventMouseMotion
		rotation.y -= mm_event.relative.x * MOUSE_SENS.x
		camera.rotation.x -= mm_event.relative.y * MOUSE_SENS.y
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
