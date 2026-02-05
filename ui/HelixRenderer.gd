extends RefCounted
class_name HelixRenderer

func render(dna_bits: PackedInt32Array, mutated: Array[int], frame: int, rows: int = 18, width: int = 22) -> String:
	if dna_bits.size() == 0:
		return ""
	var lines: Array[String] = []
	var bit_count: int = dna_bits.size()
	var y: int = 0
	while y < rows:
		var angle: float = (float((y + frame) % rows) / float(rows)) * TAU
		var offset: int = int(round(sin(angle) * (float(width) / 2.6)))
		var left_col: int = int(width / 2) + offset
		var right_col: int = width - left_col
		if right_col <= left_col:
			right_col = left_col + 1
		var left_idx: int = ((y * 3) + frame) % bit_count
		var right_idx: int = ((y * 3) + frame + 1) % bit_count
		var left_bit: String = _bit_color(str(dna_bits[left_idx]), left_idx, mutated)
		var right_bit: String = _bit_color(str(dna_bits[right_idx]), right_idx, mutated)
		var line: String = " ".repeat(width + 2)
		line = line.left(left_col) + left_bit + line.substr(left_col + 1)
		var bridge: int = left_col + 1
		while bridge < right_col:
			if bridge % 2 == 0:
				line = line.left(bridge) + "·" + line.substr(bridge + 1)
			bridge += 1
		line = line.left(right_col) + right_bit + line.substr(right_col + 1)
		lines.append(line)
		y += 1
	return "[code]" + "\n".join(lines) + "[/code]"

func _bit_color(bit: String, idx: int, mutated: Array[int]) -> String:
	if mutated.has(idx):
		return "[color=#ff4a4a]%s[/color]" % bit
	return bit
