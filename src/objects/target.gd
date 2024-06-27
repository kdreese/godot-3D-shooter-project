class_name Target
extends Area3D


signal target_destroyed(player_id: int)


func on_raycast_hit(player_id: int) -> void:
	destroy_self.rpc(player_id)


@rpc("any_peer", "call_local")
func destroy_self(player_id: int) -> void:
	queue_free()
	target_destroyed.emit(player_id)


func handle_hit(player_id: int) -> void:
	if get_multiplayer().is_server():
		destroy_self.rpc(player_id)


func on_body_hit(body: Node) -> void:
	if body.is_in_group("Arrow"):
		handle_hit(int(str(body.archer.name)))


func on_area_hit(area: Node):
	var player = area.owner
	handle_hit(int(str(player.name)))
