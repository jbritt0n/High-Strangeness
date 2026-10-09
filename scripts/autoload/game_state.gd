extends Node

## The heart of the game. Holds mutable state and the conviction logic.
## Other autoloads hold static data; this mutates ParadigmState and emits
## signals through the SignalBus.

const MAX_THEORIES := 4
const MAX_AXES := 2

const INITIAL_CONVICTION := 50.0

# Conviction deltas.
const INTERPRET_ALIGN := 5.0
const INTERPRET_CONTRADICT := -10.0
const COMMIT_CONSISTENT := -20.0
const COMMIT_CONTRADICT := -35.0
const DAILY_REST_RECOVERY := 5.0
const SLIDER_NUDGE_INTERPRET := 5.0
const SLIDER_NUDGE_ACTIVATE := 8.0

const SAVE_PATH := "user://drift_save.tres"

var paradigm_state: ParadigmState
var day_number: int = 1

# Who the player decided they are (set during the opening). See PlayerProfile.
var profile: PlayerProfile = PlayerProfile.new()

# Daily energy. Walking and examining spend it; at zero the player collapses
# and wakes up in the motel room on the next day (see DayCycle).
const ENERGY_PER_METRE := 0.3
const EXAMINE_ENERGY := 3.0
var max_energy: float = 100.0
var energy: float = 100.0
# True when the motel room scene should play the "waking up again" beat.
var waking_up: bool = false
var _exhausted_sent: bool = false

# Set just before a scene change so the new scene can position the player.
var pending_spawn_point: String = ""


func _ready() -> void:
	paradigm_state = ParadigmState.new()
	paradigm_state.conviction = INITIAL_CONVICTION


# ---------------------------------------------------------------------------
# Sliders & theories
# ---------------------------------------------------------------------------

func adjust_slider(axis: String, delta: float) -> void:
	if paradigm_state.axis_sliders.has(axis):
		paradigm_state.axis_sliders[axis] = clampf(
			float(paradigm_state.axis_sliders[axis]) + delta, 0.0, 100.0)


## Returns true if the theory was activated. Enforces max 4 theories / 2 axes.
func activate_theory(theory_id: String) -> bool:
	if paradigm_state.active_theories.has(theory_id):
		return false
	var def := TheoryDatabase.get_definition(theory_id)
	if def == null:
		push_warning("[GameState] unknown theory: " + theory_id)
		return false
	if paradigm_state.active_theories.size() >= MAX_THEORIES:
		return false
	var axes := paradigm_state.get_axes_in_use()
	if not axes.has(def.axis) and axes.size() >= MAX_AXES:
		return false
	paradigm_state.active_theories.append(theory_id)
	adjust_slider(def.axis, SLIDER_NUDGE_ACTIVATE)
	SignalBus.active_theories_changed.emit(paradigm_state.active_theories.duplicate())
	return true


func deactivate_theory(theory_id: String) -> void:
	if paradigm_state.active_theories.has(theory_id):
		paradigm_state.active_theories.erase(theory_id)
		SignalBus.active_theories_changed.emit(paradigm_state.active_theories.duplicate())


# ---------------------------------------------------------------------------
# Evidence
# ---------------------------------------------------------------------------

## Interpret evidence under a theory. Soft-fills Ws, adjusts conviction by
## consistency, and unlocks any associated leads/journal entries.
## Returns a dict describing the changes.
func interpret_evidence(object_id: String, theory_id: String) -> Dictionary:
	var obj := EvidenceDatabase.get_object(object_id)
	var def := TheoryDatabase.get_definition(theory_id)
	if obj == null or def == null:
		return {}
	var axis := def.axis
	var proposed: Dictionary = obj.w_answers_per_axis.get(axis, {})

	var contradiction := false
	var aligned := false
	for w in proposed:
		var ans := str(proposed[w])
		var locked := str(paradigm_state.w_answers_locked.get(w, ""))
		var soft := str(paradigm_state.w_answers_soft.get(w, ""))
		if locked != "" and locked != ans:
			contradiction = true
		elif (locked != "" and locked == ans) or (soft != "" and soft == ans):
			aligned = true

	var delta := 0.0
	if contradiction:
		delta = INTERPRET_CONTRADICT
	elif aligned:
		delta = INTERPRET_ALIGN

	# Soft-fill (never overwrite a locked answer).
	for w in proposed:
		if str(paradigm_state.w_answers_locked.get(w, "")) == "":
			paradigm_state.w_answers_soft[w] = str(proposed[w])
			SignalBus.w_answer_updated.emit(w, str(proposed[w]), false)

	adjust_slider(axis, SLIDER_NUDGE_INTERPRET)
	_change_conviction(delta)

	# Unlock journal entries (first interpretation reveals them).
	for entry_id in obj.unlocks_journal_entries:
		JournalManager.unlock_entry(entry_id)

	# Unlock a lead if this axis has one.
	var lead_id := str(obj.lead_unlocks.get(axis, ""))
	if lead_id != "":
		LeadManager.unlock_lead(lead_id)

	return {
		"axis": axis,
		"conviction_delta": delta,
		"soft_fills": proposed,
		"contradiction": contradiction,
		"lead_unlocked": lead_id,
	}


