extends RefCounted
class_name LifeLogPanel

func build_entries(entries: Array) -> Array[String]:
	var lines: Array[String] = []
	for entry: Variant in entries:
		if entry is Dictionary:
			var row: Dictionary = entry
			var row_turn: int = int(row.get("turn", 0))
			var row_command: String = str(row.get("command", ""))
			var row_text: String = str(row.get("text", ""))
			var row_reason: String = str(row.get("reason", ""))
			lines.append("Turn %d > %s | %s (%s)" % [row_turn, row_command, row_text, row_reason])
	return lines
