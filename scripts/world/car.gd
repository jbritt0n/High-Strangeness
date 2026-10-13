class_name Car
extends Prop

## The car in the motel lot. It starts with a flat tyre and an empty tank:
## bring a spare tyre (it turns up somewhere on the highway shoulder) and a gas
## can (from the gas station) to fix it. Repairs persist across days (see
## GameState.car). Once it runs you can drive to any destination you have a
## lead for. (Placeholder until the proper car asset and travel screen.)

## Where the car sits (world metres) and the height of its click centre.
@export var world_pos: Vector2 = Vector2.ZERO
@export var click_height: float = 0.8

const REPAIR_ENERGY := 8.0


func _ready() -> void:
	super()
	position = Iso.to_screen(world_pos, click_height)


func interact() -> void:
	var c := GameState.car
	if not c["tire"]:
		if GameState.has_item("spare_tire"):
			var i: int = await Dialogue.choose("The rear tyre is flat to the rim. You have a spare.", ["Change the tyre.", "Later."], "BODY")
			if i == 0:
				GameState.remove_item("spare_tire")
				GameState.repair_car("tire")
				GameState.spend_energy(REPAIR_ENERGY)
				await Dialogue.say("Jack, lug wrench, a lot of swearing at a lug nut that has been waiting years for this. The spare goes on. It's not new, but it's round.", "BODY")
		else:
			await Dialogue.say("An '86 Chevy Blazer, government surplus, sun-faded to the colour of the desert it was bought for. The ghost of a unit number on the door. The rear tyre is flat to the rim and the spare carrier is empty.", "")
			await Dialogue.say("Your truck. Your hands know where the keys go. Spares bounce out of pickups on that highway all the time; one of them could be yours, if you look.", "RECALL")
	if c["tire"] and not c["fuel"]:
		if GameState.has_item("gas_can"):
			var j: int = await Dialogue.choose("The gauge sits on E like it's been nailed there.", ["Pour in the gas.", "Later."], "BODY")
			if j == 0:
				GameState.remove_item("gas_can")
				GameState.repair_car("fuel")
				await Dialogue.say("Five gallons, glugging, and the smell of it hangs in the dusk. The needle lifts off the pin.", "")
		else:
			await Dialogue.say("You turn the key to the first click. The fuel needle doesn't so much as twitch. Bone dry.", "")
			await Dialogue.say("There's a gas station further out along the highway, past the place in the photograph. Somebody there will sell you a can, if they're still selling anything.", "RECALL")
	if GameState.car_ready():
		await _drive()


func _drive() -> void:
	var here := get_tree().current_scene.scene_file_path
	var dests: Array = []
	for lead in LeadManager.get_unlocked_leads():
		if lead.target_scene != "" and lead.target_scene != here:
			dests.append(lead)
	if dests.is_empty():
		await Dialogue.say("The engine catches on the third try and settles into a rough idle. It runs. You just don't have anywhere to go yet.", "BODY")
		return
	var options: Array = []
	for d in dests:
		options.append(str(d.description))
	options.append("Stay put.")
	var k: int = await Dialogue.choose("The engine catches and settles into a rough idle. Where to?", options, "")
	if k < dests.size():
		var lead = dests[k]
		await Dialogue.fade(true, 0.9)
		SignalBus.scene_change_requested.emit(lead.target_scene, lead.spawn_point)
		Dialogue.fade(false, 0.9)
