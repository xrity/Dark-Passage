extends Control
## ============================================================
##  MainMenu
##  Чище: const-сцены, безопасные твины наведения, единый звук.
## ============================================================

const SETTINGS_SCENE := preload("res://scenes/main_menu/Settings.tscn")
const GAME_SCENE := preload("res://scenes/wires_game/WiresGame.tscn")

## Сцена лабіринту (перетягніть у інспекторі MainMenu).
## Якщо порожньо — "Нова гра" відкриє стару міні-гру напряму.
@export var maze_scene: PackedScene

const HOVER_SCALE := 0.2
const TILT := 10.0
const DURATION := 0.7

@onready var _buttons: Panel = $Buttons
@onready var _hover_sfx: AudioStreamPlayer2D = $AudioStreamPlayer2D

var _base_scale: Dictionary = {}   # Button → Vector2
var _tweens: Dictionary = {}       # Button → Tween


func _ready() -> void:
	for child in _buttons.get_children():
		if child is Button:
			_setup_button(child)


func _setup_button(btn: Button) -> void:
	btn.pivot_offset = btn.size * 0.5
	btn.scale -= Vector2(HOVER_SCALE, HOVER_SCALE)
	_base_scale[btn] = btn.scale
	btn.mouse_entered.connect(_on_hover.bind(btn))
	btn.mouse_exited.connect(_on_unhover.bind(btn))


func _kill_tween(btn: Button) -> void:
	if _tweens.has(btn) and is_instance_valid(_tweens[btn]) and _tweens[btn].is_valid():
		_tweens[btn].kill()


func _on_hover(btn: Button) -> void:
	_kill_tween(btn)
	_hover_sfx.play()
	var base: Vector2 = _base_scale[btn]
	var tw := create_tween().set_loops()
	_tweens[btn] = tw
	tw.parallel().tween_property(btn, "scale", base - Vector2(HOVER_SCALE, HOVER_SCALE), DURATION)
	tw.parallel().tween_property(btn, "rotation", deg_to_rad(TILT), DURATION)
	tw.tween_property(btn, "rotation", deg_to_rad(-TILT), DURATION)


func _on_unhover(btn: Button) -> void:
	_kill_tween(btn)
	var base: Vector2 = _base_scale[btn]
	var tw := create_tween()
	_tweens[btn] = tw
	tw.parallel().tween_property(btn, "scale", base, DURATION)
	tw.parallel().tween_property(btn, "rotation", 0.0, DURATION)


# ── Кнопки меню ───────────────────────────────────────────────
func _on_new_game_button_pressed() -> void:
	if maze_scene:
		get_tree().change_scene_to_packed(maze_scene)
	else:
		get_tree().change_scene_to_packed(GAME_SCENE)

func _on_settings_button_pressed() -> void:
	add_child(SETTINGS_SCENE.instantiate())

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_saved_games_button_pressed() -> void:
	pass

func _on_game_library_button_pressed() -> void:
	pass
