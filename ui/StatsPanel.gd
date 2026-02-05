extends RefCounted
class_name StatsPanel

const STAT_LABELS: Dictionary = {
	"strength": "Strength",
	"intellect": "Intellect",
	"perception": "Perception",
	"stress": "Stress",
	"endurance": "Endurance"
}

func render(state: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("[b]Username[/b]: %s" % str(state.get("username", "")))
	lines.append("[b]Seed[/b]: %d" % int(state.get("seed", 0)))
	lines.append("[b]Turn[/b]: %d" % int(state.get("turn", 0)))
	lines.append("")
	lines.append("[b]Stats[/b]")
	var stat_values: Dictionary = state.get("stats", {})
	for key: Variant in STAT_LABELS.keys():
		lines.append("%s: %d" % [str(STAT_LABELS.get(str(key), str(key))), int(stat_values.get(str(key), 0))])
	lines.append("")
	lines.append("[b]Conditions (diseases/superpowers)[/b]")
	var conditions: Array = state.get("conditions", [])
	if conditions.is_empty():
		lines.append("[color=#ff4a4a]None[/color]")
	else:
		for condition: Variant in conditions:
			lines.append("[color=#ff4a4a]%s[/color]" % str(condition))
	lines.append("")
	var bits: PackedInt32Array = PackedInt32Array()
	var incoming: Variant = state.get("dna_bits", PackedInt32Array())
	if incoming is PackedInt32Array:
		bits = incoming
	lines.append("[b]DNA bits[/b]: %s" % _bits_to_string(bits))
	lines.append("[b]Mutated indices[/b]: %s" % str(state.get("mutated_bit_indices", [])))
	return "\n".join(lines)

func _bits_to_string(bits: PackedInt32Array) -> String:
	var out: String = ""
	for bit: int in bits:
		out += str(bit)
	return out
