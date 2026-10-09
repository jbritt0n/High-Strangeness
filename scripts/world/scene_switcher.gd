extends Node2D

## Attached to the root of every gameplay scene. Handles scene changes and
## positions the player at the requested spawn point on load. Also tells Iso
## how this scene's art is projected.

@export var iso_origin: Vector2 = Vector2(1891.7157, 1539.1624)
@export var iso_scale: float = 1.0
## Camera elevation of this scene's art, in degrees (30 exterior, 25 motel room).
@export var iso_elevation: float = 30.0
## Lighting multiplier applied to the rendered character so it sits in the scene.
@export var ambient: Color = Color(1, 1, 1)


func _enter_tree() -> void:
	Iso.configure(iso_origin, iso_scale, iso_elevation)


func _ready() -> void:
	SignalBus.scene_change_requested.connect(_on_scene_change_requested)
	# Defer so the whole scene (player + spawn markers) exists first.
	_place_player.call_deferred()


func _place_player() -> void:
	var sp := GameState.pending_spawn_point
	if sp == "":
		return
	var marker := find_child(sp, true, false)
	var players := get_tree().get_nodes_in_group("player")
	if marker is Node2D and not players.is_empty():
		(players[0] as Node2D).global_position = (marker as Node2D).global_position
	GameState.pending_spawn_point = ""


func _on_scene_change_requested(scene_path: String, spawn_point: String) -> void:
	GameState.pending_spawn_point = spawn_point
	get_tree().change_scene_to_file.call_deferred(scene_path)
