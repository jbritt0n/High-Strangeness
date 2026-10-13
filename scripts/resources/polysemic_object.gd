class_name PolysemicObject
extends Resource

## A piece of evidence with multiple, axis-dependent interpretations.

@export var object_id: String = ""
@export var display_name: String = "Unknown Object"
@export_multiline var neutral_description: String = ""

# axis -> interpretation text shown for that lens.
@export var variants: Dictionary = {}

# Which Ws this evidence can answer, e.g. ["who","where"].
@export var w_tags: Array[String] = []

# axis -> { "who": "...", "where": "..." } proposed answers.
@export var w_answers_per_axis: Dictionary = {}

# --- Extensions (data-driven leads/journal wiring) ---
# axis -> lead_id unlocked when interpreted under that axis.
@export var lead_unlocks: Dictionary = {}

# Journal entry ids unlocked the first time this object is interpreted.
@export var unlocks_journal_entries: Array[String] = []

# --- Photo evidence ---
# If set, the object is examined as a photograph that re-develops into the
# reading the player picks (see ExaminationUI). Readings don't need an active
# theory; each one carries its own axis, answers and lead.
@export var base_image: String = ""
@export var base_caption: String = ""
## Each reading: {id, label, axis, image, caption, voice, text, answers, lead,
## requires_tag}. A reading whose image file doesn't exist yet is hidden;
## objects without a base_image use text-only readings (image "").
@export var readings: Array[Dictionary] = []


func get_reading(reading_id: String) -> Dictionary:
	for r in readings:
		if str(r.get("id", "")) == reading_id:
			return r
	return {}


## Readings the player can pick right now: art exists and any tag gate passes.
func available_readings(profile: PlayerProfile) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in readings:
		var img := str(r.get("image", ""))
		if img != "" and not ResourceLoader.exists(img):
			continue
		var tag := str(r.get("requires_tag", ""))
		if tag != "" and not profile.has_tag(tag):
			continue
		out.append(r)
	return out
