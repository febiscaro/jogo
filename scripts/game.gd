extends Node2D

const STATE_CONTRACT_SELECT = 0
const STATE_IN_CONTRACT = 1
const STATE_UPGRADE_SELECT = 2
const STATE_RUN_OVER = 3

const SAVE_PATH = "user://meta_progress.json"

const MULTIPLIER_KEYS = [
	"speed_mult",
	"paint_radius_mult",
	"paint_strength_mult",
	"paint_capacity_mult",
	"paint_regen_mult",
	"paint_drain_mult",
	"payout_mult",
	"drop_interval_mult",
]

@onready var wall: Node = $Wall
@onready var player: Node = $Player
@onready var sidebar: Panel = $UI/Sidebar
@onready var title_label: Label = $UI/Sidebar/Title
@onready var coverage_title: Label = $UI/Sidebar/CoverageTitle
@onready var coverage_value: Label = $UI/Sidebar/CoverageValue
@onready var time_title: Label = $UI/Sidebar/TimeTitle
@onready var time_value: Label = $UI/Sidebar/TimeValue
@onready var help_label: Label = $UI/Sidebar/Help
@onready var top_status: Label = $UI/TopStatus
@onready var center_message: Label = $UI/CenterMessage
@onready var swatch_blue: ColorRect = $UI/Sidebar/SwatchBlue
@onready var swatch_orange: ColorRect = $UI/Sidebar/SwatchOrange
@onready var swatch_green: ColorRect = $UI/Sidebar/SwatchGreen
@onready var swatch_purple: ColorRect = $UI/Sidebar/SwatchPurple

var money_value: Label
var day_value: Label
var streak_value: Label
var paint_value: Label
var risk_value: Label
var event_value: Label

var choice_panel: Panel
var choice_title: Label
var choice_body: Label
var choice_hint: Label

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _state: int = STATE_CONTRACT_SELECT

var _contract_templates: Array[Dictionary] = []
var _upgrade_catalog: Array[Dictionary] = []
var _event_catalog: Array[Dictionary] = []

var _contracts_offered: Array[Dictionary] = []
var _upgrades_offered: Array[Dictionary] = []
var _selected_contract: Dictionary = {}
var _active_event: Dictionary = {}
var _drops: Array[Dictionary] = []
var _owned_upgrades: Array[String] = []
var _run_modifiers: Dictionary = {}

var _elapsed: float = 0.0
var _drop_timer: float = 0.0
var _event_timer: float = 0.0
var _active_event_time: float = 0.0

var _run_seed: int = 0
var _run_day: int = 1
var _streak: int = 0
var _money: int = 0
var _run_credits_earned: int = 0
var _total_contracts_completed: int = 0
var _reputation: float = 1.0

var _meta_best_streak: int = 0
var _meta_total_runs: int = 0
var _meta_total_credits: int = 0


func _ready() -> void:
	_rng.randomize()
	_setup_ui()

	if player.has_method("set_wall"):
		player.call("set_wall", wall)

	_contract_templates = _build_contract_templates()
	_upgrade_catalog = _build_upgrade_catalog()
	_event_catalog = _build_event_catalog()

	_load_meta_progress()
	_start_new_run()


func _process(delta: float) -> void:
	if _state == STATE_IN_CONTRACT:
		_process_contract(delta)
	elif _state == STATE_RUN_OVER:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return

		var choice_index = _choice_from_key(key_event.keycode)
		if choice_index >= 0:
			if _state == STATE_CONTRACT_SELECT:
				_pick_contract(choice_index)
			elif _state == STATE_UPGRADE_SELECT:
				_pick_upgrade(choice_index)
			return

		if _state == STATE_RUN_OVER and (
			key_event.keycode == KEY_R
			or key_event.keycode == KEY_ENTER
			or key_event.keycode == KEY_SPACE
		):
			_start_new_run()


func _draw() -> void:
	for drop in _drops:
		var pos = drop.get("pos", Vector2.ZERO)
		var radius = float(drop.get("radius", 6.0))
		var color = drop.get("color", Color(0.70, 0.88, 1.0, 0.95))
		draw_circle(pos, radius, color)
		draw_line(
			pos,
			pos + Vector2(float(drop.get("drift", 0.0)) * 0.07, radius * 2.5),
			Color(color.r, color.g, color.b, 0.5),
			maxf(1.5, radius * 0.32)
		)


