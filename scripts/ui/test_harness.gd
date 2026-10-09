extends Control

## Developer control panel (not for shipping). Lets you drive the whole system
## without walking through the world.

const MVP_THEORIES := ["engineers_lens", "empty_chair", "black_ops_briefing"]
const MVP_AXES := ["exogenous", "psychogenic", "conspiratorial"]
const MVP_OBJECTS := ["polaroid_01", "metal_fragment"]

var _conviction_label: Label
var _state_label: Label


func _ready() -> void:
	_build()
	SignalBus.conviction_changed.connect(func(_v): _refresh())
	SignalBus.active_theories_changed.connect(func(_a): _refresh())
	SignalBus.w_answer_updated.connect(func(_w, _a, _l): _refresh())
	SignalBus.lead_unlocked.connect(func(_l): _refresh())
	_refresh()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.1)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 20)
	scroll.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var title := Label.new()
	title.text = "HIGH STRANGENESS — TEST HARNESS"
	title.add_theme_font_size_override("font_size", 24)
	root.add_child(title)

	_conviction_label = Label.new()
	root.add_child(_conviction_label)

	# Conviction buttons.
	root.add_child(_section("Conviction"))
	var conv_row := HBoxContainer.new()
	root.add_child(conv_row)
	conv_row.add_child(_button("-10%", func(): GameState._change_conviction(-10.0)))
	conv_row.add_child(_button("+10%", func(): GameState._change_conviction(10.0)))
	conv_row.add_child(_button("Advance Day (+5%)", func(): GameState.advance_day()))

	# Axis sliders.
	root.add_child(_section("Axis sliders (±5)"))
	for axis in MVP_AXES:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = axis
		lbl.custom_minimum_size = Vector2(160, 0)
		row.add_child(lbl)
		row.add_child(_button("-5", func(): GameState.adjust_slider(axis, -5.0); _refresh()))
		row.add_child(_button("+5", func(): GameState.adjust_slider(axis, 5.0); _refresh()))
		root.add_child(row)

	# Theory toggles.
	root.add_child(_section("Theories (max 4, max 2 axes)"))
	for tid in MVP_THEORIES:
		var def := TheoryDatabase.get_definition(tid)
		var theory_name: String = def.display_name if def else tid
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = theory_name
		lbl.custom_minimum_size = Vector2(200, 0)
		row.add_child(lbl)
		row.add_child(_button("Activate", func():
			var ok := GameState.activate_theory(tid)
			if not ok:
				print("[Harness] could not activate ", tid, " (limits/axes)")
			_refresh()))
		row.add_child(_button("Deactivate", func(): GameState.deactivate_theory(tid); _refresh()))
		root.add_child(row)

	# Examination.
	root.add_child(_section("Examine evidence"))
	for oid in MVP_OBJECTS:
		root.add_child(_button("Examine: " + oid, func(): SignalBus.examination_requested.emit(oid)))

	# Navigation / panels.
	root.add_child(_section("Scenes & panels"))
	root.add_child(_button("Go to Motel", func(): get_tree().change_scene_to_file("res://scenes/motel.tscn")))
	root.add_child(_button("Save", func(): GameState.save_game()))
	root.add_child(_button("Load", func(): GameState.load_game(); _refresh()))
	var hint := Label.new()
	hint.text = "In gameplay scenes: J = Journal, I = Inquiry Board."
	root.add_child(hint)

	root.add_child(_section("State"))
	_state_label = Label.new()
	_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_state_label)


func _section(text: String) -> Control:
	var l := Label.new()
	l.text = "— " + text + " —"
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func _refresh() -> void:
	var ps := GameState.paradigm_state
	_conviction_label.text = "Conviction: %.0f%%  [%s]   Day %d" % [
		ps.conviction, GameState.get_conviction_band(), GameState.day_number]

	var theories: Array[String] = []
	for tid in ps.active_theories:
		var def := TheoryDatabase.get_definition(tid)
		theories.append(def.display_name if def else tid)

	var w_soft := ""
	var w_locked := ""
	for w in ["who", "what", "when", "where", "why"]:
		w_soft += "%s:%s  " % [w, str(ps.w_answers_soft.get(w, "—"))]
		w_locked += "%s:%s  " % [w, str(ps.w_answers_locked.get(w, "—"))]

	var leads: Array[String] = []
	for l in LeadManager.get_unlocked_leads():
		leads.append(l.lead_id)

	_state_label.text = "Active: %s\nAxes in use: %s\n\nSOFT Ws:  %s\nLOCKED Ws: %s\n\nUnlocked leads: %s\nUnlocked journal: %s" % [
		", ".join(theories) if theories.size() > 0 else "none",
		", ".join(ps.get_axes_in_use()),
		w_soft, w_locked,
		", ".join(leads) if leads.size() > 0 else "none",
		", ".join(JournalManager.unlocked) if JournalManager.unlocked.size() > 0 else "none"]
