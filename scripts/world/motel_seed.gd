extends Area2D

## A clickable evidence object in the world. The player script handles the
## click, walks over, then calls interact() which requests examination.

@export var seed_id: String = ""
## Where the object sits on the ground, in world metres (see Iso). The player
## walks to within interact_distance of this point.
@export var ground_pos: Vector2 = Vector2.ZERO
## Click target radius in backdrop pixels.
@export var click_radius: float = 44.0


func _ready() -> void:
	add_to_group("interactable")


func _process(_delta: float) -> void:
	queue_redraw()


func contains_point(p: Vector2) -> bool:
	return global_position.distance_to(p) <= click_radius


func interact() -> void:
	print("[Evidence] examining: ", seed_id)
	GameState.spend_energy(GameState.EXAMINE_ENERGY)
	SignalBus.examination_requested.emit(seed_id)


## A slowly turning broken ring + a breathing glow, so evidence reads as
## interactive against the painted art without a hard outline.
func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	var col := Color(1.0, 0.82, 0.5, 0.35 + 0.4 * pulse)
	for i in 6:
		var a0 := t * 0.9 + i * TAU / 6.0
		draw_arc(Vector2.ZERO, 30.0 + pulse * 3.0, a0, a0 + TAU / 11.0, 8, col, 2.5, true)
	draw_circle(Vector2.ZERO, 10.0 + pulse * 5.0, Color(1.0, 0.85, 0.55, 0.10 + 0.10 * pulse))
