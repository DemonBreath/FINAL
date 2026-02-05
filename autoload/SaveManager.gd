extends Node

const SAVE_PATH := "user://intake_save_v2.json"

var save_blob: Dictionary = {
	"meta": {
		"used_usernames": [],
		"dead_usernames": [],
	},
	"profiles": {},
	"leaderboard": {},
}

func _ready() -> void:
	load_blob()

func load_blob() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_blob = _default_blob()
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		save_blob = _default_blob()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
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

func get_profile(username: String) -> Dictionary:
	var key: String = username.to_lower()
	return save_blob.get("profiles", {}).get(key, {}).duplicate(true)

func set_profile(username: String, profile: Dictionary) -> void:
	var profiles: Dictionary = save_blob.get("profiles", {})
	profiles[username.to_lower()] = profile.duplicate(true)
	save_blob["profiles"] = profiles

func username_exists(username: String) -> bool:
	var key: String = username.to_lower()
	return save_blob.get("profiles", {}).has(key)

func mark_username_used(username: String) -> void:
	var used: Array = save_blob.get("meta", {}).get("used_usernames", [])
	var key: String = username.to_lower()
	if not used.has(key):
		used.append(key)
		save_blob["meta"]["used_usernames"] = used

func mark_username_dead(username: String) -> void:
	var dead: Array = save_blob.get("meta", {}).get("dead_usernames", [])
	var key: String = username.to_lower()
	if not dead.has(key):
		dead.append(key)
		save_blob["meta"]["dead_usernames"] = dead

func is_username_dead(username: String) -> bool:
	return save_blob.get("meta", {}).get("dead_usernames", []).has(username.to_lower())

func get_leaderboard() -> Dictionary:
	return save_blob.get("leaderboard", {}).duplicate(true)

func set_leaderboard(data: Dictionary) -> void:
	save_blob["leaderboard"] = data.duplicate(true)

func _default_blob() -> Dictionary:
	return {
		"meta": {
			"used_usernames": [],
			"dead_usernames": [],
		},
		"profiles": {},
		"leaderboard": {},
	}

func _normalize_blob(raw: Dictionary) -> Dictionary:
	var normalized: Dictionary = _default_blob()
	normalized["meta"]["used_usernames"] = raw.get("meta", {}).get("used_usernames", []).duplicate(true)
	normalized["meta"]["dead_usernames"] = raw.get("meta", {}).get("dead_usernames", []).duplicate(true)
	normalized["profiles"] = raw.get("profiles", {}).duplicate(true)
	normalized["leaderboard"] = raw.get("leaderboard", {}).duplicate(true)
	return normalized
