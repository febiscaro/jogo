extends Node

const SAVE_PATH := "user://app_profile.json"

var launch_mode: String = "run"
var cursor_sensitivity: float = 1.0
var postfx_strength: float = 1.0

var total_contracts_completed: int = 0
var best_streak_seen: int = 0
var special_contracts_unlocked: bool = false

var unlocked_cosmetics: Array[String] = ["classic"]
var selected_cosmetic: String = "classic"


func _ready() -> void:
	_load()


func queue_launch(mode: String) -> void:
	launch_mode = mode


func consume_launch_mode() -> String:
	var mode = launch_mode
	launch_mode = "run"
	return mode


func set_cursor_sensitivity(value: float) -> void:
	cursor_sensitivity = clampf(value, 0.55, 1.85)
	_save()


func set_postfx_strength(value: float) -> void:
	postfx_strength = clampf(value, 0.45, 1.70)
	_save()


func get_cursor_sensitivity() -> float:
	return cursor_sensitivity


func get_postfx_strength() -> float:
	return postfx_strength


func get_unlocked_cosmetics() -> Array[String]:
	return unlocked_cosmetics.duplicate()


func set_selected_cosmetic(cosmetic_id: String) -> void:
	if unlocked_cosmetics.has(cosmetic_id):
		selected_cosmetic = cosmetic_id
		_save()


func get_selected_cosmetic() -> String:
	if not unlocked_cosmetics.has(selected_cosmetic):
		selected_cosmetic = unlocked_cosmetics[0] if not unlocked_cosmetics.is_empty() else "classic"
	return selected_cosmetic


func is_special_contracts_unlocked() -> bool:
	return special_contracts_unlocked


func register_contract_complete(current_streak: int) -> Dictionary:
	total_contracts_completed += 1
	best_streak_seen = maxi(best_streak_seen, current_streak)

	var newly_unlocked_cosmetics: Array[String] = []
	var special_just_unlocked := false

	_try_unlock_cosmetic("urban_orange", total_contracts_completed >= 3, newly_unlocked_cosmetics)
	_try_unlock_cosmetic("night_shift", best_streak_seen >= 4, newly_unlocked_cosmetics)
	_try_unlock_cosmetic("executive_clean", total_contracts_completed >= 8, newly_unlocked_cosmetics)

	if total_contracts_completed >= 7 and not special_contracts_unlocked:
		special_contracts_unlocked = true
		special_just_unlocked = true

	_save()
	return {
		"new_cosmetics": newly_unlocked_cosmetics,
		"special_unlocked": special_just_unlocked,
		"total_contracts_completed": total_contracts_completed,
	}


func _try_unlock_cosmetic(cosmetic_id: String, condition: bool, output: Array[String]) -> void:
	if condition and not unlocked_cosmetics.has(cosmetic_id):
		unlocked_cosmetics.append(cosmetic_id)
		output.append(cosmetic_id)


func get_profile_snapshot() -> Dictionary:
	return {
		"total_contracts_completed": total_contracts_completed,
		"best_streak_seen": best_streak_seen,
		"special_contracts_unlocked": special_contracts_unlocked,
		"unlocked_cosmetics": unlocked_cosmetics.duplicate(),
		"selected_cosmetic": selected_cosmetic,
		"cursor_sensitivity": cursor_sensitivity,
		"postfx_strength": postfx_strength,
	}


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(get_profile_snapshot()))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed

	cursor_sensitivity = clampf(float(data.get("cursor_sensitivity", cursor_sensitivity)), 0.55, 1.85)
	postfx_strength = clampf(float(data.get("postfx_strength", postfx_strength)), 0.45, 1.70)
	total_contracts_completed = maxi(0, int(data.get("total_contracts_completed", 0)))
	best_streak_seen = maxi(0, int(data.get("best_streak_seen", 0)))
	special_contracts_unlocked = bool(data.get("special_contracts_unlocked", false))

	var raw_cosmetics = data.get("unlocked_cosmetics", unlocked_cosmetics)
	if raw_cosmetics is Array:
		var incoming = raw_cosmetics as Array
		unlocked_cosmetics.clear()
		for value in incoming:
			var cosmetic_id = String(value)
			if cosmetic_id.is_empty():
				continue
			if not unlocked_cosmetics.has(cosmetic_id):
				unlocked_cosmetics.append(cosmetic_id)
	if unlocked_cosmetics.is_empty():
		unlocked_cosmetics = ["classic"]

	selected_cosmetic = String(data.get("selected_cosmetic", selected_cosmetic))
	if not unlocked_cosmetics.has(selected_cosmetic):
		selected_cosmetic = unlocked_cosmetics[0]
