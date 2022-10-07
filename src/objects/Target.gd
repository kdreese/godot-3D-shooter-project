extends KinematicBody


func on_hit(area: Area) -> void:
	print("Target got hit.")
	queue_free()
