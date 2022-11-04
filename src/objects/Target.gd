extends Area

signal target_destroyed

func on_hit(_area: Area) -> void:
	emit_signal("target_destroyed")
	queue_free()


func on_raycast_hit() -> void:
	emit_signal("target_destroyed")
	queue_free()
