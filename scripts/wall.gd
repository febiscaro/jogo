extends Node2D

@export var wall_size: Vector2 = Vector2(820.0, 320.0)
@export var cell_size: float = 24.0
@export var base_color: Color = Color(0.81, 0.78, 0.72, 1.0)
@export var paint_color: Color = Color(0.31, 0.62, 0.90, 1.0)
@export var frame_color: Color = Color(0.21, 0.18, 0.15, 1.0)
@export var mortar_color: Color = Color(0.66, 0.63, 0.57, 0.18)
@export var grime_color: Color = Color(0.18, 0.21, 0.24, 0.15)
@export var initial_min_coverage: float = 0.55
@export var initial_max_coverage: float = 0.78
@export var drip_start_coverage: float = 0.74
@export var drip_rate: float = 0.34
@export var drip_spread: float = 0.58
@export var drip_loss_rate: float = 0.06
@export var guide_alpha: float = 0.20
@export var texture_strength: float = 0.34
@export var wet_specular_strength: float = 0.28
@export var grime_strength: float = 0.22
@export var frame_wear: float = 0.30

var _columns: int = 0
var _rows: int = 0
var _coverage: PackedFloat32Array = PackedFloat32Array()
var _avg_coverage: float = 0.0
var _progress_ratio: float = 0.0
var _avg_color_match: float = 1.0
var _lowest_coverage: float = 0.0
var _lowest_index: int = 0
var _anim_time: float = 0.0
var _drip_intensity: float = 0.0
var _damage_heat: float = 0.0
var _palette: Array[Color] = [
	Color(0.31, 0.62, 0.90, 1.0),
	Color(0.89, 0.30, 0.27, 1.0),
	Color(0.24, 0.74, 0.50, 1.0),
	Color(0.67, 0.45, 0.88, 1.0),
]
var _cell_paint_color: PackedColorArray = PackedColorArray()
var _target_color_indices: PackedInt32Array = PackedInt32Array()
var _pattern_mode: String = "solid"
var _pattern_colors: Array[int] = [0]
var _stripe_width_cells: int = 3


func _ready() -> void:
	randomize()
	_setup_grid()
	reset_coverage(initial_min_coverage, initial_max_coverage)


func _process(delta: float) -> void:
	_anim_time += delta
	_damage_heat = maxf(0.0, _damage_heat - delta * 0.42)
	_simulate_runoff(delta)
	queue_redraw()


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
	if config.has("palette"):
		var palette_input = config["palette"]
		if palette_input is Array:
			var incoming = palette_input as Array
			_palette.clear()
			for entry in incoming:
				if entry is Color:
					_palette.append(entry)
	if _palette.is_empty():
		_palette = [
			Color(0.31, 0.62, 0.90, 1.0),
			Color(0.89, 0.30, 0.27, 1.0),
			Color(0.24, 0.74, 0.50, 1.0),
			Color(0.67, 0.45, 0.88, 1.0),
		]
	if config.has("pattern_mode"):
		_pattern_mode = String(config["pattern_mode"])
	if config.has("stripe_width_cells"):
		_stripe_width_cells = maxi(1, int(config["stripe_width_cells"]))
	if config.has("pattern_colors"):
		_pattern_colors = _sanitize_pattern_colors(config["pattern_colors"])
	else:
		_pattern_colors = _sanitize_pattern_colors(_pattern_colors)

	_setup_grid()
	_build_target_pattern()
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
	if _target_color_indices.is_empty():
		_build_target_pattern()

	var safe_min = clampf(min_coverage, 0.0, 1.0)
	var safe_max = clampf(max_coverage, safe_min, 1.0)
	for index in range(_coverage.size()):
		var coverage = randf_range(safe_min, safe_max)
		_coverage[index] = coverage
		var target_color = _target_color_for_cell(index)
		var noise = randf_range(-0.05, 0.05)
		var cell_color = Color(
			clampf(target_color.r + noise, 0.0, 1.0),
			clampf(target_color.g + noise, 0.0, 1.0),
			clampf(target_color.b + noise, 0.0, 1.0),
			1.0
		)
		var faded = base_color.lerp(cell_color, clampf(coverage * 0.86, 0.22, 1.0))
		_cell_paint_color[index] = faded

	_recalculate_cache()
	queue_redraw()


func get_wall_rect_global() -> Rect2:
	return Rect2(global_position, wall_size)


func get_coverage_ratio() -> float:
	return _progress_ratio


