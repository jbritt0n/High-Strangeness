class_name CharacterArt
extends RefCounted

## Loads a character's pre-rendered sprite sheet (see Characters.sheet).
## Layout: 7 columns (0 = idle, 1-6 = walk cycle) x 8 rows of screen
## directions starting at east and going clockwise (E, SE, S, SW, W, NW, N, NE).
## Frames are 320x576, rendered at 307.2 px/m (the motel-room scale, 3.84).

const COLS := 7
const ROWS := 8
## Feet sit 245 px below the centre of a frame.
const FEET_OFFSET := Vector2(0.0, -245.3)
const RENDER_SCALE := 3.84

static var _cache: Dictionary = {}


static func available(def: Dictionary) -> bool:
	return ResourceLoader.exists(str(def.get("sheet", "")))


## Load a sheet with generated mipmaps so it downsamples cleanly in the
## zoomed-out exterior.
static func texture(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var src: Texture2D = load(path)
	var img: Image = src.get_image()
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[path] = t
	return t


## Point `sprite` at the character's sheet and light it for the scene.
## Returns false if the sheet hasn't been rendered yet.
static func apply(sprite: Sprite2D, def: Dictionary, ambient: Color = Color.WHITE) -> bool:
	if not available(def):
		return false
	sprite.texture = texture(def["sheet"])
	sprite.hframes = COLS
	sprite.vframes = ROWS
	sprite.offset = FEET_OFFSET
	sprite.modulate = ambient
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return true


## Row for a screen-space movement vector (E=0, SE=1, S=2 ... NE=7).
static func direction_row(screen_dir: Vector2) -> int:
	return posmod(roundi(rad_to_deg(screen_dir.angle()) / 45.0), 8)
