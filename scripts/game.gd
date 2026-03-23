extends Node2D

@export var round_duration := 70.0
@export var win_coverage := 0.70
@export var lose_coverage := 0.20

@onready var wall = $Wall
@onready var player = $Player
@onready var coverage_value: Label = $UI/Sidebar/CoverageValue
@onready var time_value: Label = $UI/Sidebar/TimeValue
@onready var top_status: Label = $UI/TopStatus
@onready var center_message: Label = $UI/CenterMessage

var _elapsed := 0.0
var _drop_timer := 0.0
var _running := true
var _drops: Array[Dictionary] = []


func _ready() -> void:
	randomize()
	if player.has_method("set_wall"):
		player.set_wall(wall)
	_update_hud(wall.get_coverage_ratio())
	center_message.text = "WASD para mover | Encoste no muro para retocar"


func _process(delta: float) -> void:
	if _running:
		_elapsed += delta
		_update_drops(delta)

		var coverage := wall.get_coverage_ratio()
		_update_hud(coverage)
		_check_end_conditions(coverage)
	else:
		if Input.is_key_pressed(KEY_R):
			get_tree().reload_current_scene()

	queue_redraw()


func _draw() -> void:
	for drop in _drops:
		var pos: Vector2 = drop["pos"]
		var radius: float = drop["radius"]
		draw_circle(pos, radius, Color(0.70, 0.88, 1.0, 0.95))
		draw_line(pos, pos + Vector2(0.0, radius * 2.6), Color(0.70, 0.88, 1.0, 0.50), maxf(1.5, radius * 0.35))


func _update_drops(delta: float) -> void:
	var difficulty := clampf(_elapsed / round_duration, 0.0, 1.3)
	var wall_rect: Rect2 = wall.get_wall_rect_global()

	_drop_timer -= delta
	if _drop_timer <= 0.0:
		_spawn_drop(wall_rect, difficulty)
		_drop_timer = maxf(0.13, randf_range(0.32, 0.75) - (difficulty * 0.24))

	for index in range(_drops.size() - 1, -1, -1):
		var drop := _drops[index]
		var pos: Vector2 = drop["pos"]
		pos.y += float(drop["speed"]) * delta
		drop["pos"] = pos

		if wall_rect.has_point(pos):
			wall.damage_at(pos, float(drop["radius"]) * 2.0, float(drop["power"]) * delta)

		if pos.y > wall_rect.end.y + 120.0:
			_drops.remove_at(index)
		else:
			_drops[index] = drop


func _spawn_drop(wall_rect: Rect2, difficulty: float) -> void:
	var x := randf_range(wall_rect.position.x + 10.0, wall_rect.end.x - 10.0)
	var y := wall_rect.position.y - randf_range(30.0, 220.0)
	_drops.append({
		"pos": Vector2(x, y),
		"speed": randf_range(130.0, 240.0) + (difficulty * 140.0),
		"radius": randf_range(5.0, 9.0),
		"power": randf_range(0.65, 1.35) + (difficulty * 0.65)
	})


func _update_hud(coverage: float) -> void:
	coverage_value.text = "%d%%" % int(round(coverage * 100.0))
	var remaining := maxf(0.0, round_duration - _elapsed)
	time_value.text = "%.1fs" % remaining

	if _running:
		top_status.text = "Mantenha o muro acima de %d%% ate o tempo acabar" % int(round(win_coverage * 100.0))


func _check_end_conditions(coverage: float) -> void:
	if coverage <= lose_coverage:
		_finish_game(false, "Derrota: o muro derreteu demais! Pressione R para reiniciar.")
		return

	if _elapsed >= round_duration:
		if coverage >= win_coverage:
			_finish_game(true, "Vitoria! O muro ficou no capricho. Pressione R para jogar de novo.")
		else:
			_finish_game(false, "Tempo esgotado e faltou retoque. Pressione R para tentar de novo.")


func _finish_game(is_win: bool, message: String) -> void:
	_running = false
	center_message.text = message
	top_status.text = is_win ? "RESULTADO: VITORIA" : "RESULTADO: DERROTA"
	top_status.modulate = is_win ? Color(0.56, 0.96, 0.60, 1.0) : Color(1.0, 0.48, 0.44, 1.0)
	if player.has_method("set_game_active"):
		player.set_game_active(false)
