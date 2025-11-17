extends Node2D


@onready var field = $wiresFieldSprite
@onready var tile = $wireTileSprite

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	build_field(1.7)
	pass # Replace with function body.


func build_field(difficulty: float) -> void:
	tile.scale = Vector2(tile.scale.x * difficulty, tile.scale.y * difficulty)

	var tile_W = tile.texture.get_size().x * tile.scale.x
	var tile_H = tile.texture.get_size().y * tile.scale.y

	var tiles = round((field.scale.x / tile_W) * (field.scale.y / tile_H))

	field.add_child(tile.duplicate())


	print(tiles)
	place_tiles()

func place_tiles() -> void:

	var tile_W = tile.texture.get_size().x * tile.scale.x
	var tile_H = tile.texture.get_size().y * tile.scale.y

	var cols = round(field.scale.x / tile_W)
	var rows = round(field.scale.y / tile_H)

	tile.visible = true
	field.add_child(tile.duplicate())
	
	for j in range(rows):
		for i in range(cols):
			var field_pos = field.position
			tile.position = field_pos + Vector2(i * tile_W, j * tile_H)
			tile.visible = true
			field.add_child(tile.duplicate())

	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
