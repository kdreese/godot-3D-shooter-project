extends Control


const BUTTON_CIRCLE_RADIUS := 120
const BUTTON_SIZE := 40


onready var button_circle := $"%ButtonGrid" as Control


# Generate a circle of buttons inside of the ButtonGrid node.
func generate_button_grid() -> void:
	for angle_idx in range(8):
		var angle := PI/4 * angle_idx
		var button := Button.new()
		button_circle.add_child(button)
		button.rect_min_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
		var center := 0.5 * (button_circle.rect_size - Vector2(BUTTON_SIZE, BUTTON_SIZE))
		button.rect_position = center - BUTTON_CIRCLE_RADIUS * Vector2(sin(angle), cos(angle))





# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	generate_button_grid()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass
