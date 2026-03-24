extends Node2D

@export var viewport_size: Vector2 = Vector2(1280.0, 720.0)
@export var ground_y: float = 430.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time: float = 0.0
var _storm_level: float = 0.0
var _storm_target: float = 0.0
var _clouds: Array[Dictionary] = []
var _lightning_alpha: float = 0.0
var _lightning_timer: float = 0.0
var _next_lightning: float = 0.0
var _lightning_x: float = 0.0


func _ready() -> void:
	_rng.randomize()
	_next_lightning = _rng.randf_range(3.8, 7.4)
	_lightning_x = viewport_size.x * 0.55
	for i in range(10):
		_clouds.append(
			{
				"pos": Vector2(
					_rng.randf_range(-160.0, viewport_size.x + 140.0),
					_rng.randf_range(34.0, ground_y - 210.0)
				),
				"scale": _rng.randf_range(0.7, 1.35),
				"speed": _rng.randf_range(8.0, 22.0),
				"alpha": _rng.randf_range(0.28, 0.52),
			}
		)
	queue_redraw()


func set_storm_level(value: float) -> void:
	_storm_target = clampf(value, 0.0, 1.0)


func trigger_lightning(intensity: float = 1.0) -> void:
	var safe_intensity = clampf(intensity, 0.2, 1.8)
	_lightning_alpha = clampf(0.35 + safe_intensity * 0.32, 0.25, 0.95)
	_lightning_timer = 0.06 + safe_intensity * 0.04
	_lightning_x = _rng.randf_range(viewport_size.x * 0.12, viewport_size.x * 0.88)
	_next_lightning = _rng.randf_range(3.2, 6.8)


func _process(delta: float) -> void:
	_time += delta
	_storm_level = lerpf(_storm_level, _storm_target, minf(1.0, delta * 1.8))
	_lightning_timer = maxf(0.0, _lightning_timer - delta)
	_lightning_alpha = maxf(0.0, _lightning_alpha - delta * 2.4)
	_next_lightning -= delta
	if _storm_level > 0.46 and _next_lightning <= 0.0:
		if _rng.randf() < clampf((_storm_level - 0.35) * 0.65, 0.12, 0.52):
			trigger_lightning(0.42 + _storm_level * 0.74)
		else:
			_next_lightning = _rng.randf_range(2.8, 6.2)

	for i in range(_clouds.size()):
		var cloud: Dictionary = _clouds[i]
		var pos = cloud.get("pos", Vector2.ZERO)
		pos.x += float(cloud.get("speed", 12.0)) * delta * (1.0 + (_storm_level * 0.35))
		if pos.x > viewport_size.x + 170.0:
			pos.x = -170.0
			pos.y = _rng.randf_range(30.0, ground_y - 190.0)
		cloud["pos"] = pos
		_clouds[i] = cloud

	queue_redraw()


func _draw() -> void:
	_draw_sky()
	_draw_atmospheric_haze()
	_draw_far_hills()
	_draw_sun()
	_draw_city_layers()
	_draw_clouds()
	_draw_ground()
	_draw_ground_details()
	_draw_road_reflections()
	_draw_wind_lines()
	_draw_rain_overlay()
	_draw_rain_mist()
	_draw_lightning_flash()
	_draw_vignette()


func _draw_sky() -> void:
	var top_color = Color(0.29, 0.46, 0.70, 1.0).lerp(Color(0.15, 0.20, 0.29, 1.0), _storm_level)
	var mid_color = Color(0.54, 0.68, 0.84, 1.0).lerp(Color(0.26, 0.33, 0.44, 1.0), _storm_level)
	var horizon_color = Color(0.87, 0.91, 0.94, 1.0).lerp(Color(0.37, 0.43, 0.52, 1.0), _storm_level)
	var sky_poly = PackedVector2Array(
		[
			Vector2(0.0, 0.0),
			Vector2(viewport_size.x, 0.0),
			Vector2(viewport_size.x, ground_y + 90.0),
			Vector2(0.0, ground_y + 90.0),
		]
	)
	var sky_colors = PackedColorArray([top_color, top_color, horizon_color, horizon_color])
	draw_polygon(sky_poly, sky_colors)

	var mid_band = PackedVector2Array(
		[
			Vector2(0.0, ground_y * 0.18),
			Vector2(viewport_size.x, ground_y * 0.18),
			Vector2(viewport_size.x, ground_y * 0.68),
			Vector2(0.0, ground_y * 0.68),
		]
	)
	draw_polygon(
		mid_band,
		PackedColorArray(
			[
				Color(mid_color.r, mid_color.g, mid_color.b, 0.42),
				Color(mid_color.r, mid_color.g, mid_color.b, 0.42),
				Color(mid_color.r, mid_color.g, mid_color.b, 0.0),
				Color(mid_color.r, mid_color.g, mid_color.b, 0.0),
			]
		)
	)


