extends Control

@onready var output: RichTextLabel = $Tabs/GAME/GameLayout/GameSplit/GamePanel/Output
@onready var input: LineEdit = $Tabs/GAME/GameLayout/GameSplit/GamePanel/Input
@onready var life_log_content: VBoxContainer = $Tabs/GAME/GameLayout/GameSplit/LifeLogPanel/LifeLogScroll/LifeLogContent
@onready var life_log_placeholder: Label = $Tabs/GAME/GameLayout/GameSplit/LifeLogPanel/LifeLogScroll/LifeLogContent/LifeLogPlaceholder
@onready var stats_output: RichTextLabel = $Tabs/STATS/StatsOutput

const START_SCENARIOS: Array[String] = [
	"You wake in a public clinic recovery bay with your name missing from the intake ledger.",
	"Dawn breaks over a freight yard where you are already late for a shift you do not remember accepting.",
	"A storm siren ends as you open your eyes inside a maintenance tunnel with one working flashlight.",
	"You arrive at a licensing office holding incomplete forms for a profession you have never trained for.",
	"At first light, an automated evaluator reports your stress index as critical and requests immediate compliance.",
	"You regain consciousness in a rented capsule apartment while debt reminders queue on the wall display.",
]

const STAT_NOTIFICATIONS := {
	"strength": "Strength",
	"intellect": "Intellect",
	"perception": "Perception",
	"stress": "Stress",
	"endurance": "Endurance",
}

var available_openings: Array[String] = []

func _ready() -> void:
	_configure_input_behavior(self)
	available_openings = START_SCENARIOS.duplicate()
	available_openings.shuffle()
	_start_or_resume_life()
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
	_process_player_action(command)
	input.clear()
	_focus_main_input()

func _start_or_resume_life() -> void:
	var username := _resolve_username()
	var loaded_existing := PlayerState.start_or_resume(username)
	output.clear()
	if loaded_existing:
		var state := PlayerState.get_state()
		output.append_text("Welcome back, %s.\nResuming turn %d.\n\nEnter your next command." % [state.get("username", username), int(state.get("turn", 0))])
	else:
		_start_new_life_narrative()
	_refresh_life_log_from_state()
	_update_stats_panel()

func _resolve_username() -> String:
	var env_user := OS.get_environment("INTAKE_USERNAME").strip_edges()
	if env_user.is_empty():
		env_user = OS.get_environment("USER").strip_edges()
	if env_user.is_empty():
		env_user = OS.get_environment("USERNAME").strip_edges()
	if env_user.is_empty():
		env_user = "Player"
	return env_user

func _start_new_life_narrative() -> void:
	if available_openings.is_empty():
		available_openings = START_SCENARIOS.duplicate()
		available_openings.shuffle()
	var opening: String = available_openings.pop_back()
	output.append_text("%s\n\nEnter a command to take your first action." % opening)

func _refresh_life_log_from_state() -> void:
	for child: Node in life_log_content.get_children():
		if child != life_log_placeholder:
			child.queue_free()
	var entries: Array = PlayerState.get_state().get("life_log", [])
	life_log_placeholder.visible = entries.is_empty()
	for entry in entries:
		if entry is Dictionary:
			var label := Label.new()
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.text = "Turn %d [%s]: %s" % [int(entry.get("turn", 0)), str(entry.get("type", "log")), str(entry.get("text", ""))]
			life_log_content.add_child(label)

