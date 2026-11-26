## One run at the game: the board and the dragon on it, from the first tick until the
## run ends. Rules that involve more than the dragon (food, score, what the dragon can
## run into) belong here, so Dragon stays about movement and app/ only draws.
class_name Session
extends RefCounted

enum Delivery { NONE, NEED_MORE, TOO_MANY, COMPLETE, TIMED_OUT, WRONG_RECIPE }

const INGREDIENT := "Cucumber"
const SALMON := "Salmon"
const INGREDIENT_TYPES := [INGREDIENT, SALMON]
const DELIVERY_BONUS := 5
const ORDER_TICKS := 100

var board: Board
var dragon: Dragon
var score := 0
var ended := false
var collision_cell := Vector2i(-1, -1)
var ingredients: Dictionary[String, Vector2i] = {}
var customer_cell := Vector2i(-1, -1)
var customer_order: Dictionary[String, int] = {}
var cargo: Dictionary[String, int] = {}
var delivery_result := Delivery.NONE
var customer_ticks_left := 0
var _pending_empty_segments := 0
var _rng := RandomNumberGenerator.new()


func _init(grid_size: Vector2i, seed_value := 121, layout: Board = null) -> void:
	board = layout if layout != null else Board.bordered(grid_size)
	dragon = Dragon.new(board.size, 4, board.start)
	_rng.seed = seed_value
	_stock_ingredients()
	_spawn_customer()
	_stock_ingredients()


func tick() -> void:
	if ended:
		return
	var next_head := dragon.next_head()
	var picked: Variant = ingredients.find_key(next_head)
	var picking_up := picked != null
	var grows := picking_up or _pending_empty_segments > 0
	var occupied_count := dragon.body.size() - (0 if grows else 1)
	var body_index := dragon.body.find(next_head)
	var hits_body := body_index >= 0 and body_index < occupied_count
	if board.is_solid(next_head) or hits_body:
		collision_cell = next_head
		ended = true
		return

	var old_tail: Vector2i = dragon.body.back()
	dragon.tick()
	if grows:
		dragon.body.append(old_tail)
	if not picking_up and _pending_empty_segments > 0:
		_pending_empty_segments -= 1
	if picking_up:
		score += 1
		cargo[picked] = cargo.get(picked, 0) + 1
		ingredients.erase(picked)
		delivery_result = Delivery.NONE
	if next_head == customer_cell:
		_try_delivery()
		if delivery_result in [Delivery.COMPLETE, Delivery.WRONG_RECIPE]:
			_stock_ingredients()
			return
	if customer_ticks_left > 0:
		customer_ticks_left -= 1
		if customer_ticks_left == 0:
			_pending_empty_segments += 1
			delivery_result = Delivery.TIMED_OUT
			_spawn_customer(customer_cell)
	if ingredients.size() < INGREDIENT_TYPES.size() or delivery_result == Delivery.TIMED_OUT:
		_stock_ingredients()


func _try_delivery() -> void:
	var required := _ingredient_count(customer_order)
	var collected := _ingredient_count(cargo)
	if collected < required:
		delivery_result = Delivery.NEED_MORE
		return
	if collected > required:
		delivery_result = Delivery.TOO_MANY
		return

	if cargo != customer_order:
		cargo.clear()
		_pending_empty_segments += 1
		delivery_result = Delivery.WRONG_RECIPE
		_spawn_customer(customer_cell)
		return

	cargo.clear()
	dragon.body.resize(dragon.body.size() - required)
	score += DELIVERY_BONUS
	delivery_result = Delivery.COMPLETE
	_spawn_customer()


func _ingredient_count(items: Dictionary[String, int]) -> int:
	var total := 0
	for count in items.values():
		total += count
	return total


func _stock_ingredients() -> void:
	if ingredients.size() == INGREDIENT_TYPES.size():
		return
	var needed: Array[String] = []
	for kind: String in customer_order:
		if cargo.get(kind, 0) < customer_order[kind]:
			needed.append(kind)
	var stocked := ingredients.values()
	var open_cells: Array[Vector2i] = []
	for y in board.size.y:
		for x in board.size.x:
			var cell := Vector2i(x, y)
			if cell == customer_cell or cell in stocked or cell in dragon.body:
				continue
			if not board.is_solid(cell):
				open_cells.append(cell)
	if not needed.is_empty() and not needed.any(func(kind): return ingredients.has(kind)):
		if open_cells.is_empty() and not ingredients.is_empty():
			var available_kind: String = ingredients.keys()[0]
			open_cells.append(ingredients[available_kind])
			ingredients.erase(available_kind)
		_stock_ingredient(needed[0], open_cells)
	for kind: String in INGREDIENT_TYPES:
		if not ingredients.has(kind):
			_stock_ingredient(kind, open_cells)


func _stock_ingredient(kind: String, open_cells: Array[Vector2i]) -> void:
	if not open_cells.is_empty():
		var index := _rng.randi_range(0, open_cells.size() - 1)
		ingredients[kind] = open_cells[index]
		open_cells.remove_at(index)


func _spawn_customer(previous_cell := Vector2i(-1, -1)) -> void:
	customer_cell = Vector2i(-1, -1)
	customer_order.clear()
	customer_ticks_left = 0
	var candidates: Array[Vector2i] = []
	var neighbors := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var stocked := ingredients.values()
	for y in board.size.y:
		for x in board.size.x:
			var cell := Vector2i(x, y)
			if cell == previous_cell or cell in stocked or cell in dragon.body:
				continue
			if board.kind_at(cell) != "floor":
				continue
			for direction: Vector2i in neighbors:
				if board.kind_at(cell + direction) == "wall":
					candidates.append(cell)
					break
	if not candidates.is_empty():
		customer_cell = candidates[_rng.randi_range(0, candidates.size() - 1)]
		for _index in _rng.randi_range(1, 3):
			var kind: String = INGREDIENT_TYPES[_rng.randi_range(0, INGREDIENT_TYPES.size() - 1)]
			customer_order[kind] = customer_order.get(kind, 0) + 1
		customer_ticks_left = ORDER_TICKS