## Burn evidence: permanently lock its Ws under an axis, costing conviction and
## rewriting referencing journal entries.
func commit_evidence(object_id: String, axis: String) -> Dictionary:
	var obj := EvidenceDatabase.get_object(object_id)
	if obj == null:
		return {}
	var proposed: Dictionary = obj.w_answers_per_axis.get(axis, {})

	var contradiction := false
	for w in proposed:
		var locked := str(paradigm_state.w_answers_locked.get(w, ""))
		if locked != "" and locked != str(proposed[w]):
			contradiction = true

	var delta := COMMIT_CONTRADICT if contradiction else COMMIT_CONSISTENT

	for w in proposed:
		paradigm_state.w_answers_locked[w] = str(proposed[w])
		SignalBus.w_answer_updated.emit(w, str(proposed[w]), true)

	paradigm_state.locked_evidence[object_id] = axis
	_change_conviction(delta)
	JournalManager.invalidate_entries_for_evidence(object_id)
	SignalBus.evidence_committed.emit(object_id, axis)

	return {"axis": axis, "conviction_delta": delta, "contradiction": contradiction}


# ---------------------------------------------------------------------------
# Time
# ---------------------------------------------------------------------------

func advance_day() -> void:
	day_number += 1
	_change_conviction(DAILY_REST_RECOVERY)
	SignalBus.day_started.emit(day_number)


# ---------------------------------------------------------------------------
# Energy
# ---------------------------------------------------------------------------

func spend_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	energy = maxf(energy - amount, 0.0)
	SignalBus.energy_changed.emit(energy, max_energy)
	if energy <= 0.0 and not _exhausted_sent:
		_exhausted_sent = true
		SignalBus.exhausted.emit()


func restore_energy() -> void:
	energy = max_energy
	_exhausted_sent = false
	SignalBus.energy_changed.emit(energy, max_energy)


# ---------------------------------------------------------------------------
# Player profile (chosen in the opening)
# ---------------------------------------------------------------------------

func apply_profile(p: PlayerProfile) -> void:
	profile = p
	profile.created = true
	for axis in p.axis_bias:
		if paradigm_state.axis_sliders.has(axis):
			paradigm_state.axis_sliders[axis] = clampf(
				float(paradigm_state.axis_sliders[axis]) + float(p.axis_bias[axis]), 0.0, 100.0)
	paradigm_state.conviction = clampf(INITIAL_CONVICTION + p.conviction_bonus, 0.0, 100.0)
	max_energy = 100.0 + p.energy_bonus
	restore_energy()
	SignalBus.conviction_changed.emit(paradigm_state.conviction)
	SignalBus.profile_created.emit()


# ---------------------------------------------------------------------------
# Conviction
# ---------------------------------------------------------------------------

func _change_conviction(delta: float) -> void:
	if is_equal_approx(delta, 0.0):
		SignalBus.conviction_changed.emit(paradigm_state.conviction)
		return
	paradigm_state.conviction = clampf(paradigm_state.conviction + delta, 0.0, 100.0)
	SignalBus.conviction_changed.emit(paradigm_state.conviction)


func get_conviction() -> float:
	return paradigm_state.conviction


func get_conviction_band() -> String:
	var c := paradigm_state.conviction
	if c >= 80.0:
		return "high"
	if c <= 30.0:
		return "low"
	return "medium"


# ---------------------------------------------------------------------------
# Save / load
# ---------------------------------------------------------------------------

func save_game() -> void:
	var err := ResourceSaver.save(paradigm_state, SAVE_PATH)
	if err != OK:
		push_warning("[GameState] save failed: " + str(err))


func load_game() -> void:
	if not ResourceLoader.exists(SAVE_PATH):
		return
	var loaded := ResourceLoader.load(SAVE_PATH)
	if loaded is ParadigmState:
		paradigm_state = loaded
		SignalBus.conviction_changed.emit(paradigm_state.conviction)
		SignalBus.active_theories_changed.emit(paradigm_state.active_theories.duplicate())