func _process_player_action(command: String) -> void:
	var turn := PlayerState.advance_turn()
	var normalized := command.to_lower()
	var stat_update_line := ""
	var narrative := _build_turn_narrative(command, turn)

	if normalized.contains("walk"):
		stat_update_line = _apply_stat_delta("endurance", 1)
	elif normalized.contains("study") or normalized.contains("read"):
		stat_update_line = _apply_stat_delta("intellect", 1)
	elif normalized.contains("observe") or normalized.contains("search"):
		stat_update_line = _apply_stat_delta("perception", 1)
	elif normalized.contains("rest") or normalized.contains("recover"):
		stat_update_line = _apply_stat_delta("stress", -1)
	elif normalized.contains("panic"):
		stat_update_line = _apply_stat_delta("stress", 2)
	else:
		stat_update_line = "You commit to the action and adjust your footing for what comes next."

	_run_post_turn_mutations(turn, command)

	output.append_text("\n%s" % narrative)
	output.append_text("\n%s" % stat_update_line)
	output.append_text("\n[Next command?]")

	PlayerState.add_life_log_entry("turn", narrative, {"command": command})
	PlayerState.save_current_state()
	_refresh_life_log_from_state()
	_update_stats_panel()

	if _is_dead():
		_handle_death_and_rebirth()

func _run_post_turn_mutations(turn: int, command: String) -> void:
	if turn % 5 != 0:
		return
	var condition_name := "Mutation Echo %d" % turn
	var mutated_index := PlayerState.contract_condition(condition_name)
	if mutated_index >= 0:
		PlayerState.add_life_log_entry("condition", "Contracted %s (DNA bit %d mutated)." % [condition_name, mutated_index], {"bit_index": mutated_index, "trigger": command})

func _apply_stat_delta(stat_key: String, amount: int) -> String:
	var current_value := PlayerState.apply_stat_delta(stat_key, amount)
	var human_name: String = STAT_NOTIFICATIONS.get(stat_key, stat_key.capitalize())
	var direction := "increased" if amount > 0 else "decreased"
	PlayerState.add_life_log_entry("stat", "%s %s to %d." % [human_name, direction, current_value], {"delta": amount})
	return "%s %s to %d." % [human_name, direction, current_value]

func _build_turn_narrative(command: String, turn: int) -> String:
	var state := PlayerState.get_state()
	var stress := int(state.get("stats", {}).get("stress", 0))
	var mood := "The city hums in warning tones"
	if stress <= 2:
		mood = "The alarms settle into a low mechanical heartbeat"
	elif stress >= 8:
		mood = "Static crawls over your skin as pressure mounts"
	return "Turn %d: %s after you '%s'." % [turn, mood, command]

func _is_dead() -> bool:
	var stats: Dictionary = PlayerState.get_state().get("stats", {})
	return int(stats.get("endurance", 1)) <= 0 or int(stats.get("stress", 0)) >= 12

func _handle_death_and_rebirth() -> void:
	output.append_text("\n\n[b]You die in this timeline.[/b]\nA new life is generated immediately.")
	PlayerState.clear_current_life()
	PlayerState.start_new_life(_resolve_username())
	_start_new_life_narrative()
	PlayerState.save_current_state()
	_refresh_life_log_from_state()
	_update_stats_panel()

func _update_stats_panel() -> void:
	var state := PlayerState.get_state()
	var lines: Array[String] = []
	lines.append("[b]Username[/b]: %s" % str(state.get("username", "Player")))
	lines.append("[b]Seed[/b]: %d" % int(state.get("seed", 0)))
	lines.append("[b]Turn[/b]: %d" % int(state.get("turn", 0)))
	lines.append("")
	lines.append("[b]Stats[/b]")
	var stats: Dictionary = state.get("stats", {})
	for stat_key: String in STAT_NOTIFICATIONS.keys():
		lines.append("%s: %d" % [STAT_NOTIFICATIONS[stat_key], int(stats.get(stat_key, 0))])
	lines.append("")
	lines.append("[b]Conditions[/b]")
	var conditions: Array = state.get("conditions", [])
	if conditions.is_empty():
		lines.append("[color=#ff4a4a]None[/color]")
	else:
		for condition in conditions:
			lines.append("[color=#ff4a4a]%s[/color]" % str(condition))
	lines.append("")
	lines.append("[b]DNA bits[/b]: %s" % str(state.get("dna_bits", "")))
	lines.append("[b]Mutated bit indices[/b]: %s" % str(PlayerState.get_mutated_indices()))
	stats_output.text = "\n".join(lines)
