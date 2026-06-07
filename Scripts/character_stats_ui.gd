extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build_ui()

func _build_ui() -> void:
	# 半透明黑背景
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 1.0)
	add_child(bg)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.size = Vector2(1920, 1080)
	
	# 外距容器，讓畫面不會貼齊邊緣
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 250)
	margin.add_theme_constant_override("margin_top", 150)
	margin.add_theme_constant_override("margin_right", 250)
	margin.add_theme_constant_override("margin_bottom", 150)
	add_child(margin)
	
	# 左右分割的主要容器
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 100)
	margin.add_child(main_hbox)
	
	# === 左半部 (人物圖 & 數值) ===
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 30)
	left_vbox.custom_minimum_size = Vector2(400, 0)
	main_hbox.add_child(left_vbox)
	
	# 左上：角色樣貌
	var portrait_tex = load("res://Images/Characters/character_1.png")
	if not portrait_tex:
		portrait_tex = load("res://icon.svg")
		
	var portrait = TextureRect.new()
	portrait.texture = portrait_tex
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(400, 400)
	left_vbox.add_child(portrait)
	
	var sep1 = HSeparator.new()
	left_vbox.add_child(sep1)
	
	# 左下：四圍數值
	var stats_title = Label.new()
	stats_title.text = "角色狀態"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_title.add_theme_font_size_override("font_size", 48)
	left_vbox.add_child(stats_title)
	
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stats_grid.add_theme_constant_override("h_separation", 60)
	stats_grid.add_theme_constant_override("v_separation", 25)
	left_vbox.add_child(stats_grid)
	
	var stats = [
		{"name": "靈力", "value": randi_range(50, 150)},
		{"name": "氣血", "value": randi_range(200, 500)},
		{"name": "敏捷", "value": randi_range(20, 80)},
		{"name": "心智", "value": randi_range(40, 120)}
	]
	
	for stat in stats:
		var lbl_name = Label.new()
		lbl_name.text = stat["name"]
		lbl_name.add_theme_font_size_override("font_size", 48)
		lbl_name.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
		stats_grid.add_child(lbl_name)
		
		var lbl_val = Label.new()
		lbl_val.text = str(stat["value"])
		lbl_val.add_theme_font_size_override("font_size", 48)
		lbl_val.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		stats_grid.add_child(lbl_val)
		
	# === 中間分隔線 ===
	var vsep = VSeparator.new()
	main_hbox.add_child(vsep)
	
	# === 右半部 (背包欄位) ===
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 20)
	main_hbox.add_child(right_vbox)
	
	var inv_title = Label.new()
	inv_title.text = "背包欄位"
	inv_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inv_title.add_theme_font_size_override("font_size", 48)
	right_vbox.add_child(inv_title)
	
	var inv_scroll = ScrollContainer.new()
	inv_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(inv_scroll)
	
	var inv_grid = GridContainer.new()
	inv_grid.columns = 6
	inv_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_grid.add_theme_constant_override("h_separation", 15)
	inv_grid.add_theme_constant_override("v_separation", 15)
	inv_scroll.add_child(inv_grid)
	
	# 產生 30 個空格子作為背包預覽
	for i in range(30):
		var slot_bg = ColorRect.new()
		slot_bg.custom_minimum_size = Vector2(110, 110)
		slot_bg.color = Color(0.2, 0.2, 0.2, 0.8)
		
		var slot_border = ReferenceRect.new()
		slot_border.editor_only = false
		slot_border.border_color = Color(0.4, 0.4, 0.4)
		slot_border.border_width = 2
		slot_border.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot_bg.add_child(slot_border)
		
		var idx_label = Label.new()
		idx_label.text = str(i+1)
		idx_label.add_theme_font_size_override("font_size", 24)
		idx_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		idx_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		idx_label.position = Vector2(80, 85)
		slot_bg.add_child(idx_label)
		
		inv_grid.add_child(slot_bg)
		
	# 關閉按鈕
	var btn_close = Button.new()
	btn_close.text = "關閉"
	btn_close.custom_minimum_size = Vector2(250, 80)
	btn_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn_close.add_theme_font_size_override("font_size", 48)
	btn_close.pressed.connect(_on_close_pressed)
	right_vbox.add_child(btn_close)

func _on_close_pressed() -> void:
	get_tree().paused = false
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()
