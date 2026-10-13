extends Control

## Title / splash screen: photo backdrop, the typewritten title, and the
## New Game / Load Game / Options menu. Built in code like the other UI.

const BACKGROUND := "res://assets/art/ui/title_bg.webp"
const TEXT_SHADER := preload("res://shaders/typewriter_text.gdshader")
const FILM_POST := preload("res://scripts/world/film_post.gd")
const FIRST_SCENE := "res://scenes/motel_room.tscn"

const TITLE := "HIGH STRANGENESS"
const PAPER := Color(0.93, 0.88, 0.78)
const NEON := Color(1.0, 0.46, 0.26)
const INK_SHADOW := Color(0.18, 0.03, 0.03, 0.85)

var _font: Font
var _letters: Array[Label] = []
var _letter_mats: Array[ShaderMaterial] = []
var _rest: Array = []  # per-letter resting [offset, rotation]
var _menu: VBoxContainer
var _options: Control
var _glitch_timer: float = 2.5
var _busy: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = _make_font()
	_build_background()
	_build_title()
	_build_menu()
	_build_options()
	add_child(FILM_POST.new())

	Dialogue.set_black(true)
	Dialogue.fade(false, 1.8)
	(_menu.get_child(0) as Button).grab_focus.call_deferred()


func _make_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Courier New", "Courier Prime", "Courier", "Nimbus Mono PS", "monospace"])
	f.font_weight = 700
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load(BACKGROUND)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Slow push-in, like a held film shot.
	bg.resized.connect(func(): bg.pivot_offset = bg.size * Vector2(0.56, 0.55))
	var tw := bg.create_tween().set_loops()
	tw.tween_property(bg, "scale", Vector2(1.06, 1.06), 28.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bg, "scale", Vector2(1.0, 1.0), 28.0).set_trans(Tween.TRANS_SINE)

	# Darken the left so the menu reads over the sky.
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.62))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_bottom = 1.0
	shade.anchor_right = 0.45
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _build_title() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	row.offset_top = 46.0
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1947
	for i in TITLE.length():
		var ch := TITLE[i]
		var cell := Control.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cell)
		if ch == " ":
			cell.custom_minimum_size = Vector2(34, 96)
			continue
		var l := Label.new()
		l.text = ch
		l.add_theme_font_override("font", _font)
		l.add_theme_font_size_override("font_size", 84)
		l.add_theme_color_override("font_color", PAPER)
		l.add_theme_color_override("font_shadow_color", INK_SHADOW)
		l.add_theme_constant_override("shadow_offset_x", 5)
		l.add_theme_constant_override("shadow_offset_y", 6)
		l.add_theme_constant_override("shadow_outline_size", 7)
		var m := ShaderMaterial.new()
		m.shader = TEXT_SHADER
		m.set_shader_parameter("seed", float(i) * 1.37)
		m.set_shader_parameter("ink_wear", rng.randf_range(0.3, 0.6))
		l.material = m
		cell.add_child(l)
		cell.custom_minimum_size = l.get_minimum_size()
		l.pivot_offset = cell.custom_minimum_size * 0.5
		# Each key strikes a little off: uneven baseline and a slight tilt.
		var rest := [Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-5.0, 5.0)),
				deg_to_rad(rng.randf_range(-3.0, 3.0))]
		l.position = rest[0]
		l.rotation = rest[1]
		_letters.append(l)
		_letter_mats.append(m)
		_rest.append(rest)

	# A thin typed rule under the title, like a case-file header.
	var rule := Label.new()
	rule.text = "— — — — — — — — — — — — — — — — — — — — — —"
	rule.add_theme_font_override("font", _font)
	rule.add_theme_font_size_override("font_size", 16)
	# Keep text alpha opaque: the shader treats translucent text as a shadow pass.
	rule.add_theme_color_override("font_color", PAPER.darkened(0.45))
	rule.set_anchors_preset(Control.PRESET_CENTER_TOP)
	rule.offset_top = 150.0
	rule.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rm := ShaderMaterial.new()
	rm.shader = TEXT_SHADER
	rm.set_shader_parameter("seed", 99.0)
	rule.material = rm
	add_child(rule)


func _build_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.anchor_top = 0.5
	_menu.anchor_bottom = 0.5
	_menu.offset_left = 92.0
	_menu.offset_top = 0.0
	_menu.add_theme_constant_override("separation", 10)
	add_child(_menu)

	_menu.add_child(_menu_button("New Game", _new_game))
	var load_btn := _menu_button("Load Game", _load_game)
	if not ResourceLoader.exists(GameState.SAVE_PATH):
		load_btn.disabled = true
		load_btn.tooltip_text = "No saved game yet."
	_menu.add_child(load_btn)
	_menu.add_child(_menu_button("Options", _open_options))
	_menu.add_child(_menu_button("Quit", func(): get_tree().quit()))


