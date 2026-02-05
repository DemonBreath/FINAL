extends Control

@onready var output: RichTextLabel = $Tabs/GAME/GameLayout/GameSplit/GamePanel/Output
@onready var input: LineEdit = $Tabs/GAME/GameLayout/GameSplit/GamePanel/Input
@onready var life_log_content: VBoxContainer = $Tabs/GAME/GameLayout/GameSplit/LifeLogPanel/LifeLogScroll/LifeLogContent
@onready var life_log_placeholder: Label = $Tabs/GAME/GameLayout/GameSplit/LifeLogPanel/LifeLogScroll/LifeLogContent/LifeLogPlaceholder
@onready var stats_label: Label = $Tabs/STATS/StatsLabel

const START_SCENARIOS: Array[String] = [
	"You wake in a public clinic recovery bay with your name missing from the intake ledger.",
	"Dawn breaks over a freight yard where you are already late for a shift you do not remember accepting.",
	"A storm siren ends as you open your eyes inside a maintenance tunnel with one working flashlight.",
	"You arrive at a licensing office holding incomplete forms for a profession you have never trained for.",
	"At first light, an automated evaluator reports your stress index as critical and requests immediate compliance.",
	"You regain consciousness in a rented capsule apartment while debt reminders queue on the wall display.",
]

const SAVE_PATH := "user://intake_save.cfg"
const RISKY_KEYWORDS: Array[String] = ["run", "fight", "smoke", "jump", "attack", "sprint", "charge"]
const WAITING_KEYWORDS: Array[String] = ["wait", "idle", "sleep", "pause", "stand", "still"]

var available_openings: Array[String] = []
var game_started := false
var opening_text := ""
var previous_action_signature := ""

var world_state := {
	"location": "unknown",
	"situation": "idle",
	"time": 0,
	"entropy": 0,
}

var current_player_state := {
	"health": 100,
	"stress": 0,
	"entropy": 0,
	"isolation": 0,
	"conditions": [],
}

var initial_player_state = {}

func _ready() -> void:
	# WHY: UI defaults in Godot can block pointer events on containers on desktop,
	# so we explicitly set pass/stop behavior to keep tabs, line input, and buttons reliable.
	_configure_input_behavior(self)
	randomize()
	# WHY: Start scenarios should not repeat inside one run, so we use a shuffled draw pool.
	available_openings = START_SCENARIOS.duplicate()
	available_openings.shuffle()
	_start_new_life()
	# WHY: Deferred focus guarantees the caret appears as soon as the first frame is ready.
	call_deferred("_focus_main_input")

func _focus_main_input() -> void:
	input.grab_focus()
	input.caret_column = input.text.length()

