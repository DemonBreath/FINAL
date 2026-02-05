extends Control

@onready var output: RichTextLabel = $Tabs/GAME/GameLayout/GameSplit/GamePanel/Output
@onready var input: LineEdit = $Tabs/GAME/GameLayout/GameSplit/GamePanel/Input
@onready var life_log_content: VBoxContainer = $Tabs/GAME/GameLayout/GameSplit/LifeLogPanel/LifeLogScroll/LifeLogContent
@onready var life_log_placeholder: Label = $Tabs/GAME/GameLayout/GameSplit/LifeLogPanel/LifeLogScroll/LifeLogContent/LifeLogPlaceholder

const START_SCENARIOS: Array[String] = [
	"You wake in a public clinic recovery bay with your name missing from the intake ledger.",
	"Dawn breaks over a freight yard where you are already late for a shift you do not remember accepting.",
	"A storm siren ends as you open your eyes inside a maintenance tunnel with one working flashlight.",
	"You arrive at a licensing office holding incomplete forms for a profession you have never trained for.",
	"At first light, an automated evaluator reports your stress index as critical and requests immediate compliance.",
	"You regain consciousness in a rented capsule apartment while debt reminders queue on the wall display.",
]

const STAT_NOTIFICATIONS := {
	"walking_speed": "Walking Speed",
	"focus": "Focus",
	"resilience": "Resilience",
}

var available_openings: Array[String] = []
var stats := {
	"walking_speed": 0,
	"focus": 0,
	"resilience": 0,
}

func _ready() -> void:
	# WHY: UI defaults in Godot can block pointer events on containers on desktop,
	# so we explicitly set pass/stop behavior to keep tabs, line input, and buttons reliable.
	_configure_input_behavior(self)
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

	var opening: String = available_openings.pop_back()
	output.clear()
	output.append_text("%s\n\nEnter a command to take your first action." % opening)
	_reset_life_log()
	_add_life_log_entry("Major event: New life initialized.")

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
	var normalized := command.to_lower()
	if normalized.contains("walk"):
		_apply_stat_delta("walking_speed", 1)
	elif normalized.contains("study") or normalized.contains("read"):
		_apply_stat_delta("focus", 1)
	elif normalized.contains("rest") or normalized.contains("recover"):
		_apply_stat_delta("resilience", 1)
	else:
		output.append_text("\nSystem: Action recorded.")

func _apply_stat_delta(stat_key: String, amount: int) -> void:
	if not stats.has(stat_key):
		return

	stats[stat_key] += amount
	var human_name: String = STAT_NOTIFICATIONS.get(stat_key, stat_key)
	var direction := "increased" if amount > 0 else "decreased"
	var notification := "%s %s." % [human_name, direction]
	output.append_text("\n%s" % notification)
	_add_life_log_entry("Stat change: %s -> %d (%+d)" % [human_name, stats[stat_key], amount])
