extends CharacterBody2D

@export var base_speed: float = 300.0
@export var move_bounds: Rect2 = Rect2(260.0, 130.0, 820.0, 520.0)
@export var base_paint_radius: float = 24.0
@export var base_paint_strength_per_second: float = 6.5
@export var base_paint_capacity: float = 220.0
@export var base_paint_regen_per_second: float = 38.0
@export var base_paint_drain_per_second: float = 8.2
@export var bucket_capacity_multiplier: float = 1.16
@export var refill_efficiency: float = 0.88
@export var refill_rate_per_second: float = 64.0

@export var ground_offset_y: float = 96.0
@export var horizontal_margin: float = 42.0
@export var roller_move_speed: float = 540.0
@export var roller_x_offset: float = 26.0
@export var roller_top_margin: float = 10.0
@export var roller_bottom_margin: float = 14.0

@onready var roller: Node2D = $Roller
@onready var foam: Polygon2D = $Roller/Foam
@onready var torso: Node2D = get_node_or_null("Torso") as Node2D
@onready var head: Node2D = get_node_or_null("Head") as Node2D
@onready var arm_left: Node2D = get_node_or_null("ArmLeft") as Node2D
@onready var arm_right: Node2D = get_node_or_null("ArmRight") as Node2D
@onready var leg_left: Node2D = get_node_or_null("LegLeft") as Node2D
@onready var leg_right: Node2D = get_node_or_null("LegRight") as Node2D
@onready var roller_arm: Node2D = get_node_or_null("RollerArm") as Node2D

var _wall: Node = null
var _is_active: bool = true
var _external_paint_multiplier: float = 1.0
var _external_drain_multiplier: float = 1.0
var _external_speed_multiplier: float = 1.0
var _color_paint_multiplier: float = 1.0
var _color_drain_multiplier: float = 1.0
var _is_painting: bool = false

var _speed: float = base_speed
var _paint_radius: float = base_paint_radius
var _paint_strength: float = base_paint_strength_per_second
var _paint_capacity: float = base_paint_capacity
var _paint_regen: float = base_paint_regen_per_second
var _paint_drain: float = base_paint_drain_per_second
var _paint_amount: float = base_paint_capacity
var _active_paint_color: Color = Color(0.35, 0.66, 0.95, 1.0)
var _bucket_capacity: float = 0.0
var _bucket_amount: float = 0.0
var _bucket_world: Vector2 = Vector2.ZERO
var _bucket_radius: float = 84.0
var _is_refilling: bool = false

var _anim_time: float = 0.0
var _rest_positions: Dictionary = {}
var _ground_y: float = 595.0
var _roller_min_y: float = -490.0
var _roller_max_y: float = -120.0
var _roller_target_y: float = -170.0
var _facing: float = 1.0


func _ready() -> void:
	_paint_amount = _paint_capacity
	_bucket_capacity = _paint_capacity * bucket_capacity_multiplier
	_bucket_amount = _bucket_capacity
	_ground_y = global_position.y
	_roller_target_y = roller.position.y
	for part in [torso, head, arm_left, arm_right, leg_left, leg_right, roller_arm]:
		if part != null:
			_rest_positions[part.name] = part.position
	_apply_roller_limits()


func set_wall(wall: Node) -> void:
	_wall = wall


func set_game_active(value: bool) -> void:
	_is_active = value
	if not value:
		velocity = Vector2.ZERO


func apply_run_modifiers(modifiers: Dictionary) -> void:
	var bucket_ratio = 1.0
	if _bucket_capacity > 0.0:
		bucket_ratio = _bucket_amount / _bucket_capacity

	_speed = (base_speed + float(modifiers.get("speed_add", 0.0))) * float(modifiers.get("speed_mult", 1.0))
	_paint_radius = (base_paint_radius + float(modifiers.get("paint_radius_add", 0.0))) * float(modifiers.get("paint_radius_mult", 1.0))
	_paint_radius = clampf(_paint_radius, 16.0, 32.0)
	_paint_strength = (base_paint_strength_per_second + float(modifiers.get("paint_strength_add", 0.0))) * float(modifiers.get("paint_strength_mult", 1.0))
	_paint_capacity = (base_paint_capacity + float(modifiers.get("paint_capacity_add", 0.0))) * float(modifiers.get("paint_capacity_mult", 1.0))
	_paint_regen = (base_paint_regen_per_second + float(modifiers.get("paint_regen_add", 0.0))) * float(modifiers.get("paint_regen_mult", 1.0))
	_paint_drain = (base_paint_drain_per_second + float(modifiers.get("paint_drain_add", 0.0))) * float(modifiers.get("paint_drain_mult", 1.0))
	_bucket_capacity = _paint_capacity * bucket_capacity_multiplier
	_bucket_amount = clampf(_bucket_capacity * bucket_ratio, 0.0, _bucket_capacity)
	_paint_amount = clampf(_paint_amount, 0.0, _paint_capacity)


