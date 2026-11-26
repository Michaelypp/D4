## Engine adapter: keeps the clock, passes keys to the Session, and draws what it holds.
## It never decides rules: those live in core/session.gd.
extends Node3D

const TICK_SECONDS := 0.2
const MOVE_SECONDS := 0.17
const HUD_HEIGHT := 124.0
const CAMERA_OFFSET := Vector3(0, 20, 10)
const ROUND_SEED := 121
const SCORES_PATH := "user://restaurant_scores.cfg"
const DIRECTIONS := {
	"ui_up": Vector2i.UP,
	"ui_down": Vector2i.DOWN,
	"ui_left": Vector2i.LEFT,
	"ui_right": Vector2i.RIGHT,
}

var layout: Board
var session: Session
var stage: Stage
var levels: Array[Board] = []
var level_names := PackedStringArray()
var level_index := 0
var meshes := {}  # kit piece name -> Mesh, shared by everything that shows it (Flyweight)
var segments: Array[MeshInstance3D] = []
var camera := Camera3D.new()
var ingredient_markers: Dictionary[String, MeshInstance3D] = {}
var collision_marker := Label3D.new()
var customer_marker := MeshInstance3D.new()
var score_label := Label.new()
var order_label := Label.new()
var order_timer := ProgressBar.new()
var order_timer_fill := StyleBoxFlat.new()
var status_label := Label.new()
var level_label := Label.new()
var game_over_panel := PanelContainer.new()
var final_score_label := Label.new()
var _movement: Tween
var _clock := 0.0
var _started := false
var _paused := false
var _best_scores: Dictionary = {}


func _ready() -> void:
	_load_best_scores()
	meshes = Stage.load_kit()
	for path in Board.level_paths():
		var board := Board.load_level(path)
		if board == null:
			push_warning("Invalid restaurant layout: %s" % path)
			continue
		levels.append(board)
		level_names.append(path.get_file().get_basename())
	if levels.is_empty():
		levels.append(Board.bordered(Vector2i(20, 20)))
		level_names.append("Practice Floor")
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	get_viewport().size_changed.connect(_frame_board)
	_build_pickup_display()
	_select_level()


func _select_level() -> void:
	layout = levels[level_index]
	session = Session.new(layout.size, ROUND_SEED, layout)
	_started = false
	_paused = false
	_clock = 0.0
	_build_stage()
	_draw_dragon()
	_draw_pickup()


## Input arrives as events, so even a tap shorter than one frame is never missed.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		if levels.size() > 1 and (not _started or session.ended):
			level_index = (level_index + 1) % levels.size()
			_select_level()
		return
	if event.is_action_pressed("ui_accept"):
		if _started and not session.ended:
			return
		if session.ended:
			session = Session.new(layout.size, ROUND_SEED, layout)
			_draw_dragon()
		_started = true
		_paused = false
		_clock = 0.0
		_draw_pickup()
		return
	if not _started or session.ended:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_paused = not _paused
		if _movement != null and _movement.is_valid():
			if _paused:
				_movement.pause()
			else:
				_movement.play()
		_draw_pickup()
		return
	if _paused:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X:
		session.discard_cargo()
		_draw_pickup()
	else:
		for action in DIRECTIONS:
			if event.is_action_pressed(action):
				session.dragon.turn(DIRECTIONS[action])


func _process(delta: float) -> void:
	if _paused:
		return
	if _started and not session.ended:
		_clock += delta
	while _clock >= TICK_SECONDS and not session.ended:
		_clock -= TICK_SECONDS
		session.tick()
		if session.ended:
			_record_best_score()
		_draw_dragon(not session.ended)
		_draw_pickup()


func _load_best_scores() -> void:
	var config := ConfigFile.new()
	if config.load(SCORES_PATH) == OK:
		var scores: Variant = config.get_value("scores", "restaurants", {})
		if scores is Dictionary:
			_best_scores = scores


