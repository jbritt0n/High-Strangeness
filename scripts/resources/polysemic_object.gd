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
