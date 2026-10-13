extends Node

## Global event bus. No logic, only signals. Decouples scenes from systems.

signal examination_requested(seed_id: String)
signal examination_closed
signal scene_change_requested(scene_path: String, spawn_point: String)
signal journal_entry_unlocked(entry_id: String)
signal conviction_changed(new_value: float)
signal active_theories_changed(active_ids: Array)
signal w_answer_updated(w_id: String, answer: String, locked: bool)
signal lead_unlocked(lead_id: String)
signal evidence_committed(object_id: String, axis: String)
signal energy_changed(value: float, max_value: float)
signal exhausted
signal day_started(day: int)
signal profile_created
signal inventory_changed(items: Array)
signal car_changed
