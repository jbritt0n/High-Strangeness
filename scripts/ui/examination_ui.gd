extends CanvasLayer

## Examination overlay. Pauses the game, shows an object's neutral description,
## then a button per active theory to interpret it. After interpreting, lets the
## player burn (lock) the evidence.

var _root: Control
var _panel: PanelContainer
var _title: Label
var _desc: RichTextLabel
var _choices: VBoxContainer
var _status: Label

var _current_object: PolysemicObject
var _last_axis: String = ""


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide_overlay()
	SignalBus.examination_requested.connect(_on_examination_requested)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.8)
	_root.add_child(bg)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(640, 420)
	_panel.position = Vector2(-320, -210)
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_title)

	_desc = RichTextLabel.new()
	_desc.bbcode_enabled = true
	_desc.fit_content = true
	_desc.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(_desc)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_choices = VBoxContainer.new()
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices.add_theme_constant_override("separation", 8)
	scroll.add_child(_choices)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	vbox.add_child(_status)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(hide_overlay)
	vbox.add_child(close)


func _on_examination_requested(seed_id: String) -> void:
	var obj := EvidenceDatabase.get_object(seed_id)
	if obj == null:
		push_warning("[ExaminationUI] unknown object: " + seed_id)
		return
	_current_object = obj
	_last_axis = ""
	_status.text = ""
	_title.text = obj.display_name
	_desc.text = obj.neutral_description
	_populate_interpretations()
	_show_overlay()


func _populate_interpretations() -> void:
	for c in _choices.get_children():
		c.queue_free()

	var active: Array = GameState.paradigm_state.active_theories
	if active.is_empty():
		var note := Label.new()
		note.text = "(No active theories. Activate a theory to interpret this.)"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_choices.add_child(note)
		return

	for theory_id in active:
		var def := TheoryDatabase.get_definition(theory_id)
		if def == null:
			continue
		var variant := str(_current_object.variants.get(def.axis, ""))
		if variant == "":
			continue
		var proposed: Dictionary = _current_object.w_answers_per_axis.get(def.axis, {})
		var preview := _format_w_preview(proposed)

		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(0, 64)
		btn.text = "%s\n%s\n%s" % [def.display_name, variant, preview]
		btn.pressed.connect(_on_interpret_pressed.bind(theory_id))
		_choices.add_child(btn)


func _format_w_preview(proposed: Dictionary) -> String:
	var parts: Array[String] = []
	for w in proposed:
		parts.append("%s: %s" % [str(w).capitalize(), str(proposed[w])])
	if parts.is_empty():
		return ""
	return "[ " + ", ".join(parts) + " ]"


func _on_interpret_pressed(theory_id: String) -> void:
	var result := GameState.interpret_evidence(_current_object.object_id, theory_id)
	if result.is_empty():
		return
	_last_axis = str(result.get("axis", ""))
	var delta := float(result.get("conviction_delta", 0.0))
	var sign_txt := "+" if delta >= 0 else ""
	_status.text = "Interpreted. Conviction %s%.0f%%  (now %.0f%%)" % [
		sign_txt, delta, GameState.get_conviction()]
	if bool(result.get("contradiction", false)):
		_status.text += "  ⚠ contradicts a locked answer"
	if str(result.get("lead_unlocked", "")) != "":
		_status.text += "  • new lead unlocked"
	_show_post_interpret()


func _show_post_interpret() -> void:
	for c in _choices.get_children():
		c.queue_free()

	var info := Label.new()
	info.text = "Soft-filled the case under '%s'. Burn it to lock these answers permanently?" % _last_axis
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_choices.add_child(info)

	var burn := Button.new()
	burn.text = "🔥 Burn evidence (lock answers, costs conviction)"
	burn.pressed.connect(_on_burn_pressed)
	_choices.add_child(burn)

	var back := Button.new()
	back.text = "Reconsider (back to interpretations)"
	back.pressed.connect(_populate_interpretations)
	_choices.add_child(back)


func _on_burn_pressed() -> void:
	if _last_axis == "":
		return
	var result := GameState.commit_evidence(_current_object.object_id, _last_axis)
	var delta := float(result.get("conviction_delta", 0.0))
	_status.text = "Burned. Conviction %.0f%%  (now %.0f%%). The journal stirs." % [
		delta, GameState.get_conviction()]
	for c in _choices.get_children():
		c.queue_free()
	var done := Label.new()
	done.text = "These answers are now locked. Past entries have been rewritten."
	done.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_choices.add_child(done)


func _show_overlay() -> void:
	_root.visible = true
	get_tree().paused = true


func hide_overlay() -> void:
	_root.visible = false
	get_tree().paused = false
	SignalBus.examination_closed.emit()
