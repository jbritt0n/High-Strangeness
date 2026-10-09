class_name ParadigmState
extends Resource

## The complete mutable state of the player's worldview.
## Owned by GameState; serialized for save/load.

# Hidden axis sliders, 0-100. Drives dominant-axis resolution and visuals.
@export var axis_sliders: Dictionary = {
	"exogenous": 50.0,
	"endogenous": 50.0,
	"metaphysical": 50.0,
	"temporal": 50.0,
	"simulation": 50.0,
	"psychogenic": 50.0,
	"conspiratorial": 50.0,
}

# Conviction percentage, 0-100.
@export var conviction: float = 50.0

# Active subtheory ids. Max 4, drawn from at most 2 distinct axes.
@export var active_theories: Array[String] = []

# evidence_id -> axis the evidence was burned/locked under.
@export var locked_evidence: Dictionary = {}

# Penciled-in answers (changeable).
@export var w_answers_soft: Dictionary = {
	"who": "", "what": "", "when": "", "where": "", "why": "",
}

# Permanently committed answers (set by burning evidence).
@export var w_answers_locked: Dictionary = {
	"who": "", "what": "", "when": "", "where": "", "why": "",
}

# theory_id -> { branch_id: tier } (reserved for branches/syntheses).
@export var branch_tiers: Dictionary = {}


## Unique list of axes represented by the currently active theories.
func get_axes_in_use() -> Array:
	var result: Array = []
	for theory_id in active_theories:
		var def := TheoryDatabase.get_definition(theory_id)
		if def != null and not result.has(def.axis):
			result.append(def.axis)
	return result


## The active axis with the highest slider value. "" if no theories active.
func get_dominant_axis() -> String:
	var axes := get_axes_in_use()
	if axes.is_empty():
		return ""
	var best: String = axes[0]
	var best_val: float = float(axis_sliders.get(best, 0.0))
	for a in axes:
		var v := float(axis_sliders.get(a, 0.0))
		if v > best_val:
			best_val = v
			best = a
	return best


## Effective answer for a W: locked takes precedence over soft.
func effective_answer(w_id: String) -> String:
	var locked: String = str(w_answers_locked.get(w_id, ""))
	if locked != "":
		return locked
	return str(w_answers_soft.get(w_id, ""))
