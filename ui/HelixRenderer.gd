extends RefCounted
class_name HelixRenderer

func render(dna_bits: String, mutated: Array[int], frame: int, rows: int = 18, width: int = 22) -> String:
	if dna_bits.is_empty():
		return ""
	var lines: Array[String] = []
	var bit_count := dna_bits.length()
	for y in range(rows):
		var angle := float((y + frame) % rows) / float(rows) * TAU
		var offset := int(round(sin(angle) * (width / 2.6)))
		var left_col := (width / 2) + offset
		var right_col := width - left_col
		if right_col <= left_col:
			right_col = left_col + 1
		var left_idx := (y * 3 + frame) % bit_count
		var right_idx := (y * 3 + frame + 1) % bit_count
		var left_bit := _bit_color(dna_bits[left_idx], left_idx, mutated)
		var right_bit := _bit_color(dna_bits[right_idx], right_idx, mutated)
		var chars := " ".repeat(width + 2)
		chars = chars.left(left_col) + left_bit + chars.substr(left_col + 1)
		for bridge in range(left_col + 1, right_col):
			if bridge % 2 == 0:
				chars = chars.left(bridge) + "·" + chars.substr(bridge + 1)
		chars = chars.left(right_col) + right_bit + chars.substr(right_col + 1)
		lines.append(chars)
	return "[code]" + "\n".join(lines) + "[/code]"

func _bit_color(bit: String, idx: int, mutated: Array[int]) -> String:
	if mutated.has(idx):
		return "[color=#ff4a4a]%s[/color]" % bit
	return bit