func get_raw_coverage_ratio() -> float:
	return _avg_coverage


func get_color_match_ratio() -> float:
	return _avg_color_match


func get_lowest_coverage() -> float:
	return _lowest_coverage


func get_target_color_at(world_position: Vector2) -> Color:
	if _coverage.is_empty():
		return paint_color
	var local = to_local(world_position)
	var col = clampi(int(floor(local.x / cell_size)), 0, _columns - 1)
	var row = clampi(int(floor(local.y / cell_size)), 0, _rows - 1)
	var index = row * _columns + col
	return _target_color_for_cell(index)


func get_lowest_cell_world_pos() -> Vector2:
	if _columns <= 0 or _rows <= 0:
		return global_position + wall_size * 0.5
	var row = int(floor(float(_lowest_index) / float(_columns)))
	var col = _lowest_index % _columns
	var local = Vector2((float(col) + 0.5) * cell_size, (float(row) + 0.5) * cell_size)
	return to_global(local)


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
	var changed = _affect_cells(world_position, radius, -strength)
	if changed:
		_damage_heat = minf(1.4, _damage_heat + absf(strength) * 36.0)
	return changed


func set_drip_intensity(value: float) -> void:
	_drip_intensity = clampf(value, 0.0, 1.8)


func _setup_grid() -> void:
	_columns = maxi(1, int(ceil(wall_size.x / cell_size)))
	_rows = maxi(1, int(ceil(wall_size.y / cell_size)))

	var total_cells = _columns * _rows
	_coverage.resize(total_cells)
	_cell_paint_color.resize(total_cells)
	_target_color_indices.resize(total_cells)
	for index in range(total_cells):
		_coverage[index] = 0.0
		_cell_paint_color[index] = paint_color
		_target_color_indices[index] = 0

	_recalculate_cache()


func _recalculate_cache() -> void:
	if _coverage.is_empty():
		_avg_coverage = 0.0
		_progress_ratio = 0.0
		_avg_color_match = 1.0
		_lowest_coverage = 0.0
		return

	var total = 0.0
	var total_progress = 0.0
	var total_match = 0.0
	var lowest = 1.0
	var lowest_index = 0
	for i in range(_coverage.size()):
		var amount = _coverage[i]
		total += amount
		var match = _color_match_ratio(_cell_paint_color[i], _target_color_for_cell(i))
		total_match += match
		total_progress += amount * lerpf(0.30, 1.0, match)
		if amount < lowest:
			lowest = amount
			lowest_index = i

	_avg_coverage = total / float(_coverage.size())
	_progress_ratio = total_progress / float(_coverage.size())
	_avg_color_match = total_match / float(_coverage.size())
	_lowest_coverage = lowest
	_lowest_index = lowest_index


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
			var previous_value = _coverage[index]
			var next_value = previous_value
			var previous_color = _cell_paint_color[index]
			var next_color = previous_color
			if delta_strength > 0.0:
				var target_color = _target_color_for_cell(index)
				var color_match = _color_match_ratio(paint_color, target_color)
				var efficiency = lerpf(0.28, 1.22, color_match)
				next_value = clampf(previous_value + (delta_strength * falloff * efficiency), 0.0, 1.0)
				var blend = clampf(delta_strength * falloff * (0.62 + efficiency * 0.38), 0.0, 1.0)
				next_color = previous_color.lerp(paint_color, blend)
			else:
				next_value = clampf(previous_value + (delta_strength * falloff), 0.0, 1.0)
				var fade_back = clampf(absf(delta_strength) * falloff * 0.24, 0.0, 0.8)
				next_color = previous_color.lerp(base_color, fade_back)

			if not is_equal_approx(next_value, previous_value) or next_color != previous_color:
				_coverage[index] = next_value
				_cell_paint_color[index] = next_color
				changed = true

	if changed:
		_recalculate_cache()
		queue_redraw()
	return changed


