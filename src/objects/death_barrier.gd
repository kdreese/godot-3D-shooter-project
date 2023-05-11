extends Area3D


func _on_body_entered(body: Node3D):
	var player := body as Player
	player.on_death_barrier()
