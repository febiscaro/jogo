extends CharacterBody2D

@export var base_speed: float = 300.0
@export var move_bounds: Rect2 = Rect2(260.0, 130.0, 820.0, 520.0)
@export var base_paint_radius: float = 28.0
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
@export var roller_free_margin: float = 22.0
@export var roller_horizontal_reach: float = 132.0

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
var _move_blend: float = 0.0
var _lean_blend: float = 0.0
var _lift_blend: float = 0.0
var _arm_left_rot: float = 0.0
var _arm_right_rot: float = 0.0
var _roller_arm_rot: float = 0.0
var _head_tilt: float = 0.0
var _ground_y: float = 595.0
var _roller_min_x: float = -132.0
var _roller_max_x: float = 132.0
var _roller_min_y: float = -490.0
var _roller_max_y: float = -120.0
var _roller_target_x: float = 26.0
var _roller_target_y: float = -170.0
var _facing: float = 1.0


func _ready() -> void:
	_paint_amount = _paint_capacity
	_bucket_capacity = _paint_capacity * bucket_capacity_multiplier
	_bucket_amount = _bucket_capacity
	_ground_y = global_position.y
	_roller_target_x = roller.position.x
	_roller_target_y = roller.position.y
	for part in [torso, head, arm_left, arm_right, leg_left, leg_right, roller_arm]:
		if part != null:
			_rest_positions[part.name] = part.position
	if arm_left != null:
		_arm_left_rot = arm_left.rotation
	if arm_right != null:
		_arm_right_rot = arm_right.rotation
	if roller_arm != null:
		_roller_arm_rot = roller_arm.rotation
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
	_paint_radius = clampf(_paint_radius, 18.0, 38.0)
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

	var top_reach = wall_rect.position.y + roller_top_margin - roller_free_margin
	var bottom_reach = wall_rect.end.y - roller_bottom_margin + roller_free_margin
	_roller_min_y = top_reach - _ground_y
	_roller_max_y = bottom_reach - _ground_y
	if _roller_max_y < _roller_min_y:
		var temp = _roller_min_y
		_roller_min_y = _roller_max_y
		_roller_max_y = temp
	_roller_min_x = -maxf(48.0, roller_horizontal_reach)
	_roller_max_x = maxf(48.0, roller_horizontal_reach)
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

	var mouse_local = to_local(get_global_mouse_position())
	var mouse_target_x = clampf(mouse_local.x, _roller_min_x, _roller_max_x)
	var mouse_target_y = clampf(mouse_local.y, _roller_min_y, _roller_max_y)

	if absf(move_x) > 0.01:
		_facing = sign(move_x)

	velocity = Vector2(move_x * _speed * _external_speed_multiplier, 0.0)
	move_and_slide()

	global_position.x = clampf(global_position.x, move_bounds.position.x, move_bounds.end.x)
	global_position.y = _ground_y

	_roller_target_x = mouse_target_x
	_roller_target_y = mouse_target_y
	roller.position.y = move_toward(roller.position.y, _roller_target_y, roller_move_speed * 1.35 * delta)
	roller.position.x = move_toward(roller.position.x, _roller_target_x, roller_move_speed * 1.20 * delta)
	roller.scale.x = sign(roller.position.x) if absf(roller.position.x) > 1.0 else _facing
	var horizontal_ratio = clampf(roller.position.x / maxf(32.0, _roller_max_x), -1.0, 1.0)
	var roller_target_rot = deg_to_rad(horizontal_ratio * 9.0)
	roller.rotation = lerp_angle(roller.rotation, roller_target_rot, minf(1.0, delta * 11.0))
	var visual_denominator = maxf(24.0, absf(_roller_max_y - _roller_min_y) * 0.32)
	var roller_visual_input = clampf((_roller_target_y - roller.position.y) / visual_denominator, -1.0, 1.0)

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
	var movement_target = clampf(absf(move_x), 0.0, 1.0)
	_move_blend = move_toward(_move_blend, movement_target, delta * 4.6)
	_lean_blend = move_toward(_lean_blend, move_x, delta * 5.8)
	var lift_ratio = inverse_lerp(_roller_max_y, _roller_min_y, roller.position.y)
	_lift_blend = move_toward(_lift_blend, lift_ratio, delta * 4.2)
	_head_tilt = move_toward(_head_tilt, clampf(-_lean_blend * 0.58 + roller_input * 0.34, -1.0, 1.0), delta * 6.4)

	_anim_time += delta * (2.5 + _move_blend * 7.8)
	var bob = sin(_anim_time * 4.9) * (2.1 + _move_blend * 1.2) * _move_blend
	var sway = sin(_anim_time * 3.2) * (1.0 + _move_blend * 1.8)
	var step_cycle = sin(_anim_time * 6.1)
	var step_weight = absf(step_cycle) * 1.35 * _move_blend
	var torso_drop = step_weight * 0.32

	if torso != null:
		torso.position = _rest_position("Torso", torso.position) + Vector2(_lean_blend * 2.1, bob + torso_drop)
		torso.rotation = deg_to_rad(2.0 * _lean_blend + step_cycle * 1.1 * _move_blend)
	if head != null:
		head.position = _rest_position("Head", head.position) + Vector2(_lean_blend * 0.8, bob * 0.35 - step_weight * 0.12)
		head.rotation = deg_to_rad(-2.6 * _head_tilt + sin(_anim_time * 2.1) * 0.8 * _move_blend)

	var arm_swing = sin(_anim_time * 6.1 + PI * 0.18) * 0.19 * _move_blend
	var arm_left_target = deg_to_rad(5.0 * _lean_blend - _lift_blend * 8.0) - arm_swing
	var arm_right_target = arm_swing + deg_to_rad(-22.0 - (_lift_blend * 24.0) + roller_input * 8.6 + _lean_blend * 5.6)
	var roller_arm_target = deg_to_rad(-17.0 - (_lift_blend * 20.0) + roller_input * 6.8 + _lean_blend * 3.0)
	_arm_left_rot = lerp_angle(_arm_left_rot, arm_left_target, minf(1.0, delta * 9.0))
	_arm_right_rot = lerp_angle(_arm_right_rot, arm_right_target, minf(1.0, delta * 9.8))
	_roller_arm_rot = lerp_angle(_roller_arm_rot, roller_arm_target, minf(1.0, delta * 9.4))

	if arm_left != null:
		arm_left.position = _rest_position("ArmLeft", arm_left.position) + Vector2(-sway * 0.22, bob * 0.48 + step_weight * 0.12)
		arm_left.rotation = _arm_left_rot
	if arm_right != null:
		arm_right.position = _rest_position("ArmRight", arm_right.position) + Vector2(sway * 0.28, bob * 0.34 + step_weight * 0.18)
		arm_right.rotation = _arm_right_rot
	if roller_arm != null:
		roller_arm.position = _rest_position("RollerArm", roller_arm.position) + Vector2(sway * 0.44, bob * 0.24 + step_weight * 0.10)
		roller_arm.rotation = _roller_arm_rot

	var leg_lift_left = maxf(0.0, sin(_anim_time * 6.1 + PI * 0.5)) * 1.6 * _move_blend
	var leg_lift_right = maxf(0.0, sin(_anim_time * 6.1 + PI * 1.5)) * 1.6 * _move_blend
	if leg_left != null:
		leg_left.position = _rest_position("LegLeft", leg_left.position) + Vector2(-_lean_blend * 0.5, leg_lift_left * 0.42)
		leg_left.rotation = deg_to_rad((-3.0 + step_cycle * 1.6) * _move_blend)
	if leg_right != null:
		leg_right.position = _rest_position("LegRight", leg_right.position) + Vector2(_lean_blend * 0.5, leg_lift_right * 0.42)
		leg_right.rotation = deg_to_rad((3.0 - step_cycle * 1.6) * _move_blend)


func _rest_position(name: String, fallback: Vector2) -> Vector2:
	var value = _rest_positions.get(name, fallback)
	if value is Vector2:
		return value
	return fallback


func _apply_roller_limits() -> void:
	_roller_target_x = clampf(_roller_target_x, _roller_min_x, _roller_max_x)
	_roller_target_y = clampf(_roller_target_y, _roller_min_y, _roller_max_y)
	roller.position.x = _roller_target_x
	roller.position.y = _roller_target_y
