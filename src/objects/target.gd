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


func handle_hit(player_id: int) -> void:
	if get_multiplayer().has_multiplayer_peer():
		if get_multiplayer().is_server():
				rpc("destroy_self", player_id)
		else:
			destroy_self(player_id)


func on_body_hit(body: Node) -> void:
	if body.is_in_group("Arrow"):
		handle_hit(int(str(body.archer.name)))


func on_area_hit(area: Node):
	var player = area.find_parent("?")
	handle_hit(int(str(player.name)))
