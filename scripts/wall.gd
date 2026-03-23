extends Node2D

@export var wall_size := Vector2(820.0, 320.0)
@export var cell_size := 24.0
@export var base_color := Color(0.81, 0.78, 0.72, 1.0)
@export var paint_color := Color(0.31, 0.62, 0.90, 1.0)
@export var frame_color := Color(0.21, 0.18, 0.15, 1.0)
@export var initial_min_coverage := 0.55
@export var initial_max_coverage := 0.78

var _columns := 0
var _rows := 0
var _coverage: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	randomize()
	_setup_grid()
	queue_redraw()


func get_wall_rect_global() -> Rect2:
	return Rect2(global_position, wall_size)


func get_coverage_ratio() -> float:
	if _coverage.is_empty():
		return 0.0
	var total := 0.0
	for amount in _coverage:
		total += amount
	return total / float(_coverage.size())


func paint_at(world_position: Vector2, radius: float, strength: float) -> void:
	_affect_cells(world_position, radius, strength)


func damage_at(world_position: Vector2, radius: float, strength: float) -> void:
	_affect_cells(world_position, radius, -strength)


func _setup_grid() -> void:
	_columns = maxi(1, int(ceil(wall_size.x / cell_size)))
	_rows = maxi(1, int(ceil(wall_size.y / cell_size)))

	_coverage.resize(_columns * _rows)
	for index in _coverage.size():
		_coverage[index] = randf_range(initial_min_coverage, initial_max_coverage)


func _affect_cells(world_position: Vector2, radius: float, delta_strength: float) -> void:
	if radius <= 0.0 or is_zero_approx(delta_strength):
		return

	var local_pos := to_local(world_position)
	var wall_rect := Rect2(Vector2.ZERO, wall_size)
	if not wall_rect.grow(radius).has_point(local_pos):
		return

	var min_col := maxi(0, int(floor((local_pos.x - radius) / cell_size)))
	var max_col := mini(_columns - 1, int(floor((local_pos.x + radius) / cell_size)))
	var min_row := maxi(0, int(floor((local_pos.y - radius) / cell_size)))
	var max_row := mini(_rows - 1, int(floor((local_pos.y + radius) / cell_size)))

	for row in range(min_row, max_row + 1):
		for col in range(min_col, max_col + 1):
			var index := row * _columns + col
			var center := Vector2((col + 0.5) * cell_size, (row + 0.5) * cell_size)
			var distance := center.distance_to(local_pos)
			if distance > radius:
				continue
			var falloff := 1.0 - (distance / radius)
			_coverage[index] = clampf(_coverage[index] + (delta_strength * falloff), 0.0, 1.0)

	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, wall_size), base_color)

	for row in range(_rows):
		for col in range(_columns):
			var index := row * _columns + col
			var tint := base_color.lerp(paint_color, _coverage[index])
			var cell_rect := Rect2(
				Vector2(col * cell_size, row * cell_size),
				Vector2(cell_size + 0.7, cell_size + 0.7)
			)
			draw_rect(cell_rect, tint)

	draw_rect(Rect2(Vector2.ZERO, wall_size), frame_color, false, 6.0)
