extends CanvasLayer

## Examination overlay. Pauses the game.
##   Theory evidence: shows the neutral description, then a button per active
##   theory to interpret it, then lets the player burn (lock) it.
##   Photo evidence (objects with `readings`): shows the photograph itself; the
##   player decides what it shows and the print re-develops into that version.
##   The chosen reading is remembered, can be reconsidered, or burned to lock it.

const DEVELOP_SHADER := preload("res://shaders/polaroid_develop.gdshader")
const DEVELOP_TIME := 2.6
const INK := Color(0.16, 0.14, 0.2)

var _root: Control
var _panel: PanelContainer
var _title: Label
var _voice: Label
var _desc: RichTextLabel
var _choices: VBoxContainer
var _status: Label
var _close: Button

var _card: PanelContainer
var _photo: TextureRect
var _photo_mat: ShaderMaterial
var _caption: Label
var _developing: bool = false

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
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	margin.add_child(row)

	_build_card(row)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.custom_minimum_size = Vector2(560, 500)
	row.add_child(vbox)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_title)

	_voice = Label.new()
	_voice.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_voice)

	_desc = RichTextLabel.new()
	_desc.bbcode_enabled = true
	_desc.fit_content = true
	_desc.custom_minimum_size = Vector2(0, 80)
	_desc.add_theme_font_size_override("normal_font_size", 18)
	vbox.add_child(_desc)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_choices = VBoxContainer.new()
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices.add_theme_constant_override("separation", 8)
	scroll.add_child(_choices)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status)

	_close = Button.new()
	_close.text = "Close"
	_close.pressed.connect(hide_overlay)
	vbox.add_child(_close)


## The Polaroid itself: cream card, square print, handwritten caption.
func _build_card(row: HBoxContainer) -> void:
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.9, 0.87, 0.8)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 12.0
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(4, 8)
	_card.add_theme_stylebox_override("panel", sb)
	_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_card.add_child(vb)

	_photo = TextureRect.new()
	_photo.custom_minimum_size = Vector2(380, 380)
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_photo_mat = ShaderMaterial.new()
	_photo_mat.shader = DEVELOP_SHADER
	_photo.material = _photo_mat
	vb.add_child(_photo)

	_caption = Label.new()
	var hand := SystemFont.new()
	hand.font_names = PackedStringArray(["Ink Free", "Segoe Print", "Bradley Hand", "Comic Neue", "cursive"])
	_caption.add_theme_font_override("font", hand)
	_caption.add_theme_font_size_override("font_size", 26)
	_caption.add_theme_color_override("font_color", INK)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.custom_minimum_size = Vector2(0, 56)
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vb.add_child(_caption)


func _on_examination_requested(seed_id: String) -> void:
	var obj := EvidenceDatabase.get_object(seed_id)
	if obj == null:
		push_warning("[ExaminationUI] unknown object: " + seed_id)
		return
	_current_object = obj
	_last_axis = ""
	_status.text = ""
	_title.text = obj.display_name
	_voice.visible = false
	_desc.text = obj.neutral_description
	_card.visible = obj.base_image != ""
	if not obj.readings.is_empty():
		_open_photo()
	else:
		_populate_interpretations()
	_show_overlay()


# ---------------------------------------------------------------------------
# Photo evidence
# ---------------------------------------------------------------------------

func _current_reading() -> Dictionary:
	var id := str(GameState.paradigm_state.evidence_readings.get(_current_object.object_id, ""))
	return _current_object.get_reading(id)


func _open_photo() -> void:
	var r := _current_reading()
	_photo_mat.set_shader_parameter("progress", 0.0)
	if r.is_empty():
		if _card.visible:
			_photo.texture = load(_current_object.base_image)
			_caption.text = _current_object.base_caption
	else:
		if _card.visible:
			_photo.texture = load(str(r["image"]))
			_caption.text = str(r.get("caption", ""))
		_show_reading_text(r)
	_populate_readings()


func _show_reading_text(r: Dictionary) -> void:
	var voice := str(r.get("voice", ""))
	_voice.visible = voice != ""
	_voice.text = voice
	_voice.add_theme_color_override("font_color", Dialogue.VOICE_COLORS.get(voice, Color.WHITE))
	_desc.text = str(r.get("text", ""))


