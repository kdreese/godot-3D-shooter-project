extends Node


const VERSION := "v0.2"

const CONFIG_PATH := "user://config.cfg"

const DEFAULT_CONFIG := {
	"name": "Guest",
	"address": "localhost",
	"port": 8380,
	"mouse_sensitivity": 0.5,
	"sfx_volume": 1.0,
	"max_players": 8,
	"fullscreen": false,
	"window_size": Vector2i(1152, 648),
}

const MAX_SFX_VOLUME_DB = 0.0


var config := DEFAULT_CONFIG.duplicate(true)
var menu_to_load := "main_menu"
var server_kicked := false


func _ready() -> void:
	randomize()
	parse_args()
	load_config()
	process_mode = Node.PROCESS_MODE_ALWAYS


# When the user quits the game, save the game before the engine fully quits
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_config()
		get_tree().quit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if (not ((get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN) or (get_window().mode == Window.MODE_FULLSCREEN))) else Window.MODE_WINDOWED
		get_viewport().set_input_as_handled()


func load_config() -> void:
	var config_file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var open_error := FileAccess.get_open_error()
	if open_error == ERR_FILE_NOT_FOUND:
		print("No config file found, using default settings")
		return
	elif open_error:
		push_warning("Could not open config file for reading! Using default settings")
		return

	var new_config_variant = config_file.get_var()
	config_file.close()

	if typeof(new_config_variant) != TYPE_DICTIONARY:
		push_warning("Config file was corrupted! Using default settings")
		return
	var new_config := new_config_variant as Dictionary

	for key in new_config.keys():
		if config.has(key) and typeof(new_config[key]) == typeof(config[key]):
			var new_value = new_config[key]
			if key == "port":
				new_value = int(clamp(new_value, 0, 65535))
			elif key == "max_players":
				new_value = int(clamp(new_value, 2, 8))
			config[key] = new_value
		elif not config.has(key):
			config[key] = new_config[key]

	# Set the size of the window and center it.
	get_window().size = config["window_size"]
	var screen_id := get_window().current_screen
	var screen_center := DisplayServer.screen_get_position(screen_id) \
			+ DisplayServer.screen_get_size(screen_id) / 2
	get_window().position = screen_center - config["window_size"] / 2

	if config["fullscreen"]:
		# If we're in fullscreen, change the mode.
		get_window().mode = Window.MODE_FULLSCREEN

	Global.update_volume()


func save_config() -> void:
	var config_file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if not config_file:
		push_error("Could not open config file for writing!")
		return

	if get_window().mode == Window.MODE_FULLSCREEN:
		config["fullscreen"] = true
	else:
		config["fullscreen"] = false
		config["window_size"] = get_window().size

	config_file.store_var(config)
	config_file.close()


func update_volume() -> void:
	# Volume is given as a percent, so change that to dB.
	var sound_volume_pct := config["sfx_volume"] as float
	var sounds_bus_index := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(sounds_bus_index, MAX_SFX_VOLUME_DB + (20 * log(sound_volume_pct) / log(10)))


func parse_args() -> void:
	ArgParse.add_switch_arg("--dedicated")
	ArgParse.add_string_arg("--server-name", "Dedicated Server")
	ArgParse.add_int_arg("--port", 8380)
	ArgParse.add_int_arg("--max-players", 8)
	ArgParse.add_int_arg("--game-id", 0)
	ArgParse.add_string_arg("--password-hash", "")

	ArgParse.parse_args()
