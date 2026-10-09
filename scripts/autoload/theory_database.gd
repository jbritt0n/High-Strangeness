extends Node

## Loads all TheoryDefinition resources on startup. Static data only.

var _defs: Dictionary = {} # theory_id -> TheoryDefinition

const THEORY_DIR := "res://data/theories/"


func _ready() -> void:
	for res in Util.load_dir(THEORY_DIR):
		if res is TheoryDefinition and res.theory_id != "":
			_defs[res.theory_id] = res
	print("[TheoryDatabase] loaded ", _defs.size(), " theories")


func get_definition(theory_id: String) -> TheoryDefinition:
	return _defs.get(theory_id, null)


func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in _defs.keys():
		ids.append(k)
	return ids
