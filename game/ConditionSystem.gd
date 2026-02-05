extends RefCounted
class_name ConditionSystem

const DEFINITIONS: Dictionary = {
	"Adrenal Bloom": {"mods": {"strength": 2, "stress": 1}, "tone": "predatory"},
	"Glass Fever": {"mods": {"perception": 2, "endurance": -1}, "tone": "fractured"},
	"Quiet Static": {"mods": {"intellect": 1, "stress": -1}, "tone": "hushed"},
	"Titan Lungs": {"mods": {"endurance": 2}, "tone": "resonant"},
	"Mirror Nerves": {"mods": {"perception": 1, "stress": 2}, "tone": "paranoid"},
}

func roll_new_condition(seed: int, turn: int, command: String, existing: Array[String]) -> String:
	if turn < 2:
		return ""
	var roll: int = abs(int(hash("cond:%d:%d:%s" % [seed, turn, command.to_lower()]))) % 100
	if roll > 6:
		return ""
	var names: Array[String] = []
	for raw_name: Variant in DEFINITIONS.keys():
		names.append(str(raw_name))
	var idx: int = abs(int(hash("pick:%d:%d" % [seed, turn]))) % names.size()
	for offset in range(names.size()):
		var candidate: String = names[(idx + offset) % names.size()]
		if not existing.has(candidate):
			return candidate
	return ""

func apply_condition_effects(stats: Dictionary, conditions: Array[String]) -> Dictionary:
	var result: Dictionary = stats.duplicate(true)
	for name in conditions:
		var definition: Dictionary = DEFINITIONS.get(str(name), {})
		var mods: Dictionary = definition.get("mods", {})
		for key in mods.keys():
			result[key] = int(result.get(key, 0)) + int(mods[key])
	return result

func tone_from_conditions(conditions: Array[String]) -> String:
	if conditions.is_empty():
		return "neutral"
	var latest: String = str(conditions[conditions.size() - 1])
	return DEFINITIONS.get(latest, {}).get("tone", "neutral")
