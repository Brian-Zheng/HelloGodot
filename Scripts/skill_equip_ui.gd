extends CanvasLayer

var all_skills: Array[Dictionary] = []
var equipped_skills: Array[String] = []

var dragging: bool = false
var drag_start_mouse: Vector2
var drag_start_pos: Vector2

var panel: Panel
var slots_container: VBoxContainer
var skills_container: VBoxContainer
var msg_label: Label
var popup_unequip: PopupMenu

var current_tab: String = "攻擊"
var target_slot_idx: int = -1

func _ready() -> void:
	layer = 110
	_load_data()
	_build_ui()
	_refresh_ui()

func _load_data() -> void:
	all_skills = DatabaseManager.get_all_skills()
	equipped_skills = DatabaseManager.get_character_skills("player")

func _build_ui() -> void:
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(800, 560)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 1.0) # Solid dark background
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	panel.gui_input.connect(_on_panel_gui_input)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 15)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "技能介面"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)
	
	msg_label = Label.new()
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	vbox.add_child(msg_label)
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 30)
	vbox.add_child(hbox)
	
	# 左側 (已裝備)
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(300, 0)
	left_vbox.add_theme_constant_override("separation", 10)
	hbox.add_child(left_vbox)
	
	var left_title = Label.new()
	left_title.text = "已裝備技能 (右鍵卸下)"
	left_title.add_theme_font_size_override("font_size", 18)
	left_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	left_vbox.add_child(left_title)
	
	slots_container = VBoxContainer.new()
	slots_container.add_theme_constant_override("separation", 8)
	left_vbox.add_child(slots_container)
	
	for i in range(6):
		var slot_btn = Button.new()
		slot_btn.set_script(load("res://Scripts/skill_droppable_slot.gd"))
		slot_btn.slot_idx = i
		slot_btn.main_ui = self
		slot_btn.custom_minimum_size = Vector2(300, 50)
		slot_btn.add_theme_font_size_override("font_size", 20)
		slot_btn.button_mask = MOUSE_BUTTON_MASK_RIGHT
		slot_btn.gui_input.connect(_on_slot_gui_input.bind(i))
		slots_container.add_child(slot_btn)
		
	# 右側 (技能庫)
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 10)
	hbox.add_child(right_vbox)
	
	var tabs_hbox = HBoxContainer.new()
	tabs_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_hbox.add_theme_constant_override("separation", 10)
	right_vbox.add_child(tabs_hbox)
	
	var categories = ["攻擊", "閃避", "格檔", "斷檔", "移動", "效果"]
	for cat in categories:
		var btn = Button.new()
		btn.text = cat
		btn.add_theme_font_size_override("font_size", 16)
		btn.custom_minimum_size = Vector2(60, 35)
		btn.pressed.connect(_on_tab_pressed.bind(cat))
		tabs_hbox.add_child(btn)
		
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(scroll)
	
	skills_container = VBoxContainer.new()
	skills_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_container.add_theme_constant_override("separation", 8)
	scroll.add_child(skills_container)
	
	popup_unequip = PopupMenu.new()
	popup_unequip.add_theme_font_size_override("font_size", 18)
	popup_unequip.add_item("卸下", 0)
	popup_unequip.id_pressed.connect(_on_popup_unequip_pressed)
	add_child(popup_unequip)

	if GlobalBattleData.ui_window_positions.has("SkillUI"):
		panel.position = GlobalBattleData.ui_window_positions["SkillUI"]

func _get_skill_tooltip(skill_id: String) -> String:
	if skill_id == "": return ""
	var s = DatabaseManager.get_skill(skill_id)
	if not s: return ""
	
	var txt = "[" + s["name"] + "]\n"
	txt += "分類: " + s.get("category", "未知") + "\n"
	
	var dmg = s.get("damage", 0)
	if dmg > 0:
		var type = s.get("type", "")
		if type == "phys_attack" or type == "magic_attack":
			txt += "造成 " + str(dmg * 10) + "% 攻擊力傷害\n"
		else:
			txt += "固定傷害: " + str(dmg) + "\n"
			
	var chant = s.get("chant_turns", 0)
	if chant > 0:
		txt += "詠唱回合: " + str(chant) + "\n"
		
	var range_limit = s.get("range_limit", 0)
	if range_limit > 0:
		txt += "射程範圍: " + str(range_limit) + "\n"
		
	txt += "----------------\n"
	
	var has_effect = false
	if s.get("is_block", 0) == 1:
		txt += "格檔效果: 減免 " + str(int(s.get("block_ratio", 0.0)*100)) + "% 傷害\n"
		has_effect = true
	if s.get("is_interrupt", 0) == 1:
		txt += "具備斷檔能力\n"
		has_effect = true
	if s.get("grant_damage_boost", 0) > 0:
		txt += "賦予增傷: " + str(s["grant_damage_boost"]) + "\n"
		has_effect = true
	if s.get("grant_crit_rate", 0.0) > 0:
		txt += "增加暴擊機率: " + str(int(s["grant_crit_rate"]*100)) + "%\n"
		has_effect = true
	if s.get("grant_dodge_rate", 0.0) > 0:
		txt += "增加閃避機率: " + str(int(s["grant_dodge_rate"]*100)) + "%\n"
		has_effect = true
	
	if not has_effect and dmg == 0 and chant == 0:
		txt += "無特殊數值加成\n"
	
	return txt

