class_name Iso
extends RefCounted

## Isometric ground-plane math for the pre-rendered Blender backdrops.
## World space is metres on the ground (x, y). Screen space is backdrop pixels.
## The camera is orthographic, turned 45 degrees, looking down at `elevation`
## degrees (30 for the exterior, lower for interiors). configure() takes the
## pixel position of world (0,0,0), the px-per-metre multiplier relative to the
## exterior's 80 px/m (interiors are rendered closer, e.g. 3.84), and the
## elevation.

const BASE_ORIGIN := Vector2(1891.7157, 1539.1624)
const BASE_PX_PER_M := 80.0
const DIAG := 0.70710678

static var origin: Vector2 = BASE_ORIGIN
static var scale_factor: float = 1.0
static var elevation_deg: float = 30.0

# Pixels per metre along each world axis, derived from the elevation.
static var ax: Vector2 = Vector2(56.5686, 28.2843)
static var ay: Vector2 = Vector2(56.5686, -28.2843)
static var az: Vector2 = Vector2(0.0, -69.2820)


static func configure(new_origin: Vector2, new_scale: float, elevation: float = 30.0) -> void:
	origin = new_origin
	scale_factor = new_scale
	elevation_deg = elevation
	var s := sin(deg_to_rad(elevation))
	var c := cos(deg_to_rad(elevation))
	ax = Vector2(DIAG * BASE_PX_PER_M, DIAG * BASE_PX_PER_M * s)
	ay = Vector2(DIAG * BASE_PX_PER_M, -DIAG * BASE_PX_PER_M * s)
	az = Vector2(0.0, -BASE_PX_PER_M * c)


static func to_screen(w: Vector2, z: float = 0.0) -> Vector2:
	return origin + (ax * w.x + ay * w.y + az * z) * scale_factor


## Screen pixel -> ground-plane metres (assumes the point is on the ground).
static func to_world(p: Vector2) -> Vector2:
	return dir_to_world(p - origin)


## A screen-space direction (e.g. from WASD) -> world-space direction.
static func dir_to_world(d: Vector2) -> Vector2:
	var v := d / scale_factor
	var det := ax.x * ay.y - ay.x * ax.y
	return Vector2((v.x * ay.y - ay.x * v.y) / det, (ax.x * v.y - v.x * ax.y) / det)
