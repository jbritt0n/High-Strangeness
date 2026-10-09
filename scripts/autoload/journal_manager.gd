extends Node

## Loads JournalEntry resources, tracks unlocks and diff invalidations.

var _entries: Dictionary = {} # entry_id -> JournalEntry
var unlocked: Array[String] = []
var _pending_diff: Dictionary = {} # entry_id -> true

const JOURNAL_DIR := "res://data/journal/"


func _ready() -> void:
	for res in Util.load_dir(JOURNAL_DIR):
		if res is JournalEntry and res.entry_id != "":
			_entries[res.entry_id] = res
	print("[JournalManager] loaded ", _entries.size(), " journal entries")


func unlock_entry(entry_id: String) -> void:
	if not _entries.has(entry_id):
		push_warning("[JournalManager] unknown entry: " + entry_id)
		return
	if unlocked.has(entry_id):
		return
	unlocked.append(entry_id)
	SignalBus.journal_entry_unlocked.emit(entry_id)
	print("[JournalManager] unlocked entry: ", entry_id)


func get_entry(entry_id: String) -> JournalEntry:
	return _entries.get(entry_id, null)


## Returns { text, changed, previous, title }.
func read_entry(entry_id: String) -> Dictionary:
	var entry: JournalEntry = _entries.get(entry_id, null)
	if entry == null:
		return {}
	var result := entry.read(GameState.paradigm_state)
	result["title"] = entry.title
	_pending_diff.erase(entry_id)
	return result


func acknowledge_diff(entry_id: String) -> void:
	var entry: JournalEntry = _entries.get(entry_id, null)
	if entry == null:
		return
	entry.accept_current_as_snapshot(GameState.paradigm_state)
	_pending_diff.erase(entry_id)


## Called when evidence is locked/burned: any entry referencing it may now
## render differently and should flag a diff on next read.
func invalidate_entries_for_evidence(object_id: String) -> void:
	for entry_id in _entries:
		var entry: JournalEntry = _entries[entry_id]
		if entry.referenced_evidence_ids.has(object_id):
			_pending_diff[entry_id] = true


func has_pending_diff(entry_id: String) -> bool:
	return _pending_diff.has(entry_id)
