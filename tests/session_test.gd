extends "res://tests/test_case.gd"


func test_a_tick_moves_the_dragon_head() -> void:
	var session := Session.new(Vector2i(10, 10))
	session.tick()
	assert_eq(session.dragon.body[0], Vector2i(6, 5))


func test_the_dragon_starts_on_open_floor_inside_a_wall() -> void:
	var session := Session.new(Vector2i(10, 10))
	assert_true(session.board.is_solid(Vector2i(0, 0)))
	assert_true(not session.board.is_solid(session.dragon.body[0]))


func test_pickup_grows_the_belt_and_scores() -> void:
	var session := Session.new(Vector2i(10, 10))
	session.ingredient_cell = Vector2i(6, 5)
	var old_tail: Vector2i = session.dragon.body.back()
	assert_eq(session.dragon.body.size(), 4)
	assert_eq(session.score, 0)

	session.tick()

	assert_eq(session.dragon.body.size(), 5)
	assert_eq(session.score, 1)
	assert_eq(session.dragon.body.back(), old_tail)
	assert_true(not session.board.is_solid(session.ingredient_cell))
	assert_true(session.ingredient_cell not in session.dragon.body)


func test_same_seed_repeats_ingredient_placement() -> void:
	var first := Session.new(Vector2i(10, 10), 121)
	var second := Session.new(Vector2i(10, 10), 121)
	assert_eq(first.ingredient_cell, second.ingredient_cell)
	first.ingredient_cell = Vector2i(6, 5)
	second.ingredient_cell = first.ingredient_cell
	first.tick()
	second.tick()
	assert_eq(first.ingredient_cell, second.ingredient_cell)


func test_wall_collision_ends_the_run_before_moving() -> void:
	var session := Session.new(Vector2i(6, 6))
	session.ingredient_cell = Vector2i(1, 1)
	session.tick()
	assert_eq(session.dragon.body[0], Vector2i(4, 3))
	session.tick()
	assert_true(session.ended)
	assert_eq(session.collision_cell, Vector2i(5, 3))
	session.dragon.turn(Vector2i.UP)
	session.tick()
	assert_eq(session.dragon.body[0], Vector2i(4, 3))
	assert_eq(session.score, 0)


func test_body_collision_ends_the_run() -> void:
	var session := Session.new(Vector2i(10, 10))
	session.ingredient_cell = Vector2i(1, 1)
	session.dragon.body = [
		Vector2i(5, 5),
		Vector2i(4, 5),
		Vector2i(4, 6),
		Vector2i(5, 6),
		Vector2i(6, 6),
	]
	session.dragon.turn(Vector2i.DOWN)
	session.tick()
	assert_true(session.ended)
	assert_eq(session.collision_cell, Vector2i(5, 6))
	assert_eq(session.dragon.body[0], Vector2i(5, 5))


func test_head_can_enter_the_tail_cell_as_it_moves_away() -> void:
	var session := Session.new(Vector2i(10, 10))
	session.ingredient_cell = Vector2i(1, 1)
	session.dragon.body = [Vector2i(5, 5), Vector2i(4, 5), Vector2i(4, 6), Vector2i(5, 6)]
	session.dragon.turn(Vector2i.DOWN)
	session.tick()
	assert_true(not session.ended)
	assert_eq(session.dragon.body[0], Vector2i(5, 6))


func test_customer_and_order_are_reproducible_on_open_floor_beside_a_wall() -> void:
	var first := Session.new(Vector2i(10, 10), 121)
	var second := Session.new(Vector2i(10, 10), 121)
	var cell := first.customer_cell
	assert_eq(cell, second.customer_cell)
	assert_eq(first.customer_order, second.customer_order)
	assert_true(not first.customer_order.is_empty())
	assert_eq(first.board.kind_at(cell), "floor")
	assert_true(cell not in first.dragon.body and cell != first.ingredient_cell)
	assert_true(cell.x in [1, 8] or cell.y in [1, 8])


func test_ingredient_respawn_reserves_the_customer_cell() -> void:
	var session := Session.new(Vector2i(10, 10))
	session.board.tiles.clear()
	session.board.tiles[session.customer_cell] = "floor"
	session.ingredient_cell = session.dragon.next_head()
	session.board.tiles[session.ingredient_cell] = "floor"
	session.tick()
	assert_eq(session.score, 1)
	assert_eq(session.ingredient_cell, Vector2i(-1, -1))


func test_entering_customer_cell_without_enough_cargo_preserves_the_order() -> void:
	var session := Session.new(Vector2i(10, 10))
	session.ingredient_cell = Vector2i(1, 1)
	var customer := session.dragon.next_head()
	session.customer_cell = customer
	session.customer_order[Session.INGREDIENT] = 2
	session.tick()
	assert_eq(session.delivery_result, Session.Delivery.NEED_MORE)
	assert_eq(session.customer_cell, customer)
	assert_eq(session.customer_order[Session.INGREDIENT], 2)
	assert_eq(session.dragon.body.size(), 4)
	assert_eq(session.score, 0)


func test_exact_delivery_consumes_cargo_awards_points_and_shrinks_belt() -> void:
	var session := Session.new(Vector2i(10, 10))
	session.ingredient_cell = session.dragon.next_head()
	session.tick()
	assert_eq(session.cargo[Session.INGREDIENT], 1)
	assert_eq(session.dragon.body.size(), 5)

	session.ingredient_cell = Vector2i(1, 1)
	var customer := session.dragon.next_head()
	session.customer_cell = customer
	session.customer_order[Session.INGREDIENT] = 1
	session.customer_ticks_left = 1
	session.tick()
	assert_eq(session.delivery_result, Session.Delivery.COMPLETE)
	assert_true(session.cargo.is_empty())
	assert_eq(session.dragon.body.size(), 4)
	assert_eq(session.score, 1 + Session.DELIVERY_BONUS)
	assert_true(session.customer_cell != customer)
	assert_true(not session.customer_order.is_empty())
	assert_eq(session.customer_ticks_left, Session.ORDER_TICKS)


func test_timeout_replaces_customer_and_adds_one_empty_segment() -> void:
	var session := Session.new(Vector2i(10, 10))
	session.ingredient_cell = session.dragon.next_head()
	session.tick()
	session.ingredient_cell = Vector2i(1, 1)
	var old_customer := session.customer_cell
	session.customer_ticks_left = 1
	session.tick()
	assert_eq(session.delivery_result, Session.Delivery.TIMED_OUT)
	assert_true(session.customer_cell != old_customer)
	assert_eq(session.customer_ticks_left, Session.ORDER_TICKS)
	var tail: Vector2i = session.dragon.body.back()
	session.tick()
	assert_eq(session.dragon.body.size(), 6)
	assert_eq(session.dragon.body.back(), tail)
	assert_eq(session.cargo[Session.INGREDIENT], 1)
	assert_eq(session.score, 1)
