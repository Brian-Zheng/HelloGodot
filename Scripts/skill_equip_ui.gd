extends CanvasLayer

var all_skills: Array[Dictionary] = []
var equipped_skills: Array[String] = []

# UI 參考
var slots_container: VBoxContainer
var skills_container: VBoxContainer
var msg_label: Label
var popup_equip: PopupMenu
var popup_unequip: PopupMenu

var target_skill_id: String = ""
var target_slot_idx: int = -1

func _ready() -> void:
	# 暫停遊戲，避免背景繼續運作
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	_load_data()
	_build_ui()
	_refresh_ui()

func _load_data() -> void:
	all_skills = DatabaseManager.get_all_skills()
	var current_eq = DatabaseManager.get_character_skills("player")
	
	# 初始化 6 格
	equipped_skills.resize(6)
	for i in range(6):
		if i < current_eq.size():
			equipped_skills[i] = current_eq[i]
		else:
			equipped_skills[i] = ""

func _build_ui() -> void:
	# 背景
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	add_child(bg)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.size = Vector2(1920, 1080)
	
	# 標題
	var title = Label.new()
	title.text = "招式配置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position.y = 60
	title.add_theme_font_size_override("font_size", 48)
	add_child(title)
	
	# 訊息提示
	msg_label = Label.new()
	msg_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	msg_label.position.y = 130
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	msg_label.add_theme_font_size_override("font_size", 36)
	add_child(msg_label)

	# 主分割區域
	var hbox = HBoxContainer.new()
	hbox.position = Vector2(200, 220)
	hbox.size = Vector2(1520, 620)
	hbox.custom_minimum_size = Vector2(1520, 620)
	hbox.add_theme_constant_override("separation", 80)
	add_child(hbox)
	
	# 左側：已裝備的 6 格
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(400, 0)
	left_vbox.add_theme_constant_override("separation", 20)
	hbox.add_child(left_vbox)
	
	var left_title = Label.new()
	left_title.text = "已配置招式 (右鍵卸下)"
	left_title.add_theme_font_size_override("font_size", 24)
	left_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	left_vbox.add_child(left_title)
	
	slots_container = VBoxContainer.new()
	slots_container.add_theme_constant_override("separation", 10)
	left_vbox.add_child(slots_container)
	
	for i in range(6):
		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(400, 75)
		slot_btn.add_theme_font_size_override("font_size", 36)
		slot_btn.button_mask = MOUSE_BUTTON_MASK_RIGHT
		slot_btn.gui_input.connect(_on_slot_gui_input.bind(i))
		slots_container.add_child(slot_btn)
		
	# 右側：技能庫 (帶捲動)
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 15)
	hbox.add_child(right_vbox)
	
	var right_title = Label.new()
	right_title.text = "招式總覽 (右鍵裝備)"
	right_title.add_theme_font_size_override("font_size", 24)
	right_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6))
	right_vbox.add_child(right_title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 580)
	right_vbox.add_child(scroll)
	
	skills_container = VBoxContainer.new()
	skills_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_container.add_theme_constant_override("separation", 20)
	scroll.add_child(skills_container)
	
	# 右鍵選單
	popup_equip = PopupMenu.new()
	popup_equip.add_theme_font_size_override("font_size", 24)
	popup_equip.add_item("裝備", 0)
	popup_equip.id_pressed.connect(_on_popup_equip_pressed)
	add_child(popup_equip)
	
	popup_unequip = PopupMenu.new()
	popup_unequip.add_theme_font_size_override("font_size", 24)
	popup_unequip.add_item("卸下", 0)
	popup_unequip.id_pressed.connect(_on_popup_unequip_pressed)
	add_child(popup_unequip)
	
	# 底部儲存按鈕
	var btn_save = Button.new()
	btn_save.text = "儲存並關閉"
	btn_save.position = Vector2(860, 920)
	btn_save.size = Vector2(200, 60)
	btn_save.add_theme_font_size_override("font_size", 36)
	btn_save.pressed.connect(_on_save_pressed)
	add_child(btn_save)

