class_name PlayerProfile
extends Resource

## Who the player is: one of the investigators in Characters. The rest is
## gameplay data that later systems can read: tags gate dialogue/evidence
## reactions, axis_bias nudges the hidden theory sliders, and the bonuses tweak
## starting conviction and daily energy.

@export var created: bool = false
@export var character_id: String = ""
@export var display_name: String = ""

@export var tags: Array[String] = []
@export var axis_bias: Dictionary = {}
@export var conviction_bonus: float = 0.0
@export var energy_bonus: float = 0.0


func has_tag(tag: String) -> bool:
	return tags.has(tag)


## Fill from a Characters roster entry.
static func from_character(def: Dictionary) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.character_id = def["id"]
	p.display_name = def["name"]
	for t in def.get("tags", []):
		p.tags.append(t)
	p.axis_bias = (def.get("axis_bias", {}) as Dictionary).duplicate()
	p.conviction_bonus = float(def.get("conviction", 0.0))
	p.energy_bonus = float(def.get("energy", 0.0))
	return p
