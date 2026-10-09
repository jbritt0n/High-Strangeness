extends CanvasLayer

## Day counter and energy bar, top right.

var _day: Label
var _bar: ProgressBar
var _label: Label


func _ready() -> void:
	layer = 5
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -250.0
	box.offset_right = -18.0
	box.offset_top = 14.0
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	_day = Label.new()
	_day.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_day.add_theme_font_size_override("font_size", 18)
	_day.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	box.add_child(_day)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 12)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.04, 0.06, 0.85)
	bg.set_border_width_all(1)
	bg.border_color = Color(1, 1, 1, 0.25)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.93, 0.62, 0.42)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fg)
	box.add_child(_bar)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 12)
	_label.modulate = Color(1, 1, 1, 0.6)
	box.add_child(_label)

	SignalBus.energy_changed.connect(_on_energy)
	SignalBus.day_started.connect(func(_d: int): _refresh_day())
	_refresh_day()
	_on_energy(GameState.energy, GameState.max_energy)


func _refresh_day() -> void:
	_day.text = "DAY %d" % GameState.day_number


func _on_energy(value: float, max_value: float) -> void:
	_bar.max_value = max_value
	_bar.value = value
	_label.text = "ENERGY %d / %d" % [int(round(value)), int(round(max_value))]
	(_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = \
			Color(0.86, 0.36, 0.3) if value / max_value < 0.2 else Color(0.93, 0.62, 0.42)
