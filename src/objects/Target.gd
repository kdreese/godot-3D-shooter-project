class_name Target
extends Area


signal target_destroyed


func on_raycast_hit(player_id: int) -> void:
	if get_tree().has_network_peer():
		rpc("destroy_self", player_id)
	destroy_self(player_id)


remotesync func destroy_self(player_id: int) -> void:
	queue_free()
	emit_signal("target_destroyed", player_id)


# _on_Target_body_entered
func on_hit(body: Node) -> void:
	if body.is_in_group("Arrow"):
		if get_tree().has_network_peer():
			if get_tree().is_network_server():
				rpc("destroy_self", int(body.archer.name))
		else:
			destroy_self(int(body.archer.name))
