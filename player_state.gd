extends Node

const BASE_STAT_RANGES := {
	"strength": Vector2i(3, 10),
	"intellect": Vector2i(3, 10),
	"perception": Vector2i(3, 10),
	"stress": Vector2i(1, 6),
	"endurance": Vector2i(3, 10),
}

const STARTING_DISEASE_POOL: Array[Dictionary] = [
	{"name": "Mild Tremor", "is_superpower": false},
	{"name": "Night Fog", "is_superpower": false},
	{"name": "Lung Bloom", "is_superpower": false},
	{"name": "Echo Fever", "is_superpower": false},
	{"name": "Static Skin", "is_superpower": true},
	{"name": "Adrenal Overclock", "is_superpower": true},
	{"name": "Fractal Sight", "is_superpower": true},
]

var character_seed: int = 0
var turn_counter: int = 0
var stats: Dictionary = {}
var diseases: Array[Dictionary] = []
var superpowers: Array[String] = []

# DNA visualization hooks (prepared, intentionally minimal for now).
var dna_sequence: String = ""
var dna_digit_superpower_indices: Array[int] = []

func start_new_game() -> void:
	character_seed = randi()
	turn_counter = 0
	superpowers.clear()
	_initialize_stats()
	_initialize_diseases()
	_initialize_dna_hook_data()

func advance_turn() -> int:
	turn_counter += 1
	return turn_counter

func apply_stat_delta(stat_key: String, amount: int) -> void:
	if not stats.has(stat_key):
		return
	stats[stat_key] += amount

func add_disease(name: String, is_superpower: bool = false, track_superpower: bool = true) -> void:
	var entry := {
		"name": name,
		"is_superpower": is_superpower,
	}
	diseases.append(entry)
	if is_superpower and track_superpower:
		superpowers.append(name)

func has_superpower(name: String) -> bool:
	return superpowers.has(name)

func get_stats_lines() -> Array[String]:
	var lines: Array[String] = []
	for key: String in stats.keys():
		lines.append("%s: %d" % [_humanize_key(key), stats[key]])
	return lines

func get_disease_lines_bbcode() -> Array[String]:
	var lines: Array[String] = []
	for disease: Dictionary in diseases:
		var disease_name: String = disease.get("name", "Unknown")
		if disease.get("is_superpower", false):
			lines.append("[color=#ff4a4a]%s[/color]" % disease_name)
		else:
			lines.append("[color=#b066ff]%s[/color]" % disease_name)
	return lines

func get_dna_sequence() -> String:
	return dna_sequence

func get_dna_superpower_indices() -> Array[int]:
	return dna_digit_superpower_indices.duplicate()

func mark_dna_superpower_index(index: int) -> void:
	if index < 0:
		return
	if not dna_digit_superpower_indices.has(index):
		dna_digit_superpower_indices.append(index)

func _initialize_stats() -> void:
	stats.clear()
	for stat_key: String in BASE_STAT_RANGES.keys():
		var range: Vector2i = BASE_STAT_RANGES[stat_key]
		stats[stat_key] = randi_range(range.x, range.y)

func _initialize_diseases() -> void:
	diseases.clear()
	var pool := STARTING_DISEASE_POOL.duplicate(true)
	pool.shuffle()
	var disease_count := randi_range(1, 3)
	for index: int in disease_count:
		var disease: Dictionary = pool[index]
		add_disease(disease.get("name", "Unknown"), disease.get("is_superpower", false), false)

func _initialize_dna_hook_data() -> void:
	dna_sequence = ""
	for _digit: int in 32:
		dna_sequence += str(randi() % 2)
	dna_digit_superpower_indices.clear()

func _humanize_key(key: String) -> String:
	return key.capitalize()