func _draw_sun() -> void:
	var sun_center = Vector2(viewport_size.x * 0.82, 108.0)
	var sun_radius = 48.0
	var sun_alpha = 0.85 * (1.0 - (_storm_level * 0.8))
	var sun_color = Color(0.99, 0.86, 0.62, sun_alpha)
	draw_circle(sun_center, sun_radius, sun_color)
	for i in range(3):
		var ring = sun_radius + (24.0 * float(i + 1)) + sin(_time * 1.4 + float(i)) * 4.0
		var ring_alpha = maxf(0.0, 0.14 - (0.036 * float(i))) * (1.0 - _storm_level)
		draw_circle(sun_center, ring, Color(1.0, 0.92, 0.72, ring_alpha))

	if _storm_level < 0.55:
		for i in range(3):
			var shaft_w = 88.0 + float(i) * 54.0
			var shaft_alpha = (0.08 - float(i) * 0.02) * (1.0 - _storm_level)
			var shaft = PackedVector2Array(
				[
					sun_center + Vector2(-shaft_w, 26.0),
					sun_center + Vector2(shaft_w, 26.0),
					Vector2(viewport_size.x * 0.72 + float(i) * 54.0, ground_y + 160.0),
					Vector2(viewport_size.x * 0.50 + float(i) * 34.0, ground_y + 160.0),
				]
			)
			draw_polygon(
				shaft,
				PackedColorArray(
					[
						Color(1.0, 0.93, 0.78, shaft_alpha),
						Color(1.0, 0.93, 0.78, shaft_alpha),
						Color(1.0, 0.93, 0.78, 0.0),
						Color(1.0, 0.93, 0.78, 0.0),
					]
				)
			)


func _draw_city_layers() -> void:
	for layer in range(2):
		var depth = float(layer) / 1.0
		var base_alpha = 0.46 + depth * 0.18
		var count = 12 + layer * 4
		for i in range(count):
			var index_seed = i + layer * 11
			var width = 64.0 + float((index_seed % 5) * 16)
			var height = 42.0 + float((index_seed * 23) % (100 + layer * 30))
			var spacing = 102.0 - depth * 18.0
			var x = -40.0 + (float(i) * spacing) + depth * 22.0
			var y = ground_y - 22.0 - height + sin(float(index_seed) * 0.63) * (5.0 - depth * 2.0)
			var tone = 0.24 + float(index_seed % 4) * 0.04 + depth * 0.04
			var building_color = Color(tone, tone + 0.03, tone + 0.08, base_alpha).lerp(Color(0.14, 0.16, 0.21, 0.78), _storm_level)
			var rect = Rect2(x, y, width, height)
			draw_rect(rect, building_color)

			var roof_shadow = Rect2(x, y, width, 3.0 + depth * 2.0)
			draw_rect(roof_shadow, Color(0.05, 0.07, 0.10, 0.22))
			if width > 12.0:
				draw_rect(Rect2(x + width - 5.0, y + 4.0, 2.0, height - 7.0), Color(1.0, 1.0, 1.0, 0.05))

			var cols = int(width / 16.0)
			var rows = int(height / 22.0)
			for cx in range(cols):
				for cy in range(rows):
					var pulse = 0.55 + (sin(_time * 1.1 + float(index_seed) * 0.9 + float(cx) * 0.5 + float(cy) * 0.8) * 0.45)
					var window_alpha = clampf(pulse * (1.0 - _storm_level * 0.8) * (0.86 - depth * 0.18), 0.07, 0.62)
					var wx = x + 5.0 + float(cx) * 13.0
					var wy = y + 6.0 + float(cy) * 18.0
					draw_rect(Rect2(wx, wy, 5.0, 8.0), Color(1.0, 0.88, 0.63, window_alpha))


func _draw_clouds() -> void:
	for cloud in _clouds:
		var pos = cloud.get("pos", Vector2.ZERO)
		var scale = float(cloud.get("scale", 1.0))
		var alpha = float(cloud.get("alpha", 0.4)) * (1.0 - (_storm_level * 0.5))
		var shade = Color(0.95, 0.97, 1.0, alpha).lerp(Color(0.62, 0.67, 0.75, alpha), _storm_level)
		_draw_cloud(pos, scale, shade)


func _draw_cloud(center: Vector2, scale: float, color: Color) -> void:
	var offsets = [
		Vector2(-54.0, 6.0),
		Vector2(-20.0, -8.0),
		Vector2(14.0, -10.0),
		Vector2(48.0, 4.0),
		Vector2(0.0, 10.0),
	]
	var radii = [24.0, 28.0, 30.0, 22.0, 26.0]
	for i in range(offsets.size()):
		draw_circle(center + offsets[i] * scale, radii[i] * scale, color)


func _draw_ground() -> void:
	var top_grass = Color(0.63, 0.71, 0.58, 1.0).lerp(Color(0.48, 0.54, 0.50, 1.0), _storm_level)
	var bottom_grass = Color(0.47, 0.55, 0.43, 1.0).lerp(Color(0.34, 0.38, 0.40, 1.0), _storm_level)
	var ground_poly = PackedVector2Array(
		[
			Vector2(0.0, ground_y),
			Vector2(viewport_size.x, ground_y),
			Vector2(viewport_size.x, viewport_size.y),
			Vector2(0.0, viewport_size.y),
		]
	)
	draw_polygon(ground_poly, PackedColorArray([top_grass, top_grass, bottom_grass, bottom_grass]))

	var lane_top = ground_y + 92.0
	draw_rect(Rect2(0.0, lane_top, viewport_size.x, 66.0), Color(0.25, 0.28, 0.31, 0.34))
	draw_rect(Rect2(0.0, lane_top + 3.0, viewport_size.x, 60.0), Color(0.10, 0.12, 0.15, 0.17 + _storm_level * 0.13))
	for i in range(18):
		var lane_x = float(i) * 78.0 + fmod(_time * 38.0, 78.0)
		draw_rect(Rect2(lane_x, lane_top + 28.0, 38.0, 4.0), Color(0.95, 0.88, 0.62, 0.24))


func _draw_ground_details() -> void:
	for i in range(24):
		var x = float(i) * 56.0 + fmod(_time * 6.0, 54.0)
		var base_y = ground_y + 18.0 + sin(float(i) * 0.7) * 4.0
		var blade_h = 20.0 + float((i * 9) % 14)
		var sway = sin(_time * 1.8 + float(i) * 0.6) * (3.0 + _storm_level * 5.0)
		draw_line(
			Vector2(x, base_y),
			Vector2(x + sway, base_y - blade_h),
			Color(0.42, 0.55, 0.38, 0.36),
			1.7
		)

	for i in range(7):
		var px = 90.0 + float(i) * 170.0 + sin(_time * 0.9 + float(i)) * 6.0
		var py = ground_y + 162.0 + sin(_time * 1.4 + float(i) * 0.4) * 2.0
		var puddle_w = 52.0 + float((i % 3) * 22)
		var puddle_h = 12.0 + float((i % 2) * 5)
		_draw_soft_ellipse(Vector2(px, py), Vector2(puddle_w, puddle_h), Color(0.58, 0.73, 0.83, 0.13 + _storm_level * 0.14), 26)
		_draw_soft_ellipse(Vector2(px, py - 1.0), Vector2(puddle_w * 0.74, puddle_h * 0.48), Color(0.88, 0.95, 1.0, 0.09 + _storm_level * 0.07), 22)
		if _storm_level > 0.16:
			var ripple = 0.5 + sin(_time * (2.2 + float(i) * 0.3)) * 0.5
			var ripple_w = puddle_w * (0.42 + ripple * 0.24)
			var ripple_h = puddle_h * (0.28 + ripple * 0.20)
			_draw_soft_ellipse(Vector2(px, py), Vector2(ripple_w, ripple_h), Color(0.88, 0.95, 1.0, 0.06 + _storm_level * 0.08), 20)


