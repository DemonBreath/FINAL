extends RefCounted
class_name DNAEngine

const DNA_LENGTH := 160

func generate(seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var bits := ""
	for _i in range(DNA_LENGTH):
		bits += str(rng.randi_range(0, 1))
	return bits

func mutate_bit(dna_bits: String, mutated_indices: Array[int], seed: int, condition_name: String) -> Dictionary:
	if dna_bits.is_empty() or mutated_indices.size() >= dna_bits.length():
		return {"dna_bits": dna_bits, "index": -1}
	var pick := abs(int(hash("%s:%d:%d" % [condition_name, seed, mutated_indices.size()]))) % dna_bits.length()
	while mutated_indices.has(pick):
		pick = (pick + 1) % dna_bits.length()
	var chars: PackedStringArray = dna_bits.split("", false)
	if chars[pick] == "0":
		chars[pick] = "1"
	else:
		chars[pick] = "0"
	return {"dna_bits": "".join(chars), "index": pick}
