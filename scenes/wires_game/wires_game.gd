extends Node2D
## ============================================================
##  WiresGame  (головоломка соединения проводов / Flow-style)
##  Изменения:
##    • сложность берётся из синглтона Settings (а не из meta);
##    • добавлено определение победы (все пары соединены и поле
##      заполнено) + оверлей «Рівень пройдено!»;
##    • это ЕДИНСТВЕННАЯ версия — back_button.gd (дубликат) удалить.
## ============================================================

@onready var _field_sprite:  Sprite2D            = $wiresFieldSprite
@onready var _tile_template: Sprite2D            = $wireTileSprite
@onready var _sfx_button:    AudioStreamPlayer   = $ButtonSound

var _grid_root: Node2D

## Вбудований режим: запущено поверх лабіринту. У цьому режимі
## вихід/перемога не міняють сцену, а закривають міні-гру (сигнал closed).
@export var embedded: bool = false
signal closed

const MAX_PAIRS:      int   = 15
const MIN_PAIRS:      int   = 3
const MAX_DIFFICULTY: float = 3.0

# ── grid state ────────────────────────────────────────────────
var _grid:      Array[Array] = []   # _grid[x][y] → path-id (0 = пусто)
var _colors:    Dictionary   = {}   # id → Color
var _tile_map:  Dictionary   = {}   # Vector2i → Sprite2D  (O(1))
var _grid_size: Vector2i     = Vector2i.ZERO
var _tile_size: Vector2      = Vector2.ZERO

# ── drawing state ─────────────────────────────────────────────
var _drawing:    bool            = false
var _path_id:    int             = 0
var _path_color: Color
var _path_tiles: Array[Vector2i] = []

# ── win state ─────────────────────────────────────────────────
var _pair_count:    int        = 0
var _completed_ids: Dictionary = {}   # id → true
var _won:           bool        = false

# ── difficulty (из глобальных настроек) ───────────────────────
var difficulty: float = float(Settings.difficulty)

# ── pause ─────────────────────────────────────────────────────
var _paused:        bool      = false
var _pause_layer:   CanvasLayer
var _pause_overlay: ColorRect
var _resume_btn:    Button
var _menu_btn:      Button


# ============================================================
#  LIFECYCLE
# ============================================================
func _ready() -> void:
	_grid_root = Node2D.new()
	_grid_root.name = "WireGrid"
	add_child(_grid_root)

	_tile_template.visible = false
	_build_field(difficulty)
	_create_pause_menu()


