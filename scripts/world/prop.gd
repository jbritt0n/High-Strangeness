class_name Prop
extends Area2D

## Something in the world you can click: walk up to it, then it speaks.
## Position is the click target centre in backdrop pixels; ground_pos is where
## the player should stand (world metres, see Iso). Hovering shows an outline
## and label so painted art is readable as interactive.

@export var prop_id: String = ""
@export var hover_label: String = ""
@export var ground_pos: Vector2 = Vector2.ZERO
## Half the click rectangle, in backdrop pixels, centred on this node.
@export var click_half_size: Vector2 = Vector2(50, 50)
## How close (metres) the player must get. 0 = use the player's default.
@export var interact_distance: float = 0.0
@export var voice: String = ""
@export var lines: PackedStringArray = PackedStringArray()
## "" = just read lines | "sleep" | "mirror" | "desk" | "board" | "cabinet"
@export var action: String = ""

var _hovered: bool = false
var _chip: StyleBoxFlat


func _ready() -> void:
	add_to_group("interactable")
	z_index = 4  # highlights draw above foreground occluders
	_chip = StyleBoxFlat.new()
	_chip.bg_color = Color(0.045, 0.035, 0.05, 0.92)
	_chip.set_corner_radius_all(3)


## Highlight colour. Subclasses override (e.g. locked doors read as muted red).
func _accent() -> Color:
	return Color(0.96, 0.74, 0.46)


func _process(_delta: float) -> void:
	var h := contains_point(get_global_mouse_position())
	if h != _hovered:
		_hovered = h
		queue_redraw()
	elif _hovered:
		queue_redraw()  # keep the pulse animating


func contains_point(p: Vector2) -> bool:
	return Rect2(global_position - click_half_size, click_half_size * 2.0).has_point(p)


func interact() -> void:
	match action:
		"sleep":
			var i: int = await Dialogue.choose("The bed is rumpled in the shape of someone who left in a hurry. Possibly you.", ["Sleep. Let the day end.", "Not yet."], "BODY")
			if i == 0:
				DayCycle.sleep()
		"mirror":
			await _mirror()
		"desk":
			await Dialogue.say("The desk. A typewriter with a sheet already rolled in, a lamp that is never quite off, a drift of your own handwriting.", "")
			_open_ui("journal_ui")
		"board":
			await Dialogue.say("Photographs, scraps, red string. You don't remember hanging any of it. You do recognise the knots.", "")
			_open_ui("inquiry_ui")
		"cabinet":
			await _cabinet()
		_:
			# A line may be "VOICE|text" to be spoken by an inner voice.
			for l in lines:
				var v := voice
				var text := l
				var bar := l.find("|")
				if bar > 0 and bar < 12 and l.substr(0, bar) == l.substr(0, bar).to_upper():
					v = l.substr(0, bar)
					text = l.substr(bar + 1)
				await Dialogue.say(text, v)


func _open_ui(group: String) -> void:
	var ui := get_tree().get_first_node_in_group(group)
	if ui != null and ui.has_method("open_panel"):
		ui.open_panel()


## The filing cabinet: everything you've burned (locked in) as fact.
func _cabinet() -> void:
	var ps := GameState.paradigm_state
	var names: Array[String] = []
	for id in ps.locked_evidence:
		var obj := EvidenceDatabase.get_object(str(id))
		names.append(obj.display_name if obj != null else str(id))
	if names.is_empty():
		await Dialogue.say("Four drawers of empty folders, each labelled in your handwriting with a date that hasn't happened yet.", "")
		await Dialogue.say("Nothing has been filed as fact. Everything you believe is still in pencil.", "RECALL")
	else:
		await Dialogue.say("Four drawers. In the top one, folders marked FACT, in ink: %s." % ", ".join(names), "")
		await Dialogue.say("Burned is burned. You can't take it back. You can only build around it.", "SUSPICION")
	var entries := JournalManager.unlocked.size()
	if entries > 0:
		await Dialogue.say("Your notes run to %d entr%s. The desk has them." % [entries, "y" if entries == 1 else "ies"], "")


func _mirror() -> void:
	var p := GameState.profile
	if not p.created:
		await Dialogue.say("A face. Yours, you assume.", voice)
		return
	var def := Characters.get_def(p.character_id)
	await Dialogue.say(str(def["mirror"]), "")
	await Dialogue.say("The face doesn't argue. It also doesn't help.", "RECALL")


func _draw() -> void:
	if not _hovered:
		return
	var cam := get_viewport().get_camera_2d()
	var k: float = 1.0 / cam.zoom.x if cam != null else 1.0
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 3.5)
	var a := _accent()
	var solid := Color(a.r, a.g, a.b, 0.95)
	var r := Rect2(-click_half_size, click_half_size * 2.0).grow((3.0 + 3.0 * pulse) * k)

	# Soft wash over the object.
	draw_rect(r, Color(a.r, a.g, a.b, 0.05 + 0.05 * pulse))

	# Corner brackets instead of a box.
	var arm := minf(26.0 * k, minf(r.size.x, r.size.y) * 0.28)
	var w := 3.0 * k
	var tl := r.position
	var tr := Vector2(r.end.x, r.position.y)
	var bl := Vector2(r.position.x, r.end.y)
	var br := r.end
	for c in [[tl, 1.0, 1.0], [tr, -1.0, 1.0], [bl, 1.0, -1.0], [br, -1.0, -1.0]]:
		var o: Vector2 = c[0]
		var sx: float = c[1]
		var sy: float = c[2]
		draw_polyline(PackedVector2Array([o + Vector2(arm * sx, 0.0), o, o + Vector2(0.0, arm * sy)]), solid, w, true)
		draw_circle(o, w * 0.9, solid)

	# Label chip with an accent bar, floating above the top edge.
	if hover_label != "":
		var font := ThemeDB.fallback_font
		var fs := int(19.0 * k)
		var sz := font.get_string_size(hover_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pad := Vector2(16.0, 9.0) * k
		var box := Rect2(Vector2(-sz.x * 0.5 - pad.x, r.position.y - sz.y - pad.y * 2.0 - 12.0 * k),
				sz + pad * 2.0)
		_chip.border_color = solid
		_chip.set_border_width_all(0)
		_chip.border_width_left = int(4.0 * k)
		draw_style_box(_chip, box)
		draw_string(font, Vector2(box.position.x + pad.x + 2.0 * k, box.position.y + pad.y + sz.y * 0.78),
				hover_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.97, 0.93, 0.85))
		# stem from chip to the object
		draw_line(Vector2(0.0, box.end.y), Vector2(0.0, r.position.y), Color(a.r, a.g, a.b, 0.55), 2.0 * k)
