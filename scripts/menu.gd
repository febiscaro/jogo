extends Control

const MAIN_SCENE := "res://scenes/main.tscn"
const COSMETIC_NAMES := {
	"classic": "Classico",
	"urban_orange": "Urbano Laranja",
	"night_shift": "Turno da Noite",
	"executive_clean": "Executivo Clean",
}

@onready var title_label: Label = $Title
@onready var subtitle_label: Label = $Subtitle
@onready var left_panel: Panel = $LeftPanel
@onready var progress_body: Label = $RightPanel/ProgressBody
@onready var play_button: Button = $LeftPanel/PlayButton
@onready var tutorial_button: Button = $LeftPanel/TutorialButton
@onready var options_button: Button = $LeftPanel/OptionsButton
@onready var exit_button: Button = $LeftPanel/ExitButton
@onready var options_panel: Panel = $OptionsPanel
@onready var sens_slider: HSlider = $OptionsPanel/SensSlider
@onready var sens_value: Label = $OptionsPanel/SensValue
@onready var fx_slider: HSlider = $OptionsPanel/FxSlider
@onready var fx_value: Label = $OptionsPanel/FxValue
@onready var cosmetic_option: OptionButton = $OptionsPanel/CosmeticOption
@onready var close_options_button: Button = $OptionsPanel/CloseOptionsButton

var _app_state: Node = null
var _cosmetic_ids: Array[String] = []


func _ready() -> void:
	_app_state = get_node_or_null("/root/AppState")
	_style_ui()
	_wire_signals()
	_load_options()
	_refresh_progress()
	options_panel.visible = false


func _style_ui() -> void:
	title_label.text = "Pintor do Muro"
	title_label.add_theme_font_size_override("font_size", 52)
	title_label.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.06, 0.09, 0.14, 0.86))
	title_label.add_theme_constant_override("outline_size", 2)

	subtitle_label.text = "Roguelike de contratos - versao polida"
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color(0.76, 0.86, 0.96, 0.95))

	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.10, 0.14, 0.20, 0.86)
	left_style.border_color = Color(0.46, 0.66, 0.92, 0.48)
	left_style.set_border_width_all(2)
	left_style.corner_radius_top_left = 10
	left_style.corner_radius_top_right = 10
	left_style.corner_radius_bottom_left = 10
	left_style.corner_radius_bottom_right = 10
	left_style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	left_style.shadow_size = 8
	left_panel.add_theme_stylebox_override("panel", left_style)

	var right_panel: Panel = $RightPanel
	var right_style := left_style.duplicate()
	right_style.bg_color = Color(0.09, 0.12, 0.17, 0.82)
	right_panel.add_theme_stylebox_override("panel", right_style)

	var options_style := left_style.duplicate()
	options_style.bg_color = Color(0.07, 0.11, 0.17, 0.95)
	options_panel.add_theme_stylebox_override("panel", options_style)

	for button in [play_button, tutorial_button, options_button, exit_button, close_options_button]:
		button.focus_mode = Control.FOCUS_NONE