func _populate_readings() -> void:
	for c in _choices.get_children():
		c.queue_free()
	var oid := _current_object.object_id
	var current := _current_reading()

	if GameState.paradigm_state.locked_evidence.has(oid):
		_choices.add_child(_note("You've decided what this is. It's stopped arguing with you."))
		return

	_choices.add_child(_note("What does it show?" if current.is_empty() else "Look again?"))
	for r in _current_object.available_readings(GameState.profile):
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(0, 40)
		var is_current := str(r["id"]) == str(current.get("id", ""))
		btn.text = ("✓  " if is_current else "▸  ") + str(r["label"])
		btn.disabled = is_current or _developing
		btn.pressed.connect(_on_reading_pressed.bind(str(r["id"])))
		_choices.add_child(btn)

	if not current.is_empty():
		var burn := Button.new()
		burn.text = "🔥 That's what it is. Burn it in (locks it, costs conviction)"
		burn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		burn.disabled = _developing
		burn.pressed.connect(_on_burn_reading_pressed)
		_choices.add_child(burn)


func _on_reading_pressed(reading_id: String) -> void:
	if _developing:
		return
	var r := _current_object.get_reading(reading_id)
	var result := GameState.interpret_reading(_current_object.object_id, reading_id)
	if result.is_empty():
		return
	if not _card.visible or str(r.get("image", "")) == "":
		# Text-only evidence: no print to re-develop.
		_show_reading_text(r)
		_status.text = _conviction_text(result)
		_populate_readings()
		return
	_developing = true
	_close.disabled = true
	_populate_readings()
	_status.text = ""
	_voice.visible = false
	_desc.text = "[i]The print clouds over, milky, the way it did the first time. Then something starts to come up through it.[/i]"

	var next: Texture2D = load(str(r["image"]))
	_photo_mat.set_shader_parameter("next_image", next)
	_photo_mat.set_shader_parameter("progress", 0.0)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_caption, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_method(func(v: float): _photo_mat.set_shader_parameter("progress", v),
			0.0, 1.0, DEVELOP_TIME).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_photo.texture = next
		_photo_mat.set_shader_parameter("progress", 0.0)
		_caption.text = str(r.get("caption", "")))
	tw.tween_property(_caption, "modulate:a", 1.0, 0.6)
	await tw.finished

	_developing = false
	_close.disabled = false
	_show_reading_text(r)
	_status.text = _conviction_text(result)
	_populate_readings()


func _on_burn_reading_pressed() -> void:
	var r := _current_reading()
	if r.is_empty():
		return
	var result := GameState.commit_evidence(_current_object.object_id, str(r.get("axis", "")))
	var delta := float(result.get("conviction_delta", 0.0))
	_status.text = "Burned. Conviction %.0f%%  (now %.0f%%). The journal stirs." % [
		delta, GameState.get_conviction()]
	_populate_readings()


func _note(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _conviction_text(result: Dictionary) -> String:
	var delta := float(result.get("conviction_delta", 0.0))
	var t := "Conviction %s%.0f%%  (now %.0f%%)" % ["+" if delta >= 0 else "", delta, GameState.get_conviction()]
	if bool(result.get("contradiction", false)):
		t += "  ⚠ contradicts a locked answer"
	if str(result.get("lead_unlocked", "")) != "":
		t += "  • new lead"
	return t


# ---------------------------------------------------------------------------
# Theory evidence
# ---------------------------------------------------------------------------

func _populate_interpretations() -> void:
	for c in _choices.get_children():
		c.queue_free()

	var active: Array = GameState.paradigm_state.active_theories
	if active.is_empty():
		_choices.add_child(_note("(No active theories. Activate a theory to interpret this.)"))
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
	_status.text = "Interpreted. " + _conviction_text(result)
	_show_post_interpret()


func _show_post_interpret() -> void:
	for c in _choices.get_children():
		c.queue_free()

	_choices.add_child(_note("Soft-filled the case under '%s'. Burn it to lock these answers permanently?" % _last_axis))

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
	_choices.add_child(_note("These answers are now locked. Past entries have been rewritten."))


func _show_overlay() -> void:
	_root.visible = true
	get_tree().paused = true


func hide_overlay() -> void:
	if _developing:
		return
	_root.visible = false
	get_tree().paused = false
	SignalBus.examination_closed.emit()
