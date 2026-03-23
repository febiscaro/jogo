extends CharacterBody2D

@export var speed: float = 290.0
@export var move_bounds := Rect2(190.0, 430.0, 900.0, 220.0)
@export var paint_radius: float = 55.0
@export var paint_strength_per_second: float = 2.4

@onready var roller: Node2D = $Roller

var _wall = null
var _is_active := true


func set_wall(wall) -> void:
	_wall = wall


func set_game_active(value: bool) -> void:
	_is_active = value
	if not value:
		velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if not _is_active:
		return

	var input_vector := Vector2(
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

	velocity = input_vector.normalized() * speed
	move_and_slide()

	global_position.x = clampf(global_position.x, move_bounds.position.x, move_bounds.end.x)
	global_position.y = clampf(global_position.y, move_bounds.position.y, move_bounds.end.y)

	if _wall and _wall.has_method("paint_at"):
		_wall.call("paint_at", roller.global_position, paint_radius, paint_strength_per_second * delta)
