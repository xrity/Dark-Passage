extends Sprite2D

@onready var color_circle = $color_circle
@onready var tile_color = get_meta(&"Color")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_tile_color(tile_color)
	pass # Replace with function body.

func set_tile_color(color: Color) -> Color:
	var c := Color(color)
	color_circle.modulate = c
	return c
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
