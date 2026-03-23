extends Node2D

@export var wall_size: Vector2 = Vector2(820.0, 320.0)
@export var cell_size: float = 24.0
@export var base_color: Color = Color(0.81, 0.78, 0.72, 1.0)
@export var paint_color: Color = Color(0.31, 0.62, 0.90, 1.0)
@export var frame_color: Color = Color(0.21, 0.18, 0.15, 1.0)
@export var initial_min_coverage: float = 0.55
@export var initial_max_coverage: float = 0.78

var _columns: int = 0
var _rows: int = 0
var _coverage: PackedFloat32Array = PackedFloat32Array()
var _avg_coverage: float = 0.0
var _lowest_coverage: float = 0.0


func _ready() -> void:
	randomize()
	_setup_grid()
	reset_coverage(initial_min_coverage, initial_max_coverage)


func configure(config: Dictionary) -> void:
	if config.has("wall_size"):
		wall_size = config["wall_size"]
	if config.has("cell_size"):
		cell_size = maxf(8.0, float(config["cell_size"]))
	if config.has("base_color"):
		base_color = config["base_color"]
	if config.has("paint_color"):
		paint_color = config["paint_color"]
	if config.has("frame_color"):
		frame_color = config["frame_color"]

	_setup_grid()
	var reset_min = initial_min_coverage
	var reset_max = initial_max_coverage
	if config.has("initial_min_coverage"):
		reset_min = float(config["initial_min_coverage"])
	if config.has("initial_max_coverage"):
		reset_max = float(config["initial_max_coverage"])
	reset_coverage(reset_min, reset_max)


func set_paint_color(color: Color) -> void:
	paint_color = color
	queue_redraw()


func reset_coverage(min_coverage: float, max_coverage: float) -> void:
	if _coverage.is_empty():
		_setup_grid()

	var safe_min = clampf(min_coverage, 0.0, 1.0)
	var safe_max = clampf(max_coverage, safe_min, 1.0)
	for index in _coverage.size():
		_coverage[index] = randf_range(safe_min, safe_max)

	_recalculate_cache()
	queue_redraw()


func get_wall_rect_global() -> Rect2:
	return Rect2(global_position, wall_size)


func get_coverage_ratio() -> float:
	return _avg_coverage


func get_lowest_coverage() -> float:
	return _lowest_coverage


func get_cell_count_below(threshold: float) -> int:
	var count = 0
	for value in _coverage:
		if value < threshold:
			count += 1
	return count


func get_total_cells() -> int:
	return _coverage.size()


func paint_at(world_position: Vector2, radius: float, strength: float) -> bool:
	return _affect_cells(world_position, radius, strength)


func damage_at(world_position: Vector2, radius: float, strength: float) -> bool:
	return _affect_cells(world_position, radius, -strength)


func _setup_grid() -> void:
	_columns = maxi(1, int(ceil(wall_size.x / cell_size)))
	_rows = maxi(1, int(ceil(wall_size.y / cell_size)))

	_coverage.resize(_columns * _rows)
	for index in _coverage.size():
		_coverage[index] = 0.0

	_recalculate_cache()


func _recalculate_cache() -> void:
	if _coverage.is_empty():
		_avg_coverage = 0.0
		_lowest_coverage = 0.0
		return

	var total = 0.0
	var lowest = 1.0
	for amount in _coverage:
		total += amount
		if amount < lowest:
			lowest = amount

	_avg_coverage = total / float(_coverage.size())
	_lowest_coverage = lowest


func _affect_cells(world_position: Vector2, radius: float, delta_strength: float) -> bool:
	if radius <= 0.0 or is_zero_approx(delta_strength):
		return false

	var local_pos = to_local(world_position)
	var wall_rect = Rect2(Vector2.ZERO, wall_size)
	if not wall_rect.grow(radius).has_point(local_pos):
		return false

	var min_col = maxi(0, int(floor((local_pos.x - radius) / cell_size)))
	var max_col = mini(_columns - 1, int(floor((local_pos.x + radius) / cell_size)))
	var min_row = maxi(0, int(floor((local_pos.y - radius) / cell_size)))
	var max_row = mini(_rows - 1, int(floor((local_pos.y + radius) / cell_size)))

	var changed = false
	for row in range(min_row, max_row + 1):
		for col in range(min_col, max_col + 1):
			var index = row * _columns + col
			var center = Vector2((col + 0.5) * cell_size, (row + 0.5) * cell_size)
			var distance = center.distance_to(local_pos)
			if distance > radius:
				continue

			var falloff = 1.0 - (distance / radius)
			var next_value = clampf(_coverage[index] + (delta_strength * falloff), 0.0, 1.0)
			if not is_equal_approx(next_value, _coverage[index]):
				_coverage[index] = next_value
				changed = true

	if changed:
		_recalculate_cache()
		queue_redraw()
	return changed


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, wall_size), base_color)

	for row in range(_rows):
		for col in range(_columns):
			var index = row * _columns + col
			var tint = base_color.lerp(paint_color, _coverage[index])
			var cell_rect = Rect2(
				Vector2(col * cell_size, row * cell_size),
				Vector2(cell_size + 0.7, cell_size + 0.7)
			)
			draw_rect(cell_rect, tint)

	draw_rect(Rect2(Vector2.ZERO, wall_size), frame_color, false, 6.0)
