extends CanvasLayer

signal dialog_finished
signal action_triggered(action_name: String)

var current_script: Array = []
var current_index: int = 0
var is_playing: bool = false
var is_typing: bool = false

@onready var main_container = $Control
@onready var text_label = $Control/DialogBox/RichTextLabel

@onready var left_avatar = $Control/LeftAvatar
@onready var left_name = $Control/LeftAvatar/NameBox/Label
@onready var left_tex = $Control/LeftAvatar/TextureRect

@onready var right_avatar = $Control/RightAvatar
@onready var right_name = $Control/RightAvatar/NameBox/Label
@onready var right_tex = $Control/RightAvatar/TextureRect

var type_timer: Timer

func _ready() -> void:
	main_container.hide()
	
	type_timer = Timer.new()
	type_timer.wait_time = 0.05
	type_timer.timeout.connect(_on_type_timer_timeout)
	add_child(type_timer)

func play_dialog(script_data: Array) -> void:
	if is_playing:
		return
		
	current_script = script_data
	current_index = 0
	is_playing = true
	main_container.show()
	
	# Pre-load avatars for both sides so they are visible from the start
	var has_left = false
	var has_right = false
	for d in current_script:
		if d.get("side", "left") == "left" and d.has("avatar"):
			left_tex.texture = load(d["avatar"])
			left_name.text = d.get("speaker", "")
			has_left = true
		elif d.get("side", "") == "right" and d.has("avatar"):
			right_tex.texture = load(d["avatar"])
			right_name.text = d.get("speaker", "")
			has_right = true
			
	left_avatar.visible = has_left
	right_avatar.visible = has_right
	
	_show_current_line()

func _show_current_line() -> void:
	if current_index >= current_script.size():
		_end_dialog()
		return
		
	var data = current_script[current_index]
	
	# Setup UI based on side
	left_avatar.modulate = Color(0.5, 0.5, 0.5, 1)
	right_avatar.modulate = Color(0.5, 0.5, 0.5, 1)
	
	if data.get("side", "left") == "left":
		left_avatar.modulate = Color(1, 1, 1, 1)
		left_name.text = data.get("speaker", "")
		if data.has("avatar") and data["avatar"] != "":
			left_tex.texture = load(data["avatar"])
	else:
		right_avatar.modulate = Color(1, 1, 1, 1)
		right_name.text = data.get("speaker", "")
		if data.has("avatar") and data["avatar"] != "":
			right_tex.texture = load(data["avatar"])
			
	# Start typing
	text_label.text = data.get("text", "")
	text_label.visible_characters = 0
	is_typing = true
	type_timer.start()
	
	if data.has("action") and data["action"] != "":
		action_triggered.emit(data["action"])

func _on_type_timer_timeout() -> void:
	if text_label.visible_characters < text_label.get_total_character_count():
		text_label.visible_characters += 1
	else:
		is_typing = false
		type_timer.stop()

func _unhandled_input(event: InputEvent) -> void:
	if not is_playing:
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
			_advance_dialog()
			
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_advance_dialog()

func _advance_dialog() -> void:
	if is_typing:
		# Finish typing immediately
		text_label.visible_characters = -1
		is_typing = false
		type_timer.stop()
	else:
		# Next line
		current_index += 1
		_show_current_line()

func _end_dialog() -> void:
	is_playing = false
	main_container.hide()
	dialog_finished.emit()
