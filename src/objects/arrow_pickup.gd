extends Area3D


signal arrow_collected


const SPIN_SPEED := 0.5
const VERTICAL_OSCILLATION_FREQUENCY := 1
const VERTICAL_OSCILLATION_AMPLITUDE := 0.15

@onready var mesh_instance_3d = $MeshInstance3D
@onready var initial_y = mesh_instance_3d.position.y


func _physics_process(delta) -> void:
	mesh_instance_3d.rotation.y += SPIN_SPEED * delta
	mesh_instance_3d.position.y = initial_y \
			+ sin(Time.get_unix_time_from_system() * VERTICAL_OSCILLATION_FREQUENCY) \
			* VERTICAL_OSCILLATION_AMPLITUDE


func _on_body_entered(body):
	if body is Player:
		emit_signal("arrow_collected", body.name)
		queue_free()
