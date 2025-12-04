extends Node2D

# --- Переменные для узлов (@onready) ---
@onready var field = $wiresFieldSprite2
@onready var tile = $wireTileSprite
@onready var grid_container = Node2D.new()

# --- Настройки сетки и игрового процесса ---
const MAX_PAIRS = 15
const MIN_PAIRS = 3
const MAX_DIFFICULTY = 3.0
var _current_grid: Array[Array] = [] # Финальная сетка для игрока (только Endpoints)
var _current_colors: Dictionary = {}

# --- Переменные для прокладки пути пользователя ---
var is_drawing = false
var current_path_id = 0
var current_path_color: Color
var current_path_tiles: Array[Vector2i] = []
var grid_size = Vector2i.ZERO

# --- Инициализация ---
func _ready() -> void:
	add_child(grid_container)
	grid_container.name = "WireGrid"
	build_field(4.0)
	tile.visible = false

# ------------------------------------------------------------------------------
## 🚀 Генерация Поля (Оставлено без изменений, чтобы не дублировать код)
# ------------------------------------------------------------------------------

func build_field(difficulty: float) -> void:
	for child in grid_container.get_children():
		child.queue_free()

	var actual_difficulty = clampf(difficulty, 1.0, MAX_DIFFICULTY)
	var new_tile_scale = Vector2(1.0 / actual_difficulty, 1.0 / actual_difficulty)
	tile.scale = new_tile_scale
	
	var tile_W = tile.texture.get_size().x * tile.scale.x
	var tile_H = tile.texture.get_size().y * tile.scale.y
	
	var cols = int(field.scale.x / tile_W)
	var rows = int(field.scale.y / tile_H)
	
	grid_size = Vector2i(cols, rows)
	var total_tiles = cols * rows

	var max_possible_pairs = floor(total_tiles / 3.0)
	var max_pairs_limit = min(MAX_PAIRS, max_possible_pairs)
	var pair_count = randi_range(MIN_PAIRS, max_pairs_limit)
	pair_count = max(MIN_PAIRS, pair_count)
	
	var result = generate_field(cols, rows, pair_count)
	
	_current_grid = result["grid"]
	_current_colors = result["colors"]
	var endpoints = result["endpoints"]
	
	place_tiles(_current_grid, _current_colors, endpoints)

func find_empty_position(cols: int, rows: int, occupied_list: Array[Vector2i]) -> Vector2i:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var pos: Vector2i
	var attempts = 0
	while true:
		pos = Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		if not occupied_list.has(pos):
			return pos
		attempts += 1
		if attempts > 1000:
			push_error("Не удалось найти пустую позицию!")
			return Vector2i.ZERO
			
	return pos

func generate_field(cols: int, rows: int, pair_count: int) -> Dictionary:
	var grid: Array[Array] = []
	var occupied_for_path_gen: Array[Array] = [] # Сетка занятости для AStar

	# Инициализация сеток
	for x in range(cols):
		grid.append([])
		occupied_for_path_gen.append([])
		for y in range(rows):
			grid[x].append(0)
			occupied_for_path_gen[x].append(false)

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var color_table := {}
	var endpoints: Array[Dictionary] = []

	var all_occupied_endpoints: Array[Vector2i] = []
	
	for i in range(1, pair_count + 1):
		color_table[i] = Color(rng.randf(), rng.randf(), rng.randf())
		
		var start_pos: Vector2i
		var end_pos: Vector2i
		
		# 1. Находим конечные точки
		start_pos = find_empty_position(cols, rows, all_occupied_endpoints)
		
		var attempts = 0
		while true:
			end_pos = Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
			
			if end_pos != start_pos and not all_occupied_endpoints.has(end_pos):
				if start_pos.distance_to(end_pos) >= 2.0:
					break
			
			attempts += 1
			if attempts > 1000:
				push_error("Не удалось найти конечную точку для пары %d" % i)
				break
		
		if attempts > 1000: continue

		# 2. Генерируем путь, используя текущую сетку занятости
		var path = build_path(start_pos, end_pos, grid_size, occupied_for_path_gen)
		
		if path.is_empty() and start_pos != end_pos:
			push_warning("AStar не смог найти путь для пары %d. Пропуск." % i)
			continue # Пропускаем эту пару, если путь не найден
			
		# 3. Резервируем Endpoints и путь в сетке занятости
		all_occupied_endpoints.append(start_pos)
		all_occupied_endpoints.append(end_pos)
		
		endpoints.append({"pos": start_pos, "id": i})
		endpoints.append({"pos": end_pos, "id": i})

		for pos in path:
			occupied_for_path_gen[pos.x][pos.y] = true
			
		occupied_for_path_gen[start_pos.x][start_pos.y] = true
		occupied_for_path_gen[end_pos.x][end_pos.y] = true

		# 4. Отмечаем ТОЛЬКО стартовую и конечную точки в финальной сетке для игрока
		grid[start_pos.x][start_pos.y] = i
		grid[end_pos.x][end_pos.y] = i
		
	return {
		"grid": grid,
		"colors": color_table,
		"endpoints": endpoints
	}