func _draw() -> void:
	_draw_wall_base()

	for row in range(_rows):
		for col in range(_columns):
			var index = row * _columns + col
			var coverage = _coverage[index]
			var cell_paint = _cell_paint_color[index]
			var tint = base_color.lerp(cell_paint, coverage)
			var noise = _get_cell_noise(col, row)
			var texture_mod = 1.0 + noise * texture_strength * 0.16
			tint = Color(
				clampf(tint.r * texture_mod, 0.0, 1.0),
				clampf(tint.g * texture_mod, 0.0, 1.0),
				clampf(tint.b * texture_mod, 0.0, 1.0),
				1.0
			)
			tint = tint.darkened((1.0 - coverage) * 0.10 + absf(noise) * 0.04)

			var cell_pos = Vector2(float(col) * cell_size, float(row) * cell_size)
			var cell_w = minf(cell_size, wall_size.x - cell_pos.x)
			var cell_h = minf(cell_size, wall_size.y - cell_pos.y)
			if cell_w <= 0.0 or cell_h <= 0.0:
				continue

			var cell_rect = Rect2(cell_pos, Vector2(cell_w, cell_h))
			draw_rect(cell_rect, tint)
			var top_band_h = maxf(1.0, cell_h * 0.14)
			var bottom_band_h = maxf(1.0, cell_h * 0.16)
			draw_rect(
				Rect2(cell_rect.position, Vector2(cell_w, top_band_h)),
				Color(1.0, 1.0, 1.0, 0.04 + coverage * 0.04 + maxf(0.0, noise) * 0.05)
			)
			draw_rect(
				Rect2(cell_rect.position + Vector2(0.0, cell_h - bottom_band_h), Vector2(cell_w, bottom_band_h)),
				Color(0.0, 0.0, 0.0, 0.03 + (1.0 - coverage) * 0.06)
			)
			if cell_w > 2.0 and cell_h > 2.0:
				draw_rect(
					cell_rect,
					Color(mortar_color.r, mortar_color.g, mortar_color.b, mortar_color.a * (0.46 + (1.0 - coverage) * 0.45)),
					false,
					1.0
				)

			if coverage > 0.58 and (_drip_intensity > 0.14 or _damage_heat > 0.12):
				var glint = 0.04 + (_drip_intensity * wet_specular_strength * 0.10) + maxf(0.0, noise) * 0.03
				draw_line(
					cell_rect.position + Vector2(cell_w * 0.28, cell_h * 0.18),
					cell_rect.position + Vector2(cell_w * 0.72, cell_h * 0.88),
					Color(0.96, 0.98, 1.0, glint),
					1.0
				)

			if coverage < 0.28 and (col + row) % 2 == 0:
				_draw_cell_cracks(cell_rect, coverage)
			if coverage < 0.44 and (col * 7 + row * 5) % 9 == 0:
				var streak_top = cell_rect.position + Vector2(cell_rect.size.x * 0.5, cell_rect.size.y * 0.35)
				var streak_len = 6.0 + (1.0 - coverage) * 14.0
				draw_line(
					streak_top,
					streak_top + Vector2(0.0, streak_len),
					Color(grime_color.r, grime_color.g, grime_color.b, 0.18 + grime_strength * 0.24),
					1.0
				)

	_draw_surface_grime_overlay()
	_draw_wet_streaks()
	_draw_pattern_guides()
	_draw_weakest_marker()
	_draw_shine()
	_draw_frame_ambient_occlusion()
	_draw_frame_details()


func _simulate_runoff(delta: float) -> void:
	if delta <= 0.0 or _rows <= 1 or _columns <= 0:
		return

	var flow_boost = clampf(_drip_intensity + (_damage_heat * 1.15), 0.0, 2.2)
	var active_rate = drip_rate * (0.42 + flow_boost)
	if active_rate <= 0.0:
		return

	var next_coverage: PackedFloat32Array = _coverage.duplicate()
	var changed = false

	for row in range(_rows - 2, -1, -1):
		for col in range(_columns):
			var index = row * _columns + col
			var amount = next_coverage[index]
			if amount <= drip_start_coverage:
				continue

			var excess = amount - drip_start_coverage
			var runoff = minf(excess, active_rate * delta * (0.36 + excess))
			if runoff <= 0.0001:
				continue

			var remain = runoff
			var below_index = index + _columns
			var below_capacity = maxf(0.0, 1.0 - next_coverage[below_index])
			var down_bias = 0.72 + (flow_boost * 0.10)
			var move_down = minf(remain, minf(remain * down_bias, below_capacity))
			if move_down > 0.0:
				next_coverage[index] -= move_down
				next_coverage[below_index] += move_down
				remain -= move_down
				changed = true

			if remain <= 0.0001:
				continue

			var side_targets: Array[int] = []
			if col > 0:
				side_targets.append(below_index - 1)
			if col < _columns - 1:
				side_targets.append(below_index + 1)

			if not side_targets.is_empty():
				var side_total = remain * drip_spread
				var each = side_total / float(side_targets.size())
				var moved_side = 0.0
				for target in side_targets:
					var cap = maxf(0.0, 1.0 - next_coverage[target])
					var add = minf(each, cap)
					if add <= 0.0:
						continue
					next_coverage[target] += add
					moved_side += add
					changed = true
				if moved_side > 0.0:
					next_coverage[index] -= moved_side

	for col in range(_columns):
		var bottom_index = (_rows - 1) * _columns + col
		var bottom_amount = next_coverage[bottom_index]
		if bottom_amount <= drip_start_coverage:
			continue

		var bottom_excess = bottom_amount - drip_start_coverage
		var loss = minf(bottom_amount, drip_loss_rate * delta * bottom_excess * (0.42 + flow_boost))
		if loss <= 0.0001:
			continue
		next_coverage[bottom_index] -= loss
		changed = true

	if changed:
		_coverage = next_coverage
		_recalculate_cache()


