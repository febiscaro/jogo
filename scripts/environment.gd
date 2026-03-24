extends Node2D

@export var viewport_size: Vector2 = Vector2(1280.0, 720.0)
@export var ground_y: float = 430.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time: float = 0.0
var _storm_level: float = 0.0
var _storm_target: float = 0.0
var _clouds: Array[Dictionary] = []


func _ready() -> void:
	_rng.randomize()
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


func _process(delta: float) -> void:
	_time += delta
	_storm_level = lerpf(_storm_level, _storm_target, minf(1.0, delta * 1.8))

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
	_draw_sun()
	_draw_city_layers()
	_draw_clouds()
	_draw_ground()
	_draw_ground_details()
	_draw_wind_lines()
	_draw_rain_overlay()
	_draw_vignette()


func _draw_sky() -> void:
	var top_color = Color(0.33, 0.53, 0.79, 1.0).lerp(Color(0.20, 0.26, 0.35, 1.0), _storm_level)
	var horizon_color = Color(0.87, 0.92, 0.95, 1.0).lerp(Color(0.39, 0.45, 0.55, 1.0), _storm_level)
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


func _draw_city_layers() -> void:
	for i in range(14):
		var width = 68.0 + float((i % 4) * 14)
		var height = 44.0 + float((i * 31) % 110)
		var x = -20.0 + (float(i) * 94.0)
		var y = ground_y - 24.0 - height + sin(float(i) * 0.7) * 7.0
		var tone = 0.29 + float(i % 3) * 0.05
		var building_color = Color(tone, tone + 0.03, tone + 0.08, 0.58).lerp(Color(0.18, 0.19, 0.24, 0.68), _storm_level)
		var rect = Rect2(x, y, width, height)
		draw_rect(rect, building_color)

		var cols = int(width / 16.0)
		var rows = int(height / 22.0)
		for cx in range(cols):
			for cy in range(rows):
				var pulse = 0.55 + (sin(_time * 1.1 + float(i) * 0.9 + float(cx) * 0.5 + float(cy) * 0.8) * 0.45)
				var window_alpha = clampf(pulse * (1.0 - _storm_level * 0.8), 0.12, 0.65)
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
	draw_rect(Rect2(0.0, lane_top, viewport_size.x, 66.0), Color(0.31, 0.34, 0.35, 0.27))
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
		draw_ellipse(Vector2(px, py), Vector2(puddle_w, puddle_h), Color(0.58, 0.73, 0.83, 0.13 + _storm_level * 0.14))
		draw_ellipse(Vector2(px, py - 1.0), Vector2(puddle_w * 0.74, puddle_h * 0.48), Color(0.88, 0.95, 1.0, 0.09 + _storm_level * 0.07))


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


func _draw_vignette() -> void:
	var edge = 110.0
	var alpha = 0.11 + _storm_level * 0.16
	draw_rect(Rect2(0.0, 0.0, viewport_size.x, edge), Color(0.03, 0.04, 0.06, alpha))
	draw_rect(Rect2(0.0, viewport_size.y - edge, viewport_size.x, edge), Color(0.03, 0.04, 0.06, alpha * 1.1))
	draw_rect(Rect2(0.0, 0.0, edge, viewport_size.y), Color(0.03, 0.04, 0.06, alpha * 0.8))
	draw_rect(Rect2(viewport_size.x - edge, 0.0, edge, viewport_size.y), Color(0.03, 0.04, 0.06, alpha * 0.8))
