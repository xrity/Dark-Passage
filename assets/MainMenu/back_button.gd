extends CenterContainer

@onready var back_button= $BackButton
var animation

var tweens := {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	back_button.mouse_entered.connect(
		func() -> void:
			if tweens.has(back_button) and tweens[back_button].is_valid():
				tweens[back_button].kill()
			
			animation = get_tree().create_tween().set_loops()
			
			tweens[back_button] = animation
			animation.parallel().tween_property(back_button, "scale", Vector2(0.9, 0.9), 0.7)
			animation.parallel().tween_property(back_button, "rotation", deg_to_rad(5), 0.7)
			animation.tween_property(back_button, "rotation", deg_to_rad(-5), 0.7))
			
	back_button.mouse_exited.connect(
		func() -> void:
			if tweens.has(back_button) and tweens[back_button].is_valid():
				tweens[back_button].kill()
			
			animation = get_tree().create_tween()
			
			tweens[back_button] = animation
			animation.parallel().tween_property(back_button, "scale", Vector2(1.0, 1.0), 0.7)
			animation.parallel().tween_property(back_button, "rotation", deg_to_rad(0), 0.7)
	)

func _on_back_button_pressed() -> void:
	get_parent().queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