func _setup_ui() -> void:
	title_label.text = "Contratos"
	help_label.layout_mode = 0
	help_label.offset_left = 20.0
	help_label.offset_top = 204.0
	help_label.offset_right = 180.0
	help_label.offset_bottom = 228.0
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.text = "WASD mover  |  1-2-3 escolhas  |  R reinicia"

	money_value = _ensure_stat_label("MoneyValue", 20.0, 420.0, 180.0, 446.0, 18)
	day_value = _ensure_stat_label("DayValue", 20.0, 462.0, 180.0, 488.0, 18)
	streak_value = _ensure_stat_label("StreakValue", 20.0, 504.0, 180.0, 530.0, 18)
	paint_value = _ensure_stat_label("PaintValue", 20.0, 546.0, 180.0, 572.0, 18)
	risk_value = _ensure_stat_label("RiskValue", 20.0, 588.0, 180.0, 614.0, 16)
	event_value = _ensure_stat_label("EventValue", 20.0, 630.0, 180.0, 656.0, 16)

	_ensure_stat_label("MoneyTitle", 20.0, 400.0, 180.0, 422.0, 13).text = "Creditos"
	_ensure_stat_label("DayTitle", 20.0, 442.0, 180.0, 464.0, 13).text = "Dia da run"
	_ensure_stat_label("StreakTitle", 20.0, 484.0, 180.0, 506.0, 13).text = "Streak"
	_ensure_stat_label("PaintTitle", 20.0, 526.0, 180.0, 548.0, 13).text = "Tanque"
	_ensure_stat_label("RiskTitle", 20.0, 568.0, 180.0, 590.0, 13).text = "Risco"
	_ensure_stat_label("EventTitle", 20.0, 610.0, 180.0, 632.0, 13).text = "Evento"

	choice_panel = _ensure_panel("ChoicePanel", 250.0, 90.0, 1070.0, 620.0)
	choice_panel.self_modulate = Color(0.95, 0.96, 0.98, 0.95)
	choice_title = _ensure_panel_label(choice_panel, "ChoiceTitle", 24.0, 20.0, 796.0, 56.0, 28)
	choice_body = _ensure_panel_label(choice_panel, "ChoiceBody", 24.0, 76.0, 796.0, 460.0, 19)
	choice_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_hint = _ensure_panel_label(choice_panel, "ChoiceHint", 24.0, 476.0, 796.0, 518.0, 16)

	top_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _ensure_stat_label(node_name: String, left: float, top: float, right: float, bottom: float, font_size: int) -> Label:
	var existing = sidebar.get_node_or_null(node_name)
	var label: Label
	if existing and existing is Label:
		label = existing as Label
	else:
		label = Label.new()
		label.name = node_name
		sidebar.add_child(label)

	label.layout_mode = 0
	label.offset_left = left
	label.offset_top = top
	label.offset_right = right
	label.offset_bottom = bottom
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _ensure_panel(panel_name: String, left: float, top: float, right: float, bottom: float) -> Panel:
	var ui_root = $UI
	var existing = ui_root.get_node_or_null(panel_name)
	var panel: Panel
	if existing and existing is Panel:
		panel = existing as Panel
	else:
		panel = Panel.new()
		panel.name = panel_name
		ui_root.add_child(panel)

	panel.layout_mode = 0
	panel.offset_left = left
	panel.offset_top = top
	panel.offset_right = right
	panel.offset_bottom = bottom
	return panel


func _ensure_panel_label(parent: Panel, node_name: String, left: float, top: float, right: float, bottom: float, font_size: int) -> Label:
	var existing = parent.get_node_or_null(node_name)
	var label: Label
	if existing and existing is Label:
		label = existing as Label
	else:
		label = Label.new()
		label.name = node_name
		parent.add_child(label)

	label.layout_mode = 0
	label.offset_left = left
	label.offset_top = top
	label.offset_right = right
	label.offset_bottom = bottom
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _choice_from_key(keycode: int) -> int:
	if keycode == KEY_1 or keycode == KEY_KP_1:
		return 0
	if keycode == KEY_2 or keycode == KEY_KP_2:
		return 1
	if keycode == KEY_3 or keycode == KEY_KP_3:
		return 2
	return -1


func _start_new_run() -> void:
	_run_seed = int(_rng.randi())
	_run_day = 1
	_streak = 0
	_money = 0
	_run_credits_earned = 0
	_total_contracts_completed = 0
	_reputation = 1.0
	_owned_upgrades.clear()
	_run_modifiers = _base_modifiers()
	_active_event.clear()
	_active_event_time = 0.0
	_drops.clear()

	if player.has_method("set_game_active"):
		player.call("set_game_active", false)
	if player.has_method("apply_run_modifiers"):
		player.call("apply_run_modifiers", _run_modifiers)
	if player.has_method("set_external_modifiers"):
		player.call("set_external_modifiers", 1.0, 1.0, 1.0)

	top_status.modulate = Color(1, 1, 1, 1)
	_enter_contract_selection("Nova run iniciada. Escolha um contrato.")


func _enter_contract_selection(message: String) -> void:
	_state = STATE_CONTRACT_SELECT
	_active_event.clear()
	_active_event_time = 0.0
	_drops.clear()
	_contracts_offered = _generate_contract_offers()
	_selected_contract = {}

	if player.has_method("set_game_active"):
		player.call("set_game_active", false)
	if player.has_method("set_external_modifiers"):
		player.call("set_external_modifiers", 1.0, 1.0, 1.0)

	coverage_title.text = "Cobertura"
	coverage_value.text = "--"
	time_title.text = "Tempo"
	time_value.text = "--"
	risk_value.text = "-"
	event_value.text = "Planejando"

	top_status.text = message
	center_message.text = "Use 1, 2 ou 3 para aceitar contrato."
	_show_contract_choices()
	_update_sidebar_meta()
	queue_redraw()


