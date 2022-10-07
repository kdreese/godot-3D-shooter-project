extends Area


func on_hit(area: Area) -> void:
	queue_free()


func on_raycast_hit() -> void:
	queue_free()