func _wire_signals() -> void:
	play_button.pressed.connect(_on_play_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	options_button.pressed.connect(_on_options_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	close_options_button.pressed.connect(_on_close_options_pressed)
	sens_slider.value_changed.connect(_on_sensitivity_changed)
	fx_slider.value_changed.connect(_on_postfx_changed)
	cosmetic_option.item_selected.connect(_on_cosmetic_selected)


func _load_options() -> void:
	var sens = 1.0
	var fx = 1.0
	var selected_cosmetic_id = "classic"
	var unlocked_cosmetics: Array[String] = ["classic"]
	if _app_state != null:
		if _app_state.has_method("get_cursor_sensitivity"):
			sens = float(_app_state.call("get_cursor_sensitivity"))
		if _app_state.has_method("get_postfx_strength"):
			fx = float(_app_state.call("get_postfx_strength"))
		if _app_state.has_method("get_selected_cosmetic"):
			selected_cosmetic_id = String(_app_state.call("get_selected_cosmetic"))
		if _app_state.has_method("get_unlocked_cosmetics"):
			var list = _app_state.call("get_unlocked_cosmetics")
			if list is Array:
				unlocked_cosmetics.clear()
				for value in list:
					unlocked_cosmetics.append(String(value))

	sens_slider.min_value = 0.55
	sens_slider.max_value = 1.85
	sens_slider.step = 0.01
	sens_slider.value = sens
	fx_slider.min_value = 0.45
	fx_slider.max_value = 1.70
	fx_slider.step = 0.01
	fx_slider.value = fx

	_update_sens_label(sens)
	_update_fx_label(fx)
	_rebuild_cosmetic_list(unlocked_cosmetics, selected_cosmetic_id)


func _refresh_progress() -> void:
	var profile: Dictionary = {}
	if _app_state != null and _app_state.has_method("get_profile_snapshot"):
		profile = _app_state.call("get_profile_snapshot")
	var meta = _read_meta_progress()
	var contracts_done = int(profile.get("total_contracts_completed", 0))
	var best_profile = int(profile.get("best_streak_seen", 0))
	var best_meta = int(meta.get("best_streak", 0))
	var best = maxi(best_profile, best_meta)
	var total_runs = int(meta.get("total_runs", 0))
	var total_credits = int(meta.get("total_credits", 0))
	var special_unlocked = bool(profile.get("special_contracts_unlocked", false))
	var cosmetics_count = 0
	var cosmetics = profile.get("unlocked_cosmetics", [])
	if cosmetics is Array:
		cosmetics_count = (cosmetics as Array).size()

	progress_body.text = (
		"Progresso do perfil\n\n"
		+ "Contratos concluidos: %d\n"
		+ "Melhor streak: %d\n"
		+ "Runs totais: %d\n"
		+ "Creditos acumulados: C$%d\n\n"
		+ "Cosmeticos liberados: %d\n"
		+ "Contratos especiais: %s"
	) % [
		contracts_done,
		best,
		total_runs,
		total_credits,
		cosmetics_count,
		"Liberados" if special_unlocked else "Bloqueados",
	]


func _read_meta_progress() -> Dictionary:
	var path = "user://meta_progress.json"
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _rebuild_cosmetic_list(cosmetic_ids: Array[String], selected_id: String) -> void:
	cosmetic_option.clear()
	_cosmetic_ids.clear()
	if cosmetic_ids.is_empty():
		cosmetic_ids = ["classic"]
	for cosmetic_id in cosmetic_ids:
		var label = COSMETIC_NAMES.get(cosmetic_id, cosmetic_id.capitalize())
		cosmetic_option.add_item(label)
		_cosmetic_ids.append(cosmetic_id)

	var selected_index = 0
	for i in range(_cosmetic_ids.size()):
		if _cosmetic_ids[i] == selected_id:
			selected_index = i
			break
	cosmetic_option.select(selected_index)


func _on_play_pressed() -> void:
	if _app_state != null and _app_state.has_method("queue_launch"):
		_app_state.call("queue_launch", "run")
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_tutorial_pressed() -> void:
	if _app_state != null and _app_state.has_method("queue_launch"):
		_app_state.call("queue_launch", "tutorial")
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_options_pressed() -> void:
	options_panel.visible = not options_panel.visible


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_close_options_pressed() -> void:
	options_panel.visible = false


func _on_sensitivity_changed(value: float) -> void:
	_update_sens_label(value)
	if _app_state != null and _app_state.has_method("set_cursor_sensitivity"):
		_app_state.call("set_cursor_sensitivity", value)


func _on_postfx_changed(value: float) -> void:
	_update_fx_label(value)
	if _app_state != null and _app_state.has_method("set_postfx_strength"):
		_app_state.call("set_postfx_strength", value)


func _on_cosmetic_selected(index: int) -> void:
	if index < 0 or index >= _cosmetic_ids.size():
		return
	if _app_state != null and _app_state.has_method("set_selected_cosmetic"):
		_app_state.call("set_selected_cosmetic", _cosmetic_ids[index])
	_refresh_progress()


func _update_sens_label(value: float) -> void:
	sens_value.text = "x%.2f" % value


func _update_fx_label(value: float) -> void:
	fx_value.text = "x%.2f" % value
