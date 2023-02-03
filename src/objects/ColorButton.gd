extends Button
class_name ColorButton

const BUTTON_RADIUS: float = 30.0
const HOVER_SCALE: float = 1.1
const PRESSED_SCALE: float = 1.05

var stylebox: StyleBox = preload("res://resources/ui_themes/ColorButtonStylebox.tres")

var global_center_position: Vector2


func _ready() -> void:
	connect("mouse_entered", self, "set_size_info", [HOVER_SCALE])
	connect("mouse_exited", self, "set_size_info", [1.0])
	pass


# Set the initial color of the button.
func init(color: Color, center_position: Vector2) -> void:
	var new_stylebox = stylebox.duplicate()
	new_stylebox.bg_color = color
	add_stylebox_override("normal", new_stylebox)
	add_stylebox_override("focus", new_stylebox)
	add_stylebox_override("pressed", new_stylebox)
	add_stylebox_override("hover", new_stylebox)
	var disabled_stylebox = stylebox.duplicate()
	disabled_stylebox.bg_color = color.darkened(0.666) # 😈
	add_stylebox_override("disabled", disabled_stylebox)
	global_center_position = center_position
	set_size_info(1.0)


# Set the scale of the button, while preserving the center position.
func set_size_info(scale: float) -> void:
	var true_scale = scale
	if disabled:
		true_scale = 1.0
	rect_size = 2 * BUTTON_RADIUS * true_scale * Vector2(1.0, 1.0)
	rect_global_position = global_center_position - BUTTON_RADIUS * true_scale * Vector2(1.0, 1.0)
