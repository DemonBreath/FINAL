extends Node

const STAT_RANGES := {
	"strength": Vector2i(3, 9),
	"intellect": Vector2i(3, 9),
	"perception": Vector2i(3, 9),
	"stress": Vector2i(1, 4),
	"endurance": Vector2i(3, 9),
}

var dna_engine: DNAEngine = DNAEngine.new()
var condition_system: ConditionSystem = ConditionSystem.new()
var narrative_engine: NarrativeEngine = NarrativeEngine.new()

var player_state: Dictionary = _empty_state()

func _ready() -> void:
	player_state = _normalize_state(player_state)

func start_or_resume(requested_username: String) -> Dictionary:
	var username: String = _sanitize_username(requested_username)
	SaveManager.load_blob()
	var profile: Dictionary = SaveManager.get_profile(username)
	if not profile.is_empty() and not bool(profile.get("dead", false)):
		player_state = _normalize_state(profile)
		return {"loaded": true, "username": player_state["username"]}
	var final_username: String = _unique_username(username)
	_start_new_character(final_username)
	return {"loaded": false, "username": final_username}

func _start_new_character(username: String) -> void:
	var seed: int = int(Time.get_unix_time_from_system()) ^ abs(int(hash("%s:%d" % [username, Time.get_ticks_usec()])))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var stats: Dictionary = _generate_stats(rng)
	var dna_bits: String = dna_engine.generate(seed)
	player_state = {
		"username": username,
		"seed": seed,
		"turn": 0,
		"stats": stats.duplicate(true),
		"starting_stats": stats.duplicate(true),
		"conditions": [],
		"dna_bits": dna_bits,
		"mutated_bit_indices": [],
		"life_log": [],
		"used_text_hashes": [],
		"dead": false,
	}
	var opening: String = narrative_engine.opening(seed, username, player_state["used_text_hashes"])
	append_life_log("opening", opening)
	SaveManager.mark_username_used(username)
	save_current_state()

func append_life_log(entry_type: String, text: String, meta: Dictionary = {}) -> void:
	var entry: Dictionary = {
		"turn": int(player_state.get("turn", 0)),
		"type": entry_type,
		"text": text,
		"meta": meta.duplicate(true),
		"stamp": "%s" % Time.get_datetime_string_from_system(),
	}
	var entries: Array = player_state.get("life_log", [])
	entries.append(entry)
	player_state["life_log"] = entries

func resolve_turn(command: String) -> Dictionary:
	if player_state.is_empty() or bool(player_state.get("dead", false)):
		return {"narrative": "No active life.", "prompt": "Start again with a new identity.", "stat_line": ""}
	var clean_command: String = command.strip_edges()
	player_state["turn"] = int(player_state.get("turn", 0)) + 1
	var turn: int = int(player_state["turn"])
	var intent: String = _parse_intent(clean_command)
	var stat_line: String = _apply_intent(intent)
	var condition: String = condition_system.roll_new_condition(int(player_state["seed"]), turn, clean_command, player_state["conditions"])
	if not condition.is_empty():
		_contract_condition(condition)
		append_life_log("condition", "A dramatic onset: %s." % condition, {})
	var tone: String = condition_system.tone_from_conditions(player_state["conditions"])
	var narrative_payload: Dictionary = narrative_engine.response(int(player_state["seed"]), turn, clean_command if not clean_command.is_empty() else "wait", tone, player_state["used_text_hashes"])
	append_life_log("turn", narrative_payload["narrative"], {"command": clean_command, "intent": intent})
	append_life_log("stat", stat_line, {})
	_update_leaderboard_stub()
	save_current_state()
	return {
		"narrative": narrative_payload["narrative"],
		"prompt": narrative_payload["prompt"],
		"stat_line": stat_line,
		"condition": condition,
	}

func is_dead() -> bool:
	var stats: Dictionary = player_state.get("stats", {})
	return int(stats.get("endurance", 0)) <= 0 or int(stats.get("stress", 0)) >= 14

func kill_current_life(reason: String) -> void:
	if player_state.is_empty() or bool(player_state.get("dead", false)):
		return
	player_state["dead"] = true
	append_life_log("death", reason, {})
	SaveManager.mark_username_dead(str(player_state.get("username", "")))
	save_current_state()

func get_state() -> Dictionary:
	return player_state.duplicate(true)

func current_opening_text() -> String:
	var entries: Array = player_state.get("life_log", [])
	for entry in entries:
		if entry is Dictionary and str(entry.get("type", "")) == "opening":
			return str(entry.get("text", ""))
	return ""

func save_current_state() -> void:
	if player_state.is_empty():
		return
	SaveManager.set_profile(str(player_state.get("username", "")), player_state)
	SaveManager.save_blob_to_disk()

func _parse_intent(command: String) -> String:
	var normalized: String = command.to_lower()
	if normalized.is_empty():
		return "pause"
	if normalized.contains("walk") or normalized.contains("run"):
		return "move"
	if normalized.contains("study") or normalized.contains("read") or normalized.contains("think"):
		return "analyze"
	if normalized.contains("observe") or normalized.contains("search") or normalized.contains("look"):
		return "scan"
	if normalized.contains("rest") or normalized.contains("sleep"):
		return "recover"
	if normalized.contains("panic") or normalized.contains("shout"):
		return "spiral"
	return "improvise"

