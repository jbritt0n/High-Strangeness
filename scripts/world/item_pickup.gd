class_name ItemPickup
extends Prop

## Something you can pick up and carry (GameState.inventory). Uses its Prop
## lines as the pickup text, then removes itself from the world.

@export var item_id: String = ""


func _ready() -> void:
	super()
	if GameState.has_item(item_id):
		queue_free()


func interact() -> void:
	await super()
	GameState.add_item(item_id)
	queue_free()