func build_path(start: Vector2i, end: Vector2i, size: Vector2i, occupied_map: Array[Array]) -> Array[Vector2i]:
	var astar = AStarGrid2D.new()
	astar.size = size
	astar.cell_size = Vector2(1, 1)
	astar.offset = Vector2i.ZERO
	
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	
	astar.update()

	# Задаем непроходимые клетки
	for x in range(size.x):
		for y in range(size.y):
			if occupied_map[x][y]:
				astar.set_point_solid(Vector2i(x, y), true)
			else:
				astar.set_point_solid(Vector2i(x, y), false)
				
	# Убедимся, что Endpoints текущего пути всегда проходимы
	astar.set_point_solid(start, false)
	astar.set_point_solid(end, false)


	# Находим путь
	var path_array = astar.get_id_path(start, end)
	
	var path: Array[Vector2i] = []
	for point in path_array:
		path.append(point)

	if path.size() >= 2:
		path.pop_back() # Удаляем конец
		path.remove_at(0) # Удаляем старт
		
	return path

# ------------------------------------------------------------------------------
## 🖼️ Размещение Плиток и Анимация
# ------------------------------------------------------------------------------

func place_tiles(grid: Array, colors: Dictionary, endpoints: Array) -> void:
	var cols = grid.size()
	var rows = grid[0].size()
	var tile_w = tile.texture.get_size().x * tile.scale.x
	var tile_h = tile.texture.get_size().y * tile.scale.y
	
	var endpoint_map = {}
	for ep in endpoints:
		endpoint_map[ep.pos] = true

	for x in range(cols):
		for y in range(rows):
			var id = grid[x][y]
			var grid_pos = Vector2i(x, y)
			var t = tile.duplicate() as Sprite2D
			t.visible = true
			t.position = field.position + Vector2(x * tile_w + tile_w / 2, y * tile_h + tile_h / 2)
			
			t.set_meta(&"Id", id)
			t.set_meta(&"GridPos", grid_pos)
			
			t.modulate = Color(1, 1, 1, 0)
			
			var visual_node = t.get_child(0) as Sprite2D
			
			if id == 0:
				visual_node.visible = false
			else:
				t.set_meta(&"Color", colors[id])
				visual_node.visible = true
				visual_node.modulate = colors[id]
				
				if endpoint_map.has(grid_pos):
					t.set_meta(&"IsEndpoint", true)
				else:
					t.set_meta(&"IsEndpoint", false)
					
			grid_container.add_child(t)

			if id != 0:
				_animate_tile_draw(t, true)

func _animate_tile_draw(node: CanvasItem, appear: bool) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var final_alpha = 1.0 if appear else 0.0
	var duration = 0.2
	
	tween.tween_property(node, "modulate:a", final_alpha, duration)
	
	if not appear:
		# Используем bind для Godot 4
		tween.chain().call_deferred_callable(node.set_visible.bind(false))