func _show_contract_choices() -> void:
	choice_panel.visible = true
	choice_title.text = "Escolha Seu Proximo Contrato"

	var lines: Array[String] = []
	for i in range(_contracts_offered.size()):
		var contract: Dictionary = _contracts_offered[i]
		lines.append(_format_contract(i, contract))

	choice_body.text = "\n\n".join(lines)
	choice_hint.text = "1/2/3: selecionar contrato  |  Roguelike: se quebrar a run, volta do zero."


func _pick_contract(index: int) -> void:
	if index < 0 or index >= _contracts_offered.size():
		return

	_selected_contract = _contracts_offered[index]
	_start_contract()


func _start_contract() -> void:
	_state = STATE_IN_CONTRACT
	_elapsed = 0.0
	_drop_timer = 0.0
	_event_timer = _rng.randf_range(5.6, 9.8)
	_active_event_time = 0.0
	_active_event.clear()
	_drops.clear()

	var config = {
		"paint_color": _selected_contract.get("paint_color", Color(0.31, 0.62, 0.90, 1.0)),
		"initial_min_coverage": _selected_contract.get("initial_min", 0.54),
		"initial_max_coverage": _selected_contract.get("initial_max", 0.72),
	}
	if wall.has_method("configure"):
		wall.call("configure", config)
	elif wall.has_method("set_paint_color"):
		wall.call("set_paint_color", config["paint_color"])

	if player.has_method("set_game_active"):
		player.call("set_game_active", true)
	if player.has_method("apply_run_modifiers"):
		player.call("apply_run_modifiers", _run_modifiers)
	if player.has_method("refill_paint"):
		player.call("refill_paint")
	if player.has_method("set_external_modifiers"):
		player.call("set_external_modifiers", 1.0, 1.0, 1.0)

	_apply_palette(_selected_contract.get("paint_color", Color(0.31, 0.62, 0.90, 1.0)))
	choice_panel.visible = false
	top_status.text = "Contrato ativo: %s" % _selected_contract.get("title", "Sem nome")
	center_message.text = "Pinte sem parar e sobreviva ao clima."
	_update_sidebar_meta()
	queue_redraw()


func _process_contract(delta: float) -> void:
	_elapsed += delta
	_update_event_system(delta)
	_update_drops(delta)

	var coverage = float(wall.call("get_coverage_ratio"))
	var lowest = float(wall.call("get_lowest_coverage"))
	var duration = float(_selected_contract.get("duration", 60.0))
	var target = clampf(float(_selected_contract.get("target_coverage", 0.68)) + float(_run_modifiers.get("target_offset", 0.0)), 0.35, 0.95)
	var fail_threshold = clampf(float(_selected_contract.get("fail_coverage", 0.21)) + float(_run_modifiers.get("fail_offset", 0.0)), 0.05, 0.65)

	_update_contract_hud(coverage, duration, target)
	var fracture_limit = fail_threshold * 0.85
	var bad_cells = int(wall.call("get_cell_count_below", fracture_limit))
	var total_cells = maxi(1, int(wall.call("get_total_cells")))
	var fracture_ratio = float(bad_cells) / float(total_cells)

	if coverage <= fail_threshold or fracture_ratio >= 0.72:
		_fail_run("O muro cedeu sob a chuva acida.", coverage, lowest)
		return

	if _elapsed >= duration:
		if coverage >= target:
			_complete_contract(coverage, target, lowest)
		else:
			_fail_run("Tempo acabou e o contrato ficou abaixo da meta.", coverage, lowest)
		return

	queue_redraw()


func _update_drops(delta: float) -> void:
	var wall_rect: Rect2 = wall.call("get_wall_rect_global")
	var duration = maxf(1.0, float(_selected_contract.get("duration", 60.0)))
	var pressure = 1.0 + (_elapsed / duration) * 0.42 + float(maxi(0, _run_day - 1)) * 0.05
	var event_spawn_mult = _event_value("spawn_mult", 1.0)
	var event_speed_mult = _event_value("speed_mult", 1.0)
	var event_radius_mult = _event_value("radius_mult", 1.0)
	var event_damage_mult = _event_value("damage_mult", 1.0)
	var wind_force = _event_value("wind", 0.0)
	var drop_interval_mult = float(_run_modifiers.get("drop_interval_mult", 1.0))

	var base_interval = float(_selected_contract.get("drop_interval", 0.52))
	var spawn_interval = maxf(0.07, (base_interval * drop_interval_mult) / (pressure * event_spawn_mult))

	_drop_timer -= delta
	while _drop_timer <= 0.0:
		_spawn_drop(wall_rect, pressure, event_speed_mult, event_radius_mult, wind_force)
		_drop_timer += spawn_interval

	var melt_resist = clampf(float(_run_modifiers.get("melt_resist", 0.0)), 0.0, 0.82)
	var damage_scale = maxf(0.05, event_damage_mult * (1.0 - melt_resist))

	for i in range(_drops.size() - 1, -1, -1):
		var drop: Dictionary = _drops[i]
		var pos = drop.get("pos", Vector2.ZERO)
		var speed = float(drop.get("speed", 200.0))
		var radius = float(drop.get("radius", 6.0))
		var drift = float(drop.get("drift", 0.0))
		var power = float(drop.get("power", 1.0))

		pos.x += drift * delta
		pos.y += speed * delta
		drop["pos"] = pos

		if wall_rect.has_point(pos):
			wall.call("damage_at", pos, radius * 2.0, power * damage_scale * delta)

		if pos.y > wall_rect.end.y + 120.0 or pos.x < wall_rect.position.x - 120.0 or pos.x > wall_rect.end.x + 120.0:
			_drops.remove_at(i)
		else:
			_drops[i] = drop


