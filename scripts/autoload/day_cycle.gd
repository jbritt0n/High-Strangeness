extends Node

## Runs the day loop. When the player runs out of energy (or chooses to sleep)
## they black out and wake up in the same motel room on the next day.

const MOTEL_ROOM := "res://scenes/motel_room.tscn"

var _busy: bool = false


func _ready() -> void:
	SignalBus.exhausted.connect(collapse)


func collapse() -> void:
	if _busy:
		return
	_busy = true
	await Dialogue.say("Your legs make the decision before you do. The ground tilts up to meet you, politely, as if it had been waiting.", "BODY")
	await Dialogue.fade(true, 1.4)
	await Dialogue.say("Somewhere very far away, a motel sign buzzes. Then nothing.", "")
	_new_day()


## Voluntary sleep from the bed.
func sleep() -> void:
	if _busy:
		return
	_busy = true
	await Dialogue.fade(true, 1.2)
	_new_day()


func _new_day() -> void:
	GameState.advance_day()
	GameState.restore_energy()
	GameState.waking_up = true
	GameState.pending_spawn_point = "SpawnBed"
	get_tree().change_scene_to_file(MOTEL_ROOM)
	_busy = false
