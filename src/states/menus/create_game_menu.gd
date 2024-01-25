extends Control


## Signal to go mack to the menu.
signal back_to_menu

## Signal to create a game on the main server.
signal create_game(server_name: String, max_players: int)

## Signal to host a game locally
signal host_game(port: int, max_players: int)


enum CreateMode {
	HOST_REMOTE = 0,
	HOST_LOCAL = 1,
}

const BUTTON_TEXT = {
	CreateMode.HOST_REMOTE: "Create Game",
	CreateMode.HOST_LOCAL: "Host Game"
}


@onready var mode_select: OptionButton = %ModeSelect
@onready var port_label: Label = %PortLabel
@onready var port_spin_box: SpinBox = %PortSpinBox
@onready var name_label: Label = %NameLabel
@onready var name_line_edit: LineEdit = %NameLineEdit
@onready var create_button: Button = %CreateButton
@onready var num_players_slider: HSlider = %NumPlayersSlider
@onready var slider_label: Label = %SliderLabel


func _ready() -> void:
	port_spin_box.value = Global.config.get("port", 0)


## Handle dropdown selection.
func on_mode_change(index: int) -> void:
	if index == CreateMode.HOST_LOCAL:
		port_label.show()
		port_spin_box.show()
		name_label.hide()
		name_line_edit.hide()
		create_button.disabled = false
	else:
		port_label.hide()
		port_spin_box.hide()
		name_label.show()
		name_line_edit.show()
		if name_line_edit.text == "":
			create_button.disabled = true
	create_button.text = BUTTON_TEXT[index]


## Update the disabled state of the button when the text box is changed.
func on_text_changed(text: String) -> void:
	create_button.disabled = (text == "")


func on_port_value_changed(new_value: float) -> void:
	Global.config.port = int(new_value)


func on_slider_value_changed(value: float) -> void:
	slider_label.text = str(int(value))


func on_back_button_pressed() -> void:
	hide()


## Handle create button presses.
func on_create_button_pressed() -> void:
	if mode_select.selected == CreateMode.HOST_LOCAL:
		host_game.emit(int(port_spin_box.value), num_players_slider.value)
	else:
		create_game.emit(name_line_edit.text, num_players_slider.value)
	hide()