func _sanitize_pattern_colors(raw_value) -> Array[int]:
	var result: Array[int] = []
	if raw_value is Array:
		for entry in raw_value:
			var idx = clampi(int(entry), 0, _palette.size() - 1)
			if not result.has(idx):
				result.append(idx)
	if result.is_empty():
		result.append(0)
	return result


func _build_target_pattern() -> void:
	if _target_color_indices.is_empty():
		return
	_pattern_colors = _sanitize_pattern_colors(_pattern_colors)
	var stripe_size = maxi(1, _stripe_width_cells)
	for row in range(_rows):
		for col in range(_columns):
			var index = row * _columns + col
			var palette_index = _pattern_colors[0]
			match _pattern_mode:
				"stripe_h":
					var band_h = int(floor(float(row) / float(stripe_size))) % _pattern_colors.size()
					palette_index = _pattern_colors[band_h]
				"stripe_v":
					var band_v = int(floor(float(col) / float(stripe_size))) % _pattern_colors.size()
					palette_index = _pattern_colors[band_v]
				"checker":
					var band_c = (int(floor(float(col) / float(stripe_size))) + int(floor(float(row) / float(stripe_size)))) % _pattern_colors.size()
					palette_index = _pattern_colors[band_c]
				_:
					palette_index = _pattern_colors[0]
			_target_color_indices[index] = clampi(palette_index, 0, _palette.size() - 1)


func _target_color_for_cell(index: int) -> Color:
	if _palette.is_empty():
		return paint_color
	if index < 0 or index >= _target_color_indices.size():
		return _palette[0]
	var color_index = clampi(_target_color_indices[index], 0, _palette.size() - 1)
	return _palette[color_index]


func _color_match_ratio(a: Color, b: Color) -> float:
	var dr = a.r - b.r
	var dg = a.g - b.g
	var db = a.b - b.b
	var dist = sqrt((dr * dr) + (dg * dg) + (db * db))
	return clampf(1.0 - (dist / 1.32), 0.0, 1.0)


func _draw_pattern_guides() -> void:
	if _pattern_mode == "solid" or _target_color_indices.is_empty():
		return

	var stripe_size = maxi(1, _stripe_width_cells)
	match _pattern_mode:
		"stripe_h":
			var y = 0.0
			var band = 0
			while y < wall_size.y:
				var idx = _pattern_colors[band % _pattern_colors.size()]
				var color = _palette[clampi(idx, 0, _palette.size() - 1)]
				var h = minf(float(stripe_size) * cell_size, wall_size.y - y)
				draw_rect(Rect2(0.0, y, wall_size.x, h), Color(color.r, color.g, color.b, guide_alpha * 0.34))
				draw_line(Vector2(0.0, y), Vector2(wall_size.x, y), Color(1.0, 1.0, 1.0, 0.16), 1.0)
				y += float(stripe_size) * cell_size
				band += 1
		"stripe_v":
			var x = 0.0
			var band_v = 0
			while x < wall_size.x:
				var idx_v = _pattern_colors[band_v % _pattern_colors.size()]
				var color_v = _palette[clampi(idx_v, 0, _palette.size() - 1)]
				var w = minf(float(stripe_size) * cell_size, wall_size.x - x)
				draw_rect(Rect2(x, 0.0, w, wall_size.y), Color(color_v.r, color_v.g, color_v.b, guide_alpha * 0.34))
				draw_line(Vector2(x, 0.0), Vector2(x, wall_size.y), Color(1.0, 1.0, 1.0, 0.16), 1.0)
				x += float(stripe_size) * cell_size
				band_v += 1
		"checker":
			var block = float(stripe_size) * cell_size
			for row in range(int(ceil(wall_size.y / block))):
				for col in range(int(ceil(wall_size.x / block))):
					var idx_c = _pattern_colors[(row + col) % _pattern_colors.size()]
					var color_c = _palette[clampi(idx_c, 0, _palette.size() - 1)]
					var rect = Rect2(
						Vector2(float(col) * block, float(row) * block),
						Vector2(minf(block, wall_size.x - float(col) * block), minf(block, wall_size.y - float(row) * block))
					)
					draw_rect(rect, Color(color_c.r, color_c.g, color_c.b, guide_alpha * 0.22))
		_:
			pass

	draw_rect(Rect2(Vector2.ZERO, wall_size), Color(1.0, 1.0, 1.0, 0.10), false, 1.0)


