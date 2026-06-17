extends Node2D
## ============================================================
##  Map  —  справжній зв'язний лабіринт
##  Будується ОДИН раз алгоритмом recursive backtracker (DFS):
##    • кожна клітинка отримує набір відкритих сторін;
##    • за патерном [верх, право, низ, лево] підбирається тайл зі STRUCTS;
##    • опційно ставляться стіни-колізії, щоб гравець ходив коридорами.
##  Лабіринт повністю прохідний — будь-яка клітинка досяжна.
## ============================================================

# [верх, право, низ, лево]
const STRUCTS := [
	[0,0,0,0], [1,0,0,0], [0,1,0,0], [0,0,1,0],
	[0,0,0,1], [1,1,0,0], [1,0,1,0], [1,0,0,1],
	[0,1,1,0], [0,1,0,1], [0,0,1,1], [1,1,1,0],
	[1,1,0,1], [1,0,1,1], [0,1,1,1], [1,1,1,1],
	[-1,-1,-1,-1],
]

@export var tile_scenes: Array[PackedScene] = [
	preload("res://map test/tile/tile.tscn"),
	preload("res://map test/tile/tile1.tscn"),
	preload("res://map test/tile/tile2.tscn"),
	preload("res://map test/tile/tile3.tscn"),
	preload("res://map test/tile/tile4.tscn"),
	preload("res://map test/tile/tile5.tscn"),
	preload("res://map test/tile/tile6.tscn"),
	preload("res://map test/tile/tile7.tscn"),
	preload("res://map test/tile/tile8.tscn"),
	preload("res://map test/tile/tile9.tscn"),
	preload("res://map test/tile/tile10.tscn"),
	preload("res://map test/tile/tile11.tscn"),
	preload("res://map test/tile/tile12.tscn"),
	preload("res://map test/tile/tile13.tscn"),
	preload("res://map test/tile/tile14.tscn"),
	preload("res://map test/tile/tile15.tscn"),
	preload("res://map test/tile/tile16.tscn"),
]

const COLS := 32
const ROWS := 16
const CELL_SIZE := 80

# Напрямки в порядку STRUCTS: 0=верх 1=право 2=низ 3=лево
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

@onready var _player: Node2D = $player

## Старт гравця (у клітинках).
@export var start_cell: Vector2i = Vector2i(1, 1)
## Ставити стіни-колізії, щоб гравець не проходив крізь них.
@export var add_walls: bool = true
## Товщина стін у пікселях.
@export var wall_thickness: float = 10.0

## Міні-гра з тайла-портала.
@export var wires_game_scene: PackedScene
## Клітинка, де з'явиться портал.
@export var trigger_cell: Vector2i = Vector2i(30, 14)

# _open[x][y] = [bool верх, право, низ, лево]
var _open: Array = []
var _trigger: Node2D
var _trigger_cell_current: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	randomize()
	_generate_maze()
	_render_all()
	_place_player()
	if add_walls:
		_build_walls()
	_spawn_trigger_at(_clamp_cell(trigger_cell))


# ============================================================
#  ГЕНЕРАЦІЯ (recursive backtracker)
# ============================================================
func _generate_maze() -> void:
	_open.clear()
	for x in COLS:
		var col: Array = []
		for y in ROWS:
			col.append([false, false, false, false])
		_open.append(col)

	var start := _clamp_cell(start_cell)
	var visited: Dictionary = {start: true}
	var stack: Array[Vector2i] = [start]

	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var options := _unvisited_neighbors(cur, visited)
		if options.is_empty():
			stack.pop_back()
			continue
		var choice: Array = options.pick_random()
		var nxt: Vector2i = choice[0]
		var dir: int = choice[1]
		# відкриваємо прохід в обидві сторони
		_open[cur.x][cur.y][dir] = true
		_open[nxt.x][nxt.y][(dir + 2) % 4] = true
		visited[nxt] = true
		stack.append(nxt)