# ------------------------------------------------------------------------------
## ✍️ Обработка Ввода Пользователя (Здесь основные изменения)
# ------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var grid_pos = screen_to_grid(event.position)
			
			if not is_valid_grid_pos(grid_pos):
				if is_drawing and not event.pressed:
					stop_drawing_path(Vector2i(-1, -1))
				return
				
			if event.pressed:
				start_drawing_path(grid_pos)
			else:
				stop_drawing_path(grid_pos)
				
	# 🛑 ИСПРАВЛЕНИЕ 1: Добавлена интерполяция для плавного рисования
	elif event is InputEventMouseMotion and is_drawing:
		var current_grid_pos = screen_to_grid(event.position)
	
	if current_path_tiles.is_empty(): 
		return
	
	var last_pos = current_path_tiles.back()
	
	var current_grid_pos = screen_to_grid(event.position)
	
	if current_grid_pos == last_pos:
		return

	# --- Преобразование в Vector2 для использования метода lerp ---
	var last_pos_f = Vector2(last_pos) 
	var current_grid_pos_f = Vector2(current_grid_pos)
	# ------------------------------------------------------------

	var dx = abs(current_grid_pos.x - last_pos.x)
	var dy = abs(current_grid_pos.y - last_pos.y)
	var steps = max(dx, dy)
	
	if steps > 0:
		for i in range(1, steps + 1):
			var t = float(i) / steps
			
			# Теперь используем Vector2.lerp
			var interp_pos_float = last_pos_f.lerp(current_grid_pos_f, t) 
			
			# Округляем и преобразуем обратно в Vector2i
			var step_pos = Vector2i(round(interp_pos_float.x), round(interp_pos_float.y))
			
			if step_pos != current_path_tiles.back():
				draw_path(step_pos)

func screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var local_pos = to_local(screen_pos)
	var relative_pos = local_pos - field.position
	
	var tile_W = tile.texture.get_size().x * tile.scale.x
	var tile_H = tile.texture.get_size().y * tile.scale.y
	
	var x = floor((relative_pos.x / tile_W) - 0.5) 
	var y = floor((relative_pos.y / tile_H) - 0.5)
	
	return Vector2i(x, y)

