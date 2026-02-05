extends Node

const BASE_STAT_KEYS: Array[String] = ["strength", "intellect", "perception", "stress", "endurance"]
const STAT_BOUNDS: Dictionary = {
	"strength": Vector2i(0, 20),
	"intellect": Vector2i(0, 20),
	"perception": Vector2i(0, 20),
	"stress": Vector2i(0, 20),
	"endurance": Vector2i(0, 20)
}

var username: String = ""
var seed: int = 0
var turn: int = 0
var stats: Dictionary = {"strength": 0, "intellect": 0, "perception": 0, "stress": 0, "endurance": 0}
var conditions: Array[String] = []
var dna_bits: PackedInt32Array = PackedInt32Array()
var mutated_bit_indices: Array[int] = []

var life_log: Array[Dictionary] = []
var intro_shown: bool = false
var dead: bool = false
var environment_memory: Dictionary = {"last_zone": "processing district", "echo": 0}

var dna_engine: DNAEngine = DNAEngine.new()
var narrative_engine: NarrativeEngine = NarrativeEngine.new()

func _ready() -> void:
	if seed == 0:
		_reset_runtime_defaults()
	_ensure_non_null()

func _ensure_non_null() -> void:
	if username == "":
		username = ""
	if stats.is_empty():
		stats = {"strength": 0, "intellect": 0, "perception": 0, "stress": 0, "endurance": 0}
	if conditions == null:
		conditions = []
	if dna_bits == null:
		dna_bits = PackedInt32Array()
	if mutated_bit_indices == null:
		mutated_bit_indices = []
	if life_log == null:
		life_log = []

func start_or_resume(requested_username: String) -> void:
	var desired_username: String = _sanitize_username(requested_username)
	SaveManager.load_blob()
	var loaded: Dictionary = SaveManager.load_game()
	if not loaded.is_empty() and str(loaded.get("username", "")) == desired_username:
		deserialize(loaded)
		return
	var by_name: Dictionary = SaveManager.get_profile(desired_username)
	if not by_name.is_empty() and not bool(by_name.get("dead", false)):
		deserialize(by_name)
		SaveManager.set_current_username(desired_username)
		return
	var unique_name: String = _ensure_unique_username(desired_username)
	_begin_new_life(unique_name)

func apply_action(command: String) -> Dictionary:
	if dead:
		return {
			"text": "This life has ended. Observation continues without you.",
			"stat_shift_reason": "deceased",
			"possible_condition": null,
			"prompt": _prompt_text()
		}
	turn += 1
	var clean_command: String = command.strip_edges()
	if clean_command.is_empty():
		clean_command = "wait"
	var payload: Dictionary = narrative_engine.generate(
		seed,
		turn,
		clean_command,
		stats,
		conditions,
		environment_memory
	)
	var stat_reason: String = str(payload.get("stat_shift_reason", "ambient drift"))
	apply_stat_shift(stat_reason)
	var possible_condition_value: Variant = payload.get("possible_condition", null)
	if possible_condition_value != null:
		add_condition(str(possible_condition_value))
	_append_life_log(turn, clean_command, str(payload.get("text", "")), stat_reason)
	if int(stats.get("endurance", 0)) <= 0:
		dead = true
		SaveManager.mark_username_dead(username)
	save()
	payload["prompt"] = _prompt_text()
	return payload

func apply_stat_shift(reason: String) -> void:
	var shift_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	shift_rng.seed = int(abs(hash("%d:%d:%s" % [seed, turn, reason])))
	for key: String in BASE_STAT_KEYS:
		var current: int = int(stats.get(key, 0))
		var delta: int = shift_rng.randi_range(-1, 1)
		if key == "stress" and reason.contains("calm"):
			delta = min(delta, 0)
		if key == "stress" and reason.contains("threat"):
			delta = max(delta, 0)
		if key == "endurance" and reason.contains("strain"):
			delta = min(delta, 0)
		var bounds: Vector2i = STAT_BOUNDS.get(key, Vector2i(0, 20))
		stats[key] = clampi(current + delta, bounds.x, bounds.y)

func add_condition(name: String) -> void:
	var normalized: String = name.strip_edges()
	if normalized.is_empty():
		return
	if conditions.has(normalized):
		return
	conditions.append(normalized)
	var mutation_index: int = dna_engine.mutate_once(dna_bits, mutated_bit_indices, seed, normalized)
	if mutation_index >= 0:
		mutated_bit_indices.append(mutation_index)

