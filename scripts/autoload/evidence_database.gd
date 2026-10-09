extends Node

## Loads all PolysemicObject resources on startup. Static data only.

var _objects: Dictionary = {} # object_id -> PolysemicObject

const EVIDENCE_DIR := "res://data/evidence/"


func _ready() -> void:
	for res in Util.load_dir(EVIDENCE_DIR):
		if res is PolysemicObject and res.object_id != "":
			_objects[res.object_id] = res
	print("[EvidenceDatabase] loaded ", _objects.size(), " evidence objects")


func get_object(object_id: String) -> PolysemicObject:
	return _objects.get(object_id, null)


func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in _objects.keys():
		ids.append(k)
	return ids
