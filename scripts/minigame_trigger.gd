class_name MiniGameTrigger
extends Area2D
## ============================================================
##  MiniGameTrigger  —  тайл-портал у лабіринті
##  Коли гравець (CharacterBody2D) наступає на нього, поверх
##  лабіринту відкривається міні-гра (WiresGame). Лабіринт
##  замерзає. Після виходу/перемоги гра закривається й
##  керування повертається до лабіринту.
##
##  Створюється з коду (map.gd), нічого в сцені робити не треба.
## ============================================================

@export var wires_game_scene: PackedScene
@export var marker_color: Color = Color(0.25, 0.9, 1.0)

## Випромінюється після закриття міні-гри (карта пересуває портал).
signal finished

var cell_size: float = 80.0

var _active: bool = false
var _overlay: CanvasLayer
var _pulse: float = 0.0


func _ready() -> void:
	monitoring = true
	# Зона зіткнення під клітинку
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(cell_size, cell_size) * 0.85
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	var s := cell_size * 0.7
	var r := Rect2(-s * 0.5, -s * 0.5, s, s)
	draw_rect(r, Color(marker_color, 0.22), true)        # заливка
	draw_rect(r, marker_color, false, 3.0)               # рамка


func _process(delta: float) -> void:
	# легка пульсація, щоб тайл привертав увагу
	_pulse += delta * 3.0
	var k := 1.0 + 0.08 * sin(_pulse)
	scale = Vector2(k, k)
	modulate.a = 0.7 + 0.3 * (0.5 + 0.5 * sin(_pulse))


func _on_body_entered(body: Node) -> void:
	if _active or wires_game_scene == null:
		return
	if not (body is CharacterBody2D):
		return
	_launch()


func _launch() -> void:
	_active = true
	var cs := get_tree().current_scene
	if cs == null:
		_active = false
		return

	# Шар поверх лабіринту
	_overlay = CanvasLayer.new()
	_overlay.layer = 50
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	cs.add_child(_overlay)

	# Непрозорий фон, щоб сховати заморожений лабіринт
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 1)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)

	# Сама міні-гра у вбудованому режимі
	var game := wires_game_scene.instantiate()
	game.set("embedded", true)
	_overlay.add_child(game)
	if game.has_signal("closed"):
		game.connect("closed", _on_minigame_closed)

	# Заморозити лабіринт (overlay лишається активним завдяки ALWAYS)
	cs.process_mode = Node.PROCESS_MODE_DISABLED


func _on_minigame_closed() -> void:
	var cs := get_tree().current_scene
	if cs:
		cs.process_mode = Node.PROCESS_MODE_INHERIT
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_active = false
	finished.emit()
