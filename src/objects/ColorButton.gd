extends Button
class_name ColorButton


const BUTTON_RADIUS: float = 30.0
const BUTTON_CIRCLE_RADIUS_SCALE: float = 0.8
const HOVER_SCALE: float = 1.1
const PRESSED_SCALE: float = 1.05


# A default stylebox for color buttons.
var stylebox: StyleBox = preload("res://resources/ui_themes/ColorButtonStylebox.tres")
# The angle for this button from vertical.
var angle: float = 0.0


# Connect signals to set button size.
func _ready() -> void:
	connect("mouse_entered", self, "set_size_info", [HOVER_SCALE])
	connect("mouse_exited", self, "set_size_info", [1.0])


# Set the initial color of the button.
# :param color: The color of this button (when not disabled)
# :param angle: The angle from vertical to this button within the button circle.
func init(color: Color, angle: float) -> void:
	self.angle = angle
	var new_stylebox := stylebox.duplicate()
	new_stylebox.bg_color = color
	add_stylebox_override("normal", new_stylebox)
	add_stylebox_override("focus", new_stylebox)
	add_stylebox_override("pressed", new_stylebox)
	add_stylebox_override("hover", new_stylebox)
	var disabled_stylebox := stylebox.duplicate()
	disabled_stylebox.bg_color = color.darkened(0.666) # 😈
	add_stylebox_override("disabled", disabled_stylebox)
	set_size_info(1.0)


# Set the scale of the button, while preserving the center position.
# :param scale: The scale to set this button to.
func set_size_info(scale: float) -> void:
	var true_scale := 1.0 if disabled else scale
	# Get the position of the center of the button circle.
	var button_circle := get_parent() as Control
	var circle_center_position := button_circle.rect_global_position + 0.5 * button_circle.rect_size
	# The radius of the circle should be slightly less than half the maximum allowed by the rectangle
	var min_rect_dimension := min(button_circle.rect_size.x, button_circle.rect_size.y)
	var circle_radius := 0.5 * BUTTON_CIRCLE_RADIUS_SCALE * min_rect_dimension
	# The center position of the button
	var button_center_position := circle_center_position + circle_radius * Vector2(-sin(angle), cos(angle))
	rect_size = 2 * BUTTON_RADIUS * true_scale * Vector2(1.0, 1.0)
	rect_global_position = button_center_position - BUTTON_RADIUS * true_scale * Vector2(1.0, 1.0)
