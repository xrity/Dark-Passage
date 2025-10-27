extends Node2D

#[верх, право, низ, лево]
const STRUCTS = [
	[0,0,0,0], [1,0,0,0], [0,1,0,0], [0,0,1,0], 
	[0,0,0,1], [1,1,0,0], [1,0,1,0], [1,0,0,1], 
	[0,1,1,0], [0,1,0,1], [0,0,1,1], [1,1,1,0],
	[1,1,0,1], [1,0,1,1], [0,1,1,1], [1,1,1,1],
	[-1,-1,-1,-1]
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
	preload("res://map test/tile/tile16.tscn")
]

@onready var player = $player
@onready var cell_size = 80

var grid = []

# --- ФУНКЦИЯ ЗАПУСКА ---
func _ready():
	for y in range(16):
		var row = []
		for x in range(32):
			row.append(0)
		grid.append(row)

	# создаем границы карты (номер 16 — стена)
	for y in range(16):
		for x in range(32):
			if x == 0 or y == 0 or x == 31 or y == 15:
				grid[y][x] = 16
	
	grid[1][1] = 2  # стартовая точка
	print(grid)
	generate(1, 1)


# --- ПРОВЕРКА ПЕРЕДВИЖЕНИЯ ---
func _process(delta):
	var grid_x = int(player.position.x / cell_size)
	var grid_y = int(player.position.y / cell_size)
	
	if grid[grid_y][grid_x] == 0:
		generate(grid_x, grid_y)


# --- ГЕНЕРАЦИЯ ---
func generate(grid_x, grid_y):
	# очищаем старые тайлы
	for child in get_children():
		if child != player:
			child.queue_free()
		
	# очищаем внутренние клетки
	for x in range(1, 31):
		for y in range(1, 15):
			if x != grid_x and y != grid_y:
				grid[y][x] = 0
				
	# создаем новые значения
	if grid[grid_y + 1][grid_x] != 16:
		var aaa = STRUCTS.find([randi() % 2, randi() % 2, 1, randi() % 2])
		grid[grid_y + 1][grid_x] = aaa
		
	if grid[grid_y - 1][grid_x] != 16:
		grid[grid_y - 1][grid_x] = STRUCTS.find([1, randi() % 2, randi() % 2, randi() % 2])
		
	if grid[grid_y][grid_x + 1] != 16:
		grid[grid_y][grid_x + 1] = STRUCTS.find([randi() % 2, 1, randi() % 2, randi() % 2])
		
	if grid[grid_y][grid_x - 1] != 16:
		grid[grid_y][grid_x - 1] = STRUCTS.find([randi() % 2, randi() % 2, randi() % 2, 1])
		
	# отрисовка тайлов
	_render_tile(grid_x, grid_y)          # центр
	_render_tile(grid_x, grid_y + 1)      # низ
	_render_tile(grid_x, grid_y - 1)      # верх
	_render_tile(grid_x + 1, grid_y)      # право
	_render_tile(grid_x - 1, grid_y)      # лево


# --- ОТРИСОВКА ТАЙЛА ---
func _render_tile(x, y):
	# Проверяем границы
	if x < 0 or x >= 32 or y < 0 or y >= 16:
		return
	
	var index = grid[y][x]
	if index < 0 or index >= tile_scenes.size():
		return
	
	var tile = tile_scenes[index].instantiate()
	add_child(tile)
	tile.position = Vector2(x * cell_size + cell_size / 2, y * cell_size + cell_size / 2)


# --- ДОБАВЛЕНИЕ КОЛЛИЗИИ ---
func add_collision_to_tile(tile):
	var static_body = StaticBody2D.new()
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	
	shape.size = Vector2(cell_size, cell_size)
	collision.shape = shape
	
	static_body.add_child(collision)
	tile.add_child(static_body)
