extends Node2D

## The Sundowner's neon sign. Its art is a pre-rendered sprite (child "Sprite").
## Conviction drives how it behaves: low = sputtering and dim, medium = a
## slight hum, high = steady and bright. The dominant active theory tints it.
## Per-theory sign variants (different lettering) can be dropped into
## `variant_textures` keyed by theory id; the sign swaps to them automatically.

const FLICKER_STEP := 0.11

@export var variant_textures: Dictionary = {}   # theory_id -> Texture2D

var _sprite: Sprite2D
var _default_texture: Texture2D
var _timer: Timer
var _tint: Color = Color.WHITE


func _ready() -> void:
	_sprite = $Sprite
	_default_texture = _sprite.texture
	_timer = Timer.new()
	_timer.wait_time = FLICKER_STEP
	_timer.timeout.connect(_on_flicker)
	add_child(_timer)
	SignalBus.active_theories_changed.connect(func(_ids: Array): _refresh())
	SignalBus.conviction_changed.connect(func(_v: float): _refresh())
	_refresh()


func _refresh() -> void:
	var theories: Array = GameState.paradigm_state.active_theories
	_tint = Color.WHITE
	_sprite.texture = _default_texture
	if not theories.is_empty():
		var id: String = theories[0]
		var def := TheoryDatabase.get_definition(id)
		if def != null and def.motel_name != "":
			_tint = Color.WHITE.lerp(def.motel_color, 0.3)
		if variant_textures.has(id):
			_sprite.texture = variant_textures[id]
	if GameState.get_conviction_band() == "low":
		if _timer.is_stopped():
			_timer.start()
	else:
		_timer.stop()
		var v := 0.92 if GameState.get_conviction_band() == "medium" else 1.0
		_sprite.modulate = Color(v, v, v) * _tint


func _on_flicker() -> void:
	# Low conviction: the neon sputters.
	var levels := [1.0, 1.0, 0.8, 0.55, 0.3, 1.0, 0.9]
	var v: float = levels[randi() % levels.size()]
	_sprite.modulate = Color(v, v, v) * _tint
