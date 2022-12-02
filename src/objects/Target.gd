extends Area


signal target_destroyed


func on_raycast_hit(peer_id: int) -> void:
	if get_tree().network_peer:
		rpc("destroy_self", peer_id)
	destroy_self(peer_id)


remote func destroy_self(peer_id: int) -> void:
	emit_signal("target_destroyed", peer_id)
	queue_free()