func _record_best_score() -> void:
	var restaurant := level_names[level_index]
	if session.score <= int(_best_scores.get(restaurant, 0)):
		return
	_best_scores[restaurant] = session.score
	var config := ConfigFile.new()
	config.set_value("scores", "restaurants", _best_scores)
	if config.save(SCORES_PATH) != OK:
		push_warning("Could not save restaurant records to local storage.")


## Frame the whole restaurant so a new ingredient is visible anywhere it spawns.
func _build_stage() -> void:
	if stage != null:
		stage.free()
	stage = Stage.new(layout.tiles, meshes)
	add_child(stage)
	var center := Vector3(layout.size.x / 2.0, 0.0, layout.size.y / 2.0)
	camera.position = center + CAMERA_OFFSET
	camera.look_at(center)
	_frame_board()


func _frame_board() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var play_height := maxf(1.0, viewport_size.y - HUD_HEIGHT)
	var play_width := maxf(1.0, viewport_size.x)
	var board_size := float(maxi(layout.size.x, layout.size.y)) * 1.10
	camera.size = board_size * viewport_size.y / minf(play_height, play_width)
	camera.v_offset = camera.size * HUD_HEIGHT / (2.0 * maxf(viewport_size.y, 1.0))


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


func _make_ingredient_marker(mesh: PrimitiveMesh, color: Color) -> MeshInstance3D:
	var ingredient := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
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
	return ingredient


func _build_pickup_display() -> void:
	var cucumber := CylinderMesh.new()
	cucumber.top_radius = 0.28
	cucumber.bottom_radius = 0.28
	cucumber.height = 0.20
	ingredient_markers[Session.INGREDIENT] = _make_ingredient_marker(cucumber, Color("6fff31"))
	var salmon := BoxMesh.new()
	salmon.size = Vector3(0.65, 0.18, 0.34)
	var salmon_marker := _make_ingredient_marker(salmon, Color("ff7944"))
	ingredient_markers[Session.SALMON] = salmon_marker
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(0.055, 0.018, 0.35)
	var stripe_material := StandardMaterial3D.new()
	stripe_material.albedo_color = Color("fff0d6")
	stripe_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stripe_mesh.material = stripe_material
	for x: float in [-0.18, 0.0, 0.18]:
		var stripe := MeshInstance3D.new()
		stripe.mesh = stripe_mesh
		stripe.position = Vector3(x, 0.093, 0.0)
		stripe.rotation.y = PI / 7.0
		salmon_marker.add_child(stripe)
	collision_marker.text = "×"
	collision_marker.font_size = 96
	collision_marker.outline_size = 14
	collision_marker.pixel_size = 0.012
	collision_marker.modulate = Color("ff413d")
	collision_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	collision_marker.no_depth_test = true
	add_child(collision_marker)
	var diamond := BoxMesh.new()
	diamond.size = Vector3(0.53, 0.12, 0.53)
	var customer_material := StandardMaterial3D.new()
	customer_material.albedo_color = Color("e449e0")
	customer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	diamond.material = customer_material
	customer_marker.mesh = diamond
	customer_marker.rotation.y = PI / 4.0
	add_child(customer_marker)

	var hud := CanvasLayer.new()
	add_child(hud)
	hud.add_child(score_label)
	score_label.position = Vector2(16, 12)
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(status_label)
	status_label.position = Vector2(16, 62)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(level_label)
	level_label.position = Vector2(16, 84)
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(order_label)
	order_label.position = Vector2(16, 40)
	order_label.add_theme_font_size_override("font_size", 20)
	order_label.add_theme_constant_override("outline_size", 6)
	order_label.add_theme_color_override("font_color", Color("ffb9f9"))
	hud.add_child(order_timer)
	order_timer.position = Vector2(16, 108)
	order_timer.size = Vector2(190, 6)
	order_timer.max_value = Session.ORDER_TICKS
	order_timer.show_percentage = false
	order_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var timer_track := StyleBoxFlat.new()
	timer_track.bg_color = Color("3a242d")
	timer_track.set_corner_radius_all(3)
	order_timer_fill.set_corner_radius_all(3)
	order_timer.add_theme_stylebox_override("background", timer_track)
	order_timer.add_theme_stylebox_override("fill", order_timer_fill)
	_build_game_over(hud)