func serialize() -> Dictionary:
	var data: Dictionary = {
		"username": username,
		"seed": seed,
		"turn": turn,
		"stats": stats.duplicate(true),
		"conditions": conditions.duplicate(true),
		"dna_bits": dna_bits,
		"mutated_bit_indices": mutated_bit_indices.duplicate(true),
		"life_log": life_log.duplicate(true),
		"intro_shown": intro_shown,
		"dead": dead,
		"environment_memory": environment_memory.duplicate(true)
	}
	return data

func deserialize(data: Dictionary) -> void:
	username = str(data.get("username", ""))
	seed = int(data.get("seed", 0))
	turn = int(data.get("turn", 0))
	stats = data.get("stats", {}).duplicate(true)
	conditions = []
	for value: Variant in data.get("conditions", []):
		conditions.append(str(value))
	dna_bits = PackedInt32Array()
	var incoming_bits: Variant = data.get("dna_bits", PackedInt32Array())
	if incoming_bits is PackedInt32Array:
		dna_bits = incoming_bits
	elif incoming_bits is Array:
		for bit_value: Variant in incoming_bits:
			dna_bits.append(int(bit_value))
	elif incoming_bits is String:
		dna_bits = dna_engine.generate_from_string(str(incoming_bits))
	mutated_bit_indices = []
	for idx_value: Variant in data.get("mutated_bit_indices", []):
		mutated_bit_indices.append(int(idx_value))
	life_log = []
	for entry_variant: Variant in data.get("life_log", []):
		if entry_variant is Dictionary:
			life_log.append(entry_variant.duplicate(true))
	intro_shown = bool(data.get("intro_shown", turn > 0))
	dead = bool(data.get("dead", false))
	environment_memory = data.get("environment_memory", {"last_zone": "processing district", "echo": 0}).duplicate(true)
	_ensure_non_null()

func get_state() -> Dictionary:
	return serialize()

func current_opening_text() -> String:
	return "You arrive in INTAKE with no restart and no clean slate."

func save() -> void:
	SaveManager.save_game(serialize())

func _append_life_log(log_turn: int, command: String, text: String, reason: String) -> void:
	var entry: Dictionary = {
		"turn": log_turn,
		"command": command,
		"text": text,
		"reason": reason,
		"stamp": Time.get_datetime_string_from_system()
	}
	life_log.append(entry)

func _prompt_text() -> String:
	return "What do you attempt next? [Turn %d]" % turn

func _begin_new_life(final_username: String) -> void:
	_reset_runtime_defaults()
	username = final_username
	seed = int(Time.get_unix_time_from_system()) ^ int(abs(hash("%s:%d" % [username, Time.get_ticks_usec()])))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	stats = {
		"strength": rng.randi_range(4, 8),
		"intellect": rng.randi_range(4, 8),
		"perception": rng.randi_range(4, 8),
		"stress": rng.randi_range(1, 4),
		"endurance": rng.randi_range(4, 8)
	}
	dna_bits = dna_engine.generate(seed)
	SaveManager.mark_username_used(username)
	SaveManager.set_current_username(username)
	save()

func _reset_runtime_defaults() -> void:
	username = ""
	seed = 0
	turn = 0
	stats = {"strength": 0, "intellect": 0, "perception": 0, "stress": 0, "endurance": 0}
	conditions = []
	dna_bits = PackedInt32Array()
	mutated_bit_indices = []
	life_log = []
	intro_shown = false
	dead = false
	environment_memory = {"last_zone": "processing district", "echo": 0}

func _sanitize_username(raw: String) -> String:
	var cleaned: String = raw.strip_edges()
	if cleaned.is_empty():
		return "Player"
	return cleaned

func _ensure_unique_username(base: String) -> String:
	if not SaveManager.username_exists(base) and not SaveManager.is_username_dead(base):
		return base
	var index: int = 1
	while index < 10000:
		var candidate: String = "%s_%03d" % [base, index]
		if not SaveManager.username_exists(candidate) and not SaveManager.is_username_dead(candidate):
			return candidate
		index += 1
	return "%s_%d" % [base, Time.get_unix_time_from_system()]
