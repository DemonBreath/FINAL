extends RefCounted
class_name DNAEngine

const DNA_LENGTH: int = 160

func generate(seed: int) -> PackedInt32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var bits: PackedInt32Array = PackedInt32Array()
	var index: int = 0
	while index < DNA_LENGTH:
		bits.append(rng.randi_range(0, 1))
		index += 1
	return bits

func generate_from_string(bit_string: String) -> PackedInt32Array:
	var bits: PackedInt32Array = PackedInt32Array()
	var index: int = 0
	while index < bit_string.length():
		var char_text: String = bit_string.substr(index, 1)
		bits.append(1 if char_text == "1" else 0)
		index += 1
	return bits

func mutate_once(bits: PackedInt32Array, existing_indices: Array[int], seed: int, condition_name: String) -> int:
	if bits.size() == 0:
		return -1
	if existing_indices.size() >= bits.size():
		return -1
	var pick: int = int(abs(hash("%s:%d:%d" % [condition_name, seed, existing_indices.size()]))) % bits.size()
	while existing_indices.has(pick):
		pick = (pick + 1) % bits.size()
	var old_value: int = int(bits[pick])
	bits[pick] = 1 if old_value == 0 else 0
	return pick

func get_dna_string(bits: PackedInt32Array) -> String:
	var out: String = ""
	for bit: int in bits:
		out += str(bit)
	return out