func refill_paint() -> void:
	_paint_amount = _paint_capacity
	_bucket_capacity = _paint_capacity * bucket_capacity_multiplier
	_bucket_amount = _bucket_capacity


func set_bucket(bucket_position: Vector2, radius: float = 72.0) -> void:
	_bucket_world = bucket_position
	_bucket_radius = maxf(24.0, radius)


func set_move_bounds_from_wall(wall_rect: Rect2) -> void:
	var left = wall_rect.position.x - horizontal_margin
	var right = wall_rect.end.x + horizontal_margin
	move_bounds = Rect2(left, move_bounds.position.y, maxf(80.0, right - left), move_bounds.size.y)

	_ground_y = wall_rect.end.y + ground_offset_y
	global_position.y = _ground_y

	_roller_min_y = (wall_rect.position.y + roller_top_margin) - _ground_y
	_roller_max_y = (wall_rect.end.y - roller_bottom_margin) - _ground_y
	if _roller_max_y < _roller_min_y:
		var temp = _roller_min_y
		_roller_min_y = _roller_max_y
		_roller_max_y = temp
	_apply_roller_limits()


func set_paint_color(color: Color) -> void:
	_active_paint_color = color
	if _paint_amount > 5.0:
		foam.modulate = color


func set_external_modifiers(speed_multiplier: float, paint_multiplier: float, drain_multiplier: float) -> void:
	_external_speed_multiplier = maxf(0.1, speed_multiplier)
	_external_paint_multiplier = maxf(0.1, paint_multiplier)
	_external_drain_multiplier = maxf(0.1, drain_multiplier)


func set_color_efficiency(paint_multiplier: float, drain_multiplier: float) -> void:
	_color_paint_multiplier = maxf(0.4, paint_multiplier)
	_color_drain_multiplier = maxf(0.5, drain_multiplier)


func get_paint_ratio() -> float:
	if _paint_capacity <= 0.0:
		return 0.0
	return _paint_amount / _paint_capacity


func get_bucket_ratio() -> float:
	if _bucket_capacity <= 0.0:
		return 0.0
	return _bucket_amount / _bucket_capacity


func is_painting() -> bool:
	return _is_painting


func is_refilling() -> bool:
	return _is_refilling


func get_roller_position() -> Vector2:
	return foam.global_position


func get_stat_snapshot() -> Dictionary:
	return {
		"speed": _speed,
		"paint_radius": _paint_radius,
		"paint_strength": _paint_strength,
		"paint_capacity": _paint_capacity,
		"paint_regen": _paint_regen,
		"paint_drain": _paint_drain,
		"bucket_capacity": _bucket_capacity,
		"bucket_amount": _bucket_amount,
	}


func _physics_process(delta: float) -> void:
	if not _is_active:
		return

	var move_x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	if Input.is_key_pressed(KEY_D):
		move_x += 1.0
	if Input.is_key_pressed(KEY_A):
		move_x -= 1.0
	move_x = clampf(move_x, -1.0, 1.0)

	var roller_input = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	if Input.is_key_pressed(KEY_S):
		roller_input += 1.0
	if Input.is_key_pressed(KEY_W):
		roller_input -= 1.0
	roller_input = clampf(roller_input, -1.0, 1.0)
	var mouse_target_y = clampf(get_global_mouse_position().y - _ground_y, _roller_min_y, _roller_max_y)

	if absf(move_x) > 0.01:
		_facing = sign(move_x)

	velocity = Vector2(move_x * _speed * _external_speed_multiplier, 0.0)
	move_and_slide()

	global_position.x = clampf(global_position.x, move_bounds.position.x, move_bounds.end.x)
	global_position.y = _ground_y

	if absf(roller_input) > 0.01:
		_roller_target_y = clampf(_roller_target_y + (roller_input * roller_move_speed * delta), _roller_min_y, _roller_max_y)
	else:
		_roller_target_y = mouse_target_y
	roller.position.y = move_toward(roller.position.y, _roller_target_y, roller_move_speed * 1.35 * delta)
	roller.position.x = lerpf(roller.position.x, roller_x_offset * _facing, minf(1.0, delta * 14.0))
	roller.scale.x = _facing
	var roller_visual_input = roller_input
	if absf(roller_visual_input) <= 0.01:
		var visual_denominator = maxf(24.0, absf(_roller_max_y - _roller_min_y) * 0.35)
		roller_visual_input = clampf((mouse_target_y - roller.position.y) / visual_denominator, -1.0, 1.0)
	roller.rotation = deg_to_rad(roller_visual_input * 2.6)

	_animate_body(move_x, roller_visual_input, delta)
	_is_refilling = false

	var near_bucket = _bucket_world != Vector2.ZERO and global_position.distance_to(_bucket_world) <= _bucket_radius
	var wants_refill = near_bucket and Input.is_key_pressed(KEY_E)
	if wants_refill and _bucket_amount > 0.0 and _paint_amount < _paint_capacity:
		var refill_speed = (_paint_regen * 1.35) + refill_rate_per_second
		var refill_amount = minf(refill_speed * delta, minf(_paint_capacity - _paint_amount, _bucket_amount * refill_efficiency))
		if refill_amount > 0.0001:
			var bucket_cost = refill_amount / maxf(0.1, refill_efficiency)
			_paint_amount += refill_amount
			_bucket_amount = maxf(0.0, _bucket_amount - bucket_cost)
			_is_refilling = true

	var did_paint = false
	var wants_paint = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_P)
	if _wall and _wall.has_method("paint_at") and _paint_amount > 0.0 and not _is_refilling and wants_paint:
		var tank_ratio = clampf(_paint_amount / maxf(1.0, _paint_capacity), 0.12, 1.0)
		var paint_strength = _paint_strength * _external_paint_multiplier * _color_paint_multiplier * tank_ratio
		did_paint = bool(_wall.call("paint_at", foam.global_position, _paint_radius, paint_strength * delta))

	if did_paint:
		var paint_cost = _paint_drain * _external_drain_multiplier * _color_drain_multiplier * delta
		_paint_amount = maxf(0.0, _paint_amount - paint_cost)

	_is_painting = did_paint
	foam.modulate = _active_paint_color if _paint_amount > 5.0 else Color(0.45, 0.45, 0.45, 1.0)
	queue_redraw()


