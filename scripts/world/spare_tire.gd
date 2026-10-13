extends ItemPickup

## The spare tyre for the motel car. It lies somewhere different on the
## highway shoulder each day until you pick it up. The sprite was rendered once
## at `render_spot`; it's shifted to the chosen spot.

@export var spots: PackedVector2Array = PackedVector2Array()
@export var render_spot: Vector2 = Vector2.ZERO
## Top-left of the rendered sprite in backdrop pixels (from highway_sprites.json).
@export var sprite_origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	if GameState.car.get("tire", false) or GameState.has_item(item_id) or spots.is_empty():
		queue_free()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.day_number * 7919 + 13
	var spot: Vector2 = spots[rng.randi() % spots.size()]
	ground_pos = spot
	position = Iso.to_screen(spot, 0.15)
	var sprite := get_node_or_null("Sprite") as Sprite2D
	if sprite != null:
		# Lie on the ground under the player, not above like the hover highlight.
		sprite.z_as_relative = false
		sprite.z_index = -8
		sprite.position = sprite_origin + Iso.to_screen(spot) - Iso.to_screen(render_spot) - position
	super()