func _build_game_over(hud: CanvasLayer) -> void:
	var center := CenterContainer.new()
	hud.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = HUD_HEIGHT
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
	restart.text = "Enter / Space: restart · Tab: change restaurant"
	restart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(restart)


func _draw_pickup() -> void:
	for kind: String in ingredient_markers:
		var marker := ingredient_markers[kind]
		marker.visible = session.ingredients.has(kind)
		if marker.visible:
			marker.position = _center(session.ingredients[kind]) + Vector3.UP * 0.35
	score_label.text = (
		"Score: %d   |   Cargo: %s" % [session.score, _format_ingredients(session.cargo)]
	)
	customer_marker.visible = not session.customer_order.is_empty()
	customer_marker.position = _center(session.customer_cell) + Vector3.UP * 0.6
	order_label.text = ""
	order_timer.visible = customer_marker.visible
	if customer_marker.visible:
		_draw_order_progress()
	collision_marker.visible = session.ended
	collision_marker.position = _center(session.collision_cell) + Vector3.UP
	game_over_panel.visible = session.ended
	var restaurant := level_names[level_index]
	var best := int(_best_scores.get(restaurant, 0))
	final_score_label.text = "Final score: %d  ·  Best: %d" % [session.score, best]
	level_label.text = "%s  ·  Best: %d" % [restaurant, best]
	if not _started and levels.size() > 1:
		level_label.text += "  ·  Tab to change"
	elif _started and not session.ended and not _paused:
		level_label.text += "  ·  P to pause"
	if not _started:
		status_label.text = "Press Enter or Space to start · Arrow keys to steer"
	elif _paused:
		status_label.text = "Paused · Press P to resume"
	else:
		match session.delivery_result:
			Session.Delivery.NEED_MORE:
				status_label.text = "Collect the missing ingredients, then return."
			Session.Delivery.TOO_MANY:
				status_label.text = "Too much cargo. Press X to discard it."
			Session.Delivery.COMPLETE:
				status_label.text = "Delivered! +%d points" % Session.DELIVERY_BONUS
			Session.Delivery.TIMED_OUT:
				status_label.text = "Order expired. +1 empty belt segment."
			Session.Delivery.WRONG_RECIPE:
				status_label.text = "Wrong recipe. Cargo cleared, +1 empty segment."
			Session.Delivery.DISCARDED:
				status_label.text = "Cargo discarded. Collect a fresh order."
			_:
				status_label.text = "" if session.cargo.is_empty() else "X: discard cargo"


func _draw_order_progress() -> void:
	var parts := PackedStringArray()
	for kind: String in Session.INGREDIENT_TYPES:
		if session.customer_order.has(kind):
			var carried: int = session.cargo.get(kind, 0)
			parts.append("%s %d/%d" % [kind, carried, session.customer_order[kind]])
	var seconds := ceili(session.customer_ticks_left * TICK_SECONDS)
	order_label.text = "Order: %s   |   %ds" % [", ".join(parts), seconds]
	order_timer.value = session.customer_ticks_left
	if seconds <= 5:
		order_timer_fill.bg_color = Color("ff6682")
	elif seconds <= 10:
		order_timer_fill.bg_color = Color("ffcd70")
	else:
		order_timer_fill.bg_color = Color("78e5b1")


func _format_ingredients(items: Dictionary[String, int]) -> String:
	if items.is_empty():
		return "Empty"
	var parts := PackedStringArray()
	for kind: String in Session.INGREDIENT_TYPES:
		if items.has(kind):
			parts.append("%s ×%d" % [kind, items[kind]])
	return ", ".join(parts)
