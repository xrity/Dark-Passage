extends Control
@export var audio_bus_name: String
var audio_bus_id

signal difficulty_changed(new_value)

var difficulty := 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_value_changed(value: float) -> void:
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(audio_bus_id, db)


func _on_difficulty_button_item_selected(index: int) -> void:
	difficulty = index
	load("res://scenes/wires_game/WiresGame.tscn").set_meta("Difficulty", difficulty)
