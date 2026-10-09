class_name RoomDoor
extends Prop

## A motel door. Locked ones answer with a line; an unlocked one changes scene.

@export var locked: bool = true
@export var locked_lines: PackedStringArray = PackedStringArray()
@export var unlock_line: String = ""
@export var target_scene: String = ""
@export var spawn_point: String = ""


## Locked doors read as a muted, cold red; open ones as a calm teal.
func _accent() -> Color:
	return Color(0.82, 0.45, 0.4) if locked else Color(0.45, 0.82, 0.78)


func interact() -> void:
	if locked:
		var line := "Locked."
		if not locked_lines.is_empty():
			line = locked_lines[randi() % locked_lines.size()]
		await Dialogue.say(line, "")
		return
	if unlock_line != "":
		await Dialogue.say(unlock_line, voice)
	SignalBus.scene_change_requested.emit(target_scene, spawn_point)