func _apply_intent(intent: String) -> String:
	var stats: Dictionary = player_state.get("stats", {})
	match intent:
		"move":
			stats["endurance"] = int(stats.get("endurance", 0)) + 1
			stats["stress"] = int(stats.get("stress", 0)) + 1
		"analyze":
			stats["intellect"] = int(stats.get("intellect", 0)) + 1
		"scan":
			stats["perception"] = int(stats.get("perception", 0)) + 1
		"recover":
			stats["stress"] = max(0, int(stats.get("stress", 0)) - 2)
			stats["endurance"] = int(stats.get("endurance", 0)) + 1
		"spiral":
			stats["stress"] = int(stats.get("stress", 0)) + 3
			stats["endurance"] = int(stats.get("endurance", 0)) - 1
		"pause":
			stats["stress"] = max(0, int(stats.get("stress", 0)) - 1)
		_:
			stats["strength"] = int(stats.get("strength", 0)) + 1
	player_state["stats"] = condition_system.apply_condition_effects(stats, player_state.get("conditions", []))
	return "Intent %s resolved. Stats shifted." % intent

func _contract_condition(condition_name: String) -> void:
	var conditions: Array = player_state.get("conditions", [])
	if conditions.has(condition_name):
		return
	conditions.append(condition_name)
	player_state["conditions"] = conditions
	var mutation: Dictionary = dna_engine.mutate_bit(str(player_state.get("dna_bits", "")), _get_mutated_indices(), int(player_state.get("seed", 0)), condition_name)
	player_state["dna_bits"] = mutation.get("dna_bits", player_state.get("dna_bits", ""))
	var idx: int = int(mutation.get("index", -1))
	if idx >= 0:
		var mutated: Array[int] = _get_mutated_indices()
		mutated.append(idx)
		player_state["mutated_bit_indices"] = mutated


func _get_mutated_indices() -> Array[int]:
	var typed: Array[int] = []
	for value: Variant in player_state.get("mutated_bit_indices", []):
		typed.append(int(value))
	return typed

func _generate_stats(rng: RandomNumberGenerator) -> Dictionary:
	var stats: Dictionary = {}
	for key in STAT_RANGES.keys():
		var range: Vector2i = STAT_RANGES[key]
		stats[key] = rng.randi_range(range.x, range.y)
	return stats

func _sanitize_username(raw: String) -> String:
	var clean: String = raw.strip_edges()
	if clean.is_empty():
		clean = "Player"
	return clean

func _unique_username(base_username: String) -> String:
	if not SaveManager.username_exists(base_username):
		return base_username
	var i: int = 1
	while i < 5000:
		var candidate: String = "%s_%03d" % [base_username, i]
		if not SaveManager.username_exists(candidate):
			return candidate
		i += 1
	return "%s_%d" % [base_username, Time.get_unix_time_from_system()]

func _normalize_state(raw: Dictionary) -> Dictionary:
	var normalized: Dictionary = {
		"username": str(raw.get("username", "Player")),
		"seed": int(raw.get("seed", 0)),
		"turn": int(raw.get("turn", 0)),
		"stats": raw.get("stats", {}).duplicate(true),
		"starting_stats": raw.get("starting_stats", {}).duplicate(true),
		"conditions": raw.get("conditions", []).duplicate(true),
		"dna_bits": str(raw.get("dna_bits", "")),
		"mutated_bit_indices": [],
		"life_log": raw.get("life_log", []).duplicate(true),
		"used_text_hashes": raw.get("used_text_hashes", []).duplicate(true),
		"dead": bool(raw.get("dead", false)),
	}
	var raw_mutated: Array = raw.get("mutated_bit_indices", [])
	var typed_mutated: Array[int] = []
	for value: Variant in raw_mutated:
		typed_mutated.append(int(value))
	normalized["mutated_bit_indices"] = typed_mutated
	if normalized["starting_stats"].is_empty():
		normalized["starting_stats"] = normalized["stats"].duplicate(true)
	return normalized

func _update_leaderboard_stub() -> void:
	var board: Dictionary = SaveManager.get_leaderboard()
	board["longest_life"] = max(int(board.get("longest_life", 0)), int(player_state.get("turn", 0)))
	board["most_mutations"] = max(int(board.get("most_mutations", 0)), player_state.get("mutated_bit_indices", []).size())
	board["highest_stress_survived"] = max(int(board.get("highest_stress_survived", 0)), int(player_state.get("stats", {}).get("stress", 0)))
	board["most_turns"] = board.get("longest_life", 0)
	board["rarest_condition"] = ""
	SaveManager.set_leaderboard(board)

func _empty_state() -> Dictionary:
	return {
		"username": "",
		"seed": 0,
		"turn": 0,
		"stats": {},
		"starting_stats": {},
		"conditions": [],
		"dna_bits": "",
		"mutated_bit_indices": [],
		"life_log": [],
		"used_text_hashes": [],
		"dead": false,
	}
