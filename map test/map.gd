extends Node2D

#[верх, право, низ, лево]
const STRUCTS = [
	[0,0,0,0], [1,0,0,0], [0,1,0,0], [0,0,1,0], 
	[0,0,0,1], [1,1,0,0], [1,0,1,0], [1,0,0,1], 
	[0,1,1,0], [0,1,0,1], [0,0,1,1], [1,1,1,0],
	[1,1,0,1], [1,0,1,1], [0,1,1,1], [1,1,1,1],
	[-1,-1,-1,-1]
]

@export var tile_scene: PackedScene
@onready var player = $player
@onready var cell_size = 80

var grid = []

func _ready():
	for y in range(16):
		var row = []
		for x in range(32):
			row.append(0)
		grid.append(row)
	for y in range(16):
		for x in range(32):
			if x==0 or y==0 or x==31 or y==15:
				grid[y][x] = 16
	grid[1][1] = 2
	print(grid)
	generate(1, 1)

func _process(delta):
	var grid_x = int(player.position.x / cell_size)
	var grid_y = int(player.position.y / cell_size)
	
	if grid[grid_y][grid_x] == 0:
		generate(grid_x, grid_y)
	

func generate(grid_x, grid_y):
	for child in get_children():
		if child != player:
			child.queue_free()
		
	for x in range(1, 31):
		for y in range(1, 15):
			if x!=grid_x and y!=grid_y:
				grid[y][x] = 0
				
				
	if grid[grid_y+1][grid_x] != 16:
		var aaa = STRUCTS.find([randi() % 2, randi() % 2, 1, randi() % 2])
		print(aaa)
		grid[grid_y+1][grid_x] = aaa
		
	if grid[grid_y-1][grid_x] != 16:
		grid[grid_y-1][grid_x] = STRUCTS.find([1, randi() % 2, randi() % 2, randi() % 2])
		
	if grid[grid_y][grid_x+1] != 16:
		grid[grid_y][grid_x] = STRUCTS.find([randi() % 2, 1, randi() % 2, randi() % 2])
		
	if grid[grid_y][grid_x-1] != 16:
		grid[grid_y][grid_x-1] = STRUCTS.find([randi() % 2, randi() % 2, randi() % 2, 1])
		
	
	_render_tile(grid_y, grid_x)
	_render_tile(grid_y+1, grid_x)
	_render_tile(grid_y-1, grid_x)
	_render_tile(grid_y, grid_x+1)
	_render_tile(grid_y, grid_x-1)
	#print()
	#print(grid[grid_y][grid_x])
	print(grid[grid_y+1][grid_x])
	#print(grid[grid_y][grid_x+1])
	#print(grid[grid_y-1][grid_x])
	#print(grid[grid_y][grid_x-1])


func _render_tile(grid_x, grid_y):
	var t = tile_scene.instantiate()
	add_child(t)
	t.frame = grid[grid_y][grid_x-1]
	t.position = Vector2(grid_x * cell_size + cell_size/2, grid_y * cell_size + cell_size/2)