func _configure_input_behavior(root: Node) -> void:
	if root is Container or root is ColorRect or (root is Control and not _is_interactive_control(root)):
		(root as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		(root as Control).focus_mode = Control.FOCUS_NONE

	if root is TabContainer or root is BaseButton or root is LineEdit:
		(root as Control).mouse_filter = Control.MOUSE_FILTER_STOP
		(root as Control).focus_mode = Control.FOCUS_ALL

	for child: Node in root.get_children():
		_configure_input_behavior(child)

func _is_interactive_control(node: Node) -> bool:
	return node is TabContainer or node is BaseButton or node is LineEdit

func _on_submit_pressed() -> void:
	_submit_current_input()

func _on_input_text_submitted(_new_text: String) -> void:
	_submit_current_input()

func _submit_current_input() -> void:
	var command := input.text.strip_edges()
	if command.is_empty():
		_focus_main_input()
		return

	output.append_text("\n> %s" % command)
	_add_life_log_entry("Action: %s" % command)
	_process_player_action(command)
	input.clear()
	_focus_main_input()

func _start_new_life() -> void:
	if available_openings.is_empty():
		available_openings = START_SCENARIOS.duplicate()
		available_openings.shuffle()

	opening_text = available_openings.pop_back()
	output.clear()
	output.append_text("%s\n\nWhat do you do?" % opening_text)
	_reset_life_log()
	_add_life_log_entry("Major event: New life initialized.")
	_load_or_initialize_state()
	_update_stats_label()

func _load_or_initialize_state() -> void:
	var loaded := _load_saved_state()
	if not loaded:
		world_state = {
			"location": "intake sector",
			"situation": "idle",
			"time": 0,
			"entropy": 0,
		}
		current_player_state = {
			"health": 100,
			"stress": 0,
			"entropy": 0,
			"isolation": 0,
			"conditions": [],
		}
		initial_player_state = {}
		game_started = false
		previous_action_signature = ""
		_save_state()

func _load_saved_state() -> bool:
	var save := ConfigFile.new()
	if save.load(SAVE_PATH) != OK:
		return false

	world_state["location"] = str(save.get_value("world", "location", "intake sector"))
	world_state["situation"] = str(save.get_value("world", "situation", "idle"))
	world_state["time"] = int(save.get_value("world", "time", 0))
	world_state["entropy"] = int(save.get_value("world", "entropy", 0))

	current_player_state["health"] = int(save.get_value("current", "health", 100))
	current_player_state["stress"] = int(save.get_value("current", "stress", 0))
	current_player_state["entropy"] = int(save.get_value("current", "entropy", 0))
	current_player_state["isolation"] = int(save.get_value("current", "isolation", 0))
	current_player_state["conditions"] = save.get_value("current", "conditions", [])

	initial_player_state = save.get_value("initial", "state", {})
	game_started = bool(save.get_value("meta", "game_started", false))
	previous_action_signature = str(save.get_value("meta", "previous_action_signature", ""))

	if not current_player_state.has("conditions"):
		current_player_state["conditions"] = []
	if initial_player_state.has("conditions") == false and initial_player_state.size() > 0:
		initial_player_state["conditions"] = []

	return true

func _save_state() -> void:
	var save := ConfigFile.new()
	save.set_value("world", "location", world_state["location"])
	save.set_value("world", "situation", world_state["situation"])
	save.set_value("world", "time", world_state["time"])
	save.set_value("world", "entropy", world_state["entropy"])

	save.set_value("current", "health", current_player_state["health"])
	save.set_value("current", "stress", current_player_state["stress"])
	save.set_value("current", "entropy", current_player_state["entropy"])
	save.set_value("current", "isolation", current_player_state["isolation"])
	save.set_value("current", "conditions", current_player_state["conditions"])

	save.set_value("initial", "state", initial_player_state)
	save.set_value("meta", "game_started", game_started)
	save.set_value("meta", "previous_action_signature", previous_action_signature)
	save.save(SAVE_PATH)

func _reset_life_log() -> void:
	for child: Node in life_log_content.get_children():
		if child != life_log_placeholder:
			child.queue_free()
	life_log_placeholder.visible = true

func _add_life_log_entry(entry: String) -> void:
	life_log_placeholder.visible = false
	var label := Label.new()
	label.text = entry
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	life_log_content.add_child(label)

func _process_player_action(command: String) -> void:
	if not game_started:
		_initialize_character_baseline()

	var normalized := command.to_lower().strip_edges()
	var action_signature := _action_signature(normalized)
	var result_description := _interpret_action(normalized)
	var changes := _apply_turn_rules(normalized, action_signature)
	world_state["time"] += 1
	world_state["entropy"] = current_player_state["entropy"]
	_add_condition_if_needed()
	_update_stats_label()
	_save_state()

	output.append_text("\n%s" % _compose_turn_prompt(result_description, changes))

func _initialize_character_baseline() -> void:
	game_started = true
	current_player_state["health"] = randi_range(90, 100)
	current_player_state["stress"] = randi_range(1, 5)
	current_player_state["entropy"] = randi_range(0, 2)
	current_player_state["isolation"] = randi_range(0, 2)
	current_player_state["conditions"] = []

	# Record immutable initial state once.
	if initial_player_state.is_empty():
		initial_player_state = {
			"health": current_player_state["health"],
			"stress": current_player_state["stress"],
			"entropy": current_player_state["entropy"],
			"isolation": current_player_state["isolation"],
			"conditions": [],
		}

	_add_life_log_entry("Character initialized.")
	_add_life_log_entry("Baseline recorded.")

func _action_signature(normalized_command: String) -> String:
	for risky: String in RISKY_KEYWORDS:
		if normalized_command.contains(risky):
			return "risky"
	for waiting: String in WAITING_KEYWORDS:
		if normalized_command.contains(waiting):
			return "inactive"
	if normalized_command.contains("look") or normalized_command.contains("scan"):
		return "observe"
	if normalized_command.contains("talk") or normalized_command.contains("ask"):
		return "social"
	return normalized_command.split(" ", false)[0] if normalized_command.find(" ") > -1 else normalized_command

func _interpret_action(normalized: String) -> String:
	if normalized.contains("look") or normalized.contains("scan"):
		world_state["situation"] = "surveying"
		return "You sweep your surroundings and map exits, cameras, and blind corners."
	if normalized.contains("talk") or normalized.contains("ask"):
		world_state["situation"] = "negotiating"
		return "You test the room with a few careful words, gauging who responds and who hides intent."
	if normalized.contains("move") or normalized.contains("walk"):
		world_state["situation"] = "relocating"
		world_state["location"] = "corridor %d" % int(world_state["time"] + 1)
		return "You keep moving, counting doors and memorizing patterns in the floor lights."
	if _contains_any(normalized, WAITING_KEYWORDS):
		world_state["situation"] = "waiting"
		return "You hold position and let the system's noise settle around you."
	if _contains_any(normalized, RISKY_KEYWORDS):
		world_state["situation"] = "taking risk"
		return "You commit to a dangerous impulse before caution can override it."
	world_state["situation"] = "improvising"
	return "The system accepts your action and the moment shifts in subtle, permanent ways."

func _apply_turn_rules(normalized: String, action_signature: String) -> Array[String]:
	var changes: Array[String] = []

	current_player_state["entropy"] += 1
	changes.append("Entropy +1")
	_add_life_log_entry("Stat change: entropy increased to %d." % current_player_state["entropy"])

	if previous_action_signature == action_signature and not action_signature.is_empty():
		current_player_state["stress"] += 1
		changes.append("Stress +1 from repeating yourself")
		_add_life_log_entry("Stat change: stress increased to %d from repeated actions." % current_player_state["stress"])

	if _contains_any(normalized, WAITING_KEYWORDS):
		current_player_state["isolation"] += 1
		changes.append("Isolation +1")
		_add_life_log_entry("Stat change: isolation increased to %d during inactivity." % current_player_state["isolation"])

	if _contains_any(normalized, RISKY_KEYWORDS):
		current_player_state["health"] = max(0, int(current_player_state["health"]) - 1)
		changes.append("Health -1")
		_add_life_log_entry("Stat change: health decreased to %d after risk." % current_player_state["health"])

	if changes.size() == 1:
		changes.append("No additional shift detected")

	previous_action_signature = action_signature
	return changes

func _contains_any(text: String, keywords: Array[String]) -> bool:
	for keyword: String in keywords:
		if text.contains(keyword):
			return true
	return false

func _add_condition_if_needed() -> void:
	var conditions: Array = current_player_state["conditions"]
	if int(current_player_state["stress"]) >= 10 and not conditions.has("Unidentified Condition"):
		conditions.append("Unidentified Condition")
		_add_life_log_entry("Condition added: Unidentified Condition.")
	current_player_state["conditions"] = conditions

func _compose_turn_prompt(result_description: String, changes: Array[String]) -> String:
	var summary := "Turn %d | Location: %s | Situation: %s\n%s\nChanges: %s\nWhat do you do?" % [
		int(world_state["time"]),
		str(world_state["location"]),
		str(world_state["situation"]),
		result_description,
		", ".join(changes),
	]
	return summary

func _format_conditions(conditions: Array) -> String:
	if conditions.is_empty():
		return "None"
	var lines: Array[String] = []
	for condition: Variant in conditions:
		lines.append("• %s" % str(condition))
	return "\n".join(lines)

func _update_stats_label() -> void:
	var initial_conditions := []
	if initial_player_state.has("conditions"):
		initial_conditions = initial_player_state["conditions"]

	var initial_text := "INITIAL STATE\nHealth: %s\nStress: %s\nEntropy: %s\nIsolation: %s\nConditions: %s" % [
		str(initial_player_state.get("health", "Not recorded yet")),
		str(initial_player_state.get("stress", "Not recorded yet")),
		str(initial_player_state.get("entropy", "Not recorded yet")),
		str(initial_player_state.get("isolation", "Not recorded yet")),
		_format_conditions(initial_conditions),
	]

	var current_conditions: Array = current_player_state["conditions"]
	var current_text := "CURRENT STATE\nHealth: %d\nStress: %d\nEntropy: %d\nIsolation: %d\nConditions: %s" % [
		int(current_player_state["health"]),
		int(current_player_state["stress"]),
		int(current_player_state["entropy"]),
		int(current_player_state["isolation"]),
		_format_conditions(current_conditions),
	]

	stats_label.text = "%s\n\n%s" % [initial_text, current_text]
