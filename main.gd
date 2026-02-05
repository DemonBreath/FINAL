extends Control

@onready var output: RichTextLabel = $UI/Output
@onready var input: TextEdit = $UI/Input

func _ready() -> void:
	input.grab_focus()

func _on_submit_pressed() -> void:
	var command := input.text.strip_edges()
	if command.is_empty():
		return
	output.append_text("\n> %s" % command)
	input.clear()
	input.grab_focus()
