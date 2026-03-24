extends CharacterBody2D

@export var base_speed: float = 290.0
@export var move_bounds: Rect2 = Rect2(260.0, 130.0, 820.0, 520.0)
@export var base_paint_radius: float = 78.0
@export var base_paint_strength_per_second: float = 6.2
@export var base_paint_capacity: float = 260.0
@export var base_paint_regen_per_second: float = 36.0
@export var base_paint_drain_per_second: float = 5.2

@onready var roller: Node2D = $Roller
@onready var foam: Polygon2D = $Roller/Foam

var _wall: Node = null
var _is_active: bool = true
var _external_paint_multiplier: float = 1.0
var _external_drain_multiplier: float = 1.0
var _external_speed_multiplier: float = 1.0
var _is_painting: bool = false

var _speed: float = base_speed
var _paint_radius: float = base_paint_radius
var _paint_strength: float = base_paint_strength_per_second
var _paint_capacity: float = base_paint_capacity
var _paint_regen: float = base_paint_regen_per_second
var _paint_drain: float = base_paint_drain_per_second
var _paint_amount: float = base_paint_capacity
var _active_paint_color: Color = Color(0.35, 0.66, 0.95, 1.0)


func _ready() -> void:
	_paint_amount = _paint_capacity


func set_wall(wall: Node) -> void:
	_wall = wall


func set_game_active(value: bool) -> void:
	_is_active = value
	if not value:
		velocity = Vector2.ZERO


func apply_run_modifiers(modifiers: Dictionary) -> void:
	_speed = (base_speed + float(modifiers.get("speed_add", 0.0))) * float(modifiers.get("speed_mult", 1.0))
	_paint_radius = (base_paint_radius + float(modifiers.get("paint_radius_add", 0.0))) * float(modifiers.get("paint_radius_mult", 1.0))
	_paint_strength = (base_paint_strength_per_second + float(modifiers.get("paint_strength_add", 0.0))) * float(modifiers.get("paint_strength_mult", 1.0))
	_paint_capacity = (base_paint_capacity + float(modifiers.get("paint_capacity_add", 0.0))) * float(modifiers.get("paint_capacity_mult", 1.0))
	_paint_regen = (base_paint_regen_per_second + float(modifiers.get("paint_regen_add", 0.0))) * float(modifiers.get("paint_regen_mult", 1.0))
	_paint_drain = (base_paint_drain_per_second + float(modifiers.get("paint_drain_add", 0.0))) * float(modifiers.get("paint_drain_mult", 1.0))
	_paint_amount = clampf(_paint_amount, 0.0, _paint_capacity)


func refill_paint() -> void:
	_paint_amount = _paint_capacity


func set_move_bounds_from_wall(wall_rect: Rect2) -> void:
	var margin_x = 42.0
	var top = wall_rect.position.y + 24.0
	var bottom = wall_rect.end.y + 230.0
	move_bounds = Rect2(
		wall_rect.position.x - margin_x,
		top,
		wall_rect.size.x + (margin_x * 2.0),
		maxf(120.0, bottom - top)
	)


func set_paint_color(color: Color) -> void:
	_active_paint_color = color
	if _paint_amount > 5.0:
		foam.modulate = color


func set_external_modifiers(speed_multiplier: float, paint_multiplier: float, drain_multiplier: float) -> void:
	_external_speed_multiplier = maxf(0.1, speed_multiplier)
	_external_paint_multiplier = maxf(0.1, paint_multiplier)
	_external_drain_multiplier = maxf(0.1, drain_multiplier)


func get_paint_ratio() -> float:
	if _paint_capacity <= 0.0:
		return 0.0
	return _paint_amount / _paint_capacity


func is_painting() -> bool:
	return _is_painting


func get_stat_snapshot() -> Dictionary:
	return {
		"speed": _speed,
		"paint_radius": _paint_radius,
		"paint_strength": _paint_strength,
		"paint_capacity": _paint_capacity,
		"paint_regen": _paint_regen,
		"paint_drain": _paint_drain,
	}


func _physics_process(delta: float) -> void:
	if not _is_active:
		return

	var input_vector = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.y += 1.0
	if Input.is_key_pressed(KEY_W):
		input_vector.y -= 1.0

	var direction = input_vector.normalized()
	velocity = direction * (_speed * _external_speed_multiplier)
	move_and_slide()

	global_position.x = clampf(global_position.x, move_bounds.position.x, move_bounds.end.x)
	global_position.y = clampf(global_position.y, move_bounds.position.y, move_bounds.end.y)

	if direction.length() > 0.1:
		roller.rotation = direction.angle() + PI * 0.5

	var did_paint = false
	if _wall and _wall.has_method("paint_at") and _paint_amount > 0.0:
		var paint_strength = _paint_strength * _external_paint_multiplier
		did_paint = bool(_wall.call("paint_at", roller.global_position, _paint_radius, paint_strength * delta))

	if did_paint:
		var paint_cost = _paint_drain * _external_drain_multiplier * delta
		_paint_amount = maxf(0.0, _paint_amount - paint_cost)
	else:
		_paint_amount = minf(_paint_capacity, _paint_amount + (_paint_regen * delta))

	_is_painting = did_paint
	foam.modulate = _active_paint_color if _paint_amount > 5.0 else Color(0.45, 0.45, 0.45, 1.0)
