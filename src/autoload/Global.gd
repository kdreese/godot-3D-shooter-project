extends Node


const CONFIG_PATH := "user://config.cfg"

var config := {
	"name": "Guest",
	"favorite_color": Color(255, 0, 0, 255),
	"address": "localhost",
	"port": 8380,
}


func _ready() -> void:
	randomize()
	load_config()
	pause_mode = Node.PAUSE_MODE_PROCESS


# When the user quits the game, save the game before the engine fully quits
func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		save_config()
		get_tree().quit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		OS.window_fullscreen = not OS.window_fullscreen
		get_tree().set_input_as_handled()


func load_config():
	var config_file := File.new()
	var error := config_file.open(CONFIG_PATH, File.READ)
	if error:
		push_warning("Could not open config file for reading")
		return

	var new_config_variant = config_file.get_var()
	config_file.close()

	if typeof(new_config_variant) != TYPE_DICTIONARY:
		return
	var new_config := new_config_variant as Dictionary

	for key in config.keys():
		if new_config.has(key) and typeof(new_config[key]) == typeof(config[key]):
			var new_value = new_config[key]
			if key == "port" and (new_value < 0 or new_value > 65535):
				continue
			config[key] = new_config[key]


func save_config():
	var config_file := File.new()
	var error := config_file.open(CONFIG_PATH, File.WRITE)
	if error:
		push_error("Could not open config file for writing")
		return

	config_file.store_var(config)
	config_file.close()
