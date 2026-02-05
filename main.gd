extends Control

@onready var output: RichTextLabel = $Tabs/GAME/GameLayout/GameSplit/GamePanel/Output
@onready var input: TextEdit = $Tabs/GAME/GameLayout/GameSplit/GamePanel/Input

enum LoopState { SCENARIO, SUMMARY }

const COLD_OPENS := [
	"Neon rain sheets down as a courier drone drops a locked case at your feet.",
	"A packed transit car lurches to a stop and every light snaps to emergency red.",
	"You slip into a candlelit archive just as the curator seals the only exit.",
	"Static hisses from your radio: someone whispers your name and a countdown begins.",
]

var state: LoopState = LoopState.SCENARIO
var active_cold_open := ""
var cycle_index := 0
var cycle_log: Array[Dictionary] = []

func _ready() -> void:
	randomize()
	_start_new_cycle(true)
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
		LoopState.SCENARIO:
			cycle_log[cycle_log.size() - 1]["response"] = command
			_write_summary(command)
			state = LoopState.SUMMARY
		LoopState.SUMMARY:
			cycle_index += 1
			_start_new_cycle(false)

func _start_new_cycle(is_first_cycle: bool) -> void:
	active_cold_open = COLD_OPENS[randi() % COLD_OPENS.size()]
	cycle_log.append({
		"cycle": cycle_index,
		"cold_open": active_cold_open,
		"response": "",
	})
	if is_first_cycle:
		output.text = active_cold_open
	else:
		output.append_text("\n\n%s" % active_cold_open)
	state = LoopState.SCENARIO

func _write_summary(response: String) -> void:
	output.append_text("\n\nCycle %d Summary: In '%s', you answered, \"%s.\"" % [cycle_index, active_cold_open, response])
	output.append_text("\nAftershock: The world shifts subtly around your choice.")
