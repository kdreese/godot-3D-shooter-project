@tool
extends HBoxContainer
class_name FancyButton


signal pressed


const OFFSET_MIN_SIZE = Vector2(0.0, 0.0)
const OFFSET_MAX_SIZE = Vector2(10.0, 0.0)


@export var text: String = ""

@onready var spacer: Control = $Spacer
@onready var button: Button = $Button


func _ready() -> void:
	button.text = text


func _process(_delta: float) -> void:
	if button.text != text:
		button.text = text


func on_button_press() -> void:
	pressed.emit()


func on_button_enter() -> void:
	get_tree().create_tween().tween_property(spacer, "custom_minimum_size", OFFSET_MAX_SIZE, 0.1)


func on_button_exit() -> void:
	get_tree().create_tween().tween_property(spacer, "custom_minimum_size", OFFSET_MIN_SIZE, 0.1)
