extends CanvasLayer

var dragging: bool = false
var drag_start_mouse: Vector2
var drag_start_pos: Vector2
var panel: Panel
var equip_slots: Dictionary = {}
var stat_labels: Dictionary = {}

func _ready() -> void:
	layer = 110
	_build_ui()
	_refresh_equipment_slots()
	GlobalBattleData.equipment_changed.connect(_refresh_equipment_slots)

func _build_ui() -> void:
	# 浮動視窗面板 (直立長條型)
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(400, 920) # 再次拉高以容納下方獨立出來的至寶格子
	# 預設放置在畫面左上方
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(50, 20) # 確保絕對不會被截斷
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
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)
	
	var window_title = Label.new()
	window_title.text = "角色狀態"
	window_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	window_title.add_theme_font_size_override("font_size", 24)
	window_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(window_title)
	
	# === 上方：角色半身圖與裝備 ===
	var portrait_bg = ColorRect.new()
	portrait_bg.color = Color(0.1, 0.1, 0.1, 0.8)
	portrait_bg.custom_minimum_size = Vector2(0, 420) # 高度增加以包含下方至寶
	portrait_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(portrait_bg)
	
	var portrait_vbox = VBoxContainer.new()
	portrait_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_vbox.add_theme_constant_override("separation", 0)
	portrait_bg.add_child(portrait_vbox)
	
	var image_container = Control.new()
	image_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_vbox.add_child(image_container)
	
	var portrait_tex = load("res://Images/Characters/character_1.png")
	if not portrait_tex:
		portrait_tex = load("res://icon.svg")
		
	var portrait = TextureRect.new()
	portrait.texture = portrait_tex
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_container.add_child(portrait)
	
	# === 左右兩側裝備格子層 (覆蓋在圖片上) ===
	var equip_margin = MarginContainer.new()
	equip_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	equip_margin.add_theme_constant_override("margin_left", 10)
	equip_margin.add_theme_constant_override("margin_right", 10)
	equip_margin.add_theme_constant_override("margin_top", 10)
	equip_margin.add_theme_constant_override("margin_bottom", 10)
	equip_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_container.add_child(equip_margin)
	
	var left_equips = VBoxContainer.new()
	left_equips.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_equips.alignment = BoxContainer.ALIGNMENT_CENTER
	left_equips.add_theme_constant_override("separation", 10)
	left_equips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equip_margin.add_child(left_equips)
	
	var right_equips = VBoxContainer.new()
	right_equips.size_flags_horizontal = Control.SIZE_SHRINK_END
	right_equips.alignment = BoxContainer.ALIGNMENT_CENTER
	right_equips.add_theme_constant_override("separation", 10)
	right_equips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equip_margin.add_child(right_equips)
	
	var left_slots = ["武器1", "護甲", "鞋子"]
	for s in left_slots:
		left_equips.add_child(_create_equip_slot(s))
		
	var right_slots = ["武器2", "符祿", "周圓"]
	for s in right_slots:
		right_equips.add_child(_create_equip_slot(s))
		
	# === 底部至寶格子層 (在圖片正下方，但仍在黑底內) ===
	var bottom_equips_margin = MarginContainer.new()
	bottom_equips_margin.add_theme_constant_override("margin_top", 10)
	bottom_equips_margin.add_theme_constant_override("margin_bottom", 15)
	portrait_vbox.add_child(bottom_equips_margin)
	
	var bottom_equips = HBoxContainer.new()
	bottom_equips.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_equips.add_theme_constant_override("separation", 20)
	bottom_equips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_equips_margin.add_child(bottom_equips)
	
	var bottom_slots = ["至寶1", "至寶2", "至寶3"]
	for s in bottom_slots:
		bottom_equips.add_child(_create_equip_slot(s))

	# 人物名稱標籤
	var name_lbl = Label.new()
	name_lbl.text = "主角"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var shadow = LabelSettings.new()
	shadow.shadow_color = Color(0, 0, 0, 1)
	shadow.shadow_size = 4
	shadow.font_size = 30
	name_lbl.label_settings = shadow
	vbox.add_child(name_lbl)
	
	var sep1 = HSeparator.new()
	sep1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep1)
	
	# === 下方：各類詳細數值 ===
	var stats_title = Label.new()
	stats_title.text = "詳細狀態"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(stats_title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var stats_vbox = VBoxContainer.new()
	stats_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_vbox.add_theme_constant_override("separation", 15)
	scroll.add_child(stats_vbox)
	
	var stat_names = ["等級", "經驗值", "氣血 (HP)", "靈力 (MP)", "攻擊力", "防禦力", "敏捷", "心智", "暴擊率", "閃避率"]
	
	for s_name in stat_names:
		var stat_hbox = HBoxContainer.new()
		stat_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# 屬性名稱
		var lbl_name = Label.new()
		lbl_name.text = s_name
		lbl_name.add_theme_font_size_override("font_size", 18)
		lbl_name.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_hbox.add_child(lbl_name)
		
		# 屬性數值
		var lbl_val = Label.new()
		lbl_val.text = "0"
		lbl_val.add_theme_font_size_override("font_size", 18)
		lbl_val.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_hbox.add_child(lbl_val)
		
		stat_labels[s_name] = lbl_val
		stats_vbox.add_child(stat_hbox)

	if GlobalBattleData.ui_window_positions.has("CharacterStatsUI"):
		panel.position = GlobalBattleData.ui_window_positions["CharacterStatsUI"]

func _create_equip_slot(slot_name: String) -> Control:
	var slot_bg = ColorRect.new()
	slot_bg.set_script(load("res://Scripts/droppable_slot.gd"))
	slot_bg.slot_name = slot_name
	slot_bg.custom_minimum_size = Vector2(60, 60)
	slot_bg.color = Color(0.15, 0.15, 0.15, 0.9)
	
	var border = ReferenceRect.new()
	border.editor_only = false
	border.border_color = Color(0.6, 0.6, 0.6)
	border.border_width = 2
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_bg.add_child(border)
	
	var lbl = Label.new()
	lbl.name = "ItemLabel"
	lbl.text = slot_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_bg.add_child(lbl)
	
	equip_slots[slot_name] = slot_bg
	slot_bg.gui_input.connect(_on_slot_gui_input.bind(slot_bg))
	
	return slot_bg

func _on_slot_gui_input(event: InputEvent, slot_node: Control) -> void:
	if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		if not slot_node.current_item.is_empty():
			DatabaseManager.unequip_item(slot_node.current_item["char_equip_id"])

func _get_item_tooltip(item: Dictionary) -> String:
	if item.is_empty(): return ""
	var txt = "[" + item.get("name", "未知") + "]\n"
	var type_name = item.get("type", "未知")
	if type_name == "weapon": type_name = "武器"
	elif type_name == "armor": type_name = "護甲"
	elif type_name == "shoes": type_name = "鞋子"
	elif type_name == "talisman": type_name = "符祿"
	elif type_name == "zhou_yuan": type_name = "周圓"
	elif type_name == "treasure": type_name = "至寶"
	
	txt += "類型: " + type_name + "\n"
	txt += "----------------\n"
	var has_stats = false
	if item.get("bonus_hp", 0) > 0: txt += "氣血: +" + str(item["bonus_hp"]) + "\n"; has_stats = true
	if item.get("bonus_mp", 0) > 0: txt += "靈力: +" + str(item["bonus_mp"]) + "\n"; has_stats = true
	if item.get("bonus_attack", 0) > 0: txt += "攻擊: +" + str(item["bonus_attack"]) + "\n"; has_stats = true
	if item.get("bonus_defense", 0) > 0: txt += "防禦: +" + str(item["bonus_defense"]) + "\n"; has_stats = true
	if item.get("bonus_agility", 0) > 0: txt += "敏捷: +" + str(item["bonus_agility"]) + "\n"; has_stats = true
	if item.get("bonus_mind", 0) > 0: txt += "心智: +" + str(item["bonus_mind"]) + "\n"; has_stats = true
	if not has_stats: txt += "無提供數值加成\n"
	txt += "----------------\n"
	txt += item.get("description", "沒有描述。")
	return txt

func _color_stat(lbl: Label, total: int, base: int) -> void:
	if total > base:
		lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2)) # 綠色代表有裝備加成
	else:
		lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2)) # 預設金色

