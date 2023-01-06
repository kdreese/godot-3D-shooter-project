extends Control

const BUTTON_SIZE := 40


onready var button := $"%Button" as Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button.rect_position = -(BUTTON_SIZE / 2) * Vector2(-1, -1)
	button.rect_size = BUTTON_SIZE * Vector2(1, 1)



# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass
