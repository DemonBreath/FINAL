extends RefCounted
class_name NarrativeEngine

const ZONES: Array[String] = ["intake atrium", "medical tramline", "salt archive", "mirror corridor", "quarantine deck"]
const ACTION_CLAUSES: Array[String] = [
	"you move without permission",
	"your choice is logged as noncompliant",
	"the watchers recalculate your threat",
	"old machinery wakes to observe"
]
const CONDITION_EVENTS: Dictionary = {
	"Adrenal Bloom": "Your pulse spikes into predatory clarity.",
	"Glass Fever": "Edges refract and your depth sense cracks.",
	"Quiet Static": "The world goes soft as static eats the loudest alarms.",
	"Titan Lungs": "Air thickens, but your chest adapts and expands.",
	"Mirror Nerves": "Every reflection twitches half a second before you do."
}

func generate(seed: int, turn: int, command: String, stats: Dictionary, conditions: Array[String], environment_memory: Dictionary) -> Dictionary:
	var zone: String = _pick_zone(seed, turn, environment_memory)
	var clause: String = _pick_clause(seed, turn, command)
	var stress: int = int(stats.get("stress", 0))
	var endurance: int = int(stats.get("endurance", 0))
	var tone: String = ""
	if stress >= 10:
		tone = " Pressure gnaws at your concentration."
	elif endurance <= 2:
		tone = " Your body trembles under chronic strain."
	else:
		tone = " You keep your breathing measured."
	var text: String = "Turn %d in %s: You %s; %s.%s" % [turn, zone, command, clause, tone]
	var reason: String = _stat_reason(command, stress, endurance)
	var candidate_condition: Variant = _possible_condition(seed, turn, command, conditions)
	if candidate_condition != null:
		text += " " + str(CONDITION_EVENTS.get(str(candidate_condition), "A new syndrome takes root."))
	return {
		"text": text,
		"stat_shift_reason": reason,
		"possible_condition": candidate_condition
	}

func _pick_zone(seed: int, turn: int, environment_memory: Dictionary) -> String:
	var memory_echo: int = int(environment_memory.get("echo", 0))
	var pick: int = int(abs(hash("zone:%d:%d:%d" % [seed, turn, memory_echo]))) % ZONES.size()
	return ZONES[pick]

func _pick_clause(seed: int, turn: int, command: String) -> String:
	var pick: int = int(abs(hash("clause:%d:%d:%s" % [seed, turn, command.to_lower()]))) % ACTION_CLAUSES.size()
	return ACTION_CLAUSES[pick]

func _stat_reason(command: String, stress: int, endurance: int) -> String:
	var lower: String = command.to_lower()
	if lower.contains("rest") or lower.contains("wait"):
		return "calm recovery"
	if lower.contains("run") or lower.contains("fight"):
		return "physical strain"
	if stress >= 10:
		return "psychological threat"
	if endurance <= 2:
		return "fatigue strain"
	return "ambient drift"

func _possible_condition(seed: int, turn: int, command: String, conditions: Array[String]) -> Variant:
	if turn < 2:
		return null
	var roll: int = int(abs(hash("cond:%d:%d:%s" % [seed, turn, command.to_lower()]))) % 100
	if roll > 8:
		return null
	var names: Array[String] = []
	for key: Variant in CONDITION_EVENTS.keys():
		names.append(str(key))
	var base_pick: int = int(abs(hash("name:%d:%d" % [seed, turn]))) % names.size()
	var offset: int = 0
	while offset < names.size():
		var name: String = names[(base_pick + offset) % names.size()]
		if not conditions.has(name):
			return name
		offset += 1
	return null