func _draw_wind_lines() -> void:
	if _storm_level <= 0.04:
		return

	var amount = int(24 + (_storm_level * 56.0))
	for i in range(amount):
		var seed = float(i) * 0.67
		var x = fmod((seed * 117.0) + (_time * (240.0 + _storm_level * 120.0)), viewport_size.x + 180.0) - 90.0
		var y = 58.0 + fmod(seed * 83.0 + _time * 72.0, ground_y - 90.0)
		var length = 18.0 + fmod(seed * 41.0, 18.0)
		draw_line(
			Vector2(x, y),
			Vector2(x + length, y + (6.0 + _storm_level * 8.0)),
			Color(0.86, 0.93, 1.0, 0.11 + _storm_level * 0.15),
			1.3
		)


func _draw_rain_overlay() -> void:
	if _storm_level < 0.12:
		return

	var streak_count = int(42 + _storm_level * 120.0)
	for i in range(streak_count):
		var seed = float(i) * 1.37
		var x = fmod(seed * 97.0 + _time * (420.0 + _storm_level * 220.0), viewport_size.x + 200.0) - 100.0
		var y = fmod(seed * 57.0 + _time * 350.0, viewport_size.y + 120.0) - 60.0
		var len = 12.0 + fmod(seed * 23.0, 16.0) + _storm_level * 12.0
		draw_line(
			Vector2(x, y),
			Vector2(x - 4.0 - _storm_level * 6.0, y + len),
			Color(0.85, 0.95, 1.0, 0.06 + _storm_level * 0.17),
			1.2
		)
		if _storm_level > 0.55 and i % 5 == 0:
			draw_circle(Vector2(x - 3.0, y + len), 1.1 + _storm_level * 0.6, Color(0.86, 0.95, 1.0, 0.11))


func _draw_vignette() -> void:
	var edge = 130.0
	var alpha = 0.12 + _storm_level * 0.18
	draw_rect(Rect2(0.0, 0.0, viewport_size.x, edge), Color(0.03, 0.04, 0.06, alpha))
	draw_rect(Rect2(0.0, viewport_size.y - edge, viewport_size.x, edge), Color(0.03, 0.04, 0.06, alpha * 1.1))
	draw_rect(Rect2(0.0, 0.0, edge, viewport_size.y), Color(0.03, 0.04, 0.06, alpha * 0.8))
	draw_rect(Rect2(viewport_size.x - edge, 0.0, edge, viewport_size.y), Color(0.03, 0.04, 0.06, alpha * 0.8))


func _draw_atmospheric_haze() -> void:
	var haze_top = ground_y - 180.0
	var haze_bottom = ground_y + 16.0
	var haze_color = Color(0.78, 0.86, 0.94, 0.16 + _storm_level * 0.12)
	var haze_poly = PackedVector2Array(
		[
			Vector2(0.0, haze_top),
			Vector2(viewport_size.x, haze_top),
			Vector2(viewport_size.x, haze_bottom),
			Vector2(0.0, haze_bottom),
		]
	)
	draw_polygon(
		haze_poly,
		PackedColorArray(
			[
				Color(haze_color.r, haze_color.g, haze_color.b, 0.0),
				Color(haze_color.r, haze_color.g, haze_color.b, 0.0),
				haze_color,
				haze_color,
			]
		)
	)