# ============================================================
#  PAUSE
# ============================================================
func _create_pause_menu() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 128
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)

	_pause_overlay = ColorRect.new()
	_pause_overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.visible = false
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_layer.add_child(_pause_overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.custom_minimum_size = Vector2(220, 120)
	_pause_overlay.add_child(vbox)

	_resume_btn = _make_btn("Продовжити", vbox)
	_menu_btn   = _make_btn("Вийти в меню", vbox)

	_resume_btn.pressed.connect(_on_resume_pressed)
	_menu_btn.pressed.connect(_on_menu_pressed)


func _make_btn(label: String, parent: Node) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(200, 50)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(btn)
	return btn


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _won:
		_toggle_pause()


func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused      = _paused
	_pause_overlay.visible = _paused


func _on_resume_pressed() -> void:
	_sfx_button.play()
	await _sfx_button.finished
	_toggle_pause()


func _on_menu_pressed() -> void:
	_sfx_button.play()
	await _sfx_button.finished
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")


func _on_back_button_pressed() -> void:
	if embedded:
		closed.emit()
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")


# ============================================================
#  FIELD BUILDING
# ============================================================
func _build_field(diff: float) -> void:
	assert(_grid_root.get_child_count() == 0, "Grid root must be empty before building.")

	var d := clampf(diff, 1.0, MAX_DIFFICULTY)

	_tile_template.scale = _tile_template.scale / d
	_tile_size = _tile_template.texture.get_size() * _tile_template.scale

	var cols := int(_field_sprite.scale.x / _tile_size.x)
	var rows := int(_field_sprite.scale.y / _tile_size.y)
	_grid_size = Vector2i(cols, rows)

	var max_pairs := mini(MAX_PAIRS, int(floor(cols * rows / 3.0)))
	var rng := _new_rng()
	_pair_count = rng.randi_range(MIN_PAIRS, max_pairs)

	var result := _generate_field(cols, rows, _pair_count)
	_grid   = result["grid"]   as Array
	_colors = result["colors"] as Dictionary
	# реальное число успешно размещённых пар
	_pair_count = (result["colors"] as Dictionary).size()

	_place_tiles(result["endpoints"] as Array)


func _new_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng


# ============================================================
#  GRID GENERATION
# ============================================================
func _generate_field(cols: int, rows: int, pair_count: int) -> Dictionary:
	var grid:         Array[Array] = []
	var occupied_map: Array[Array] = []
	for x in cols:
		grid.append([])
		occupied_map.append([])
		for _y in rows:
			grid[x].append(0)
			occupied_map[x].append(false)

	var rng := _new_rng()
	var colors:    Dictionary        = {}
	var endpoints: Array[Dictionary] = []

	for i in range(1, pair_count + 1):
		var start := _random_free_pos(cols, rows, occupied_map, rng)
		if start == Vector2i(-1, -1):
			continue
		var end := _random_far_pos(cols, rows, start, occupied_map, rng)

		if end == Vector2i(-1, -1):
			push_warning("Could not place endpoint pair %d — skipping." % i)
			continue

		var path := _build_astar_path(start, end, occupied_map)
		if path.is_empty() and start != end:
			push_warning("A* found no path for pair %d — skipping." % i)
			continue

		colors[i] = Color(rng.randf(), rng.randf(), rng.randf())

		for p: Vector2i in path:
			occupied_map[p.x][p.y] = true
		occupied_map[start.x][start.y] = true
		occupied_map[end.x][end.y]     = true

		grid[start.x][start.y] = i
		grid[end.x][end.y]     = i

		endpoints.append({"pos": start, "id": i})
		endpoints.append({"pos": end,   "id": i})

	return {"grid": grid, "colors": colors, "endpoints": endpoints}


func _random_free_pos(cols: int, rows: int,
		occupied_map: Array[Array], rng: RandomNumberGenerator) -> Vector2i:
	for _attempt in 1000:
		var pos := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		if not (occupied_map[pos.x][pos.y] as bool):
			return pos
	return Vector2i(-1, -1)


func _random_far_pos(cols: int, rows: int, start: Vector2i,
		occupied_map: Array[Array], rng: RandomNumberGenerator) -> Vector2i:
	for _attempt in 1000:
		var pos := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		if pos != start \
				and not (occupied_map[pos.x][pos.y] as bool) \
				and start.distance_to(pos) >= 2.0:
			return pos
	return Vector2i(-1, -1)


func _build_astar_path(start: Vector2i, end: Vector2i,
		occupied_map: Array[Array]) -> Array[Vector2i]:
	var astar := AStarGrid2D.new()
	astar.size          = _grid_size
	astar.cell_size     = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

	for x in _grid_size.x:
		for y in _grid_size.y:
			astar.set_point_solid(Vector2i(x, y), occupied_map[x][y] as bool)

	astar.set_point_solid(start, false)
	astar.set_point_solid(end,   false)

	var raw := astar.get_id_path(start, end)
	if raw.size() >= 2:
		raw.pop_back()
		raw.remove_at(0)
	return raw


# ============================================================
#  TILE PLACEMENT
# ============================================================
func _place_tiles(endpoints: Array) -> void:
	var cols := _grid_size.x
	var rows := _grid_size.y

	var endpoint_set: Dictionary = {}
	for ep in endpoints:
		endpoint_set[(ep as Dictionary)["pos"]] = true

	for x in cols:
		for y in rows:
			var id: int = _grid[x][y]
			var grid_pos := Vector2i(x, y)

			var t := _tile_template.duplicate() as Sprite2D
			t.visible  = true
			t.position = _field_sprite.position + Vector2(x * _tile_size.x, y * _tile_size.y)

			t.set_meta(&"Id",      id)
			t.set_meta(&"GridPos", grid_pos)

			var visual := t.get_child(0) as Sprite2D

			if id == 0:
				visual.visible = false
			else:
				var col: Color = _colors[id]
				t.set_meta(&"Color",      col)
				t.set_meta(&"IsEndpoint", endpoint_set.has(grid_pos))
				visual.visible  = true
				visual.modulate = col
				_animate_tile(t, true)

			_grid_root.add_child(t)
			_tile_map[grid_pos] = t


# ============================================================
#  TILE ANIMATION
# ============================================================
func _animate_tile(node: CanvasItem, appear: bool) -> void:
	var child := node.get_child(0) as CanvasItem
	if not child:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(child, "modulate:a", 1.0 if appear else 0.0, 0.2)


# ============================================================
#  COORDINATE HELPERS
# ============================================================
func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var local := to_local(screen_pos) - _field_sprite.position
	return Vector2i(int(floor(local.x / _tile_size.x)), int(floor(local.y / _tile_size.y)))


func _is_valid_pos(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < _grid_size.x and pos.y < _grid_size.y


func _get_tile(pos: Vector2i) -> Sprite2D:
	return _tile_map.get(pos, null) as Sprite2D


# ============================================================
#  PATH MANAGEMENT
# ============================================================
func _clear_path(id: int) -> void:
	if id == 0:
		return
	_completed_ids.erase(id)
	for x in _grid_size.x:
		for y in _grid_size.y:
			if (_grid[x][y] as int) != id:
				continue
			var t := _get_tile(Vector2i(x, y))
			if t and not (t.get_meta(&"IsEndpoint", false) as bool):
				_grid[x][y] = 0
				(t.get_child(0) as CanvasItem).visible = false
				_animate_tile(t, false)


func _reset_path_visual() -> void:
	for pos: Vector2i in _path_tiles:
		var t := _get_tile(pos)
		if not t:
			continue
		var visual := t.get_child(0) as CanvasItem
		if t.get_meta(&"IsEndpoint", false) as bool:
			visual.modulate = t.get_meta(&"Color") as Color
			visual.visible  = true
		else:
			visual.visible = false
			_animate_tile(t, false)
	_clear_path(_path_id)


func _start_drawing(pos: Vector2i) -> void:
	var t := _get_tile(pos)
	if not t:
		return
	var id: int = t.get_meta(&"Id")
	if id <= 0 or not (t.get_meta(&"IsEndpoint", false) as bool):
		return

	_clear_path(id)
	_drawing    = true
	_path_id    = id
	_path_color = t.get_meta(&"Color")
	_path_tiles.append(pos)


func _extend_path(pos: Vector2i) -> void:
	if not _drawing or _path_tiles.is_empty():
		return

	var last: Vector2i = _path_tiles.back()
	if pos == last:
		return
	if absi(pos.x - last.x) + absi(pos.y - last.y) != 1:
		return

	var t := _get_tile(pos)
	if not t:
		return

	var static_id: int = t.get_meta(&"Id")          # колір ендпоінта (0 для звичайної клітинки)
	var is_endpoint: bool = t.get_meta(&"IsEndpoint", false)
	var grid_id: int = _grid[pos.x][pos.y]           # поточна зайнятість (прокладені шляхи)

	# ── Backtrack ────────────────────────────────────────────
	if _path_tiles.size() > 1 and (_path_tiles[-2] as Vector2i) == pos:
		var removed_pos: Vector2i = _path_tiles.pop_back()
		var removed_tile := _get_tile(removed_pos)
		if removed_tile and not (removed_tile.get_meta(&"IsEndpoint", false) as bool):
			_grid[removed_pos.x][removed_pos.y] = 0
			(removed_tile.get_child(0) as CanvasItem).visible = false
			_animate_tile(removed_tile, false)
		return

	# ── Advance ──────────────────────────────────────────────
	# Дозволено йти лише на:
	#   • власний ендпоінт (того ж кольору), або
	#   • справді порожню клітинку (не зайняту іншим прокладеним шляхом).
	var allowed: bool
	if is_endpoint:
		allowed = static_id == _path_id
	else:
		allowed = grid_id == 0

	if _path_tiles.has(pos) or not allowed:
		return

	# одразу позначаємо клітинку зайнятою цим шляхом,
	# щоб інші шляхи не могли пройти крізь неї
	if not is_endpoint:
		_grid[pos.x][pos.y] = _path_id

	_path_tiles.append(pos)
	var visual := t.get_child(0) as CanvasItem
	visual.visible  = true
	visual.modulate = _path_color * 0.85
	_animate_tile(t, true)


func _stop_drawing(pos: Vector2i) -> void:
	if not _drawing:
		return
	_drawing = false

	var t := _get_tile(pos)
	if not t:
		_reset_path_visual()
		_path_tiles.clear()
		_path_id = 0
		return

	var target_id: int = t.get_meta(&"Id")
	var is_endpoint: bool = t.get_meta(&"IsEndpoint", false)
	var success := target_id == _path_id and is_endpoint and _path_tiles.size() > 1

	if success:
		for p: Vector2i in _path_tiles:
			var ft := _get_tile(p)
			if not ft:
				continue
			if not (ft.get_meta(&"IsEndpoint", false) as bool):
				_grid[p.x][p.y] = _path_id
			var ft_visual := ft.get_child(0) as CanvasItem
			ft_visual.visible  = true
			ft_visual.modulate = _path_color
		_completed_ids[_path_id] = true
		_check_win()
	else:
		_reset_path_visual()

	_path_tiles.clear()
	_path_id = 0


# ============================================================
#  WIN
# ============================================================
func _check_win() -> void:
	# Перемога = усі пари з'єднані (заповнювати все поле не потрібно).
	if _completed_ids.size() >= _pair_count and _pair_count > 0:
		_on_win()


func _on_win() -> void:
	if _won:
		return
	_won = true
	var label := Label.new()
	label.text = "Рівень пройдено!"
	label.add_theme_font_size_override("font_size", 48)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_layer.add_child(label)

	if embedded:
		await get_tree().create_timer(1.5).timeout
		closed.emit()


# ============================================================
#  INPUT
# ============================================================
func _unhandled_input(event: InputEvent) -> void:
	if _paused or _won:
		return

	# ── Касание / кнопка мыши ─────────────────────────────────
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var gp := _screen_to_grid(mb.position)
			if not _is_valid_pos(gp):
				if _drawing and not mb.pressed:
					_stop_drawing(Vector2i(-1, -1))
				return
			if mb.pressed:
				_start_drawing(gp)
			else:
				_stop_drawing(gp)
			return

	# ── Движение (перетаскивание) ─────────────────────────────
	if not _drawing or _path_tiles.is_empty():
		return

	var motion_pos: Vector2
	if event is InputEventMouseMotion:
		motion_pos = (event as InputEventMouseMotion).position
	elif event is InputEventScreenDrag:
		motion_pos = (event as InputEventScreenDrag).position
	else:
		return

	var current_gp := _screen_to_grid(motion_pos)
	var last_gp: Vector2i = _path_tiles.back()
	if current_gp == last_gp:
		return

	var steps := maxi(absi(current_gp.x - last_gp.x), absi(current_gp.y - last_gp.y))
	for i in range(1, steps + 1):
		var t_f := float(i) / float(steps)
		var interp := Vector2(last_gp).lerp(Vector2(current_gp), t_f)
		var step_gp := Vector2i(roundi(interp.x), roundi(interp.y))
		if step_gp != (_path_tiles.back() as Vector2i):
			_extend_path(step_gp)
