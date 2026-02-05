extends Control

@onready var output: RichTextLabel = $Tabs/GAME/GameLayout/GameSplit/GamePanel/Output
@onready var input: LineEdit = $Tabs/GAME/GameLayout/GameSplit/GamePanel/Input
@onready var life_log_content: VBoxContainer = $Tabs/GAME/GameLayout/GameSplit/LifeLogPanel/LifeLogScroll/LifeLogContent
@onready var life_log_placeholder: Label = $Tabs/GAME/GameLayout/GameSplit/LifeLogPanel/LifeLogScroll/LifeLogContent/LifeLogPlaceholder
@onready var stats_output: RichTextLabel = $Tabs/STATS/StatsOutput
@onready var tabs: TabContainer = $Tabs

var helix_renderer: HelixRenderer = HelixRenderer.new()
var stats_panel: StatsPanel = StatsPanel.new()
var life_log_panel: LifeLogPanel = LifeLogPanel.new()
var dna_engine: DNAEngine = DNAEngine.new()

var helix_game: RichTextLabel = RichTextLabel.new()
var helix_stats: RichTextLabel = RichTextLabel.new()
var splash_layer: ColorRect = ColorRect.new()
var splash_helix: RichTextLabel = RichTextLabel.new()
var splash_started: bool = false
var pregame_bits: PackedInt32Array = PackedInt32Array()

func _ready() -> void:
	_configure_input_behavior(self)
	_install_helix_ui()
	_start_or_resume_life()
	call_deferred("_focus_main_input")

func _start_or_resume_life() -> void:
	var username: String = _resolve_username()
	PlayerState.start_or_resume(username)
	output.clear()
	if PlayerState.turn == 0:
		output.append_text(PlayerState.current_opening_text())
	_append_prompt()
	_refresh_all_panels()

func _resolve_username() -> String:
	var user: String = OS.get_environment("INTAKE_USERNAME").strip_edges()
	if user.is_empty():
		user = OS.get_environment("USER").strip_edges()
	if user.is_empty():
		user = OS.get_environment("USERNAME").strip_edges()
	if user.is_empty():
		user = "Player"
	return user

func _submit_current_input() -> void:
	var command: String = input.text.strip_edges()
	if command.is_empty():
		command = "wait"
	output.append_text("\n> %s" % command)
	var turn_result: Dictionary = PlayerState.apply_action(command)
	output.append_text("\n%s" % str(turn_result.get("text", "")))
	var condition_value: Variant = turn_result.get("possible_condition", null)
	if condition_value != null:
		output.append_text("\n[color=#ff4a4a]Condition acquired: %s[/color]" % str(condition_value))
	_append_prompt()
	_refresh_all_panels()
	input.clear()
	_focus_main_input()

func _append_prompt() -> void:
	output.append_text("\n%s" % ("What do you attempt next? [Turn %d]" % PlayerState.turn))

func _refresh_all_panels() -> void:
	_refresh_life_log()
	stats_output.text = stats_panel.render(PlayerState.get_state())
	_render_helix()

func _refresh_life_log() -> void:
	for child: Node in life_log_content.get_children():
		if child != life_log_placeholder:
			child.queue_free()
	var entries: Array[String] = life_log_panel.build_entries(PlayerState.get_state().get("life_log", []))
	life_log_placeholder.visible = entries.is_empty()
	for line: String in entries:
		var label: Label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = line
		life_log_content.add_child(label)
	var scroll: ScrollContainer = $Tabs/GAME/GameLayout/GameSplit/LifeLogPanel/LifeLogScroll
	scroll.scroll_vertical = 1000000

func _render_helix() -> void:
	var bits_to_render: PackedInt32Array = pregame_bits
	var mutation_indices: Array[int] = []
	var frame: int = 0
	if splash_started:
		bits_to_render = PlayerState.dna_bits
		mutation_indices = PlayerState.mutated_bit_indices
		frame = PlayerState.turn
	var helix: String = helix_renderer.render(bits_to_render, mutation_indices, frame)
	helix_game.text = helix
	helix_stats.text = helix
	splash_helix.text = helix

func _on_submit_pressed() -> void:
	_submit_current_input()

func _on_input_text_submitted(_new_text: String) -> void:
	_submit_current_input()

func _focus_main_input() -> void:
	input.grab_focus()
	input.caret_column = input.text.length()

func _configure_input_behavior(root: Node) -> void:
	if root is Control:
		var control: Control = root as Control
		if _is_interactive_control(root):
			control.mouse_filter = Control.MOUSE_FILTER_STOP
			control.focus_mode = Control.FOCUS_ALL
		else:
			control.mouse_filter = Control.MOUSE_FILTER_PASS
			control.focus_mode = Control.FOCUS_NONE
	for child: Node in root.get_children():
		_configure_input_behavior(child)

func _is_interactive_control(node: Node) -> bool:
	return node is TabContainer or node is BaseButton or node is LineEdit

func _install_helix_ui() -> void:
	pregame_bits = dna_engine.generate(int(Time.get_unix_time_from_system()))

	helix_game = RichTextLabel.new()
	helix_game.bbcode_enabled = true
	helix_game.scroll_active = false
	helix_game.fit_content = true
	$Tabs/GAME/GameLayout.add_child(helix_game)
	$Tabs/GAME/GameLayout.move_child(helix_game, 1)

	helix_stats = RichTextLabel.new()
	helix_stats.bbcode_enabled = true
	helix_stats.scroll_active = true
	helix_stats.custom_minimum_size = Vector2(0, 240)
	$Tabs/STATS.add_child(helix_stats)
	$Tabs/STATS.move_child(helix_stats, 0)

	splash_layer = ColorRect.new()
	splash_layer.color = Color(0, 0, 0, 0.92)
	splash_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(splash_layer)

	var title: Label = Label.new()
	title.text = "INTAKE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 24
	title.offset_bottom = 100
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(0.78, 0.32, 0.9, 1))
	splash_layer.add_child(title)

	splash_helix = RichTextLabel.new()
	splash_helix.bbcode_enabled = true
	splash_helix.set_anchors_preset(Control.PRESET_CENTER)
	splash_helix.custom_minimum_size = Vector2(540, 300)
	splash_layer.add_child(splash_helix)

	var click_note: Label = Label.new()
	click_note.text = "Tap / Click to begin"
	click_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	click_note.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	click_note.offset_top = -60
	click_note.offset_bottom = -20
	click_note.add_theme_color_override("font_color", Color(0.78, 0.32, 0.9, 1))
	splash_layer.add_child(click_note)

	splash_layer.gui_input.connect(_on_splash_input)
	tabs.visible = false
	_render_helix()

func _on_splash_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_activate_game_ui()
	elif event is InputEventScreenTouch and event.pressed:
		_activate_game_ui()

func _activate_game_ui() -> void:
	splash_started = true
	splash_layer.hide()
	tabs.visible = true
	_render_helix()
	_focus_main_input()