func _refresh_ui() -> void:
	for i in range(6):
		var btn = slots_container.get_child(i)
		var sid = equipped_skills[i]
		btn.skill_id = sid
		if sid == "":
			btn.text = "格 " + str(i+1) + " :  (空)"
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			btn.tooltip_text = ""
		else:
			var skill_data = DatabaseManager.get_skill(sid)
			btn.text = "格 " + str(i+1) + " :  " + (skill_data["name"] if skill_data else sid)
			btn.add_theme_color_override("font_color", Color(1, 1, 1))
			btn.tooltip_text = _get_skill_tooltip(sid)
			
	for child in skills_container.get_children():
		child.queue_free()
		
	var cat_skills = all_skills.filter(func(s): return s.get("category", "") == current_tab)
	
	for s in cat_skills:
		var btn = Button.new()
		btn.set_script(load("res://Scripts/skill_draggable_button.gd"))
		btn.skill_id = s["skill_id"]
		
		var dmg = s.get("damage", 0)
		var chant = s.get("chant_turns", 0)
		var info = s["name"]
		var type = s.get("type", "")
		if dmg > 0:
			if type == "phys_attack" or type == "magic_attack":
				info += " (傷:" + str(dmg * 10) + "%)"
			else:
				info += " (傷:" + str(dmg) + ")"
		if chant > 0: info += " (詠:" + str(chant) + ")"
		
		btn.text = info
		btn.custom_minimum_size = Vector2(0, 45)
		btn.add_theme_font_size_override("font_size", 18)
		btn.button_mask = MOUSE_BUTTON_MASK_RIGHT
		
		if equipped_skills.has(s["skill_id"]):
			btn.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
			btn.text += " [已裝備]"
			
		btn.tooltip_text = _get_skill_tooltip(s["skill_id"])
		btn.gui_input.connect(_on_skill_list_gui_input.bind(s["skill_id"]))
		skills_container.add_child(btn)

func _on_tab_pressed(tab_name: String) -> void:
	current_tab = tab_name
	_refresh_ui()

func _on_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if equipped_skills[slot_idx] != "":
			target_slot_idx = slot_idx
			popup_unequip.position = get_viewport().get_mouse_position()
			popup_unequip.popup()
	elif event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		if equipped_skills[slot_idx] != "":
			equipped_skills[slot_idx] = ""
			DatabaseManager.save_character_skills("player", equipped_skills)
			_refresh_ui()

func _on_skill_list_gui_input(event: InputEvent, skill_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			if equipped_skills.has(skill_id):
				var idx = equipped_skills.find(skill_id)
				equipped_skills[idx] = ""
				DatabaseManager.save_character_skills("player", equipped_skills)
				_refresh_ui()
			else:
				var empty_idx = equipped_skills.find("")
				if empty_idx != -1:
					equipped_skills[empty_idx] = skill_id
					DatabaseManager.save_character_skills("player", equipped_skills)
					_refresh_ui()
				else:
					msg_label.text = "技能格已滿！請先卸下其他技能。"
		elif event.pressed:
			msg_label.text = "請直接「按住並拖曳」技能到左側格子上來裝備！\n或「左鍵雙擊」快速裝備/卸載。"

func _handle_skill_drop(data: Dictionary, target_slot_idx: int) -> void:
	msg_label.text = ""
	if data.source == "library":
		equipped_skills[target_slot_idx] = data.skill_id
	elif data.source == "slot":
		var source_idx = data.slot_idx
		var temp = equipped_skills[target_slot_idx]
		equipped_skills[target_slot_idx] = equipped_skills[source_idx]
		equipped_skills[source_idx] = temp
		
	DatabaseManager.save_character_skills("player", equipped_skills)
	_refresh_ui()

func _on_popup_unequip_pressed(id: int) -> void:
	msg_label.text = ""
	if target_slot_idx != -1:
		equipped_skills[target_slot_idx] = ""
		DatabaseManager.save_character_skills("player", equipped_skills)
		_refresh_ui()

func _exit_tree() -> void:
	if panel:
		GlobalBattleData.ui_window_positions["SkillUI"] = panel.position
		DatabaseManager.save_ui_window_position("SkillUI", panel.position)
		
	DatabaseManager.save_character_skills("player", equipped_skills)

func _close() -> void:
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_K:
			_close()
			get_viewport().set_input_as_handled()

func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_start_mouse = panel.get_global_mouse_position()
			drag_start_pos = panel.position
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		var current_mouse = panel.get_global_mouse_position()
		panel.position = drag_start_pos + (current_mouse - drag_start_mouse)
