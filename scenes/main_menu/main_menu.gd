extends Control

@onready var game_buttons = $GameButtons
@onready var main_menu_buttons = $main_menu_buttons
@onready var Settings_scene = preload("res://scenes/main_menu/Settings.tscn")
@onready var Game_scene = preload("res://scenes/wires_game/WiresGame.tscn")
var animation

var tweens := {}

func _ready() -> void:
	for child in game_buttons.get_children():
		if child is Button:
			child.pivot_offset = child.size / 2
			child.mouse_entered.connect(_on_button_mouse_entered.bind(child))
			child.mouse_exited.connect(_on_button_mouse_exited.bind(child))
			child.scale = Vector2(1.0, 1.0)
			
	for child in main_menu_buttons.get_children():
		if child is Button:
			child.pivot_offset = child.size / 2
			child.mouse_entered.connect(_on_button_mouse_entered.bind(child))
			child.mouse_exited.connect(_on_button_mouse_exited.bind(child))
			child.scale = Vector2(1.0, 1.0)


func _process(delta: float) -> void:
	pass
	
func _on_button_mouse_entered(button: Button):
	
	if tweens.has(button) and tweens[button].is_valid():
		tweens[button].kill()
	
	animation = get_tree().create_tween().set_loops()
	
	tweens[button] = animation
	
	animation.parallel().tween_property(button, "scale", Vector2(0.9, 0.9), 0.7)
	animation.parallel().tween_property(button, "rotation", deg_to_rad(10), 0.7)
	animation.tween_property(button, "rotation", deg_to_rad(-10), 0.7)
	
func _on_button_mouse_exited(button: Button):
	if tweens.has(button) and tweens[button].is_valid():
		tweens[button].kill()
	
	animation = get_tree().create_tween()
	tweens[button] = animation
	animation.tween_property(button, "scale", Vector2(1.0, 1.0), 0.7)
	animation.tween_property(button, "rotation", deg_to_rad(0), 0.7)
	animation.chain()


func _on_new_game_button_pressed() -> void:
	$AudioStreamPlayer2D.play()
	pass
	

func _on_saved_games_button_pressed() -> void:
	$AudioStreamPlayer2D.play()
	pass # Replace with function body.


func _on_exit_button_pressed() -> void:
	$AudioStreamPlayer2D.play()
	get_tree().quit()

func _on_settings_button_pressed() -> void:
	$AudioStreamPlayer2D.play()
	var settings = Settings_scene.instantiate()
	add_child(settings)

func _on_game_library_button_pressed() -> void:
	$AudioStreamPlayer2D.play()
	pass # Replace with function body.
