extends CanvasLayer

## Full-screen film look. Low conviction = grainy, flickery, drained;
## high conviction = clean, sharp. Add this node to any world scene.

const SHADER := preload("res://shaders/film_post.gdshader")

# band -> shader params
const BANDS := {
	"low": {"grain": 0.24, "color_noise": 0.07, "aberration": 0.005,
			"flicker": 0.08, "saturation": 0.78, "vignette": 0.6},
	"medium": {"grain": 0.1, "color_noise": 0.015, "aberration": 0.0018,
			"flicker": 0.0, "saturation": 0.9, "vignette": 0.45},
	"high": {"grain": 0.035, "color_noise": 0.0, "aberration": 0.0006,
			"flicker": 0.0, "saturation": 1.05, "vignette": 0.3},
}

var _mat: ShaderMaterial
var _tween: Tween


func _ready() -> void:
	layer = 100
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	rect.material = _mat
	add_child(rect)

	SignalBus.conviction_changed.connect(_on_conviction_changed)
	_apply(GameState.get_conviction_band(), true)


func _on_conviction_changed(_value: float) -> void:
	_apply(GameState.get_conviction_band(), false)


func _apply(band: String, instant: bool) -> void:
	var target: Dictionary = BANDS[band]
	if _tween:
		_tween.kill()
	if instant:
		for k in target:
			_mat.set_shader_parameter(k, target[k])
		return
	_tween = create_tween().set_parallel(true)
	for k in target:
		var from: float = _mat.get_shader_parameter(k)
		_tween.tween_method(func(v: float): _mat.set_shader_parameter(k, v),
				from, float(target[k]), 0.8)
