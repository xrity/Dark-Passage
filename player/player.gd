extends CharacterBody2D

@export var move_speed = 500
@onready var sprite = $Sprite2D
@onready var animations = $AnimationPlayer
@onready var camera = $Camera2D
var player_rotation = "down"

func handle_input():
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed
	
func direction_player():
	player_rotation = 'down'
	if velocity.y < 0: 
		player_rotation = 'up'
	if velocity.x < 0: 
		sprite.scale.x = -1
	if velocity.x > 0:
		sprite.scale.x = 1
	return player_rotation
	
func updateAnimation():
	if velocity.length() == 0:
		animations.play('idle_' + player_rotation)
	else:
		animations.play('walk_' + direction_player())
		
func _process(_delta):
	handle_input()
	move_and_slide()
	updateAnimation()
