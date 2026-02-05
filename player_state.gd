extends Node

const BASE_STAT_RANGES := {
	"strength": Vector2i(3, 10),
	"intellect": Vector2i(3, 10),
	"perception": Vector2i(3, 10),
	"stress": Vector2i(1, 6),
	"endurance": Vector2i(3, 10),
}

const STARTING_CONDITION_POOL: Array[String] = [
	"Mild Tremor",
	"Night Fog",
	"Lung Bloom",
	"Echo Fever",
	"Static Skin",
	"Adrenal Overclock",
	"Fractal Sight",
]

const SAVE_PATH := "user://intake_saves.json"
const DNA_LENGTH := 128

var game_state: Dictionary = {}
var current_username: String = ""

func start_or_resume(username: String) -> bool:
	current_username = username.strip_edges()
	if current_username.is_empty():
		current_username = "Player"

	var save_data := _read_all_saves()
	if save_data.has(current_username):
		game_state = _normalize_loaded_state(save_data[current_username])
		return true

	start_new_life(current_username)
	return false

func start_new_life(username: String = "") -> void:
	if not username.is_empty():
		current_username = username
	if current_username.is_empty():
		current_username = "Player"

	var rng := RandomNumberGenerator.new()
	var seed := int(Time.get_unix_time_from_system()) ^ randi()
	rng.seed = seed

	game_state = {
		"username": current_username,
		"seed": seed,
		"turn": 0,
		"stats": _generate_stats(rng),
		"conditions": [],
		"life_log": [],
		"dna_bits": _generate_dna_bits(rng, DNA_LENGTH),
		"mutated_indices": [],
	}

	var initial_condition_count := rng.randi_range(0, 3)
	for _i: int in range(initial_condition_count):
		var condition := STARTING_CONDITION_POOL[rng.randi_range(0, STARTING_CONDITION_POOL.size() - 1)]
		contract_condition(condition)

	add_life_log_entry("system", "New life initialized.", {"seed": seed})
	save_current_state()

func clear_current_life() -> void:
	if current_username.is_empty():
		return
	var save_data := _read_all_saves()
	save_data.erase(current_username)
	_write_all_saves(save_data)
	game_state = {}

func advance_turn() -> int:
	if game_state.is_empty():
		return 0
	game_state["turn"] = int(game_state.get("turn", 0)) + 1
	return int(game_state["turn"])

func apply_stat_delta(stat_key: String, amount: int) -> int:
	if game_state.is_empty():
		return 0
	var stats: Dictionary = game_state.get("stats", {})
	if not stats.has(stat_key):
		return 0
	stats[stat_key] = int(stats[stat_key]) + amount
	game_state["stats"] = stats
	return int(stats[stat_key])

func contract_condition(condition_name: String) -> int:
	if game_state.is_empty() or condition_name.is_empty():
		return -1
	var conditions: Array = game_state.get("conditions", [])
	if not conditions.has(condition_name):
		conditions.append(condition_name)
		game_state["conditions"] = conditions
		return _mark_random_mutation_index()
	return -1

func add_life_log_entry(entry_type: String, text: String, meta: Dictionary = {}) -> void:
	if game_state.is_empty():
		return
	var log_entry := {
		"turn": int(game_state.get("turn", 0)),
		"type": entry_type,
		"text": text,
		"meta": meta,
		"timestamp": Time.get_datetime_string_from_system(),
	}
	var entries: Array = game_state.get("life_log", [])
	entries.append(log_entry)
	game_state["life_log"] = entries

func save_current_state() -> void:
	if game_state.is_empty() or current_username.is_empty():
		return
	var save_data := _read_all_saves()
	save_data[current_username] = game_state
	_write_all_saves(save_data)

func get_state() -> Dictionary:
	return game_state.duplicate(true)

func get_mutated_indices() -> Array[int]:
	var result: Array[int] = []
	for value in game_state.get("mutated_indices", []):
		result.append(int(value))
	return result

func get_dna_bits() -> String:
	return str(game_state.get("dna_bits", ""))

func _mark_random_mutation_index() -> int:
	var dna_bits := get_dna_bits()
	if dna_bits.is_empty():
		return -1
	var mutated := get_mutated_indices()
	if mutated.size() >= dna_bits.length():
		return -1

	var rng := RandomNumberGenerator.new()
	rng.seed = int(game_state.get("seed", 0)) + int(game_state.get("turn", 0)) + mutated.size() + randi()
	var index := rng.randi_range(0, dna_bits.length() - 1)
	while mutated.has(index):
		index = rng.randi_range(0, dna_bits.length() - 1)
	mutated.append(index)
	game_state["mutated_indices"] = mutated
	return index

func _generate_stats(rng: RandomNumberGenerator) -> Dictionary:
	var generated := {}
	for stat_key: String in BASE_STAT_RANGES.keys():
		var range: Vector2i = BASE_STAT_RANGES[stat_key]
		generated[stat_key] = rng.randi_range(range.x, range.y)
	return generated

func _generate_dna_bits(rng: RandomNumberGenerator, length: int) -> String:
	var bits := ""
	for _i: int in range(length):
		bits += str(rng.randi_range(0, 1))
	return bits

func _read_all_saves() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var raw_text := file.get_as_text()
	file.close()
	if raw_text.is_empty():
		return {}
	var parsed = JSON.parse_string(raw_text)
	if parsed is Dictionary:
		return parsed
	return {}

func _write_all_saves(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()

func _normalize_loaded_state(state: Dictionary) -> Dictionary:
	var normalized := {
		"username": str(state.get("username", current_username)),
		"seed": int(state.get("seed", 0)),
		"turn": int(state.get("turn", 0)),
		"stats": state.get("stats", {}).duplicate(true),
		"conditions": state.get("conditions", []).duplicate(true),
		"life_log": state.get("life_log", []).duplicate(true),
		"dna_bits": str(state.get("dna_bits", "")),
		"mutated_indices": state.get("mutated_indices", []).duplicate(true),
	}

	for stat_key: String in BASE_STAT_RANGES.keys():
		if not normalized["stats"].has(stat_key):
			normalized["stats"][stat_key] = BASE_STAT_RANGES[stat_key].x

	if str(normalized["dna_bits"]).is_empty():
		normalized["dna_bits"] = _generate_dna_bits(RandomNumberGenerator.new(), DNA_LENGTH)

	return normalized
