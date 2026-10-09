extends CharacterBody2D

## Investigator. Click anywhere to walk (A* over the scene's walk grid), click
## evidence/doors/props to walk up to them and interact. WASD / arrows also work.
## Position is in backdrop pixels (feet); movement is done in world metres via Iso.
## If a scene has no "world_nav" node the player falls back to free screen-space
## movement (used by the older blockout scenes).
##
## Visuals: the rendered character (see CharacterArt) when its sprite sheets
## exist, otherwise the flat silhouette under "Body".

@export var speed_mps: float = 2.8
@export var fallback_speed: float = 220.0
## How close (metres) the player must stand to interact, unless the target says otherwise.
@export var interact_distance: float = 2.3
## Walk-cycle frames per second.
@export var walk_fps: float = 11.0
## Silhouette design height is 98 px; a 1.75 m person is ~121 px at exterior scale.
@export var body_scale: float = 1.235

var _path := PackedVector2Array()
var _path_i: int = 0
var _pending: Node = null
var _facing: float = 1.0
var _width: float = 1.0

var _have_sprite: bool = false
var _row: int = 2            # facing south (towards the camera) by default
var _anim_t: float = 0.0
var _moving: bool = false


func _ready() -> void:
	add_to_group("player")
	apply_profile()
	SignalBus.profile_created.connect(apply_profile)


## Show the chosen investigator: their rendered sprite sheet if it exists,
## otherwise the flat silhouette tinted with their colours.
func apply_profile() -> void:
	var def := Characters.get_def(GameState.profile.character_id)
	var ambient := Color.WHITE
	var scene: Node = owner if owner != null else get_tree().current_scene
	if scene != null and scene.get("ambient") != null:
		ambient = scene.get("ambient")
	_have_sprite = CharacterArt.apply($Sprite, def, ambient)
	$Sprite.visible = _have_sprite
	$Body.visible = not _have_sprite
	if not _have_sprite:
		$Body/Coat.color = def["coat"]
		$Body/Head.color = def["skin"]
		$Body/HairLong.visible = false
		$Body/HatBrim.visible = false
		$Body/HatCrown.visible = false
		$Body/Hair.visible = false
	_refresh_body()


func _refresh_body() -> void:
	var s := body_scale * Iso.scale_factor
	$Body.scale = Vector2(_facing * s * _width, s)
	var k := Iso.scale_factor / CharacterArt.RENDER_SCALE
	$Sprite.scale = Vector2(k, k)
	$Shadow.scale = Vector2(Iso.scale_factor * 1.2, Iso.scale_factor * 1.2)


func _nav() -> Node:
	return get_tree().get_first_node_in_group("world_nav")


func _world_pos() -> Vector2:
	return Iso.to_world(global_position)


func _reach_of(it: Node) -> float:
	var d: float = it.interact_distance if "interact_distance" in it else 0.0
	return d if d > 0.0 else interact_distance


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var nav := _nav()
	if nav == null:
		return
	var p := get_global_mouse_position()
	_pending = _interactable_at(p)
	var target: Vector2 = _pending.ground_pos if _pending != null else Iso.to_world(p)
	if _pending != null:
		print("[Player] walking to: ", _pending.name)
		if _world_pos().distance_to(_pending.ground_pos) <= _reach_of(_pending):
			var it := _pending
			_pending = null
			_do_interact(it)
			return
	_path = nav.find_path(_world_pos(), target)
	_path_i = 0


func _interactable_at(p: Vector2) -> Node:
	var best: Node = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.has_method("contains_point") and n.contains_point(p):
			var d := (n as Node2D).global_position.distance_to(p)
			if d < best_d:
				best_d = d
				best = n
	return best


func _do_interact(it: Node) -> void:
	it.interact()


func _physics_process(delta: float) -> void:
	var kb := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var nav := _nav()
	if nav == null:
		velocity = kb * fallback_speed
		move_and_slide()
		_set_motion(velocity != Vector2.ZERO, velocity, delta)
		return

	var w := _world_pos()
	var step := Vector2.ZERO
	if kb != Vector2.ZERO:
		_path = PackedVector2Array()
		_pending = null
		step = Iso.dir_to_world(kb).normalized() * speed_mps * delta
	elif _path_i < _path.size():
		if _pending != null and w.distance_to(_pending.ground_pos) <= _reach_of(_pending):
			_finish_pending()
			_set_motion(false, Vector2.ZERO, delta)
			return
		var to := _path[_path_i] - w
		var max_step := speed_mps * delta
		if to.length() <= max_step:
			step = to
			_path_i += 1
		else:
			step = to.normalized() * max_step
	elif _pending != null:
		_finish_pending()
		_set_motion(false, Vector2.ZERO, delta)
		return

	var moved := false
	var sd := Vector2.ZERO
	if step != Vector2.ZERO:
		var before := w
		if nav.is_walkable(w + step):
			w += step
		elif nav.is_walkable(w + Vector2(step.x, 0.0)):
			w += Vector2(step.x, 0.0)
		elif nav.is_walkable(w + Vector2(0.0, step.y)):
			w += Vector2(0.0, step.y)
		sd = Iso.to_screen(w) - Iso.to_screen(before)
		moved = sd.length() > 0.001
		if absf(sd.x) > 0.01:
			_facing = signf(sd.x)
		global_position = Iso.to_screen(w)
		GameState.spend_energy(before.distance_to(w) * GameState.ENERGY_PER_METRE)
	_set_motion(moved, sd, delta)


## Drives the sprite's direction row and walk-cycle frame.
func _set_motion(moving: bool, screen_dir: Vector2, delta: float) -> void:
	_moving = moving
	if moving:
		_row = CharacterArt.direction_row(screen_dir)
		_anim_t += delta * walk_fps
	else:
		_anim_t = 0.0
	if _have_sprite:
		var col := 0 if not moving else 1 + int(_anim_t) % 6
		$Sprite.frame = _row * CharacterArt.COLS + col
	_refresh_body()


func _finish_pending() -> void:
	var it := _pending
	_pending = null
	_path = PackedVector2Array()
	if it != null and _world_pos().distance_to(it.ground_pos) <= _reach_of(it) * 1.6:
		_do_interact(it)
