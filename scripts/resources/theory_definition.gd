class_name TheoryDefinition
extends Resource

## A single subtheory (one of the 23 UFO narratives). Data-driven via .tres.

@export var theory_id: String = ""
@export var display_name: String = ""
@export var axis: String = "" # one of the 7 axis codes
@export_multiline var voice_description: String = "" # UI flavor

@export var color_tint: Color = Color.WHITE

# Motel sign presentation when this is the dominant active theory.
@export var motel_name: String = ""
@export var motel_font: Font
@export var motel_color: Color = Color.WHITE

# Optional gating flag; "" means always available.
@export var unlock_condition_flag: String = ""
