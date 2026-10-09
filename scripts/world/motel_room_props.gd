extends Node2D

## Builds the clickable things in the motel room from a table. Positions are
## world metres inside the room (see Iso); "z" is the height of the click
## centre. "half" is the click rectangle half-size in backdrop pixels.

const OWN_DOOR := "res://scenes/motel.tscn"

const PROPS := [
	{"id": "bed", "label": "Bed", "pos": Vector2(-1.85, -0.9), "z": 0.6, "stand": Vector2(-0.45, -0.9),
	 "half": Vector2(260, 130), "action": "sleep"},
	{"id": "nightstand", "label": "Nightstand", "pos": Vector2(-2.68, 0.55), "z": 0.7, "stand": Vector2(-1.9, 0.5),
	 "half": Vector2(110, 120), "voice": "",
	 "lines": [
		"A clock radio, a rotary phone, a glass of water that is almost certainly not water, and a bottle of pills with the label scratched off. The clock says 6:12. It has said 6:12 every time you've looked.",
		"RECALL|A clock that agrees with itself is not a clock that's working.",
	 ]},
	{"id": "tv", "label": "Television", "pos": Vector2(-0.5, 2.1), "z": 1.1, "stand": Vector2(-0.5, 1.5),
	 "half": Vector2(120, 120),
	 "lines": [
		"The TV is off. The screen glows anyway, the pale blue of something waiting to be asked a question.",
		"SUSPICION|Tuned to a station that doesn't exist. Press your ear to the glass and you can hear it not existing.",
	 ]},
	{"id": "mirror", "label": "Mirror", "pos": Vector2(0.75, 2.38), "z": 1.55, "stand": Vector2(0.75, 1.5),
	 "half": Vector2(95, 140), "action": "mirror"},
	{"id": "window", "label": "Window", "pos": Vector2(1.95, 2.4), "z": 1.45, "stand": Vector2(1.95, 1.5),
	 "half": Vector2(170, 150),
	 "lines": [
		"Venetian blinds, striped orange and pink by the neon outside. The sign says SUNDOWNER. Letter by letter it seems to be saying it to you personally.",
		"RECALL|The light is the same colour as the headache.",
	 ]},
	{"id": "bathroom", "label": "Bathroom", "pos": Vector2(-2.3, 2.46), "z": 1.0, "stand": Vector2(-2.0, 1.5),
	 "half": Vector2(95, 175),
	 "lines": [
		"The bathroom door is ajar. The light inside is the wrong temperature.",
		"BODY|Later. Deal with it later. Your head has opinions about bathrooms.",
	 ]},
	{"id": "table", "label": "Table", "pos": Vector2(1.55, 0.35), "z": 0.8, "stand": Vector2(0.55, 0.35),
	 "half": Vector2(140, 100),
	 "lines": [
		"A round table. A notepad, a pen, an ashtray holding one cigarette that has burned all the way down without being smoked.",
		"On the notepad, in your handwriting: DON'T TRUST THE CLOCK. You don't remember writing it. You feel you should have.",
		"SUSPICION|Then who's the clock for?",
	 ]},
	{"id": "suitcase", "label": "Suitcase", "pos": Vector2(2.4, 1.9), "z": 0.75, "stand": Vector2(2.3, 1.1),
	 "half": Vector2(160, 120),
	 "lines": [
		"An open suitcase. Shirts folded with a military precision that isn't how you fold things. Underneath, a stack of unlabelled cassettes.",
		"RECALL|Whoever packed this packed for a long trip. Somebody expected you to be gone a while.",
	 ]},
	# The morning routine: desk (journal), cork board (inquiry board), cabinet (filed facts).
	{"id": "desk", "label": "Desk · journal", "pos": Vector2(-2.65, 1.6), "z": 0.9, "stand": Vector2(-1.6, 1.25),
	 "half": Vector2(150, 110), "action": "desk"},
	{"id": "board", "label": "Cork board · inquiry", "pos": Vector2(-2.965, 1.5), "z": 1.6, "stand": Vector2(-1.6, 1.25),
	 "half": Vector2(210, 170), "action": "board"},
	{"id": "cabinet", "label": "Filing cabinet", "pos": Vector2(-1.58, 2.1), "z": 0.65, "stand": Vector2(-1.55, 1.2),
	 "half": Vector2(95, 190), "action": "cabinet"},
	{"id": "armchair", "label": "Armchair", "pos": Vector2(2.55, -0.6), "z": 0.55, "stand": Vector2(1.7, -0.6),
	 "half": Vector2(140, 120),
	 "lines": [
		"Your coat hangs over the armchair, still warm. Someone sat here recently, and the someone had your build.",
		"SUSPICION|Or the coat is warm because the radiator is on. The radiator is not on.",
	 ]},
]


func _ready() -> void:
	for d in PROPS:
		var p := Prop.new()
		p.name = "Prop_" + str(d["id"])
		p.prop_id = d["id"]
		p.hover_label = d["label"]
		p.position = Iso.to_screen(d["pos"], d["z"])
		p.ground_pos = d["stand"]
		p.click_half_size = d["half"]
		p.action = d.get("action", "")
		p.interact_distance = 1.3
		if d.has("lines"):
			p.lines = PackedStringArray(d["lines"])
		add_child(p)

	# The way out.
	var door := RoomDoor.new()
	door.name = "Door_exit"
	door.prop_id = "exit"
	door.hover_label = "Outside"
	door.position = Iso.to_screen(Vector2(1.75, -2.475), 1.05)
	door.ground_pos = Vector2(1.75, -1.75)
	door.click_half_size = Vector2(120, 270)
	door.interact_distance = 1.2
	door.locked = false
	door.target_scene = OWN_DOOR
	door.spawn_point = "SpawnRoom3"
	door.voice = "BODY"
	door.unlock_line = "You pick up the key, you hope, and step out into the buzzing orange light."
	add_child(door)