func _spawn_drop(wall_rect: Rect2, pressure: float, speed_mult: float, radius_mult: float, wind_force: float) -> void:
	var x = _rng.randf_range(wall_rect.position.x + 12.0, wall_rect.end.x - 12.0)
	var y = wall_rect.position.y - _rng.randf_range(30.0, 210.0)

	var base_speed = float(_selected_contract.get("drop_speed", 180.0))
	var base_power = float(_selected_contract.get("drop_power", 1.0))
	var base_radius = float(_selected_contract.get("drop_radius", 7.0))
	var color = _selected_contract.get("drop_color", Color(0.70, 0.88, 1.0, 0.95))

	_drops.append({
		"pos": Vector2(x, y),
		"speed": base_speed * pressure * speed_mult * _rng.randf_range(0.90, 1.12),
		"power": base_power * pressure * _rng.randf_range(0.84, 1.22),
		"radius": base_radius * radius_mult * _rng.randf_range(0.9, 1.15),
		"drift": _rng.randf_range(-28.0, 28.0) + wind_force,
		"color": color,
	})


func _update_event_system(delta: float) -> void:
	if not _active_event.is_empty():
		_active_event_time -= delta
		event_value.text = "%s (%.1fs)" % [_active_event.get("name", "Evento"), maxf(0.0, _active_event_time)]
		if _active_event_time <= 0.0:
			_clear_active_event()
		return

	_event_timer -= delta
	event_value.text = "Ceu instavel"
	if _event_timer > 0.0:
		return

	var frequency = clampf(float(_selected_contract.get("event_frequency", 0.42)), 0.05, 1.2)
	var trigger_chance = clampf(0.18 + (frequency * 0.52), 0.1, 0.9)
	if _rng.randf() <= trigger_chance:
		_activate_event()

	_event_timer = _rng.randf_range(6.4, 11.2) / maxf(0.4, frequency)


func _activate_event() -> void:
	if _event_catalog.is_empty():
		return

	var event_template: Dictionary = _event_catalog[_rng.randi_range(0, _event_catalog.size() - 1)]
	_active_event = event_template.duplicate(true)
	_active_event_time = _rng.randf_range(float(_active_event.get("duration_min", 7.0)), float(_active_event.get("duration_max", 11.0)))

	var speed_mult = _event_value("player_speed_mult", 1.0)
	var paint_mult = _event_value("player_paint_mult", 1.0)
	var drain_mult = _event_value("player_drain_mult", 1.0)
	if player.has_method("set_external_modifiers"):
		player.call("set_external_modifiers", speed_mult, paint_mult, drain_mult)

	top_status.text = "Evento: %s" % _active_event.get("name", "Clima hostil")
	center_message.text = _active_event.get("description", "")


func _clear_active_event() -> void:
	_active_event.clear()
	_active_event_time = 0.0
	if player.has_method("set_external_modifiers"):
		player.call("set_external_modifiers", 1.0, 1.0, 1.0)
	event_value.text = "Ceu limpo"
	top_status.text = "Contrato ativo: %s" % _selected_contract.get("title", "Sem nome")
	center_message.text = "Continue o retoque."


func _event_value(key: String, default_value: float) -> float:
	if _active_event.is_empty():
		return default_value
	return float(_active_event.get(key, default_value))


func _update_contract_hud(coverage: float, duration: float, target: float) -> void:
	coverage_title.text = "Cobertura (meta %d%%)" % int(round(target * 100.0))
	coverage_value.text = "%d%%" % int(round(coverage * 100.0))
	var remaining = maxf(0.0, duration - _elapsed)
	time_title.text = "Tempo restante"
	time_value.text = "%.1fs" % remaining

	var paint_ratio = 0.0
	if player.has_method("get_paint_ratio"):
		paint_ratio = float(player.call("get_paint_ratio"))
	paint_value.text = "%d%%" % int(round(paint_ratio * 100.0))

	risk_value.text = _selected_contract.get("risk_label", "-")
	_update_sidebar_meta()


