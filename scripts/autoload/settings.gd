extends Node

## Player options, persisted to user://settings.cfg. Autoload (after Dialogue).

const PATH := "user://settings.cfg"
const DISPLAY_MODES := ["Windowed", "Maximized", "Fullscreen"]

var display_mode: int = 1
var master_volume: float = 0.8
var text_speed: float = 80.0  # dialogue characters per second


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		display_mode = int(cfg.get_value("display", "mode", display_mode))
		master_volume = float(cfg.get_value("audio", "master", master_volume))
		text_speed = float(cfg.get_value("text", "speed", text_speed))
	apply()


func apply() -> void:
	match display_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	AudioServer.set_bus_mute(0, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.001)))
	Dialogue.chars_per_sec = text_speed


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "mode", display_mode)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("text", "speed", text_speed)
	cfg.save(PATH)
