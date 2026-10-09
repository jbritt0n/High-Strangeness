extends CanvasLayer

## Toggle with I (or Tab). Shows the 5 W cards (soft + locked), active theories,
## and the conviction stability meter.

const W_ORDER := ["who", "what", "when", "where", "why"]

var _root: Control
var _w_labels: Dictionary = {} # w_id -> Label
var _theories_label: Label
var _conviction_bar: ProgressBar
var _conviction_label: Label


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("inquiry_ui")
	_build()
	_root.visible = false
	SignalBus.conviction_changed.connect(func(_v): _refresh())
	SignalBus.active_theories_changed.connect(func(_a): _refresh())
	SignalBus.w_answer_updated.connect(func(_w, _a, _l): _refresh())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_I:
		_toggle()


func _toggle() -> void:
	_root.visible = not _root.visible
	if _root.visible:
		_refresh()


## Opens the board (used by the cork board in the motel room).
func open_panel() -> void:
	if not _root.visible:
		_toggle()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.08, 0.94)
	_root.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 40)
	_root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "INQUIRY BOARD  (press I to close)"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	# Conviction meter.
	_conviction_label = Label.new()
	vbox.add_child(_conviction_label)
	_conviction_bar = ProgressBar.new()
	_conviction_bar.min_value = 0
	_conviction_bar.max_value = 100
	_conviction_bar.custom_minimum_size = Vector2(400, 24)
	vbox.add_child(_conviction_bar)

	vbox.add_child(HSeparator.new())

	# 5 W cards.
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	vbox.add_child(grid)
	for w in W_ORDER:
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(150, 0)
		var head := Label.new()
		head.text = w.to_upper()
		head.add_theme_font_size_override("font_size", 18)
		card.add_child(head)
		var ans := Label.new()
		ans.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ans.custom_minimum_size = Vector2(150, 0)
		card.add_child(ans)
		_w_labels[w] = ans
		grid.add_child(card)

	vbox.add_child(HSeparator.new())

	_theories_label = Label.new()
	_theories_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_theories_label)


func _refresh() -> void:
	var ps := GameState.paradigm_state
	_conviction_bar.value = ps.conviction
	_conviction_label.text = "Conviction (stability): %.0f%%  [%s]" % [
		ps.conviction, GameState.get_conviction_band()]

	for w in W_ORDER:
		var locked := str(ps.w_answers_locked.get(w, ""))
		var soft := str(ps.w_answers_soft.get(w, ""))
		var lbl: Label = _w_labels[w]
		if locked != "":
			lbl.text = "🔒 " + locked
			lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		elif soft != "":
			lbl.text = "✎ " + soft
			lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		else:
			lbl.text = "—"
			lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	var names: Array[String] = []
	for tid in ps.active_theories:
		var def := TheoryDatabase.get_definition(tid)
		names.append(def.display_name if def else tid)
	var axes := ps.get_axes_in_use()
	_theories_label.text = "Active theories (%d/4): %s\nAxes in use (%d/2): %s" % [
		names.size(), ", ".join(names) if names.size() > 0 else "none",
		axes.size(), ", ".join(axes) if axes.size() > 0 else "none"]