func _refresh_ui() -> void:
	# 1. 刷新左側 6 格
	for i in range(6):
		var btn = slots_container.get_child(i) as Button
		var sid = equipped_skills[i]
		if sid == "":
			btn.text = "格 " + str(i+1) + " :  (空)"
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			var skill_data = DatabaseManager.get_skill(sid)
			btn.text = "格 " + str(i+1) + " :  " + (skill_data["name"] if skill_data else sid)
			btn.add_theme_color_override("font_color", Color(1, 1, 1))
			
	# 2. 刷新右側分類技能庫
	for child in skills_container.get_children():
		child.queue_free()
		
	var categories = ["攻擊", "閃避", "格檔", "斷檔", "移動", "效果"]
	for cat in categories:
		var cat_skills = all_skills.filter(func(s): return s.get("category", "") == cat)
		if cat_skills.size() == 0: continue
		
		# 分類標題
		var cat_label = Label.new()
		cat_label.text = "【 " + cat + " 】"
		cat_label.add_theme_font_size_override("font_size", 24)
		cat_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		skills_container.add_child(cat_label)
		
		# 該分類下的招式按鈕網格
		var grid = GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 15)
		grid.add_theme_constant_override("v_separation", 15)
		skills_container.add_child(grid)
		
		for s in cat_skills:
			var btn = Button.new()
			# 顯示名稱與關鍵數值
			var dmg = s.get("damage", 0)
			var chant = s.get("chant_turns", 0)
			var info = s["name"]
			if dmg > 0: info += " (傷:" + str(dmg) + ")"
			if chant > 0: info += " (詠:" + str(chant) + ")"
			
			btn.text = info
			btn.custom_minimum_size = Vector2(240, 50)
			btn.add_theme_font_size_override("font_size", 24)
			btn.button_mask = MOUSE_BUTTON_MASK_RIGHT
			
			# 如果這個招式已經裝在身上，稍微反灰標示
			if equipped_skills.has(s["skill_id"]):
				btn.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
				btn.text += " [已裝備]"
				
			btn.gui_input.connect(_on_skill_list_gui_input.bind(s["skill_id"]))
			grid.add_child(btn)

# --- 互動邏輯 ---

func _on_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if equipped_skills[slot_idx] != "":
			target_slot_idx = slot_idx
			popup_unequip.position = get_viewport().get_mouse_position()
			popup_unequip.popup()

func _on_skill_list_gui_input(event: InputEvent, skill_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# 只有沒被裝備的才能按右鍵裝備 (看您的需求，這裡先不鎖死，讓玩家可以重複裝備同一招)
		target_skill_id = skill_id
		popup_equip.position = get_viewport().get_mouse_position()
		popup_equip.popup()

func _on_popup_equip_pressed(id: int) -> void:
	msg_label.text = ""
	var empty_idx = -1
	for i in range(6):
		if equipped_skills[i] == "":
			empty_idx = i
			break
	
	if empty_idx == -1:
		msg_label.text = "裝備欄已滿！請先在左側對著技能按右鍵卸下。"
	else:
		equipped_skills[empty_idx] = target_skill_id
		_refresh_ui()

func _on_popup_unequip_pressed(id: int) -> void:
	msg_label.text = ""
	if target_slot_idx != -1:
		equipped_skills[target_slot_idx] = ""
		_refresh_ui()

func _on_save_pressed() -> void:
	# 收集非空的招式寫入資料庫
	var final_skills: Array[String] = []
	for sid in equipped_skills:
		if sid != "":
			final_skills.append(sid)
			
	DatabaseManager.save_character_skills("player", final_skills)
	get_tree().paused = false
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_save_pressed()
			get_viewport().set_input_as_handled()