func _draw_far_hills() -> void:
	var layers = [
		{"base_y": ground_y - 74.0, "height": 44.0, "freq": 0.010, "alpha": 0.24},
		{"base_y": ground_y - 56.0, "height": 32.0, "freq": 0.014, "alpha": 0.30},
	]
	for layer in layers:
		var points = PackedVector2Array()
		points.append(Vector2(0.0, ground_y + 16.0))
		for x in range(0, int(viewport_size.x) + 20, 20):
			var fx = float(x)
			var y = float(layer["base_y"])
			y += sin((fx * float(layer["freq"])) + _time * 0.18) * float(layer["height"])
			y += sin((fx * float(layer["freq"]) * 0.43) + _time * 0.09 + 1.2) * (float(layer["height"]) * 0.46)
			points.append(Vector2(fx, y))
		points.append(Vector2(viewport_size.x, ground_y + 16.0))
		var alpha = float(layer["alpha"]) + _storm_level * 0.12
		var color = Color(0.24, 0.31, 0.39, alpha)
		var colors = PackedColorArray()
		for _i in range(points.size()):
			colors.append(color)
		draw_polygon(points, colors)


func _draw_road_reflections() -> void:
	var lane_top = ground_y + 92.0
	var lane_rect = Rect2(0.0, lane_top, viewport_size.x, 66.0)
	var gloss_alpha = 0.08 + _storm_level * 0.18
	for i in range(5):
		var t = float(i) / 4.0
		var y = lane_rect.position.y + 6.0 + t * (lane_rect.size.y - 14.0)
		var wave = sin(_time * 0.9 + t * 8.0) * 22.0
		var shine_rect = Rect2(80.0 + wave, y, viewport_size.x * 0.78, 2.0)
		draw_rect(shine_rect, Color(0.88, 0.95, 1.0, gloss_alpha * (1.0 - t * 0.55)))


func _draw_rain_mist() -> void:
	if _storm_level < 0.16:
		return
	var mist = PackedVector2Array(
		[
			Vector2(0.0, ground_y - 30.0),
			Vector2(viewport_size.x, ground_y - 30.0),
			Vector2(viewport_size.x, ground_y + 210.0),
			Vector2(0.0, ground_y + 210.0),
		]
	)
	var alpha = 0.03 + _storm_level * 0.11
	draw_polygon(
		mist,
		PackedColorArray(
			[
				Color(0.82, 0.90, 0.96, 0.0),
				Color(0.82, 0.90, 0.96, 0.0),
				Color(0.82, 0.90, 0.96, alpha),
				Color(0.82, 0.90, 0.96, alpha),
			]
		)
	)


func _draw_lightning_flash() -> void:
	if _lightning_alpha <= 0.01:
		return

	var overlay_alpha = _lightning_alpha * (0.20 + _storm_level * 0.22)
	draw_rect(Rect2(0.0, 0.0, viewport_size.x, ground_y + 90.0), Color(0.90, 0.96, 1.0, overlay_alpha))

	var x = _lightning_x
	var y = 14.0
	var bolt_alpha = clampf(_lightning_alpha * 1.25, 0.16, 1.0)
	for i in range(8):
		var nx = x + sin((_time * 32.0) + float(i) * 1.7) * 14.0 + _rng.randf_range(-8.0, 8.0)
		var ny = y + 26.0 + float(i) * 10.0
		draw_line(Vector2(x, y), Vector2(nx, ny), Color(0.95, 0.99, 1.0, bolt_alpha), 2.4)
		draw_line(Vector2(x, y), Vector2(nx, ny), Color(0.66, 0.84, 1.0, bolt_alpha * 0.45), 5.4)
		x = nx
		y = ny
		if y > ground_y - 22.0:
			break

	if _lightning_timer > 0.0:
		draw_circle(Vector2(_lightning_x, 38.0), 26.0, Color(0.92, 0.98, 1.0, _lightning_alpha * 0.36))


func _draw_soft_ellipse(center: Vector2, radii: Vector2, color: Color, points: int = 24) -> void:
	var safe_points = maxi(8, points)
	var polygon = PackedVector2Array()
	var colors = PackedColorArray()
	for i in range(safe_points):
		var angle = TAU * float(i) / float(safe_points)
		polygon.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
		colors.append(color)
	draw_polygon(polygon, colors)
