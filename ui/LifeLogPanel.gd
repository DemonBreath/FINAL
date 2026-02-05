extends RefCounted
class_name LifeLogPanel

func build_entries(entries: Array) -> Array[String]:
	var lines: Array[String] = []
	for entry in entries:
		if entry is Dictionary:
			lines.append("Turn %d [%s] %s" % [int(entry.get("turn", 0)), str(entry.get("type", "log")), str(entry.get("text", ""))])
	return lines
