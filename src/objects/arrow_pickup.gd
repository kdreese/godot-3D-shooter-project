extends Area3D


signal arrow_collected


const ROTATION_FREQ = 0.15 # in Hz
const OSCILLATION_FREQ := 0.25 # in Hz
const OSCILLATION_AMPLITUDE := 0.1 # in meters.
const MESH_POSITION := 0.4 * Vector3.UP
const MAX_ANIMATION_TIME := 1.0 / (ROTATION_FREQ * OSCILLATION_FREQ)


@onready var mesh_instance_3d := $MeshInstance3D
var animation_time := randf_range(0.0, MAX_ANIMATION_TIME)


func _process(delta) -> void:
	animation_time = wrapf(animation_time + delta, 0.0, MAX_ANIMATION_TIME)
	mesh_instance_3d.rotation.y = wrapf(2 * PI * ROTATION_FREQ * animation_time, 0.0, 2 * PI)
	var y_offset := OSCILLATION_AMPLITUDE * sin(2 * PI * OSCILLATION_FREQ * animation_time)
	mesh_instance_3d.position = MESH_POSITION + y_offset * Vector3.UP


func _on_body_entered(body):
	if body is Player and body.is_active:
		emit_signal("arrow_collected", body.name)
		queue_free()
