extends RefCounted
class_name StatsPanel

const STAT_LABELS := {
	"strength": "Strength",
	"intellect": "Intellect",
	"perception": "Perception",
	"stress": "Stress",
	"endurance": "Endurance",
}

func render(state: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("[b]Username[/b]: %s" % state.get("username", ""))
	lines.append("[b]Seed[/b]: %d" % int(state.get("seed", 0)))
	lines.append("[b]Turn[/b]: %d" % int(state.get("turn", 0)))
	lines.append("")
	lines.append("[b]Base stats[/b]")
	var stats: Dictionary = state.get("stats", {})
	for key in STAT_LABELS.keys():
		lines.append("%s: %d" % [STAT_LABELS[key], int(stats.get(key, 0))])
	lines.append("")
	lines.append("[b]Starting stats snapshot[/b]")
	var starting: Dictionary = state.get("starting_stats", {})
	for key in STAT_LABELS.keys():
		lines.append("%s: %d" % [STAT_LABELS[key], int(starting.get(key, 0))])
	lines.append("")
	lines.append("[b]Conditions[/b]")
	var conditions: Array = state.get("conditions", [])
	if conditions.is_empty():
		lines.append("[color=#ff4a4a]None[/color]")
	else:
		for condition in conditions:
			lines.append("[color=#ff4a4a]%s[/color]" % str(condition))
	lines.append("")
	lines.append("[b]DNA string[/b]: %s" % str(state.get("dna_bits", "")))
	lines.append("[b]Mutated indices[/b]: %s" % str(state.get("mutated_bit_indices", [])))
	return "\n".join(lines)
