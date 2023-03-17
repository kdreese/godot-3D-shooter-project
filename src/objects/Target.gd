class_name Target
extends Area3D


signal target_destroyed


func on_raycast_hit(player_id: int) -> void:
	if get_multiplayer().has_multiplayer_peer():
		rpc("destroy_self", player_id)
	destroy_self(player_id)


@rpc("any_peer") func destroy_self(player_id: int) -> void:
	emit_signal("target_destroyed", player_id)
	get_parent().remove_child(self)
	queue_free()
