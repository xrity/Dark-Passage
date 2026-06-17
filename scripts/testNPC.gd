class_name TestNPC
extends Area2D
## ============================================================
##  TestNPC  —  тестовий персонаж
##  Просто червоний квадрат. Коли гравець поруч і натискає F —
##  видає багато тексту "test" через DialogueBox.
##  Створюється з коду (map.gd), окремої сцени не треба.
## ============================================================

@export var npc_color: Color = Color(0.9, 0.15, 0.15)
@export var talk_key: Key = KEY_F          ## клавіша діалогу

var cell_size: float = 80.0

var _player_inside: bool = false


func _ready() -> void:
	monitoring = true
	# Зона, у якій можна заговорити (трохи більша за клітинку)
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = cell_size
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _draw() -> void:
	var s := cell_size * 0.6
	var r := Rect2(-s * 0.5, -s * 0.5, s, s)
	draw_rect(r, npc_color, true)              # червоний квадрат
	draw_rect(r, Color.WHITE, false, 2.0)      # біла рамка


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		_player_inside = true


func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		_player_inside = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == talk_key:
		_talk()


func _talk() -> void:
	if DialogueBox.is_active():
		return
	var line := "test ".repeat(40).strip_edges()
	var lines: Array = []
	for _i in 5:
		lines.append({"name": "Test", "text": line})
	DialogueBox.say(lines)