func _draw() -> void:
	var shoulder = Vector2(8.0 * _facing, -15.0)
	var roller_base = roller.position + Vector2(0.0, 16.0)
	draw_line(shoulder, roller_base, Color(0.30, 0.23, 0.16, 0.95), 6.0)
	draw_line(shoulder + Vector2(0.0, -1.0), roller_base + Vector2(0.0, -1.0), Color(0.62, 0.50, 0.38, 0.52), 2.2)

	for i in range(3):
		var t = float(i + 1) / 4.0
		var point = shoulder.lerp(roller_base, t)
		draw_circle(point, 1.4, Color(0.12, 0.12, 0.12, 0.32))

	if _is_painting:
		draw_circle(roller.position + Vector2(0.0, -12.0), 11.0, Color(_active_paint_color.r, _active_paint_color.g, _active_paint_color.b, 0.20))


func _animate_body(move_x: float, roller_input: float, delta: float) -> void:
	var movement = clampf(absf(move_x), 0.0, 1.0)
	_anim_time += delta * (2.8 + movement * 7.6)
	var bob = sin(_anim_time * 4.8) * 2.0 * movement
	var sway = sin(_anim_time * 3.2) * 1.5 * movement
	var lift_ratio = inverse_lerp(_roller_max_y, _roller_min_y, roller.position.y)

	if torso != null:
		torso.position = _rest_position("Torso", torso.position) + Vector2(0.0, bob)
		torso.rotation = deg_to_rad(2.6 * _facing * movement)
	if head != null:
		head.position = _rest_position("Head", head.position) + Vector2(0.0, bob * 0.4)
		head.rotation = deg_to_rad(-3.2 * _facing * movement)

	var arm_swing = sin(_anim_time * 6.2) * 0.22 * movement
	if arm_left != null:
		arm_left.position = _rest_position("ArmLeft", arm_left.position) + Vector2(-sway * 0.2, bob * 0.45)
		arm_left.rotation = -arm_swing
	if arm_right != null:
		arm_right.position = _rest_position("ArmRight", arm_right.position) + Vector2(sway * 0.24, bob * 0.3)
		arm_right.rotation = arm_swing + deg_to_rad(-24.0 - (lift_ratio * 22.0) + roller_input * 8.0)
	if roller_arm != null:
		roller_arm.position = _rest_position("RollerArm", roller_arm.position) + Vector2(sway * 0.4, bob * 0.22)
		roller_arm.rotation = deg_to_rad(-18.0 - (lift_ratio * 18.0) + roller_input * 6.0)

	var leg_swing = sin(_anim_time * 6.2 + PI * 0.5) * 1.5 * movement
	if leg_left != null:
		leg_left.position = _rest_position("LegLeft", leg_left.position) + Vector2(0.0, absf(leg_swing) * 0.25)
		leg_left.rotation = deg_to_rad(-4.0) * movement
	if leg_right != null:
		leg_right.position = _rest_position("LegRight", leg_right.position) + Vector2(0.0, absf(-leg_swing) * 0.25)
		leg_right.rotation = deg_to_rad(4.0) * movement


func _rest_position(name: String, fallback: Vector2) -> Vector2:
	var value = _rest_positions.get(name, fallback)
	if value is Vector2:
		return value
	return fallback


func _apply_roller_limits() -> void:
	_roller_target_y = clampf(_roller_target_y, _roller_min_y, _roller_max_y)
	roller.position.y = _roller_target_y
