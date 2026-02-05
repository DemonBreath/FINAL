extends RefCounted
class_name NarrativeEngine

const OPENING_A := ["a failed transit station", "an intake ward", "a rain-clogged underpass", "a civic processing hall"]
const OPENING_B := ["with a stamped wristband you do not recognize", "while loudspeakers list numbers that skip yours", "as drones scan for compliance marks", "with your file flagged as incomplete"]
const OPENING_C := ["Someone whispers your name then vanishes.", "A wall display asks you to prove you are alive.", "A maintenance door unlocks for exactly three seconds.", "A siren dies mid-note, as if listening."]

const RESP_A := ["The district exhales", "Concrete lights shiver", "A watchtower lens rotates", "A vending shrine flickers"]
const RESP_B := ["after you", "while you", "as you"]
const RESP_C := ["and the system records your intent", "and nearby strangers adjust their distance", "and a hidden protocol acknowledges the move", "and your pulse syncs with distant machinery"]
const PROMPTS := ["What do you attempt next?", "Your move, survivor.", "Choose the next risk.", "Name your next action."]

func opening(seed: int, username: String, used_hashes: Array) -> String:
	return _unique_text(seed, 0, username, used_hashes, OPENING_A, OPENING_B, OPENING_C, true)

func response(seed: int, turn: int, command: String, tone: String, used_hashes: Array) -> Dictionary:
	var lead: String = _pick(RESP_A, "lead", seed, turn, command)
	var bridge: String = _pick(RESP_B, "bridge", seed, turn, command)
	var close: String = _pick(RESP_C, "close", seed, turn, command)
	var tone_clause: String = ""
	match tone:
		"predatory": tone_clause = " Hunger sharpens every sound"
		"fractured": tone_clause = " Reflections split into impossible angles"
		"hushed": tone_clause = " The noise floor drops to a whisper"
		"resonant": tone_clause = " Your breathing carries like a drum"
		"paranoid": tone_clause = " Every shadow appears to react"
		_: tone_clause = ""
	var text: String = "Turn %d: %s %s \"%s\", %s.%s" % [turn, lead, bridge, command, close, tone_clause]
	text = _enforce_unique(text, seed, turn, used_hashes)
	var prompt: String = _unique_prompt(seed, turn, used_hashes)
	return {"narrative": text, "prompt": prompt}

func _unique_text(seed: int, turn: int, key: String, used_hashes: Array, a: Array, b: Array, c: Array, opening_mode: bool = false) -> String:
	var variant: int = 0
	while variant < 128:
		var part_a: String = _pick(a, "a", seed, turn + variant, key)
		var part_b: String = _pick(b, "b", seed, turn + variant, key)
		var part_c: String = _pick(c, "c", seed, turn + variant, key)
		var text: String = "You surface in %s %s. %s" % [part_a, part_b, part_c]
		if opening_mode:
			text += ""
		var h: String = str(hash(text))
		if not used_hashes.has(h):
			used_hashes.append(h)
			return text
		variant += 1
	return "You wake in another unrepeated corner of the city."

func _unique_prompt(seed: int, turn: int, used_hashes: Array) -> String:
	var i: int = 0
	while i < 32:
		var prompt: String = _pick(PROMPTS, "prompt", seed, turn + i, str(i))
		var tagged: String = "%s [%d]" % [prompt, turn + i]
		var h: String = str(hash(tagged))
		if not used_hashes.has(h):
			used_hashes.append(h)
			return tagged
		i += 1
	return "What now?"

func _enforce_unique(text: String, seed: int, turn: int, used_hashes: Array) -> String:
	var i: int = 0
	var candidate: String = text
	while i < 64:
		var h: String = str(hash(candidate))
		if not used_hashes.has(h):
			used_hashes.append(h)
			return candidate
		candidate = "%s (%d)" % [text, abs(int(hash("%d:%d:%d" % [seed, turn, i]))) % 997]
		i += 1
	return "%s *" % text

func _pick(source: Array, tag: String, seed: int, turn: int, key: String) -> String:
	if source.is_empty():
		return ""
	var idx: int = abs(int(hash("%s:%d:%d:%s" % [tag, seed, turn, key]))) % source.size()
	return str(source[idx])
