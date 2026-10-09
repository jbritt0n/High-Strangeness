class_name Characters
extends RefCounted

## The playable investigators. Each is a fully designed character with their own
## look, background and starting worldview. To add one: give it an entry here,
## drop its portrait in assets/art/portraits/ and render its sprite sheet to
## assets/art/characters/ (7 columns: idle + 6 walk frames, 8 direction rows).
##
## Fields
##   id / name / role / age   identity shown on the selection screen
##   blurb                    who they were before the missing time
##   traits                   short lines describing how they see the world
##   portrait / sheet         art paths (sheet may not exist yet -> silhouette)
##   axis_bias                nudges to the hidden theory sliders (see ParadigmState)
##   conviction / energy      bonuses to starting conviction and daily energy
##   tags                     flags other systems check: GameState.profile.has_tag()
##   intro                    [voice, line] pairs played after choosing
##   mirror                   what the bathroom mirror says about them
##   coat / skin              colours for the fallback silhouette

const ROSTER := [
	{
		"id": "dale",
		"name": "Dale Kessler",
		"role": "Ex-Air Force radar operator",
		"age": "Fifty-eight",
		"blurb": "Twenty-two years watching empty sky for the Air Force, on a mountaintop that officially didn't have a name. He knows what a real return looks like on a scope, and he knows what a return looks like when someone has decided it isn't there. He left the service with a pension, a hearing problem, and a file nobody would let him read.",
		"traits": [
			"Trained to trust instruments over people",
			"Knows the difference between a ghost and a lie",
			"Doesn't sleep much. The sky keeps odd hours.",
		],
		"portrait": "res://assets/art/portraits/dale_kessler.webp",
		"sheet": "res://assets/art/characters/dale_kessler.png",
		"axis_bias": {"exogenous": 10.0, "conspiratorial": 8.0, "endogenous": 4.0},
		"conviction": 0.0,
		"energy": 5.0,
		"tags": ["dale", "air_force", "radar_operator", "veteran"],
		"intro": [
			["RECALL", "Kessler. Dale. It comes back the way a phone number does, by the hands first."],
			["RECALL", "A radar operator. You spent twenty-two years looking at a green sweep on a dark screen, waiting for it to show you something you were allowed to report."],
			["SUSPICION", "And then the day it showed you something you weren't. [i]Everyone remembers the day they stopped being useful.[/i]"],
			["BODY", "There's a pill bottle in your jacket pocket. A folded scrap of paper beside it, soft with handling. Your hands have been in there more than once. Whatever's written on it, you've read it enough to wear it out."],
		],
		"mirror": "Fifty-eight, going on a hard seventy. Shaved head, grey stubble, and a face that has spent a long time not reacting to things. Sunglasses in the jacket, because the light in here is the wrong kind.",
		"coat": Color(0.17, 0.26, 0.38),
		"skin": Color(0.62, 0.46, 0.36),
	},
]


static func get_def(id: String) -> Dictionary:
	for d in ROSTER:
		if d["id"] == id:
			return d
	return ROSTER[0]


static func has_character(id: String) -> bool:
	for d in ROSTER:
		if d["id"] == id:
			return true
	return false
