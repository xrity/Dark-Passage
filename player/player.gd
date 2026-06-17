extends CharacterBody2D
## ============================================================
##  Player
##  Движение перенесено в _physics_process (правильно для move_and_slide).
##  Направление взгляда (up/down) хранится между кадрами,
##  горизонталь только отражает спрайт.
## ============================================================

@export var move_speed: float = 500.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _camera: Camera2D = $Camera2D

var _facing: String = "down"


func _physics_process(_delta: float) -> void:
	# Если идёт диалог — игрок стоит (на случай, если время не на паузе).
	if DialogueBox.is_active():
		velocity = Vector2.ZERO
	else:
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = dir * move_speed

	move_and_slide()
	_update_facing()
	_update_animation()


func _update_facing() -> void:
	if velocity.y < 0.0:
		_facing = "up"
	elif velocity.y > 0.0:
		_facing = "down"

	if velocity.x < 0.0:
		_sprite.scale.x = -absf(_sprite.scale.x)
	elif velocity.x > 0.0:
		_sprite.scale.x = absf(_sprite.scale.x)


func _update_animation() -> void:
	if velocity.is_zero_approx():
		_anim.play("idle_" + _facing)
	else:
		_anim.play("walk_" + _facing)
