extends CanvasLayer

## Toggle with J. Lists unlocked entries; rendering changes with the worldview,
## flagging diffs the player can acknowledge.

var _root: Control
var _list: VBoxContainer
var _content: RichTextLabel
var _diff_box: VBoxContainer
var _selected_id: String = ""


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("journal_ui")
	_build()
	_root.visible = false
	SignalBus.journal_entry_unlocked.connect(func(_id): _refresh_list())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_J:
		_toggle()


func _toggle() -> void:
	_root.visible = not _root.visible
	if _root.visible:
		_refresh_list()


## Opens the journal (used by the desk in the motel room).
func open_panel() -> void:
	if not _root.visible:
		_toggle()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.04, 0.07, 0.92)
	_root.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 40)
	_root.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	margin.add_child(hbox)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(260, 0)
	hbox.add_child(left)
	var lt := Label.new()
	lt.text = "JOURNAL  (press J to close)"
	lt.add_theme_font_size_override("font_size", 20)
	left.add_child(lt)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	left.add_child(_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(right)
	_content = RichTextLabel.new()
	_content.bbcode_enabled = true
	_content.fit_content = true
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_content)
	_diff_box = VBoxContainer.new()
	right.add_child(_diff_box)


func _refresh_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	if JournalManager.unlocked.is_empty():
		var none := Label.new()
		none.text = "(empty)"
		_list.add_child(none)
		return
	for entry_id in JournalManager.unlocked:
		var entry := JournalManager.get_entry(entry_id)
		var btn := Button.new()
		btn.text = entry.title if entry else entry_id
		if JournalManager.has_pending_diff(entry_id):
			btn.text += "  ⚠"
		btn.pressed.connect(_select.bind(entry_id))
		_list.add_child(btn)


func _select(entry_id: String) -> void:
	_selected_id = entry_id
	var data := JournalManager.read_entry(entry_id)
	for c in _diff_box.get_children():
		c.queue_free()
	if data.is_empty():
		return
	_content.text = "[b]%s[/b]\n\n%s" % [str(data.get("title", "")), str(data.get("text", ""))]
	if bool(data.get("changed", false)):
		var warn := Label.new()
		warn.text = "⚠ This entry has changed."
		warn.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
		_diff_box.add_child(warn)
		var prev := RichTextLabel.new()
		prev.bbcode_enabled = true
		prev.fit_content = true
		prev.text = "[i][color=#888]Previously:[/color][/i]\n[s][color=#888]%s[/color][/s]" % str(data.get("previous", ""))
		_diff_box.add_child(prev)
		var ack := Button.new()
		ack.text = "Acknowledge change"
		ack.pressed.connect(_acknowledge.bind(entry_id))
		_diff_box.add_child(ack)
	_refresh_list()


func _acknowledge(entry_id: String) -> void:
	JournalManager.acknowledge_diff(entry_id)
	_select(entry_id)
