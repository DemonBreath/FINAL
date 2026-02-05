extends Control

@onready var output: RichTextLabel = $UI/Output
@onready var input: TextEdit = $UI/Input

enum LoopState { INTAKE, SCENARIO, SUMMARY }

const SCENARIOS := [
	"The lights flicker and an announcement asks you to confirm the ingredients for the group meal.",
	"A friend asks if you can describe the flavor in a way that makes it sound appealing.",
	"You notice a quiet corner that might hide what you were eating from view.",
	"A message pops up asking whether you'd share your choice with the community board.",
]

var state: LoopState = LoopState.INTAKE
var scenario_index := 0
var last_consumed := ""

func _ready() -> void:
	output.clear()
	output.append_text("Welcome. We'll move through a short loop together.")
	_prompt_intake()
	input.grab_focus()

func _on_submit_pressed() -> void:
	var command := input.text.strip_edges()
	output.text += "\n[system received input]"
	if command.is_empty():
		return
	output.append_text("\n> %s" % command)
	input.clear()
	input.grab_focus()
	_process_input(command)

func _process_input(command: String) -> void:
	match state:
		LoopState.INTAKE:
			last_consumed = command
			_present_scenario()
			state = LoopState.SCENARIO
		LoopState.SCENARIO:
			_write_summary(command)
			state = LoopState.SUMMARY
			_prompt_intake()
			state = LoopState.INTAKE
		LoopState.SUMMARY:
			_prompt_intake()
			state = LoopState.INTAKE

func _present_scenario() -> void:
	var scenario = SCENARIOS[scenario_index]
	scenario_index = (scenario_index + 1) % SCENARIOS.size()
	output.append_text("\n\nScenario: %s" % scenario)
	output.append_text("\nHow do you respond?")

func _write_summary(response: String) -> void:
	output.append_text("\n\nSummary: After consuming %s, you responded, \"%s.\"" % [last_consumed, response])
	output.append_text("\nImpact: Your choice shapes the moment and how others perceive the situation.")
	output.append_text("\nVisibility: The details may be noticed depending on how openly you share them.")

func _prompt_intake() -> void:
	output.append_text("\n\nWhat did you consume?")