func _complete_contract(coverage: float, target: float, lowest: float) -> void:
	_clear_active_event()
	_drops.clear()
	if player.has_method("set_game_active"):
		player.call("set_game_active", false)

	var base_payout = int(_selected_contract.get("payout", 100))
	var quality = clampf((coverage - target) * 2.4, 0.0, 0.9)
	var stability_bonus = clampf((lowest - 0.25) * 0.8, 0.0, 0.35)
	var payout_scale = float(_run_modifiers.get("payout_mult", 1.0))
	var payout = int(round(float(base_payout) * (1.0 + quality + stability_bonus) * payout_scale))

	_money += payout
	_run_credits_earned += payout
	_streak += 1
	_total_contracts_completed += 1
	_reputation += 0.45 + quality
	_run_day += 1

	top_status.text = "Contrato entregue! +C$%d" % payout
	center_message.text = "Excelente. Agora escolha um upgrade para a run."
	_enter_upgrade_selection()


func _fail_run(reason: String, coverage: float, lowest: float) -> void:
	_state = STATE_RUN_OVER
	_clear_active_event()
	_drops.clear()
	if player.has_method("set_game_active"):
		player.call("set_game_active", false)

	_meta_total_runs += 1
	_meta_total_credits += _run_credits_earned
	if _streak > _meta_best_streak:
		_meta_best_streak = _streak
	_save_meta_progress()

	top_status.text = "RUN QUEBRADA"
	top_status.modulate = Color(1.0, 0.48, 0.44, 1.0)
	center_message.text = "Pressione R, ENTER ou ESPACO para iniciar nova run."

	choice_panel.visible = true
	choice_title.text = "Resumo da Run"
	choice_body.text = (
		"Motivo da queda: %s\n\n"
		+ "Cobertura final: %d%%\n"
		+ "Ponto mais fraco do muro: %d%%\n"
		+ "Streak atingida: %d\n"
		+ "Contratos concluidos: %d\n"
		+ "Creditos na run: C$%d\n\n"
		+ "Melhor streak global: %d\n"
		+ "Runs totais: %d\n"
		+ "Creditos totais acumulados: C$%d"
	) % [
		reason,
		int(round(coverage * 100.0)),
		int(round(lowest * 100.0)),
		_streak,
		_total_contracts_completed,
		_run_credits_earned,
		_meta_best_streak,
		_meta_total_runs,
		_meta_total_credits,
	]
	choice_hint.text = "R / ENTER / ESPACO: iniciar nova run"
	_update_sidebar_meta()
	queue_redraw()


func _enter_upgrade_selection() -> void:
	_upgrades_offered = _roll_upgrade_choices()
	if _upgrades_offered.is_empty():
		_enter_contract_selection("Sem upgrades disponiveis. Proximo contrato!")
		return

	_state = STATE_UPGRADE_SELECT
	choice_panel.visible = true
	choice_title.text = "Escolha Um Upgrade"

	var lines: Array[String] = []
	for i in range(_upgrades_offered.size()):
		var upgrade: Dictionary = _upgrades_offered[i]
		lines.append("%d) %s\n%s" % [i + 1, upgrade.get("name", "Upgrade"), upgrade.get("description", "")])

	choice_body.text = "\n\n".join(lines)
	choice_hint.text = "1/2/3: aplicar upgrade e continuar a run"
	coverage_title.text = "Cobertura"
	time_title.text = "Tempo"
	_update_sidebar_meta()


func _pick_upgrade(index: int) -> void:
	if index < 0 or index >= _upgrades_offered.size():
		return

	var upgrade: Dictionary = _upgrades_offered[index]
	_apply_upgrade(upgrade)
	top_status.text = "Upgrade ativo: %s" % upgrade.get("name", "")
	center_message.text = "Run fortalecida. Novos contratos liberados."
	_enter_contract_selection("Escolha o proximo contrato.")


func _apply_upgrade(upgrade: Dictionary) -> void:
	var upgrade_id = String(upgrade.get("id", ""))
	var stackable = bool(upgrade.get("stackable", false))
	if not stackable and not _owned_upgrades.has(upgrade_id):
		_owned_upgrades.append(upgrade_id)

	var effects: Dictionary = upgrade.get("effects", {})
	for key in effects.keys():
		if MULTIPLIER_KEYS.has(key):
			var current_mul = float(_run_modifiers.get(key, 1.0))
			_run_modifiers[key] = current_mul * float(effects[key])
		else:
			var current_add = float(_run_modifiers.get(key, 0.0))
			_run_modifiers[key] = current_add + float(effects[key])

	if player.has_method("apply_run_modifiers"):
		player.call("apply_run_modifiers", _run_modifiers)


func _roll_upgrade_choices() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for entry in _upgrade_catalog:
		var upgrade_id = String(entry.get("id", ""))
		var stackable = bool(entry.get("stackable", false))
		if stackable or not _owned_upgrades.has(upgrade_id):
			pool.append(entry)

	if pool.is_empty():
		return []

	var choices: Array[Dictionary] = []
	var attempts = 0
	while choices.size() < 3 and attempts < 40:
		attempts += 1
		var candidate: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
		var candidate_id = String(candidate.get("id", ""))
		var already = false
		for selected in choices:
			if String(selected.get("id", "")) == candidate_id:
				already = true
				break
		if already and not bool(candidate.get("stackable", false)):
			continue
		choices.append(candidate)

	return choices