func is_valid_grid_pos(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < grid_size.x and pos.y < grid_size.y

func get_tile_at(pos: Vector2i) -> Sprite2D:
	if not is_valid_grid_pos(pos):
		return null
		
	for child in grid_container.get_children():
		if child.get_meta(&"GridPos") == pos:
			return child as Sprite2D
			
	return null

func clear_path(id_to_clear: int) -> void:
	if id_to_clear == 0:
		return

	var cols = grid_size.x
	var rows = grid_size.y

	for x in range(cols):
		for y in range(rows):
			var grid_pos = Vector2i(x, y)
			
			if _current_grid[x][y] == id_to_clear:
				var tile_node = get_tile_at(grid_pos)
				
				# 🛑 Проверка: Убедимся, что узел существует
				if tile_node:
					var is_endpoint = tile_node.get_meta(&"IsEndpoint", false)
					
					if not is_endpoint:
						_current_grid[x][y] = 0
						tile_node.modulate = Color.WHITE
						tile_node.get_child(0).visible = false
						_animate_tile_draw(tile_node, false)

func start_drawing_path(pos: Vector2i) -> void:
	var tile_node = get_tile_at(pos)
	if not tile_node:
		return
		
	var id = tile_node.get_meta(&"Id")
	var is_endpoint = tile_node.get_meta(&"IsEndpoint", false)

	if id > 0 and is_endpoint:
		
		clear_path(id) 
		
		is_drawing = true
		current_path_id = id
		current_path_color = tile_node.get_meta(&"Color")
		current_path_tiles.append(pos)
		
		tile_node.modulate = Color.WHITE * 0.5 

func draw_path(pos: Vector2i) -> void:
	if not is_drawing:
		return
		
	if current_path_tiles.is_empty():
		return
		
	var last_pos = current_path_tiles.back()
	
	if pos == last_pos: 
		return
	
	# Оставляем эту проверку, чтобы отсечь прыжки, которые не удалось интерполировать
	if pos.distance_to(last_pos) > 1.0: 
		return
		
	var tile_node = get_tile_at(pos)
	if not tile_node:
		return
		
	var target_id = tile_node.get_meta(&"Id")
	var is_endpoint = tile_node.get_meta(&"IsEndpoint", false)
	
	# Условие для продолжения:
	var can_continue = not current_path_tiles.has(pos) and (
		target_id == 0 or # Плитка пуста (разрешено)
		(target_id == current_path_id and is_endpoint) # Плитка является EndPoint нашего цвета (разрешено: завершение пути)
	)

	if can_continue:
		current_path_tiles.append(pos)
		
		_animate_tile_draw(tile_node, true)
		
		if target_id == 0:
			tile_node.get_child(0).visible = true 
			tile_node.get_child(0).modulate = current_path_color
			
		tile_node.modulate = current_path_color * 0.7 
		
	# 2. Если это предыдущая плитка в пути (отмена/стирание)
	elif current_path_tiles.size() > 1 and current_path_tiles[-2] == pos:
		var removed_pos = current_path_tiles.pop_back()
		var removed_tile = get_tile_at(removed_pos)
	
		# 🛑 ИСПРАВЛЕНИЕ 2: Проверка removed_tile на null перед использованием
		if removed_tile:
			var is_removed_endpoint = removed_tile.get_meta(&"IsEndpoint", false)
			
			if not is_removed_endpoint:
				_animate_tile_draw(removed_tile, false)
			
			# Сброс визуализации удаленной плитки
			if is_removed_endpoint:
				removed_tile.modulate = current_path_color * 0.5
			else:
				removed_tile.modulate = Color.WHITE 
				removed_tile.get_child(0).visible = false 

func stop_drawing_path(pos: Vector2i) -> void:
	if not is_drawing:
		return
		
	is_drawing = false
	
	var tile_node = get_tile_at(pos)
	
	# Сброс, если остановились вне сетки
	if not tile_node: 
		_reset_path_visualization()
		return
	
	var target_id = tile_node.get_meta(&"Id")
	var is_endpoint = tile_node.get_meta(&"IsEndpoint", false)
	
	# Проверка на успешное соединение
	if target_id == current_path_id and is_endpoint and current_path_tiles.size() > 1:
		
		print("✅ Путь для ID %d успешно проложен!" % current_path_id)
		
		# Сохранить путь в основную сетку и финальная визуализация
		for path_pos in current_path_tiles:
			var final_tile = get_tile_at(path_pos)
			
			if final_tile: # 🛑 Проверка: Убедимся, что узел существует
				if not final_tile.get_meta(&"IsEndpoint", false):
					_current_grid[path_pos.x][path_pos.y] = current_path_id
				
				final_tile.modulate = Color.WHITE 
				final_tile.get_child(0).visible = true
				final_tile.get_child(0).modulate = current_path_color
		
	else:
		# Неуспешное соединение - сброс
		print("❌ Путь для ID %d сброшен." % current_path_id)
		_reset_path_visualization()
		
	current_path_tiles.clear()
	current_path_id = 0

func _reset_path_visualization() -> void:
	for pos in current_path_tiles:
		var tile_node = get_tile_at(pos)
		
		if not tile_node: continue # Пропускаем, если узел не найден
		
		var is_endpoint = tile_node.get_meta(&"IsEndpoint", false)
		
		# Сброс модулятора
		tile_node.modulate = Color.WHITE
		
		if not is_endpoint:
			tile_node.get_child(0).visible = false
			_animate_tile_draw(tile_node, false) 
		else:
			# Если это Endpoint, он должен вернуться к нормальному цвету и видимости
			tile_node.modulate = Color.WHITE * 1.0
			tile_node.get_child(0).modulate = tile_node.get_meta(&"Color")
			tile_node.get_child(0).visible = true
			
	clear_path(current_path_id)
