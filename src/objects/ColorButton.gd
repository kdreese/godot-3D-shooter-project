extends CenterContainer
class_name ColorButton


const BUTTON_RADIUS: float = 30.0
const BUTTON_CIRCLE_RADIUS_SCALE: float = 0.8
const HOVER_SCALE: float = 1.1
const PRESSED_SCALE: float = 1.05

onready var button: Button = $"%Button"

var color: Color


# A default stylebox for color buttons.
var stylebox: StyleBox = preload("res://resources/ui_themes/ColorButtonStylebox.tres")


# Connect signals to set button size.
func _ready() -> void:
	button.connect("mouse_entered", self, "set_button_size", [HOVER_SCALE])
	button.connect("mouse_exited", self, "set_button_size", [1.0])

	var new_stylebox := stylebox.duplicate()
	new_stylebox.bg_color = color
	button.add_stylebox_override("normal", new_stylebox)
	button.add_stylebox_override("focus", new_stylebox)
	button.add_stylebox_override("pressed", new_stylebox)
	button.add_stylebox_override("hover", new_stylebox)
	var disabled_stylebox := stylebox.duplicate()
	disabled_stylebox.bg_color = color.darkened(0.666) # 😈
	button.add_stylebox_override("disabled", disabled_stylebox)
	set_button_size(1.0)


# Sets the color of this button. Make sure this function is called BEFORE _ready
# :param color: The color of this button (when not disabled)
func set_button_color(new_color: Color) -> void:
	color = new_color


# Set the scale of the button, while preserving the center position.
# :param scale: The scale to set this button to.
func set_button_size(scale: float) -> void:
	var true_scale := 1.0 if button.disabled else scale
	button.rect_min_size = 2.0 * BUTTON_RADIUS * true_scale * Vector2.ONE
	print("Setting button size: %.2f" % scale)
