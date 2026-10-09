extends Node

## Drives what happens when the motel room loads:
##   first time ever  -> the full wake-up, then choose who you are
##   after a new day  -> a short "the ceiling again" beat, then the morning
##                       routine: desk (journal), cork board (inquiry), cabinet
## Attach to a child node of the motel room scene.

@export var select_path: NodePath

const MORNINGS := [
	"The ceiling again. The same water stain, the same country that doesn't exist, slightly rearranged in the night.",
	"You wake in the same place. The clock radio and your wristwatch have disagreed again. You decide, arbitrarily, to believe neither.",
	"A headache, but a smaller one. Like a coin you've almost swallowed. The room is exactly as you left it. That's what bothers you.",
	"Morning, or the version of it this place allows. The key is on the nightstand. You don't remember putting it there. You never do.",
]

# The start-of-day ritual, nudging the player toward the desk, board and cabinet.
const ROUTINE := [
	"Before the day gets its hands on you: the desk for the notes, the cork board for the case, the cabinet for what you've decided is true.",
	"The usual order. Desk, board, cabinet. Read what you wrote. Decide who you believe. Then go out and be wrong about it.",
	"Coffee you don't have, a routine you do. The desk remembers for you. The board argues with it. The cabinet keeps score.",
]


func _ready() -> void:
	if not GameState.profile.created:
		Dialogue.set_black(true)
		_first_wake.call_deferred()
	elif GameState.waking_up:
		GameState.waking_up = false
		Dialogue.set_black(true)
		_morning.call_deferred()


func _morning() -> void:
	await get_tree().process_frame
	var day := GameState.day_number
	Dialogue.begin_skippable()
	await Dialogue.say(MORNINGS[(day - 2) % MORNINGS.size()], "")
	await Dialogue.fade(false, 1.6)
	if day == 2:
		await Dialogue.say("Day %d. You've been in this room before. You will be in it again. Your legs know it; the rest of you is catching up." % day, "RECALL")
	await Dialogue.say(ROUTINE[(day - 2) % ROUTINE.size()], "BODY")
	Dialogue.end_skippable()


func _first_wake() -> void:
	await get_tree().process_frame

	# Esc / Skip jumps straight to character selection, then past the intro.
	Dialogue.begin_skippable()
	await say("[i]Pain.[/i] A flat white pain, pressed into both temples like a coin into each eye. It has a pulse. The pulse is not yours.", "PAIN")
	await say("You are lying on your back. You know this because of the ceiling: acoustic tile, water-stained into the shape of a country that doesn't exist.", "")
	await say("Somewhere, a very long way off, a refrigerator hums, or a dial tone, or you do.", "")
	await say("Open your eyes. Whoever's eyes they are.", "BODY")
	await Dialogue.fade(false, 2.5)

	await say("There is a room. A bed you are in, a lamp that is on, a TV that is not on but is somehow glowing. A smell of cigarette ash and carpet glue.", "")
	await say("What day is it?", "RECALL")
	await say("The clock radio says 6:12. It doesn't say whether that's morning. Your wristwatch says Tuesday. The newspaper under the door says Friday. Neither is exactly wrong. Neither is right.", "")
	await say("Three days. Or three weeks. Or a very small number of very large hours. Somebody took them. Make a list of who benefits.", "SUSPICION")
	await say("Don't. Not yet. Start smaller. [i]Who are you?[/i]", "RECALL")
	await say("You can't find the answer. You can feel the shape of where it should be, the way a tongue finds a missing tooth. Everything around the gap is intact. That's the unsettling part.", "")
	await say("Let's rebuild, then. A little at a time. Starting with whoever you're willing to be.", "GRIEF")
	Dialogue.end_skippable()
	Dialogue.set_black(false)  # in case the reveal fade was skipped mid-way

	var select := get_node(select_path)
	var id: String = await select.run()
	var def := Characters.get_def(id)
	var profile := PlayerProfile.from_character(def)

	Dialogue.begin_skippable()
	for line in def["intro"]:
		await say(line[1], line[0])

	GameState.apply_profile(profile)

	await say("That's enough. That's a person. It'll do until a better one turns up.", "RECALL")
	await say("Or until somebody comes to collect the old one.", "SUSPICION")
	await say("Your head still hurts. Outside, a neon sign buzzes the name of a motel you apparently chose. Go and walk it off. Look at things. Believe some of them.", "")
	await say("You'll get tired. You always do. When you do, you'll wake up here, with your headache and your key, and the day will start over, a little different.", "BODY")
	await say("Every morning begins at the same three places: the desk for your notes, the cork board for the case, the filing cabinet for whatever you decide is true. [i]Click to walk. Click things to look at them.[/i]", "BODY")
	Dialogue.end_skippable()


func say(text: String, voice: String = "") -> void:
	await Dialogue.say(text, voice)