func _generate_contract_offers() -> Array[Dictionary]:
	var max_tier = mini(5, 1 + int(floor(float(_run_day + _streak) / 2.2)))
	var candidates: Array[Dictionary] = []
	for template in _contract_templates:
		if int(template.get("tier", 1)) <= max_tier + 1:
			candidates.append(template)

	if candidates.is_empty():
		candidates = _contract_templates.duplicate(true)

	var offers: Array[Dictionary] = []
	var attempts = 0
	while offers.size() < 3 and attempts < 50:
		attempts += 1
		var template: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
		offers.append(_roll_contract(template))

	return offers


func _roll_contract(template: Dictionary) -> Dictionary:
	var day_scale = 1.0 + float(maxi(0, _run_day - 1)) * 0.08
	var duration = _rng.randf_range(float(template.get("duration_min", 45.0)), float(template.get("duration_max", 80.0)))
	var target = clampf(
		_rng.randf_range(float(template.get("target_min", 0.62)), float(template.get("target_max", 0.82))) + (float(_run_day - 1) * 0.006),
		0.5,
		0.92
	)
	var fail_threshold = clampf(
		_rng.randf_range(float(template.get("fail_min", 0.18)), float(template.get("fail_max", 0.27))) + (float(_run_day - 1) * 0.0025),
		0.1,
		0.5
	)
	var payout = int(round(_rng.randf_range(float(template.get("payout_min", 80.0)), float(template.get("payout_max", 160.0))) * day_scale))
	var drop_interval = maxf(
		0.11,
		_rng.randf_range(float(template.get("drop_interval_min", 0.42)), float(template.get("drop_interval_max", 0.68))) / day_scale
	)
	var drop_speed = _rng.randf_range(float(template.get("drop_speed_min", 130.0)), float(template.get("drop_speed_max", 220.0))) * day_scale
	var drop_power = _rng.randf_range(float(template.get("drop_power_min", 0.7)), float(template.get("drop_power_max", 1.2))) * (1.0 + float(maxi(0, _run_day - 1)) * 0.04)
	var drop_radius = _rng.randf_range(float(template.get("drop_radius_min", 5.0)), float(template.get("drop_radius_max", 9.0)))
	var event_frequency = _rng.randf_range(float(template.get("event_min", 0.3)), float(template.get("event_max", 0.65)))

	var danger_score = ((1.0 / drop_interval) * drop_power * (drop_speed / 180.0) * (target + event_frequency))
	var risk = "Baixo"
	if danger_score >= 3.1 and danger_score < 4.2:
		risk = "Medio"
	elif danger_score >= 4.2 and danger_score < 5.7:
		risk = "Alto"
	elif danger_score >= 5.7:
		risk = "Extremo"

	return {
		"title": template.get("title", "Contrato"),
		"client": template.get("client", "Cliente"),
		"description": template.get("description", ""),
		"duration": duration,
		"target_coverage": target,
		"fail_coverage": fail_threshold,
		"payout": payout,
		"drop_interval": drop_interval,
		"drop_speed": drop_speed,
		"drop_power": drop_power,
		"drop_radius": drop_radius,
		"event_frequency": event_frequency,
		"paint_color": template.get("paint_color", Color(0.31, 0.62, 0.90, 1.0)),
		"drop_color": template.get("drop_color", Color(0.70, 0.88, 1.0, 0.95)),
		"initial_min": template.get("initial_min", 0.52),
		"initial_max": template.get("initial_max", 0.75),
		"risk_label": risk,
		"danger_score": danger_score,
	}


func _format_contract(index: int, contract: Dictionary) -> String:
	return (
		"%d) %s  |  %s\n"
		+ "Cliente: %s\n"
		+ "Tempo: %.0fs  Meta: %d%%  Ruina: %d%%\n"
		+ "Pagamento: C$%d  |  Risco: %s\n"
		+ "%s"
	) % [
		index + 1,
		contract.get("title", "Contrato"),
		contract.get("risk_label", ""),
		contract.get("client", "Cliente"),
		float(contract.get("duration", 60.0)),
		int(round(float(contract.get("target_coverage", 0.7)) * 100.0)),
		int(round(float(contract.get("fail_coverage", 0.2)) * 100.0)),
		int(contract.get("payout", 0)),
		contract.get("risk_label", ""),
		contract.get("description", ""),
	]


func _update_sidebar_meta() -> void:
	money_value.text = "C$%d" % _money
	day_value.text = "%d" % _run_day
	streak_value.text = "%d" % _streak
	if _state != STATE_IN_CONTRACT:
		paint_value.text = "--"


func _apply_palette(base_color: Color) -> void:
	swatch_blue.color = base_color
	swatch_orange.color = base_color.lightened(0.24)
	swatch_green.color = base_color.darkened(0.16)
	swatch_purple.color = base_color.darkened(0.32)


func _base_modifiers() -> Dictionary:
	return {
		"speed_add": 0.0,
		"speed_mult": 1.0,
		"paint_radius_add": 0.0,
		"paint_radius_mult": 1.0,
		"paint_strength_add": 0.0,
		"paint_strength_mult": 1.0,
		"paint_capacity_add": 0.0,
		"paint_capacity_mult": 1.0,
		"paint_regen_add": 0.0,
		"paint_regen_mult": 1.0,
		"paint_drain_add": 0.0,
		"paint_drain_mult": 1.0,
		"payout_mult": 1.0,
		"drop_interval_mult": 1.0,
		"melt_resist": 0.0,
		"target_offset": 0.0,
		"fail_offset": 0.0,
	}


