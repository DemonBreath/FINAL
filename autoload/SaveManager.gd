extends Node

const SAVE_PATH: String = "user://intake_save_v3.json"

var save_blob: Dictionary = {
	"profiles": {},
	"meta": {
		"current_username": "",
		"used_usernames": [],
		"dead_usernames": []
	}
}

func _ready() -> void:
	load_blob()

func save_game(state: Dictionary) -> void:
	var normalized_state: Dictionary = state.duplicate(true)
	var username: String = str(normalized_state.get("username", "")).strip_edges()
	if username.is_empty():
		return
	var profiles: Dictionary = save_blob.get("profiles", {})
	profiles[username.to_lower()] = normalized_state
	save_blob["profiles"] = profiles
	var meta: Dictionary = save_blob.get("meta", {})
	meta["current_username"] = username
	save_blob["meta"] = meta
	save_blob_to_disk()

func load_game() -> Dictionary:
	var meta: Dictionary = save_blob.get("meta", {})
	var username: String = str(meta.get("current_username", "")).strip_edges().to_lower()
	if username.is_empty():
		return {}
	var profiles: Dictionary = save_blob.get("profiles", {})
	if not profiles.has(username):
		return {}
	var profile: Dictionary = profiles.get(username, {})
	return profile.duplicate(true)

func has_save() -> bool:
	var active: Dictionary = load_game()
	return not active.is_empty()

func get_profile(username: String) -> Dictionary:
	var key: String = username.strip_edges().to_lower()
	if key.is_empty():
		return {}
	var profiles: Dictionary = save_blob.get("profiles", {})
	var profile: Dictionary = profiles.get(key, {})
	return profile.duplicate(true)

func username_exists(username: String) -> bool:
	var key: String = username.strip_edges().to_lower()
	if key.is_empty():
		return false
	var profiles: Dictionary = save_blob.get("profiles", {})
	return profiles.has(key)

func mark_username_used(username: String) -> void:
	var key: String = username.strip_edges().to_lower()
	if key.is_empty():
		return
	var meta: Dictionary = save_blob.get("meta", {})
	var used: Array[String] = []
	for item: Variant in meta.get("used_usernames", []):
		used.append(str(item))
	if not used.has(key):
		used.append(key)
	meta["used_usernames"] = used
	save_blob["meta"] = meta

func mark_username_dead(username: String) -> void:
	var key: String = username.strip_edges().to_lower()
	if key.is_empty():
		return
	var meta: Dictionary = save_blob.get("meta", {})
	var dead: Array[String] = []
	for item: Variant in meta.get("dead_usernames", []):
		dead.append(str(item))
	if not dead.has(key):
		dead.append(key)
	meta["dead_usernames"] = dead
	save_blob["meta"] = meta
	save_blob_to_disk()

func is_username_dead(username: String) -> bool:
	var key: String = username.strip_edges().to_lower()
	if key.is_empty():
		return false
	var meta: Dictionary = save_blob.get("meta", {})
	var dead: Array = meta.get("dead_usernames", [])
	return dead.has(key)

func set_current_username(username: String) -> void:
	var meta: Dictionary = save_blob.get("meta", {})
	meta["current_username"] = username.strip_edges()
	save_blob["meta"] = meta
	save_blob_to_disk()

func load_blob() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_blob = _default_blob()
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		save_blob = _default_blob()
		return
	var raw_text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw_text)
	if parsed is Dictionary:
		save_blob = _normalize_blob(parsed)
	else:
		save_blob = _default_blob()

func save_blob_to_disk() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(save_blob, "\t", true))
	file.close()

func _default_blob() -> Dictionary:
	return {
		"profiles": {},
		"meta": {
			"current_username": "",
			"used_usernames": [],
			"dead_usernames": []
		}
	}

func _normalize_blob(raw: Dictionary) -> Dictionary:
	var normalized: Dictionary = _default_blob()
	var raw_meta: Dictionary = raw.get("meta", {})
	var meta: Dictionary = normalized.get("meta", {})
	meta["current_username"] = str(raw_meta.get("current_username", ""))
	meta["used_usernames"] = raw_meta.get("used_usernames", []).duplicate(true)
	meta["dead_usernames"] = raw_meta.get("dead_usernames", []).duplicate(true)
	normalized["meta"] = meta
	normalized["profiles"] = raw.get("profiles", {}).duplicate(true)
	return normalized
