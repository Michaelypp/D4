extends "res://tests/test_case.gd"

var board := Board.bordered(Vector2i(6, 4))


func test_border_is_solid() -> void:
	assert_true(board.is_solid(Vector2i(0, 2)))
	assert_true(board.is_solid(Vector2i(5, 3)))


func test_inside_is_open() -> void:
	assert_eq(board.kind_at(Vector2i(2, 2)), "floor")
	assert_true(not board.is_solid(Vector2i(2, 2)))


func test_off_the_board_counts_as_wall() -> void:
	assert_true(board.is_solid(Vector2i(-1, 9)))


func test_every_kind_has_rules() -> void:
	for cell in board.tiles:
		assert_true(board.tiles[cell] in Board.TILES)


func test_text_levels_load_with_a_clear_starting_belt_and_first_move() -> void:
	var paths := Board.level_paths()
	assert_true(paths.size() >= 3)
	for path in paths:
		var layout := Board.load_level(path)
		assert_true(layout != null)
		if layout == null:
			continue
		var session := Session.new(layout.size, 121, layout)
		assert_eq(session.dragon.body.size(), 4)
		assert_eq(session.dragon.body[0], layout.start)
		for cell in session.dragon.body:
			assert_true(not layout.is_solid(cell))
		assert_true(not layout.is_solid(session.dragon.next_head()))
