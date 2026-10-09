extends Node2D

## Walkable-area grid for an isometric scene, in world metres.
## A* pathfinding over a coarse grid. Press F3 to show the walkable cells.
## Rects are Rect2(x, y, width, height) in world metres.

const CELL := 0.25
const AGENT_RADIUS := 0.3

## Which hand-authored layout to use: "motel" (exterior lot) or "room".
@export var layout: String = "motel"

# Grid bounds in world metres.
var MIN := Vector2(-21.0, -18.0)
var MAX := Vector2(16.0, 9.0)

# Where the player may walk. Rect2(x, y, width, height).
var walk_rects: Array[Rect2] = []
# Things in the way.
var blocked_rects: Array[Rect2] = []
# Round obstacles. [centre, radius]
var blocked_circles: Array = []

var _grid: AStarGrid2D
var _size: Vector2i
var _debug: bool = false


func _apply_layout() -> void:
	match layout:
		"room":
			MIN = Vector2(-3.5, -3.0)
			MAX = Vector2(3.5, 3.0)
			walk_rects = [Rect2(-2.7, -2.05, 5.4, 4.05)]
			blocked_rects = [
				Rect2(-3.0, -1.75, 2.2, 1.7),     # bed
				Rect2(-3.0, 0.05, 0.65, 0.65),    # nightstand
				Rect2(-1.35, 1.8, 2.1, 0.6),      # dresser + TV
				Rect2(1.9, 1.6, 1.0, 0.6),        # luggage rack + suitcase (right corner)
				Rect2(2.15, -1.1, 0.85, 0.95),    # armchair
				Rect2(-3.0, 0.9, 0.7, 1.4),       # desk
				Rect2(-1.9, 1.75, 0.6, 0.7),      # filing cabinet
			]
			blocked_circles = [[Vector2(1.55, 0.35), 0.62]]  # round table
		_:
			MIN = Vector2(-21.0, -18.0)
			MAX = Vector2(16.0, 9.0)
			# Parking lot (right of the west wing's canopy line) + the driveway.
			walk_rects = [
				Rect2(-9.8, -10.5, 23.3, 17.7),
				Rect2(0.5, -17.5, 7.0, 7.5),
			]
			# Parked car; (the sign and dumpster stand outside the walkable area).
			blocked_rects = [Rect2(-7.7, 2.0, 2.6, 5.7)]
			# Streetlight, burning barrel. [centre, radius]
			blocked_circles = [
				[Vector2(-4.0, -8.5), 0.45],
				[Vector2(-9.4, -5.0), 0.7],
			]


func _ready() -> void:
	_apply_layout()
	add_to_group("world_nav")
	_size = Vector2i(ceili((MAX.x - MIN.x) / CELL), ceili((MAX.y - MIN.y) / CELL))
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(Vector2i.ZERO, _size)
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	for y in _size.y:
		for x in _size.x:
			_grid.set_point_solid(Vector2i(x, y), not _cell_free(Vector2i(x, y)))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_debug = not _debug
		queue_redraw()


func is_walkable(w: Vector2) -> bool:
	var c := _to_cell(w)
	return _in_bounds(c) and not _grid.is_point_solid(c)


## Nearest walkable world point to w (w itself if already walkable).
func nearest_walkable(w: Vector2) -> Vector2:
	var c0 := _to_cell(w)
	if _in_bounds(c0) and not _grid.is_point_solid(c0):
		return w
	for r in range(1, 80):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := c0 + Vector2i(dx, dy)
				if _in_bounds(c) and not _grid.is_point_solid(c):
					var d := Vector2(dx, dy).length()
					if d < best_d:
						best_d = d
						best = c
		if best.x >= 0:
			return _to_world(best)
	return w


## World-space path from a to b (both snapped onto the walkable grid).
func find_path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var ca := _to_cell(nearest_walkable(a))
	var cb := _to_cell(nearest_walkable(b))
	var out := PackedVector2Array()
	for c in _grid.get_id_path(ca, cb):
		out.append(_to_world(c))
	return out


func _cell_free(c: Vector2i) -> bool:
	var p := _to_world(c)
	var inside := false
	for r in walk_rects:
		if r.grow(-AGENT_RADIUS).has_point(p):
			inside = true
			break
	if not inside:
		return false
	for r in blocked_rects:
		if r.grow(AGENT_RADIUS).has_point(p):
			return false
	for o in blocked_circles:
		if p.distance_to(o[0]) < float(o[1]) + AGENT_RADIUS:
			return false
	return true


func _to_cell(w: Vector2) -> Vector2i:
	return Vector2i(floori((w.x - MIN.x) / CELL), floori((w.y - MIN.y) / CELL))


func _to_world(c: Vector2i) -> Vector2:
	return MIN + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < _size.x and c.y < _size.y


func _draw() -> void:
	if not _debug:
		return
	for y in _size.y:
		for x in _size.x:
			var c := Vector2i(x, y)
			if _grid.is_point_solid(c):
				continue
			var w := _to_world(c)
			var h := CELL * 0.5
			draw_colored_polygon(PackedVector2Array([
				Iso.to_screen(w + Vector2(-h, -h)), Iso.to_screen(w + Vector2(h, -h)),
				Iso.to_screen(w + Vector2(h, h)), Iso.to_screen(w + Vector2(-h, h))]),
				Color(0.2, 1.0, 0.4, 0.22))
