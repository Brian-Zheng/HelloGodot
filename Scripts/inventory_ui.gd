extends CanvasLayer

var dragging: bool = false
var drag_start_mouse: Vector2
var drag_start_pos: Vector2
var panel: Panel
var grid: GridContainer
var current_tab: String = "全部"

func _ready() -> void:
	layer = 110
	_build_ui()
	GlobalBattleData.equipment_changed.connect(_refresh_slots)

func _build_ui() -> void:
	# 建立主面板
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(640, 480)
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
	
	# 背包標題
	var title = Label.new()
	title.text = "角色背包"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)
	
	# 分頁按鈕區域
	var tabs_hbox = HBoxContainer.new()
	tabs_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_hbox.add_theme_constant_override("separation", 10)
	tabs_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tabs_hbox)
	
	var categories = ["全部", "裝備", "丹藥", "道具", "其他"]
	for cat in categories:
		var btn = Button.new()
		btn.text = cat
		btn.add_theme_font_size_override("font_size", 18)
		btn.custom_minimum_size = Vector2(80, 40)
		btn.pressed.connect(_on_tab_pressed.bind(cat))
		tabs_hbox.add_child(btn)
	
	var sep = HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)
	
	# 滾動區域與網格
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	grid = GridContainer.new()
	grid.columns = 8 # 格子縮小，一行可以塞 8 格
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	
	if GlobalBattleData.ui_window_positions.has("InventoryUI"):
		panel.position = GlobalBattleData.ui_window_positions["InventoryUI"]

	_refresh_slots()

func _exit_tree() -> void:
	if panel:
		GlobalBattleData.ui_window_positions["InventoryUI"] = panel.position
		DatabaseManager.save_ui_window_position("InventoryUI", panel.position)

func _on_tab_pressed(tab_name: String) -> void:
	current_tab = tab_name
	_refresh_slots()

func _matches_tab(type: String, tab: String) -> bool:
	if tab == "裝備" and type in ["weapon", "armor", "shoes", "talisman", "zhou_yuan", "treasure"]: return true
	if tab == "丹藥" and type == "potion": return true
	if tab == "道具" and type == "item": return true
	if tab == "其他" and type == "misc": return true
	return false

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

func _refresh_slots() -> void:
	# 清空現有格子
	for child in grid.get_children():
		child.queue_free()
		
	# 從資料庫取得該角色的裝備
	var all_equipments = DatabaseManager.get_character_equipments("player")
	var inventory_items = []
	for eq in all_equipments:
		# 沒有裝備在身上的才顯示在背包
		if eq["equipped_slot"] == null or str(eq["equipped_slot"]) == "":
			if current_tab == "全部" or _matches_tab(eq["type"], current_tab):
				inventory_items.append(eq)
		
	# 產生 48 個背包格子
	for i in range(48):
		var slot_bg = ColorRect.new()
		slot_bg.set_script(load("res://Scripts/draggable_slot.gd"))
		slot_bg.custom_minimum_size = Vector2(60, 60)
		slot_bg.color = Color(0.2, 0.2, 0.2, 0.8)
		
		var slot_border = ReferenceRect.new()
		slot_border.editor_only = false
		slot_border.border_color = Color(0.4, 0.4, 0.4)
		slot_border.border_width = 2
		slot_border.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_bg.add_child(slot_border)
		
		if i < inventory_items.size():
			var item = inventory_items[i]
			slot_bg.item_data = item
			
			var name_lbl = Label.new()
			name_lbl.text = item["name"]
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			name_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
			name_lbl.add_theme_font_size_override("font_size", 12)
			name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_bg.add_child(name_lbl)
			
			slot_bg.tooltip_text = _get_item_tooltip(item)
			
			slot_bg.gui_input.connect(_on_slot_gui_input.bind(item))
		
		grid.add_child(slot_bg)

func _find_empty_slot_for(type: String) -> String:
	var possible_slots = []
	if type == "weapon": possible_slots = ["武器1", "武器2"]
	elif type == "armor": possible_slots = ["護甲"]
	elif type == "shoes": possible_slots = ["鞋子"]
	elif type == "talisman": possible_slots = ["符祿"]
	elif type == "zhou_yuan": possible_slots = ["周圓"]
	elif type == "treasure": possible_slots = ["至寶1", "至寶2", "至寶3"]
	
	var equipped = DatabaseManager.get_character_equipments("player")
	var used_slots = []
	for eq in equipped:
		if eq["equipped_slot"] != null and str(eq["equipped_slot"]) != "":
			used_slots.append(str(eq["equipped_slot"]))
			
	for s in possible_slots:
		if not s in used_slots:
			return s
			
	if possible_slots.size() > 0:
		return possible_slots[0]
	return ""

func _on_slot_gui_input(event: InputEvent, item: Dictionary) -> void:
	if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		var target_slot = _find_empty_slot_for(item["type"])
		if target_slot != "":
			DatabaseManager.equip_item(item["char_equip_id"], target_slot)

func _close() -> void:
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_B:
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