func _menu_button(text: String, cb: Callable, size: int = 30) -> Button:
	var b := Button.new()
	b.text = "  " + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", NEON)
	b.add_theme_color_override("font_focus_color", NEON)
	b.add_theme_color_override("font_pressed_color", NEON)
	b.add_theme_color_override("font_hover_pressed_color", NEON)
	b.add_theme_color_override("font_disabled_color", PAPER.darkened(0.65))
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(s, empty)
	var m := ShaderMaterial.new()
	m.shader = TEXT_SHADER
	m.set_shader_parameter("seed", float(text.hash() % 97))
	m.set_shader_parameter("ink_wear", 0.25)
	m.set_shader_parameter("aberration_px", 0.6)
	m.set_shader_parameter("flicker", 0.1)
	b.material = m
	# The typewriter "carriage" marker on the selected line.
	var mark := func(on: bool):
		b.text = ("▸ " if on else "  ") + text
	b.mouse_entered.connect(func():
		if not b.disabled:
			b.grab_focus())
	b.focus_entered.connect(mark.bind(true))
	b.focus_exited.connect(mark.bind(false))
	b.pressed.connect(cb)
	return b


func _build_options() -> void:
	_options = Control.new()
	_options.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options.visible = false
	add_child(_options)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options.add_child(dim)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.035, 0.05, 0.94)
	sb.border_color = NEON
	sb.border_width_top = 3
	sb.border_width_left = 3
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.content_margin_left = 34.0
	sb.content_margin_right = 34.0
	sb.content_margin_top = 24.0
	sb.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(560, 0)
	_options.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)

	var head := _label("OPTIONS", 34)
	head.add_theme_color_override("font_color", NEON)
	vb.add_child(head)

	var mode := OptionButton.new()
	for m in Settings.DISPLAY_MODES:
		mode.add_item(m)
	mode.selected = Settings.display_mode
	mode.add_theme_font_override("font", _font)
	mode.add_theme_font_size_override("font_size", 20)
	mode.item_selected.connect(func(i: int):
		Settings.display_mode = i
		Settings.apply()
		Settings.save())
	vb.add_child(_row("Display", mode))

	var vol := _slider(0.0, 1.0, 0.05, Settings.master_volume)
	vol.value_changed.connect(func(v: float):
		Settings.master_volume = v
		Settings.apply())
	vol.drag_ended.connect(func(_c: bool): Settings.save())
	vb.add_child(_row("Volume", vol))

	var spd := _slider(30.0, 200.0, 10.0, Settings.text_speed)
	spd.value_changed.connect(func(v: float):
		Settings.text_speed = v
		Settings.apply())
	spd.drag_ended.connect(func(_c: bool): Settings.save())
	vb.add_child(_row("Text speed", spd))

	var back := _menu_button("Back", _close_options, 24)
	vb.add_child(back)


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", PAPER)
	return l


func _row(text: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	var l := _label(text, 22)
	l.custom_minimum_size = Vector2(170, 0)
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(control)
	return h


func _slider(lo: float, hi: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(240, 24)
	return s


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _new_game() -> void:
	if _busy:
		return
	_busy = true
	await Dialogue.fade(true, 1.2)
	get_tree().change_scene_to_file(FIRST_SCENE)


func _load_game() -> void:
	if _busy:
		return
	_busy = true
	GameState.load_game()
	await Dialogue.fade(true, 1.2)
	get_tree().change_scene_to_file(FIRST_SCENE)


func _open_options() -> void:
	_options.visible = true
	_menu.visible = false
	var back := _options.find_children("*", "Button", true, false)
	if not back.is_empty():
		(back[-1] as Button).grab_focus()


func _close_options() -> void:
	_options.visible = false
	_menu.visible = true
	(_menu.get_child(2) as Button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _options.visible and event.is_action_pressed("ui_cancel"):
		_close_options()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Title animation: letters settle, flicker and occasionally twitch.
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_glitch_timer -= delta
	if _glitch_timer <= 0.0:
		_glitch_timer = randf_range(2.5, 6.0)
		_twitch()


func _twitch() -> void:
	var n := randi_range(1, 3)
	for k in n:
		var i := randi() % _letters.size()
		var l := _letters[i]
		var m := _letter_mats[i]
		var rest: Array = _rest[i]
		var tw := create_tween()
		tw.tween_callback(func():
			l.position = rest[0] + Vector2(randf_range(-7, 7), randf_range(-4, 4))
			l.rotation = rest[1] + deg_to_rad(randf_range(-4, 4))
			m.set_shader_parameter("glitch", 1.0))
		tw.tween_interval(randf_range(0.04, 0.11))
		tw.tween_callback(func():
			l.position = rest[0]
			l.rotation = rest[1]
			m.set_shader_parameter("glitch", 0.0))
