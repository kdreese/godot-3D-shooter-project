extends KinematicBody


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_hit(area: Area) -> void:
	print("Target got hit.")
	queue_free()