func _build_contract_templates() -> Array[Dictionary]:
	return [
		{
			"tier": 1,
			"title": "Muro do Cafe Aurora",
			"client": "Dona Celia",
			"description": "Fachada pequena, chuva leve e pouco tempo de caos.",
			"duration_min": 46.0,
			"duration_max": 62.0,
			"target_min": 0.64,
			"target_max": 0.74,
			"fail_min": 0.17,
			"fail_max": 0.24,
			"payout_min": 95.0,
			"payout_max": 150.0,
			"drop_interval_min": 0.46,
			"drop_interval_max": 0.72,
			"drop_speed_min": 130.0,
			"drop_speed_max": 200.0,
			"drop_power_min": 0.65,
			"drop_power_max": 1.05,
			"drop_radius_min": 5.0,
			"drop_radius_max": 8.0,
			"event_min": 0.24,
			"event_max": 0.52,
			"paint_color": Color(0.34, 0.70, 0.96, 1.0),
			"drop_color": Color(0.75, 0.90, 1.0, 0.95),
			"initial_min": 0.56,
			"initial_max": 0.78,
		},
		{
			"tier": 2,
			"title": "Corredor da Rodoviaria",
			"client": "Prefeitura",
			"description": "Goteira constante e publico apressado cobrando acabamento.",
			"duration_min": 54.0,
			"duration_max": 76.0,
			"target_min": 0.67,
			"target_max": 0.79,
			"fail_min": 0.18,
			"fail_max": 0.27,
			"payout_min": 130.0,
			"payout_max": 210.0,
			"drop_interval_min": 0.38,
			"drop_interval_max": 0.58,
			"drop_speed_min": 160.0,
			"drop_speed_max": 245.0,
			"drop_power_min": 0.86,
			"drop_power_max": 1.32,
			"drop_radius_min": 6.0,
			"drop_radius_max": 9.5,
			"event_min": 0.34,
			"event_max": 0.66,
			"paint_color": Color(0.93, 0.63, 0.26, 1.0),
			"drop_color": Color(0.72, 0.86, 1.0, 0.94),
			"initial_min": 0.54,
			"initial_max": 0.74,
		},
		{
			"tier": 3,
			"title": "Galeria Subterranea",
			"client": "Coletivo Mural",
			"description": "Ar pesado, respingos acidos e meta artistica alta.",
			"duration_min": 58.0,
			"duration_max": 84.0,
			"target_min": 0.70,
			"target_max": 0.84,
			"fail_min": 0.20,
			"fail_max": 0.30,
			"payout_min": 175.0,
			"payout_max": 280.0,
			"drop_interval_min": 0.32,
			"drop_interval_max": 0.50,
			"drop_speed_min": 190.0,
			"drop_speed_max": 280.0,
			"drop_power_min": 1.00,
			"drop_power_max": 1.55,
			"drop_radius_min": 6.5,
			"drop_radius_max": 10.2,
			"event_min": 0.42,
			"event_max": 0.78,
			"paint_color": Color(0.26, 0.78, 0.56, 1.0),
			"drop_color": Color(0.68, 0.92, 0.84, 0.92),
			"initial_min": 0.50,
			"initial_max": 0.72,
		},
		{
			"tier": 4,
			"title": "Viaduto Horizonte",
			"client": "Consorcio Vias",
			"description": "Vento lateral forte e derretimento agressivo.",
			"duration_min": 62.0,
			"duration_max": 90.0,
			"target_min": 0.72,
			"target_max": 0.86,
			"fail_min": 0.21,
			"fail_max": 0.31,
			"payout_min": 230.0,
			"payout_max": 340.0,
			"drop_interval_min": 0.27,
			"drop_interval_max": 0.44,
			"drop_speed_min": 220.0,
			"drop_speed_max": 320.0,
			"drop_power_min": 1.10,
			"drop_power_max": 1.72,
			"drop_radius_min": 7.0,
			"drop_radius_max": 11.5,
			"event_min": 0.50,
			"event_max": 0.88,
			"paint_color": Color(0.72, 0.50, 0.92, 1.0),
			"drop_color": Color(0.78, 0.80, 1.0, 0.9),
			"initial_min": 0.49,
			"initial_max": 0.70,
		},
		{
			"tier": 5,
			"title": "Torre de Vidro 47",
			"client": "Holding Atlas",
			"description": "Contrato lendario: clima extremo e zero tolerancia.",
			"duration_min": 66.0,
			"duration_max": 96.0,
			"target_min": 0.75,
			"target_max": 0.88,
			"fail_min": 0.22,
			"fail_max": 0.33,
			"payout_min": 300.0,
			"payout_max": 460.0,
			"drop_interval_min": 0.23,
			"drop_interval_max": 0.36,
			"drop_speed_min": 240.0,
			"drop_speed_max": 360.0,
			"drop_power_min": 1.25,
			"drop_power_max": 1.95,
			"drop_radius_min": 7.5,
			"drop_radius_max": 12.0,
			"event_min": 0.58,
			"event_max": 0.96,
			"paint_color": Color(0.95, 0.42, 0.32, 1.0),
			"drop_color": Color(0.96, 0.86, 0.72, 0.9),
			"initial_min": 0.46,
			"initial_max": 0.68,
		},
	]