func _refresh_equipment_slots() -> void:
	for s_name in equip_slots:
		var slot_node = equip_slots[s_name]
		slot_node.current_item = {}
		slot_node.tooltip_text = ""
		slot_node.get_node("ItemLabel").text = s_name
		slot_node.get_node("ItemLabel").add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	
	var p_stats = GlobalBattleData.get_player_stats()
	var base_hp = p_stats["base_hp"]
	var base_mp = p_stats["base_mp"]
	var base_atk = p_stats["base_atk"]
	var base_def = p_stats["base_def"]
	var base_agi = p_stats["base_agi"]
	var base_mind = p_stats["base_mind"]
	var total_hp = p_stats["total_hp"]
	var total_mp = p_stats["total_mp"]
	var total_atk = p_stats["total_atk"]
	var total_def = p_stats["total_def"]
	var total_agi = p_stats["total_agi"]
	var total_mind = p_stats["total_mind"]
	var total_crit = p_stats["total_crit"]
	var total_dodge = p_stats["total_dodge"]
	
	var all_equipments = DatabaseManager.get_character_equipments("player")
	for eq in all_equipments:
		if eq["equipped_slot"] != null and str(eq["equipped_slot"]) != "":
			var s_name = str(eq["equipped_slot"])
			if equip_slots.has(s_name):
				var slot_node = equip_slots[s_name]
				slot_node.current_item = eq
				slot_node.tooltip_text = _get_item_tooltip(eq)
				slot_node.get_node("ItemLabel").text = eq["name"]
				slot_node.get_node("ItemLabel").add_theme_color_override("font_color", Color(1, 0.8, 0.2))
				
	# 更新 UI 數值
	if stat_labels.has("等級"): stat_labels["等級"].text = "10"
	if stat_labels.has("經驗值"): stat_labels["經驗值"].text = "120 / 1000"
	if stat_labels.has("氣血 (HP)"): 
		stat_labels["氣血 (HP)"].text = str(total_hp) + " / " + str(total_hp)
		_color_stat(stat_labels["氣血 (HP)"], total_hp, base_hp)
	if stat_labels.has("靈力 (MP)"): 
		stat_labels["靈力 (MP)"].text = str(total_mp) + " / " + str(total_mp)
		_color_stat(stat_labels["靈力 (MP)"], total_mp, base_mp)
	if stat_labels.has("攻擊力"): 
		stat_labels["攻擊力"].text = str(total_atk)
		_color_stat(stat_labels["攻擊力"], total_atk, base_atk)
	if stat_labels.has("防禦力"): 
		stat_labels["防禦力"].text = str(total_def)
		_color_stat(stat_labels["防禦力"], total_def, base_def)
	if stat_labels.has("敏捷"): 
		stat_labels["敏捷"].text = str(total_agi)
		_color_stat(stat_labels["敏捷"], total_agi, base_agi)
	if stat_labels.has("心智"): 
		stat_labels["心智"].text = str(total_mind)
		_color_stat(stat_labels["心智"], total_mind, base_mind)
	if stat_labels.has("暴擊率"): stat_labels["暴擊率"].text = str(total_crit) + "%"
	if stat_labels.has("閃避率"): stat_labels["閃避率"].text = str(total_dodge) + "%"

func _exit_tree() -> void:
	if panel:
		GlobalBattleData.ui_window_positions["CharacterStatsUI"] = panel.position
		DatabaseManager.save_ui_window_position("CharacterStatsUI", panel.position)

func _close() -> void:
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
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
