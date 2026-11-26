## The ground the dragon moves over: one tile kind per cell (Type Object).
## Rules ask what a kind means, never which kind it is, so a new kind is a new
## row in TILES plus a piece of the same name in tools/build_art.py.
class_name Board
extends RefCounted

## What each tile kind means to the rules.
const TILES := {
	"floor": {"solid": false},
	"wall": {"solid": true},
	"counter": {"solid": true},
	"table": {"solid": true},
}
const LEVELS_DIR := "res://levels"
const LEGEND := {".": "floor", "#": "wall", "C": "counter", "T": "table", "S": "floor"}

var size: Vector2i
var start := Vector2i(-1, -1)
var tiles := {}  # Vector2i cell -> tile kind name


static func level_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for filename in DirAccess.get_files_at(LEVELS_DIR):
		if filename.get_extension() == "txt":
			paths.append(LEVELS_DIR.path_join(filename))
	paths.sort()
	return paths


static func load_level(path: String) -> Board:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var rows := file.get_as_text().replace("\r\n", "\n").strip_edges().split("\n")
	var board := Board.new()
	board.size = Vector2i(rows[0].length(), rows.size())
	for y in board.size.y:
		if rows[y].length() != board.size.x:
			return null
		for x in board.size.x:
			var symbol := rows[y][x]
			if not LEGEND.has(symbol):
				return null
			var cell := Vector2i(x, y)
			var edge := x == 0 or y == 0 or x == board.size.x - 1 or y == board.size.y - 1
			if edge and symbol != "#":
				return null
			board.tiles[cell] = LEGEND[symbol]
			if symbol == "S":
				if board.start.x >= 0:
					return null
				board.start = cell
	if board.start.x < 0:
		return null
	for offset in range(-1, 4):
		if board.is_solid(board.start - Vector2i(offset, 0)):
			return null
	return board


## A floor ringed by walls: the default until you load levels from text files.
static func bordered(grid_size: Vector2i) -> Board:
	var board := Board.new()
	board.size = grid_size
	for x in grid_size.x:
		for y in grid_size.y:
			var edge := x == 0 or y == 0 or x == grid_size.x - 1 or y == grid_size.y - 1
			board.tiles[Vector2i(x, y)] = "wall" if edge else "floor"
	return board


func kind_at(cell: Vector2i) -> String:
	return tiles.get(cell, "wall")  # off the board counts as wall


func is_solid(cell: Vector2i) -> bool:
	return TILES[kind_at(cell)].solid