func _build_upgrade_catalog() -> Array[Dictionary]:
	return [
		{
			"id": "wide_roller",
			"name": "Rolo Extra Largo",
			"description": "A area de retoque aumenta bastante.",
			"effects": {"paint_radius_add": 14.0},
		},
		{
			"id": "fast_stride",
			"name": "Passo Tecnico",
			"description": "Movimento mais rapido para cobrir emergencias.",
			"effects": {"speed_add": 55.0},
		},
		{
			"id": "premium_paint",
			"name": "Tinta Premium",
			"description": "Cada passada fixa melhor a tinta no muro.",
			"effects": {"paint_strength_mult": 1.22},
		},
		{
			"id": "bigger_tank",
			"name": "Tanque Expandido",
			"description": "Mais autonomia antes de precisar recuperar tinta.",
			"effects": {"paint_capacity_add": 45.0},
		},
		{
			"id": "fast_regen",
			"name": "Bomba de Recarga",
			"description": "Recupera tinta mais rapido quando fora do muro.",
			"effects": {"paint_regen_mult": 1.35},
		},
		{
			"id": "economy_nozzle",
			"name": "Bico Economico",
			"description": "Menor consumo de tinta durante o retoque.",
			"effects": {"paint_drain_mult": 0.78},
		},
		{
			"id": "waterproof_mix",
			"name": "Selante Hidrofobico",
			"description": "Reduz o dano das gotas no muro.",
			"effects": {"melt_resist": 0.15},
		},
		{
			"id": "union_contract",
			"name": "Negociacao Sindical",
			"description": "Aumenta os pagamentos dos proximos contratos.",
			"effects": {"payout_mult": 1.20},
		},
		{
			"id": "forecast_scanner",
			"name": "Scanner Climatico",
			"description": "Diminui a pressao de spawn de gotas.",
			"effects": {"drop_interval_mult": 1.12},
		},
		{
			"id": "target_flex",
			"name": "Clausula Flexivel",
			"description": "Reduz um pouco a meta de cobertura exigida.",
			"effects": {"target_offset": -0.03},
		},
		{
			"id": "safety_clause",
			"name": "Seguro de Ruina",
			"description": "A run tolera cobertura minima um pouco menor.",
			"effects": {"fail_offset": -0.03},
		},
	]


func _build_event_catalog() -> Array[Dictionary]:
	return [
		{
			"name": "Temporal Acido",
			"description": "A chuva ficou corrosiva e mais agressiva.",
			"duration_min": 7.0,
			"duration_max": 12.0,
			"spawn_mult": 1.35,
			"speed_mult": 1.18,
			"damage_mult": 1.42,
			"radius_mult": 1.08,
			"wind": 0.0,
			"player_speed_mult": 0.95,
			"player_paint_mult": 0.88,
			"player_drain_mult": 1.20,
		},
		{
			"name": "Rajada Lateral",
			"description": "Vento empurra as gotas para os cantos do muro.",
			"duration_min": 6.0,
			"duration_max": 10.0,
			"spawn_mult": 1.08,
			"speed_mult": 1.06,
			"damage_mult": 1.04,
			"radius_mult": 1.0,
			"wind": 120.0,
			"player_speed_mult": 1.0,
			"player_paint_mult": 1.0,
			"player_drain_mult": 1.05,
		},
		{
			"name": "Seca de Solvente",
			"description": "Tinta rende menos e o tanque drena mais rapido.",
			"duration_min": 8.0,
			"duration_max": 13.0,
			"spawn_mult": 0.92,
			"speed_mult": 1.0,
			"damage_mult": 1.15,
			"radius_mult": 1.0,
			"wind": 0.0,
			"player_speed_mult": 0.96,
			"player_paint_mult": 0.74,
			"player_drain_mult": 1.34,
		},
		{
			"name": "Frente Fria",
			"description": "Gotas desaceleram e a tinta fixa melhor.",
			"duration_min": 6.0,
			"duration_max": 9.0,
			"spawn_mult": 0.88,
			"speed_mult": 0.82,
			"damage_mult": 0.78,
			"radius_mult": 0.95,
			"wind": -35.0,
			"player_speed_mult": 1.06,
			"player_paint_mult": 1.22,
			"player_drain_mult": 0.88,
		},
	]


func _save_meta_progress() -> void:
	var data = {
		"best_streak": _meta_best_streak,
		"total_runs": _meta_total_runs,
		"total_credits": _meta_total_credits,
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func _load_meta_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var data: Dictionary = parsed
	_meta_best_streak = int(data.get("best_streak", 0))
	_meta_total_runs = int(data.get("total_runs", 0))
	_meta_total_credits = int(data.get("total_credits", 0))
