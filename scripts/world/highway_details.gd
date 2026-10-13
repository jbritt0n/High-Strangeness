extends Node2D

## The highway remembers what you decided the Polaroid showed. Each child
## sprite named after a Polaroid reading ("light", "watcher", ...) is a ground
## detail rendered for that reading; only the believed one is shown. The first
## visit plays a few arrival lines that point at it.

const PHOTO := "polaroid_01"

const ARRIVAL := [
	["", "The road from the photograph. Not like it. [i]It.[/i] The same ridge, the same mountain sitting on the horizon as if it had been waiting for you to come back and look."],
]

const BY_READING := {
	"light": [["RECALL", "Past the shoulder, a circle of dirt has been cooked black, the sand at its centre fused to glass. Something sat here. Something hot, and heavy, and not for long."]],
	"watcher": [["SUSPICION", "Tyre tracks swing off the asphalt onto the gravel and stop. Three cigarette ends where a driver's window would be. They parked. They waited. They didn't hurry leaving."]],
	"planted": [["SUSPICION", "Paper on the road, still here, still face-up, and an envelope nobody has run over. Whoever left the photograph in the lot left the rest of the message out here."]],
	"shadow": [["GRIEF", "Two sets of footprints in the dust of the shoulder, walking side by side to the spot the picture was taken from. One set is yours. You're as sure of it as of your own handwriting."]],
	"road": [["RECALL", "Mile marker 117, exactly where the photograph said. It's just a road. It's always just a road, right up until it isn't."]],
}

const HINT := [["BODY", "Something catches the last of the light, down in the rocks at the edge of the pull-off."]]


func _ready() -> void:
	var reading := str(GameState.paradigm_state.evidence_readings.get(PHOTO, ""))
	for c in get_children():
		if c is CanvasItem:
			c.visible = c.name == reading
	if not GameState.flags.get("visited_highway", false):
		GameState.flags["visited_highway"] = true
		_arrive.call_deferred(reading)


func _arrive(reading: String) -> void:
	await get_tree().create_timer(0.6).timeout
	var lines: Array = ARRIVAL + BY_READING.get(reading, []) + HINT
	for l in lines:
		await Dialogue.say(l[1], l[0])
