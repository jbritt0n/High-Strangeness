extends CanvasLayer

## Narration / dialogue UI, Disco Elysium style. Autoload.
##   await Dialogue.say("text", "VOICE")
##   var i: int = await Dialogue.choose("prompt", ["a", "b"], "VOICE")
##   await Dialogue.fade(true, 1.0)      # to black;  fade(false) reveals again
## The game is paused while a box is open, so nothing moves behind it.
##   Dialogue.begin_skippable() / end_skippable() bracket a run of lines the
##   player may skip (Esc or the Skip button); skipped say() calls return at
##   once and fades snap. choose() is never skipped.

signal _advance
signal _picked(index: int)

# Typing speed; set from the Options menu via Settings.
var chars_per_sec: float = 80.0

const VOICE_COLORS := {
	"": Color(0.86, 0.83, 0.77),
	"BODY": Color(0.93, 0.62, 0.42),        # warm
	"PAIN": Color(0.86, 0.36, 0.3),
	"RECALL": Color(0.45, 0.86, 0.93),      # cyan: the outside-in, exogenous voice
	"SUSPICION": Color(0.56, 0.88, 0.5),    # green: the conspiratorial voice
	"GRIEF": Color(0.72, 0.68, 0.64),       # warm gray: the psychogenic voice
}

var _fade_rect: ColorRect
var _root: Control
var _panel: PanelContainer
var _name: Label
var _text: RichTextLabel
var _hint: Label
var _skip_btn: Button
var _choices: VBoxContainer
var _style: StyleBoxFlat

var _open: bool = false
var _typing: bool = false
var _total_chars: int = 0
var _progress: float = 0.0
var _awaiting_choice: bool = false
var _choice_count: int = 0
var _tween: Tween
var _skippable: bool = false
var _skipping: bool = false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 110.0
	_panel.offset_right = -110.0
	_panel.offset_bottom = -34.0
	_panel.offset_top = -190.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.04, 0.035, 0.05, 0.94)
	_style.border_color = VOICE_COLORS[""]
	_style.border_width_top = 3
	_style.border_width_left = 3
	_style.corner_radius_top_left = 4
	_style.corner_radius_top_right = 4
	_style.content_margin_left = 26.0
	_style.content_margin_right = 26.0
	_style.content_margin_top = 16.0
	_style.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override("panel", _style)
	_root.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)

	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 17)
	vb.add_child(_name)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 22)
	_text.add_theme_font_size_override("italics_font_size", 22)
	_text.add_theme_font_size_override("bold_font_size", 22)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_text)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	vb.add_child(_choices)

	var foot := HBoxContainer.new()
	vb.add_child(foot)

	_skip_btn = Button.new()
	_skip_btn.text = "Skip ▸▸  (Esc)"
	_skip_btn.flat = true
	_skip_btn.focus_mode = Control.FOCUS_NONE
	_skip_btn.add_theme_font_size_override("font_size", 13)
	_skip_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_skip_btn.add_theme_color_override("font_hover_color", VOICE_COLORS["BODY"])
	_skip_btn.visible = false
	_skip_btn.pressed.connect(_skip)
	foot.add_child(_skip_btn)

	_hint = Label.new()
	_hint.text = "click  ·  space"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.modulate = Color(1, 1, 1, 0.4)
	foot.add_child(_hint)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func say(text: String, voice: String = "") -> void:
	if _skipping:
		return
	_begin(text, voice)
	_choices.visible = false
	_hint.visible = true
	_skip_btn.visible = _skippable
	await _advance
	_end()


## Lines said until end_skippable() can be skipped as a block.
func begin_skippable() -> void:
	_skippable = true
	_skipping = false


func end_skippable() -> void:
	_skippable = false
	_skipping = false


## Returns the chosen index.
func choose(prompt: String, options: Array, voice: String = "") -> int:
	_begin(prompt, voice)
	_hint.visible = false
	_skip_btn.visible = false
	for c in _choices.get_children():
		c.queue_free()
	_choices.visible = true
	_awaiting_choice = true
	_choice_count = options.size()
	for i in options.size():
		var b := Button.new()
		b.text = "%d.  %s" % [i + 1, options[i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", Color(0.86, 0.83, 0.77))
		b.add_theme_color_override("font_hover_color", VOICE_COLORS["BODY"])
		var idx := i
		b.pressed.connect(func(): _picked.emit(idx))
		_choices.add_child(b)
	var picked: int = await _picked
	_awaiting_choice = false
	for c in _choices.get_children():
		c.queue_free()
	_end()
	return picked


func fade(to_black: bool, duration: float = 1.0) -> void:
	if _tween:
		_tween.kill()
	if _skipping:
		set_black(to_black)
		return
	_tween = create_tween()
	_tween.tween_property(_fade_rect, "color:a", 1.0 if to_black else 0.0, duration)
	await _tween.finished


## Jump straight to black (or clear) without animating.
func set_black(on: bool) -> void:
	if _tween:
		_tween.kill()
	_fade_rect.color.a = 1.0 if on else 0.0


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _begin(text: String, voice: String) -> void:
	if not _open:
		_open = true
		get_tree().paused = true
		_root.visible = true
		_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var col: Color = VOICE_COLORS.get(voice, VOICE_COLORS[""])
	_style.border_color = col
	_name.text = voice
	_name.visible = voice != ""
	_name.add_theme_color_override("font_color", col)
	_text.text = text
	_text.visible_characters = 0
	_total_chars = _text.get_total_character_count()
	_progress = 0.0
	_typing = true


func _end() -> void:
	_open = false
	_root.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false


func _process(delta: float) -> void:
	if not _typing:
		return
	_progress += delta * chars_per_sec
	_text.visible_characters = int(_progress)
	if _progress >= _total_chars:
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1


func _skip() -> void:
	if not _skippable or _awaiting_choice:
		return
	_skipping = true
	_advance.emit()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var pressed := false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _skippable and not _awaiting_choice:
		get_viewport().set_input_as_handled()
		_skip()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _skip_btn.visible and _skip_btn.get_global_rect().has_point(event.position):
			return  # let the Skip button take the click
		pressed = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if _awaiting_choice:
			var n: int = event.keycode - KEY_1
			if n >= 0 and n < _choice_count:
				get_viewport().set_input_as_handled()
				_picked.emit(n)
				return
		elif event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			pressed = true
	if not pressed:
		return
	if _awaiting_choice:
		return  # buttons handle clicks
	get_viewport().set_input_as_handled()
	if _typing:
		_finish_typing()
	else:
		_advance.emit()
