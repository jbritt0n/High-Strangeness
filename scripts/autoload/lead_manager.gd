extends Node

## Loads Lead resources and tracks which are unlocked.

var _leads: Dictionary = {} # lead_id -> Lead
var _unlocked: Array[String] = []

const LEAD_DIR := "res://data/leads/"


func _ready() -> void:
	for res in Util.load_dir(LEAD_DIR):
		if res is Lead and res.lead_id != "":
			res.unlocked = false # reset runtime state
			_leads[res.lead_id] = res
	print("[LeadManager] loaded ", _leads.size(), " leads")


func unlock_lead(lead_id: String) -> void:
	if not _leads.has(lead_id):
		push_warning("[LeadManager] unknown lead: " + lead_id)
		return
	if _unlocked.has(lead_id):
		return
	_unlocked.append(lead_id)
	_leads[lead_id].unlocked = true
	SignalBus.lead_unlocked.emit(lead_id)
	print("[LeadManager] unlocked lead: ", lead_id)


func is_unlocked(lead_id: String) -> bool:
	return _unlocked.has(lead_id)


func get_unlocked_leads() -> Array:
	var result: Array = []
	for id in _unlocked:
		result.append(_leads[id])
	return result


func reset() -> void:
	_unlocked.clear()
	for id in _leads:
		_leads[id].unlocked = false