func _draw_weakest_marker() -> void:
	if _coverage.is_empty():
		return
	if _lowest_coverage >= 0.96:
		return

	var row = int(floor(float(_lowest_index) / float(_columns)))
	var col = _lowest_index % _columns
	var center = Vector2((float(col) + 0.5) * cell_size, (float(row) + 0.5) * cell_size)
	var pulse = 0.5 + sin(_anim_time * 5.6) * 0.5
	var radius = cell_size * 0.32 + pulse * 3.0
	var alpha = clampf((0.94 - _lowest_coverage) * 0.9, 0.12, 0.62)
	draw_arc(center, radius, 0.0, TAU, 22, Color(1.0, 0.86, 0.36, alpha), 1.8, true)
	draw_circle(center, 1.9, Color(1.0, 0.93, 0.58, alpha * 0.9))


func _draw_wall_base() -> void:
	var top = base_color.lightened(0.10)
	var bottom = base_color.darkened(0.18)
	var poly = PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2(wall_size.x, 0.0),
			Vector2(wall_size.x, wall_size.y),
			Vector2(0.0, wall_size.y),
		]
	)
	draw_polygon(poly, PackedColorArray([top, top, bottom, bottom]))

	var stain_bands = 8
	for i in range(stain_bands):
		var t = float(i) / float(maxi(1, stain_bands - 1))
		var y = lerpf(10.0, wall_size.y - 10.0, t)
		var wobble = sin(_anim_time * 0.2 + t * 13.0) * 8.0
		var alpha = 0.018 + absf(sin(t * 8.0)) * 0.028
		draw_line(
			Vector2(12.0 + wobble, y),
			Vector2(wall_size.x - 12.0 + wobble * 0.5, y + sin(t * 9.0) * 2.0),
			Color(0.07, 0.08, 0.10, alpha),
			1.0
		)


func _draw_shine() -> void:
	var wetness = clampf(_avg_coverage + _drip_intensity * 0.16, 0.0, 1.0)
	var band_x = fmod(_anim_time * 65.0, wall_size.x + 240.0) - 120.0
	var shine_alpha = 0.04 + wetness * 0.11 + _drip_intensity * wet_specular_strength * 0.10
	var p1 = Vector2(band_x - 40.0, 0.0)
	var p2 = Vector2(band_x + 10.0, 0.0)
	var p3 = Vector2(band_x + 90.0, wall_size.y)
	var p4 = Vector2(band_x + 40.0, wall_size.y)
	draw_polygon(
		PackedVector2Array([p1, p2, p3, p4]),
		PackedColorArray(
			[
				Color(0.95, 0.98, 1.0, 0.0),
				Color(0.95, 0.98, 1.0, shine_alpha),
				Color(0.95, 0.98, 1.0, 0.0),
				Color(0.95, 0.98, 1.0, 0.0),
			]
		)
	)


func _draw_surface_grime_overlay() -> void:
	var amount = int(8 + wall_size.x / 120.0)
	for i in range(amount):
		var t = float(i) / float(maxi(1, amount - 1))
		var x = lerpf(18.0, wall_size.x - 18.0, t) + sin(t * 17.0 + _anim_time * 0.24) * 9.0
		var top = 14.0 + absf(sin(t * 6.7)) * 22.0
		var length = wall_size.y * (0.24 + absf(cos(t * 4.2)) * 0.46)
		var alpha = 0.024 + grime_strength * 0.065 + _damage_heat * 0.018
		draw_line(
			Vector2(x, top),
			Vector2(x + sin(_anim_time * 0.6 + t * 9.0) * 6.0, top + length),
			Color(grime_color.r, grime_color.g, grime_color.b, alpha),
			1.1
		)


