extends Area


signal target_destroyed


func on_hit(_area: Area) -> void:
	destroy_self()


func on_raycast_hit() -> void:
	rpc("destroy_self")
	destroy_self()


remote func destroy_self() -> void:
	emit_signal("target_destroyed")
	queue_free()
