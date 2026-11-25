## One run at the game: the board and the dragon on it, from the first tick until the
## run ends. Rules that involve more than the dragon (food, score, what the dragon can
## run into) belong here, so Dragon stays about movement and app/ only draws.
class_name Session
extends RefCounted

var board: Board
var dragon: Dragon
var score := 0
var ended := false
var collision_cell := Vector2i(-1, -1)
var ingredient_cell := Vector2i(-1, -1)
var _rng := RandomNumberGenerator.new()


func _init(grid_size: Vector2i, seed_value := 121, layout: Board = null) -> void:
	board = layout if layout != null else Board.bordered(grid_size)
	dragon = Dragon.new(board.size)
	_rng.seed = seed_value
	_spawn_ingredient()


func tick() -> void:
	if ended:
		return
	var next_head := dragon.next_head()
	var picking_up := next_head == ingredient_cell
	var occupied_count := dragon.body.size() - (0 if picking_up else 1)
	var body_index := dragon.body.find(next_head)
	var hits_body := body_index >= 0 and body_index < occupied_count
	if board.is_solid(next_head) or hits_body:
		collision_cell = next_head
		ended = true
		return

	var old_tail: Vector2i = dragon.body.back()
	dragon.tick()
	if picking_up:
		dragon.body.append(old_tail)
		score += 1
		_spawn_ingredient()


func _spawn_ingredient() -> void:
	var open_cells: Array[Vector2i] = []
	for y in board.size.y:
		for x in board.size.x:
			var cell := Vector2i(x, y)
			if not board.is_solid(cell) and cell not in dragon.body:
				open_cells.append(cell)
	ingredient_cell = Vector2i(-1, -1)
	if not open_cells.is_empty():
		ingredient_cell = open_cells[_rng.randi_range(0, open_cells.size() - 1)]