func _draw_wet_streaks() -> void:
	if _drip_intensity <= 0.06 and _damage_heat <= 0.04:
		return
	var wet = clampf(_drip_intensity * 0.62 + _damage_heat * 0.28, 0.0, 1.0)
	var amount = int(12 + wet * 36.0)
	for i in range(amount):
		var seed = float(i) * 0.79
		var x = 10.0 + fmod(seed * 61.0 + _anim_time * 11.0, wall_size.x - 20.0)
		var y = fmod(seed * 31.0 + _anim_time * 29.0, wall_size.y * 0.34)
		var len = 16.0 + fmod(seed * 47.0, wall_size.y * 0.58)
		var alpha = 0.05 + wet * 0.14
		draw_line(
			Vector2(x, y),
			Vector2(x + sin(seed + _anim_time * 1.2) * 6.0, minf(wall_size.y - 8.0, y + len)),
			Color(0.86, 0.93, 0.98, alpha),
			1.0 + wet * 0.4
		)


func _draw_frame_ambient_occlusion() -> void:
	var shadow_alpha = 0.12 + _drip_intensity * 0.06
	draw_rect(Rect2(0.0, 0.0, wall_size.x, 12.0), Color(0.0, 0.0, 0.0, shadow_alpha))
	draw_rect(Rect2(0.0, wall_size.y - 12.0, wall_size.x, 12.0), Color(0.0, 0.0, 0.0, shadow_alpha * 1.15))
	draw_rect(Rect2(0.0, 0.0, 10.0, wall_size.y), Color(0.0, 0.0, 0.0, shadow_alpha * 0.7))
	draw_rect(Rect2(wall_size.x - 10.0, 0.0, 10.0, wall_size.y), Color(0.0, 0.0, 0.0, shadow_alpha * 0.7))


func _draw_cell_cracks(cell_rect: Rect2, coverage: float) -> void:
	var crack_alpha = clampf((0.34 - coverage) * 1.8, 0.06, 0.42)
	var crack_color = Color(0.16, 0.16, 0.18, crack_alpha)
	var center = cell_rect.position + cell_rect.size * 0.5
	var amp = (1.0 - coverage) * 3.5
	draw_line(center + Vector2(-4.0, -2.0), center + Vector2(5.0 + amp, 2.0), crack_color, 1.0)
	draw_line(center + Vector2(-1.0, 0.0), center + Vector2(-5.0, 5.0 + amp), crack_color, 1.0)


func _draw_frame_details() -> void:
	draw_rect(Rect2(Vector2(-9.0, -9.0), wall_size + Vector2(18.0, 18.0)), Color(0.02, 0.03, 0.06, 0.28), false, 9.0)
	draw_rect(Rect2(Vector2.ZERO, wall_size), frame_color, false, 6.0)
	draw_rect(Rect2(Vector2(2.0, 2.0), wall_size - Vector2(4.0, 4.0)), Color(1.0, 1.0, 1.0, 0.08), false, 1.6)
	draw_rect(Rect2(Vector2(6.0, 6.0), wall_size - Vector2(12.0, 12.0)), Color(0.0, 0.0, 0.0, 0.16), false, 1.4)

	for i in range(6):
		var t = float(i) / 5.0
		var x = lerpf(16.0, wall_size.x - 16.0, t)
		var bolt_top = Vector2(x, 7.0)
		var bolt_bottom = Vector2(x, wall_size.y - 7.0)
		var rust_alpha = frame_wear * (0.12 + absf(sin(_anim_time * 0.4 + t * 4.0)) * 0.08)
		draw_circle(bolt_top, 2.2, Color(0.62, 0.64, 0.68, 0.68))
		draw_circle(bolt_bottom, 2.2, Color(0.62, 0.64, 0.68, 0.68))
		draw_circle(bolt_top + Vector2(0.0, 1.5), 3.2, Color(0.42, 0.24, 0.16, rust_alpha))
		draw_circle(bolt_bottom + Vector2(0.0, 1.5), 3.2, Color(0.42, 0.24, 0.16, rust_alpha))


func _get_cell_noise(col: int, row: int) -> float:
	var base = sin(float(col) * 1.71 + float(row) * 2.23)
	var wave = sin(_anim_time * 0.7 + float(col) * 0.32 + float(row) * 0.21)
	return clampf((base * 0.55 + wave * 0.45) * 0.5, -1.0, 1.0)
