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
	session.dragon.turn(Vector2i.UP)
	session.tick()
	assert_eq(session.dragon.body[0], Vector2i(4, 3))
	assert_eq(session.score, 0)


func test_body_collision_ends_the_run() -> void:
	var session := Session.new(Vector2i(10, 10))
	session.ingredient_cell = Vector2i(1, 1)
	session.dragon.body = [
		Vector2i(5, 5), Vector2i(4, 5), Vector2i(4, 6),
		Vector2i(5, 6), Vector2i(6, 6),
	]
	session.dragon.turn(Vector2i.DOWN)
	session.tick()
	assert_true(session.ended)
	assert_eq(session.dragon.body[0], Vector2i(5, 5))


func test_head_can_enter_the_tail_cell_as_it_moves_away() -> void:
	var session := Session.new(Vector2i(10, 10))
	session.ingredient_cell = Vector2i(1, 1)
	session.dragon.body = [Vector2i(5, 5), Vector2i(4, 5), Vector2i(4, 6), Vector2i(5, 6)]
	session.dragon.turn(Vector2i.DOWN)
	session.tick()
	assert_true(not session.ended)
	assert_eq(session.dragon.body[0], Vector2i(5, 6))
