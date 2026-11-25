## Engine adapter: keeps the clock, passes keys to the Session, and draws what it holds.
## It never decides rules: those live in core/session.gd.
extends Node3D

const TICK_SECONDS := 0.2
const MOVE_SECONDS := 0.17
const CAMERA_OFFSET := Vector3(0, 20, 10)
const ROUND_SEED := 121
const DIRECTIONS := {
	"ui_up": Vector2i.UP,
	"ui_down": Vector2i.DOWN,
	"ui_left": Vector2i.LEFT,
	"ui_right": Vector2i.RIGHT,
}

var layout := Board.restaurant()
var session := Session.new(layout.size, ROUND_SEED, layout)
var meshes := {}  # kit piece name -> Mesh, shared by everything that shows it (Flyweight)
var segments: Array[MeshInstance3D] = []
var camera := Camera3D.new()
var ingredient := MeshInstance3D.new()
var collision_marker := Label3D.new()
var score_label := Label.new()
var status_label := Label.new()
var game_over_panel := PanelContainer.new()
var final_score_label := Label.new()
var _movement: Tween
var _clock := 0.0
var _started := false


func _ready() -> void:
	meshes = Stage.load_kit()
	_build_stage()
	_build_pickup_display()
	_draw_dragon()
	_draw_pickup()


## Input arrives as events, so even a tap shorter than one frame is never missed.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if _started and not session.ended:
			return
		if session.ended:
			session = Session.new(layout.size, ROUND_SEED, layout)
			_draw_dragon()
		_started = true
		_clock = 0.0
		_draw_pickup()
		return
	if not _started or session.ended:
		return
	for action in DIRECTIONS:
		if event.is_action_pressed(action):
			session.dragon.turn(DIRECTIONS[action])


func _process(delta: float) -> void:
	if _started and not session.ended:
		_clock += delta
	while _clock >= TICK_SECONDS and not session.ended:
		_clock -= TICK_SECONDS
		session.tick()
		_draw_dragon(not session.ended)
		_draw_pickup()


## Frame the whole restaurant so a new ingredient is visible anywhere it spawns.
func _build_stage() -> void:
	add_child(Stage.new(session.board.tiles, meshes))
	add_child(camera)
	var center := Vector3(layout.size.x / 2.0, 0.0, layout.size.y / 2.0)
	camera.position = center + CAMERA_OFFSET
	camera.look_at(center)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	get_viewport().size_changed.connect(_frame_board)
	_frame_board()


func _frame_board() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var board_size := float(layout.size.x) * 1.22
	camera.size = board_size * maxf(1.0, viewport_size.y / maxf(viewport_size.x, 1.0))


func _draw_dragon(animate := false) -> void:
	var body := session.dragon.body
	var previous_count := segments.size()
	if _movement != null and _movement.is_valid():
		_movement.kill()
	if animate:
		_movement = create_tween().set_parallel()
	while segments.size() < body.size():
		var segment := MeshInstance3D.new()
		add_child(segment)
		segments.append(segment)
	var placed := Kit.layout(body)
	for i in segments.size():
		var segment := segments[i]
		var was_visible := i < previous_count and segment.visible
		segment.visible = i < body.size()
		if not segment.visible:
			continue
		var cell := body[i]
		segment.mesh = meshes[Kit.Piece.keys()[placed[i][0]].to_lower()]
		var target := _center(cell)
		if animate and was_visible:
			_movement.tween_property(segment, "position", target, MOVE_SECONDS)
		else:
			segment.position = target
		segment.rotation.y = placed[i][1] * PI / 2


func _center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, 0, cell.y + 0.5)


func _build_pickup_display() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.31
	mesh.height = 0.42
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("6fff31")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	ingredient.mesh = mesh
	add_child(ingredient)
	var base := MeshInstance3D.new()
	var plate := CylinderMesh.new()
	plate.top_radius = 0.40
	plate.bottom_radius = 0.40
	plate.height = 0.05
	var plate_material := StandardMaterial3D.new()
	plate_material.albedo_color = Color("182620")
	plate_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plate.material = plate_material
	base.mesh = plate
	base.position.y = -0.30
	ingredient.add_child(base)

	collision_marker.text = "×"
	collision_marker.font_size = 96
	collision_marker.outline_size = 14
	collision_marker.pixel_size = 0.012
	collision_marker.modulate = Color("ff413d")
	collision_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	collision_marker.no_depth_test = true
	add_child(collision_marker)

	var hud := CanvasLayer.new()
	add_child(hud)
	hud.add_child(score_label)
	score_label.position = Vector2(16, 12)
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(status_label)
	status_label.position = Vector2(16, 48)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_constant_override("outline_size", 6)
	_build_game_over(hud)


func _build_game_over(hud: CanvasLayer) -> void:
	var center := CenterContainer.new()
	hud.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(game_over_panel)
	game_over_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.06, 0.10, 0.88)
	background.set_corner_radius_all(12)
	background.content_margin_left = 24
	background.content_margin_right = 24
	background.content_margin_top = 14
	background.content_margin_bottom = 14
	game_over_panel.add_theme_stylebox_override("panel", background)
	var rows := VBoxContainer.new()
	game_over_panel.add_child(rows)
	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	rows.add_child(title)
	final_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(final_score_label)
	var restart := Label.new()
	restart.text = "Enter / Space to restart"
	restart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(restart)


func _draw_pickup() -> void:
	var cell := session.ingredient_cell
	ingredient.visible = not session.board.is_solid(cell)
	ingredient.position = _center(cell) + Vector3.UP * 0.35
	score_label.text = "Score: %d" % session.score
	collision_marker.visible = session.ended
	collision_marker.position = _center(session.collision_cell) + Vector3.UP
	game_over_panel.visible = session.ended
	final_score_label.text = "Final score: %d" % session.score
	if not _started:
		status_label.text = "Press Enter or Space to start · Arrow keys to steer"
	else:
		status_label.text = ""
