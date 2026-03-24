extends Node2D

@export var bucket_size: Vector2 = Vector2(62.0, 70.0)
@export var body_top_color: Color = Color(0.20, 0.26, 0.36, 1.0)
@export var body_bottom_color: Color = Color(0.11, 0.15, 0.21, 1.0)
@export var rim_color: Color = Color(0.43, 0.52, 0.64, 1.0)
@export var handle_color: Color = Color(0.52, 0.61, 0.73, 0.96)

var _fill_ratio: float = 1.0
var _paint_tint: Color = Color(0.34, 0.69, 0.96, 0.92)
var _active: bool = true
var _time: float = 0.0


func _ready() -> void:
	set_process(true)
	queue_redraw()


func set_fill_ratio(value: float) -> void:
	_fill_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()


func set_tint(color: Color) -> void:
	_paint_tint = Color(color.r, color.g, color.b, 0.92)
	queue_redraw()


func set_active(value: bool) -> void:
	_active = value
	visible = value
	set_process(value)
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	if not _active:
		return

	var w = bucket_size.x
	var h = bucket_size.y

	_draw_soft_ellipse(Vector2(0.0, h * 0.56), Vector2(w * 0.62, h * 0.16), Color(0.0, 0.0, 0.0, 0.20), 30)

	var body_poly = PackedVector2Array(
		[
			Vector2(-w * 0.40, -h * 0.34),
			Vector2(w * 0.40, -h * 0.34),
			Vector2(w * 0.30, h * 0.40),
			Vector2(-w * 0.30, h * 0.40),
		]
	)
	draw_polygon(body_poly, PackedColorArray([body_top_color, body_top_color, body_bottom_color, body_bottom_color]))

	draw_polyline(body_poly, Color(0.70, 0.78, 0.90, 0.34), 1.8, true)
	_draw_soft_ellipse(Vector2(0.0, -h * 0.36), Vector2(w * 0.42, h * 0.10), rim_color, 32)
	_draw_soft_ellipse(Vector2(0.0, -h * 0.36), Vector2(w * 0.30, h * 0.06), Color(0.09, 0.11, 0.15, 0.98), 30)

	var fill_height = lerpf(3.0, h * 0.56, _fill_ratio)
	var fill_top_y = h * 0.34 - fill_height
	draw_rect(
		Rect2(Vector2(-w * 0.23, fill_top_y), Vector2(w * 0.46, fill_height)),
		Color(_paint_tint.r * 0.82, _paint_tint.g * 0.82, _paint_tint.b * 0.82, 0.92)
	)
	_draw_soft_ellipse(Vector2(0.0, fill_top_y), Vector2(w * 0.24, h * 0.05), _paint_tint, 28)

	var bubble_count = int(2 + round(_fill_ratio * 4.0))
	for i in range(bubble_count):
		var seed = float(i) * 1.73
		var bx = sin(_time * 1.8 + seed) * (w * 0.12)
		var by = fill_top_y + h * 0.04 + fmod(seed * 9.0 + _time * 8.0, h * 0.14)
		var alpha = 0.12 + _fill_ratio * 0.22
		draw_circle(Vector2(bx, by), 1.6, Color(1.0, 1.0, 1.0, alpha))

	draw_arc(Vector2(0.0, -h * 0.30), w * 0.46, PI * 1.08, PI * 1.92, 22, handle_color, 2.2, true)
	draw_arc(Vector2(0.0, -h * 0.30), w * 0.42, PI * 1.10, PI * 1.90, 18, Color(1.0, 1.0, 1.0, 0.22), 1.0, true)

	var pulse = 0.8 + sin(_time * 2.8) * 0.2
	draw_rect(Rect2(-w * 0.18, -h * 0.06, w * 0.10, h * 0.32), Color(1.0, 1.0, 1.0, 0.06 * pulse))


func _draw_soft_ellipse(center: Vector2, radii: Vector2, color: Color, points: int = 24) -> void:
	var safe_points = maxi(10, points)
	var polygon = PackedVector2Array()
	var colors = PackedColorArray()
	for i in range(safe_points):
		var angle = TAU * float(i) / float(safe_points)
		polygon.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
		colors.append(color)
	draw_polygon(polygon, colors)
