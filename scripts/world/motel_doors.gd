extends Node2D

## Builds an interactive door for every motel door on the painted backdrop.
## All are locked except the player's own room (Room 3). Positions are world
## metres on the ground (see Iso); "z" is the height of the door's centre.

const DOOR_Z := 1.07
const OWN_ROOM := "r3"

const DOORS := [
	{"id": "office", "label": "Office", "pos": Vector2(-10.4, 9.92), "stand": Vector2(-10.4, 8.2),
	 "lines": ["Locked. A hand-lettered card in the glass: BACK IN 5 MIN. It's sun-bleached enough to suggest it has been five minutes for a very long time.",
			"Dark inside. Behind the desk a rotary phone sits off its hook. Nobody put it down on purpose."]},
	{"id": "r1", "label": "Room 1", "pos": Vector2(-6.0, 9.92), "stand": Vector2(-6.0, 8.2),
	 "lines": ["Room 1. Locked. A strip of light under the door, then it's gone, as if someone stepped away from it.",
			"You knock. Nothing. Somewhere inside, a TV laughs at a joke that hasn't been told yet."]},
	{"id": "r2", "label": "Room 2", "pos": Vector2(-2.4, 9.92), "stand": Vector2(-2.4, 8.2),
	 "lines": ["Room 2. Locked. The number has been painted over twice. The original shows through, and it isn't 2."]},
	{"id": "r3", "label": "Your room (3)", "pos": Vector2(1.2, 9.92), "stand": Vector2(1.2, 8.2), "own": true},
	{"id": "r4", "label": "Room 4", "pos": Vector2(4.8, 9.92), "stand": Vector2(4.8, 8.2),
	 "lines": ["Room 4. Locked. The curtain twitches. Wind, probably. There isn't any wind."]},
	{"id": "r5", "label": "Room 5", "pos": Vector2(8.4, 9.92), "stand": Vector2(8.4, 8.2),
	 "lines": ["Room 5. Locked. The door is warm, the way a door is warm when someone has just been leaning on the other side of it."]},
	{"id": "r6", "label": "Room 6", "pos": Vector2(-11.92, -5.0), "stand": Vector2(-10.4, -5.0),
	 "lines": ["Room 6. Locked. Dust on the handle. Nobody has touched this one in a long time, which, you suspect, is the point."]},
	{"id": "r7", "label": "Room 7", "pos": Vector2(-11.92, -1.4), "stand": Vector2(-10.4, -1.4),
	 "lines": ["Room 7. Locked. You press an ear to the wood and hear a very slow, even breathing. It is not coming from inside the room. It is coming from the wood."]},
	{"id": "r8", "label": "Room 8", "pos": Vector2(-11.92, 2.2), "stand": Vector2(-10.4, 2.2),
	 "lines": ["Room 8. Locked. A DO NOT DISTURB sign hangs from the handle. It's handwritten. It's in your handwriting."]},
	{"id": "r9", "label": "Room 9", "pos": Vector2(-11.92, 5.8), "stand": Vector2(-10.4, 5.8),
	 "lines": ["Room 9. Locked. Tape over the peephole, from the outside. Someone wanted whoever's in there to stay un-looked-at."]},
]


func _ready() -> void:
	for d in DOORS:
		var door := RoomDoor.new()
		door.name = "Door_" + str(d["id"])
		door.prop_id = d["id"]
		door.hover_label = d["label"]
		door.position = Iso.to_screen(d["pos"], DOOR_Z)
		door.ground_pos = d["stand"]
		door.click_half_size = Vector2(34, 80)
		if d.get("own", false):
			door.locked = false
			door.unlock_line = "The key turns before you've decided to use it. Of course it does."
			door.voice = "BODY"
			door.target_scene = "res://scenes/motel_room.tscn"
			door.spawn_point = "SpawnDoor"
		else:
			door.locked = true
			door.locked_lines = PackedStringArray(d["lines"])
		add_child(door)