func _unvisited_neighbors(cell: Vector2i, visited: Dictionary) -> Array:
	var result: Array = []
	for dir in 4:
		var n: Vector2i = cell + DIRS[dir]
		if _in_bounds(n.x, n.y) and not visited.has(n):
			result.append([n, dir])
	return result


# ============================================================
#  ВІДМАЛЮВАННЯ ТАЙЛІВ
# ============================================================
func _render_all() -> void:
	for x in COLS:
		for y in ROWS:
			var o: Array = _open[x][y]
			var pattern := [int(o[0]), int(o[1]), int(o[2]), int(o[3])]
			var index := STRUCTS.find(pattern)
			if index < 0 or index >= tile_scenes.size():
				continue
			var tile := tile_scenes[index].instantiate()
			add_child(tile)
			tile.position = _cell_center(Vector2i(x, y))


# ============================================================
#  СТІНИ (колізії)
# ============================================================
func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	add_child(body)

	for x in COLS:
		for y in ROWS:
			var o: Array = _open[x][y]
			var ox := x * CELL_SIZE
			var oy := y * CELL_SIZE
			# верхня стіна (спільна з клітинкою зверху — додаємо лише тут)
			if not o[0]:
				_add_wall(body, Vector2(ox + CELL_SIZE / 2.0, oy),
						Vector2(CELL_SIZE, wall_thickness))
			# ліва стіна (спільна з клітинкою зліва)
			if not o[3]:
				_add_wall(body, Vector2(ox, oy + CELL_SIZE / 2.0),
						Vector2(wall_thickness, CELL_SIZE))
			# права межа карти
			if x == COLS - 1 and not o[1]:
				_add_wall(body, Vector2(ox + CELL_SIZE, oy + CELL_SIZE / 2.0),
						Vector2(wall_thickness, CELL_SIZE))
			# нижня межа карти
			if y == ROWS - 1 and not o[2]:
				_add_wall(body, Vector2(ox + CELL_SIZE / 2.0, oy + CELL_SIZE),
						Vector2(CELL_SIZE, wall_thickness))


func _add_wall(body: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	body.add_child(col)


# ============================================================
#  ГРАВЕЦЬ І ПОРТАЛ
# ============================================================
func _place_player() -> void:
	if _player:
		_player.position = _cell_center(_clamp_cell(start_cell))


func _spawn_trigger_at(cell: Vector2i) -> void:
	if wires_game_scene == null:
		push_warning("map.gd: не призначено wires_game_scene — портал не створено.")
		return
	_trigger = MiniGameTrigger.new()
	_trigger.wires_game_scene = wires_game_scene
	_trigger.cell_size = float(CELL_SIZE)
	_trigger.finished.connect(_on_trigger_finished)
	add_child(_trigger)
	_trigger.position = _cell_center(cell)
	_trigger_cell_current = cell


## Після закриття міні-гри: прибрати старий портал і створити новий
## у випадковій клітинці (не там, де стоїть гравець, і не на старому місці).
func _on_trigger_finished() -> void:
	if is_instance_valid(_trigger):
		_trigger.queue_free()
	_trigger = null
	_spawn_trigger_at(_random_cell())


func _random_cell() -> Vector2i:
	var player_cell := _cell_of(_player.position) if _player else Vector2i(-1, -1)
	for _attempt in 200:
		var c := Vector2i(randi() % COLS, randi() % ROWS)
		if c != player_cell and c != _trigger_cell_current:
			return c
	return Vector2i(randi() % COLS, randi() % ROWS)


# ============================================================
#  ДОПОМІЖНЕ
# ============================================================
func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE + CELL_SIZE / 2.0,
			cell.y * CELL_SIZE + CELL_SIZE / 2.0)


func _cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / CELL_SIZE), int(pos.y / CELL_SIZE))


func _clamp_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(clampi(cell.x, 0, COLS - 1), clampi(cell.y, 0, ROWS - 1))


func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < COLS and y >= 0 and y < ROWS
