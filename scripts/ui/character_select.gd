extends CanvasLayer

## "Who are you?" Pick one of the investigators in Characters.
##   var id: String = await select.run()
## Shows the concept portrait on the left and their background on the right.
## Locked / not-yet-designed slots appear as empty silhouettes.

signal _chosen(id: String)

const SLOTS := 3   # how many cards to show (unfilled ones are placeholders)

var _built: bool = false
var _index: int = 0
var _portrait: TextureRect
var _name: Label
var _role: Label
var _blurb: Label
var _traits: Label
var _confirm: Button
var _cards: Array[Button] = []


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


## Returns the chosen character id.
func run() -> String:
	if not _built:
		_build()
	_index = 0
	_show(0)
	visible = true
	get_tree().paused = true
	var id: String = await _chosen
	visible = false
	get_tree().paused = false
	return id


func _build() -> void:
	_built = true
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.03, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 36)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)

	var title := Label.new()
	title.text = "WHO ARE YOU?"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.93, 0.62, 0.42))
	outer.add_child(title)
	var sub := Label.new()
	sub.text = "The head says one thing. The key tag, the jacket and the hands say another. Whoever you decide you are will decide a great deal else."
	sub.add_theme_font_size_override("font_size", 15)
	sub.modulate = Color(1, 1, 1, 0.65)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(sub)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 34)
	outer.add_child(row)

	# Portrait
	var frame := PanelContainer.new()
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.1, 0.1, 0.11, 1)
	fs.set_border_width_all(2)
	fs.border_color = Color(0.93, 0.62, 0.42, 0.8)
	fs.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", fs)
	frame.custom_minimum_size = Vector2(330, 0)
	row.add_child(frame)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(_portrait)

	# Details
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 34)
	info.add_child(_name)
	_role = Label.new()
	_role.add_theme_font_size_override("font_size", 19)
	_role.add_theme_color_override("font_color", Color(0.93, 0.62, 0.42))
	info.add_child(_role)
	info.add_child(HSeparator.new())
	_blurb = Label.new()
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.add_theme_font_size_override("font_size", 19)
	info.add_child(_blurb)
	_traits = Label.new()
	_traits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_traits.add_theme_font_size_override("font_size", 17)
	_traits.modulate = Color(0.85, 0.9, 1.0, 0.9)
	info.add_child(_traits)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(spacer)

	# Cards
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	info.add_child(cards)
	for i in SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 56)
		b.add_theme_font_size_override("font_size", 16)
		b.focus_mode = Control.FOCUS_NONE
		if i < Characters.ROSTER.size():
			b.text = Characters.ROSTER[i]["name"]
			b.pressed.connect(func(): _show(i))
		else:
			b.text = "???"
			b.disabled = true
		cards.add_child(b)
		_cards.append(b)

	_confirm = Button.new()
	_confirm.add_theme_font_size_override("font_size", 21)
	_confirm.custom_minimum_size = Vector2(0, 52)
	_confirm.text = "This is who I am."
	_confirm.pressed.connect(func(): _chosen.emit(str(Characters.ROSTER[_index]["id"])))
	info.add_child(_confirm)


func _show(i: int) -> void:
	_index = i
	var d: Dictionary = Characters.ROSTER[i]
	_portrait.texture = load(d["portrait"]) if ResourceLoader.exists(d["portrait"]) else null
	_name.text = d["name"]
	_role.text = "%s  ·  %s" % [d["role"], d["age"]]
	_blurb.text = d["blurb"]
	var lines: Array[String] = []
	for t in d["traits"]:
		lines.append("•  " + str(t))
	_traits.text = "\n".join(lines)
	for k in _cards.size():
		_cards[k].modulate = Color(1, 1, 1, 1) if k == i else Color(1, 1, 1, 0.55)
