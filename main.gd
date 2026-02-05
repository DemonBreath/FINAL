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
	# WHY: UI defaults in Godot can block pointer events on containers on desktop,
	# so we explicitly set pass/stop behavior to keep tabs, line input, and buttons reliable.
	_configure_input_behavior(self)
	# WHY: Start scenarios should not repeat inside one run, so we use a shuffled draw pool.
	available_openings = START_SCENARIOS.duplicate()
	available_openings.shuffle()
	start_new_life()
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

func start_new_life() -> void:
	if available_openings.is_empty():
		available_openings = START_SCENARIOS.duplicate()
		available_openings.shuffle()

	var opening: String = available_openings.pop_back()
	PlayerState.start_new_game()
	output.clear()
	output.append_text("%s\n\nEnter a command to take your first action." % opening)
	_reset_life_log()
	_add_life_log_entry("Major event: New life initialized (seed %d)." % PlayerState.character_seed)
	_update_stats_panel()

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
	var turn := PlayerState.advance_turn()
	var normalized := command.to_lower()
	var stat_line := ""

	if normalized.contains("walk"):
		stat_line = _apply_stat_delta("endurance", 1)
	elif normalized.contains("study") or normalized.contains("read"):
		stat_line = _apply_stat_delta("intellect", 1)
	elif normalized.contains("observe") or normalized.contains("search"):
		stat_line = _apply_stat_delta("perception", 1)
	elif normalized.contains("rest") or normalized.contains("recover"):
		stat_line = _apply_stat_delta("stress", -1)
	else:
		stat_line = "Action recorded."

	var narrative := _build_turn_narrative(command, turn)
	output.append_text("\n%s" % narrative)
	output.append_text("\n%s" % stat_line)
	output.append_text("\n[Next command?]")
	_run_post_turn_mutations(turn, command)
	_add_life_log_entry("Turn %d: %s" % [turn, narrative])
	_update_stats_panel()


func _run_post_turn_mutations(_turn: int, _command: String) -> void:
	# Hook reserved for future disease progression/superpower mutation logic.
	# Keep lightweight for now while guaranteeing every action has a mutation touchpoint.
	pass

func _apply_stat_delta(stat_key: String, amount: int) -> String:
	PlayerState.apply_stat_delta(stat_key, amount)
	var human_name: String = STAT_NOTIFICATIONS.get(stat_key, stat_key.capitalize())
	var direction := "increased" if amount > 0 else "decreased"
	var current_value: int = PlayerState.stats.get(stat_key, 0)
	_add_life_log_entry("Stat change: %s -> %d (%+d)" % [human_name, current_value, amount])
	return "%s %s." % [human_name, direction]

func _build_turn_narrative(command: String, turn: int) -> String:
	var mood := "The city hums in warning tones"
	if PlayerState.stats.get("stress", 0) <= 2:
		mood = "The alarms settle into a low mechanical heartbeat"
	elif PlayerState.stats.get("stress", 0) >= 8:
		mood = "Static crawls over your skin as pressure mounts"
	return "Turn %d: %s after you '%s'." % [turn, mood, command]

func _update_stats_panel() -> void:
	var lines: Array[String] = []
	lines.append("[b]Seed[/b]: %d" % PlayerState.character_seed)
	lines.append("[b]Turn[/b]: %d" % PlayerState.turn_counter)
	lines.append("")
	lines.append("[b]Stats[/b]")
	for stat_key: String in PlayerState.stats.keys():
		lines.append("%s: %d" % [STAT_NOTIFICATIONS.get(stat_key, stat_key.capitalize()), PlayerState.stats[stat_key]])
	lines.append("")
	lines.append("[b]Conditions[/b]")
	if PlayerState.diseases.is_empty():
		lines.append("[color=#b066ff]None[/color]")
	else:
		for disease: Dictionary in PlayerState.diseases:
			var disease_name: String = disease.get("name", "Unknown")
			if disease.get("is_superpower", false):
				lines.append("[color=#ff4a4a]%s[/color]" % disease_name)
			else:
				lines.append("[color=#b066ff]%s[/color]" % disease_name)
	lines.append("")
	lines.append("[b]DNA Hook[/b]: %s" % PlayerState.get_dna_sequence())
	stats_output.text = "\n".join(lines)
