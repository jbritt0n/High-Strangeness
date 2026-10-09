class_name JournalEntry
extends Resource

## A journal entry that re-renders itself based on the dominant axis and any
## locked evidence that references it. Tracks a read-snapshot for diffing.

@export var entry_id: String = ""
@export var title: String = ""
@export_multiline var ground_truth_event: String = ""

# axis -> full rewritten text.
@export var lens_templates: Dictionary = {}

@export var referenced_evidence_ids: Array[String] = []

# Runtime-only diff state (not serialized).
var _has_been_read: bool = false
var _snapshot: String = ""


## Resolve the lens to render under: locked evidence wins, else dominant axis.
func _resolve_axis(state: ParadigmState) -> String:
	for ev_id in referenced_evidence_ids:
		if state.locked_evidence.has(ev_id):
			return str(state.locked_evidence[ev_id])
	return state.get_dominant_axis()


## The text as it currently reads given the worldview.
func get_rendered_text(state: ParadigmState) -> String:
	var axis := _resolve_axis(state)
	if axis != "" and lens_templates.has(axis):
		return str(lens_templates[axis])
	return ground_truth_event


## Read the entry. Returns { text, changed, previous }.
## First read establishes the baseline; later reads diff against it.
func read(state: ParadigmState) -> Dictionary:
	var current := get_rendered_text(state)
	var changed := false
	var previous := ""
	if not _has_been_read:
		_has_been_read = true
		_snapshot = current
	elif current != _snapshot:
		changed = true
		previous = _snapshot
	return {"text": current, "changed": changed, "previous": previous}


## Accept the current rendering as the new baseline (player "acknowledges").
func accept_current_as_snapshot(state: ParadigmState) -> void:
	_snapshot = get_rendered_text(state)
	_has_been_read = true
