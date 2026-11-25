## One run at the game: the board and the dragon on it, from the first tick until the
## run ends. Rules that involve more than the dragon (food, score, what the dragon can
## run into) belong here, so Dragon stays about movement and app/ only draws.
class_name Session
extends RefCounted

enum Delivery { NONE, NEED_MORE, TOO_MANY, COMPLETE }

const INGREDIENT := "Cucumber"
const DELIVERY_BONUS := 5

var board: Board
var dragon: Dragon
var score := 0
var ended := false
var collision_cell := Vector2i(-1, -1)
var ingredient_cell := Vector2i(-1, -1)
var customer_cell := Vector2i(-1, -1)
var customer_order: Dictionary[String, int] = {}
var cargo: Dictionary[String, int] = {}
var delivery_result := Delivery.NONE
var _rng := RandomNumberGenerator.new()


func _init(grid_size: Vector2i, seed_value := 121, layout: Board = null) -> void:
	board = layout if layout != null else Board.bordered(grid_size)
	dragon = Dragon.new(board.size)
	_rng.seed = seed_value
	_spawn_ingredient()
	_spawn_customer()


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
		cargo[INGREDIENT] = cargo.get(INGREDIENT, 0) + 1
		delivery_result = Delivery.NONE
		_spawn_ingredient()
	if next_head == customer_cell:
		_try_delivery()


func _try_delivery() -> void:
	var required: int = customer_order[INGREDIENT]
	var collected: int = cargo.get(INGREDIENT, 0)
	if collected < required:
		delivery_result = Delivery.NEED_MORE
		return
	if collected > required:
		delivery_result = Delivery.TOO_MANY
		return

	cargo.clear()
	dragon.body.resize(dragon.body.size() - required)
	score += DELIVERY_BONUS
	delivery_result = Delivery.COMPLETE
	_spawn_customer()
	if board.is_solid(ingredient_cell):
		_spawn_ingredient()


func _spawn_ingredient() -> void:
	var open_cells: Array[Vector2i] = []
	for y in board.size.y:
		for x in board.size.x:
			var cell := Vector2i(x, y)
			if cell != customer_cell and not board.is_solid(cell) and cell not in dragon.body:
				open_cells.append(cell)
	ingredient_cell = Vector2i(-1, -1)
	if not open_cells.is_empty():
		ingredient_cell = open_cells[_rng.randi_range(0, open_cells.size() - 1)]


func _spawn_customer() -> void:
	customer_cell = Vector2i(-1, -1)
	customer_order.clear()
	var candidates: Array[Vector2i] = []
	var neighbors := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for y in board.size.y:
		for x in board.size.x:
			var cell := Vector2i(x, y)
			if board.kind_at(cell) != "floor" or cell == ingredient_cell or cell in dragon.body:
				continue
			for direction: Vector2i in neighbors:
				if board.kind_at(cell + direction) == "wall":
					candidates.append(cell)
					break
	if not candidates.is_empty():
		customer_cell = candidates[_rng.randi_range(0, candidates.size() - 1)]
		customer_order[INGREDIENT] = _rng.randi_range(1, 3)
