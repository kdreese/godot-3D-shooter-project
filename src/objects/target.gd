class_name Target
extends Area3D


signal target_destroyed


func on_raycast_hit(player_id: int) -> void:
	if get_multiplayer().has_multiplayer_peer():
		rpc("destroy_self", player_id)
	destroy_self(player_id)


@rpc("any_peer", "call_local")
func destroy_self(player_id: int) -> void:
	queue_free()
	emit_signal("target_destroyed", player_id)


# _on_Target_body_entered
func on_hit(body: Node) -> void:
	if body.is_in_group("Arrow"):
		if get_multiplayer().has_multiplayer_peer():
			if get_multiplayer().is_server():
				rpc("destroy_self", int(str(body.archer.name)))
		else:
			destroy_self(int(str(body.archer.name)))
