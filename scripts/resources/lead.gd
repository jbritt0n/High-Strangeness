class_name Lead
extends Resource

## A navigable destination unlocked by interpreting evidence.

@export var lead_id: String = ""
@export var target_scene: String = "" # e.g. "res://scenes/desert_highway.tscn"
@export var spawn_point: String = "" # node name in the target scene
@export_multiline var description: String = ""
@export var unlocked: bool = false
