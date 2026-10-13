extends Prop

## The station's front door: the clerk inside sells you the gas can the truck
## needs. First arrival at the station also unlocks it as a driving
## destination (lead_gas_station).

func _ready() -> void:
	super()
	LeadManager.unlock_lead("lead_gas_station")


func interact() -> void:
	if GameState.has_item("gas_can") or GameState.car.get("fuel", false):
		await Dialogue.say("The clerk lifts two fingers off the counter without looking away from the television. That's hello, and it's also goodbye.", "")
		return
	if not GameState.flags.get("met_clerk", false):
		GameState.flags["met_clerk"] = true
		await Dialogue.say("A bell over the door. Behind the counter a man in a short-sleeved shirt is watching a portable TV with the sound off. Test pattern. He's watching it closely.", "")
	var i: int = await Dialogue.choose("He doesn't look up.", [
		"I need a gas can. Five gallons.",
		"What's on the TV?",
		"Nothing. Just looking.",
	], "")
	match i:
		0:
			await Dialogue.say("Can's eight dollars. Gas is on top of that.", "CLERK")
			await Dialogue.say("There's a bill folded in your jacket you don't remember putting there. It's enough. It's always exactly enough.", "SUSPICION")
			await Dialogue.say("That your Blazer at the Sundowner? Been sitting on a flat since Tuesday.", "CLERK")
			await Dialogue.say("Since Tuesday. Which Tuesday.", "RECALL")
			GameState.add_item("gas_can")
			await Dialogue.say("You carry the can out into the dusk, sloshing. It's heavier than it looks. Most things out here are.", "BODY")
		1:
			await Dialogue.say("Same thing it's always on.", "CLERK")
			await Dialogue.say("The test pattern's colour bars are in the wrong order. You're almost sure of it.", "SUSPICION")
		_:
			pass
