extends Area2D

## Walk into this to request a scene change. Optionally gated by a lead.

@export var target_scene: String = ""
@export var spawn_point: String = ""
@export var required_lead_id: String = "" # "" = always open
## Said when the player walks in before the lead is unlocked ("" = silent).
@export var locked_line: String = ""
@export var locked_voice: String = ""

var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if not body.is_in_group("player"):
		return
	if required_lead_id != "" and not LeadManager.is_unlocked(required_lead_id):
		print("[Door] locked - requires lead: ", required_lead_id)
		if locked_line != "":
			Dialogue.say(locked_line, locked_voice)
		return
	_triggered = true
	SignalBus.scene_change_requested.emit(target_scene, spawn_point)
