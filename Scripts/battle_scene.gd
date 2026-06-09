extends Node2D

## 戰鬥場景腳本
## 負責：
##   1. 進場淡入動畫
##   2. 準備階段：Player 選擇行動填入格子，Enemy AI 自動填入
##   3. 結算階段：逐回合播放戰鬥與計算傷害
##   4. 「返回地圖」按鈕處理

const MAIN_SCENE := "res://Scence/mainscence.tscn"

## 淡入動畫持續秒數
const FADE_DURATION := 0.8

enum SubAction {
	NONE = -1,
	CHANT = 10,
	EXECUTE = 20,
	STUNNED = 99 # 被打斷後的發呆狀態
}

class BattleEntity:
	var hp: int = 100
	var max_hp: int = 100
	var pos: int = 0
	var damage_boost: int = 0
	var is_chanting: bool = false
	var block_active: bool = false
	var block_ratio: float = 0.0
	var crit_rate: float = 0.0
	var dodge_rate: float = 0.0
	
	func _init(p: int = 0):
		pos = p

var player_state: BattleEntity
var enemy_state: BattleEntity

# 記錄準備階段的詠唱減免
var player_setup_chant_reduction: int = 0
var enemy_setup_chant_reduction: int = 0

var player_slots: Array[int] = [-1, -1, -1, -1, -1, -1, -1, -1]
var enemy_slots: Array[int] = [-1, -1, -1, -1, -1, -1, -1, -1]
var player_slot_skills: Array[String] = ["", "", "", "", "", "", "", ""]
var enemy_slot_skills: Array[String] = ["", "", "", "", "", "", "", ""]
var player_slot_groups: Array[int] = [-1, -1, -1, -1, -1, -1, -1, -1]
var enemy_slot_groups: Array[int] = [-1, -1, -1, -1, -1, -1, -1, -1]

var player_equipped_skills: Array[String] = []
var enemy_equipped_skills: Array[String] = []

## 目前 Player 正要填入第幾格（0-indexed）
var player_current_slot: int = 0

## 行動格 Panel 節點快取
var player_slot_panels: Array[Panel] = []
var enemy_slot_panels: Array[Panel] = []
var player_action_buttons: Array[Button] = []
var _hp_warning_tween: Tween
var is_battling: bool = false


func _ready() -> void:
	player_state = BattleEntity.new(4)
	var p_stats = GlobalBattleData.get_player_stats()
	GlobalBattleData.init_current_stats_if_needed()
	player_state.max_hp = p_stats["total_hp"]
	player_state.hp = GlobalBattleData.current_hp
	
	enemy_state = BattleEntity.new(7)
	var e_stats = GlobalBattleData.get_enemy_stats()
	enemy_state.max_hp = e_stats["total_hp"]
	enemy_state.hp = e_stats["total_hp"]
	
	_cache_nodes()
	_load_character_skills()
	_setup_enemy_actions_ai()
	_refresh_all_slots()
	_highlight_current_slot()
	_highlight_execution_slots(false)
	_update_hp_ui()
	
	var e_exec_label = $PreparePhaseUI.get_node_or_null("EnemyExecutionSlot/Label")
	if e_exec_label:
		e_exec_label.text = "斬殺條件: 目標血量 <= %d" % GlobalBattleData.enemy_execution_threshold
	
	if GlobalBattleData.player_texture:
		var p_sprite = $PreparePhaseUI/CharacterArea.get_node_or_null("PlayerSprite")
		if p_sprite: p_sprite.texture = GlobalBattleData.player_texture
	if GlobalBattleData.enemy_texture:
		var e_sprite = $PreparePhaseUI/CharacterArea.get_node_or_null("EnemySprite")
		if e_sprite: e_sprite.texture = GlobalBattleData.enemy_texture
		
	_play_fade_in()

func _cache_nodes() -> void:
	var p_slots_root = $PreparePhaseUI.get_node_or_null("PlayerSlotsGrid")
	if p_slots_root:
		p_slots_root.add_theme_constant_override("h_separation", 0)
		for i in range(1, 9):
			var panel = p_slots_root.get_node("Slot_P%d" % i) as Panel
			panel.mouse_filter = Control.MOUSE_FILTER_STOP
			panel.gui_input.connect(_on_player_slot_gui_input.bind(i - 1))
			player_slot_panels.append(panel)

	var e_slots_root = $PreparePhaseUI.get_node_or_null("EnemySlotsGrid")
	if e_slots_root:
		e_slots_root.add_theme_constant_override("h_separation", 0)
		for i in range(1, 9):
			enemy_slot_panels.append(e_slots_root.get_node("Slot_E%d" % i) as Panel)

	var p_actions_root = $PreparePhaseUI.get_node_or_null("PlayerActionsGrid")
	if p_actions_root:
		var action_names_btn := ["Action_P1","Action_P2","Action_P3","Action_P4","Action_P5","Action_P6"]
		for n in action_names_btn:
			var btn = p_actions_root.get_node(n) as Button
			btn.set_script(load("res://Scripts/skill_tooltip_button.gd"))
			player_action_buttons.append(btn)

func _load_character_skills() -> void:
	player_equipped_skills = DatabaseManager.get_character_skills("player")
	
	var enemy_id = GlobalBattleData.current_enemy_name
	if enemy_id == "": enemy_id = "enemy"
	enemy_equipped_skills = DatabaseManager.get_character_skills(enemy_id)
	
	if enemy_equipped_skills.size() == 0:
		enemy_equipped_skills = DatabaseManager.get_character_skills("enemy")
	
	for i in range(player_action_buttons.size()):
		var btn = player_action_buttons[i]
		if i < player_equipped_skills.size() and player_equipped_skills[i] != "":
			var skill_id = player_equipped_skills[i]
			var skill_data = DatabaseManager.get_skill(skill_id)
			btn.text = skill_data["name"] if skill_data else skill_id
			btn.disabled = false
			btn.tooltip_text = _get_skill_tooltip(skill_id)
		else:
			btn.text = "（無）"
			btn.disabled = true
			btn.tooltip_text = ""

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

func _get_sub_actions_for(skill_id: String, is_player: bool) -> Array[int]:
	var result: Array[int] = []
	var reduction = player_setup_chant_reduction if is_player else enemy_setup_chant_reduction
	
	var skill_data = DatabaseManager.get_skill(skill_id)
	if not skill_data: return [SubAction.EXECUTE]
	
	var required_chants = skill_data.get("chant_turns", 0)
	var actual_chants = max(0, required_chants - reduction)
	var remaining_reduction = max(0, reduction - required_chants)
	
	# 加入此招式給予的後續減免
	remaining_reduction += skill_data.get("grant_chant_reduction", 0)
	
	for i in range(actual_chants):
		result.append(SubAction.CHANT)
	result.append(SubAction.EXECUTE)
	
	if is_player: player_setup_chant_reduction = remaining_reduction
	else: enemy_setup_chant_reduction = remaining_reduction
		
	return result

func _setup_enemy_actions_ai() -> void:
	enemy_setup_chant_reduction = 0
	var current_slot = 0
	var group_id = 0
	
	var enemy_id = GlobalBattleData.current_enemy_name
	if enemy_id == "": enemy_id = "enemy"
	
	var fixed_sequence = DatabaseManager.get_enemy_action_sequence(enemy_id)
	
	if fixed_sequence.size() == 0:
		fixed_sequence = DatabaseManager.get_enemy_action_sequence("enemy")
		
	for skill_id in fixed_sequence:
		if current_slot >= 8: break
			
		var sub_actions = _get_sub_actions_for(skill_id, false)
		if current_slot + sub_actions.size() > 8: continue
			
		for sa in sub_actions:
			enemy_slot_skills[current_slot] = skill_id
			enemy_slots[current_slot] = sa
			enemy_slot_groups[current_slot] = group_id
			current_slot += 1
		group_id += 1
			
	while current_slot < 8:
		enemy_slot_skills[current_slot] = "move_dodge"
		enemy_slots[current_slot] = SubAction.EXECUTE
		enemy_slot_groups[current_slot] = group_id
		current_slot += 1
		group_id += 1

func _play_fade_in() -> void:
	var overlay = $PreparePhaseUI.get_node_or_null("FadeOverlay") as ColorRect
	if not overlay: return
	
	overlay.show()
	overlay.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, FADE_DURATION)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): overlay.hide())

func _on_player_action_pressed(action_idx: int) -> void:
	if player_current_slot >= 8: return
	if action_idx >= player_equipped_skills.size(): return
		
	var skill_id = player_equipped_skills[action_idx]
	var sub_actions = _get_sub_actions_for(skill_id, true)
	if player_current_slot + sub_actions.size() > 8:
		print("[BattleScene] 剩餘行動格不足！")
		return
		
	var group_id = 0
	if player_current_slot > 0:
		group_id = player_slot_groups[player_current_slot - 1] + 1
		
	for sa in sub_actions:
		player_slot_skills[player_current_slot] = skill_id
		player_slots[player_current_slot] = sa
		player_slot_groups[player_current_slot] = group_id
		_refresh_player_slot(player_current_slot)
		player_current_slot += 1
		
	_highlight_current_slot()
	if player_current_slot >= 8:
		_set_player_buttons_enabled(false)

func _on_player_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if is_battling: return
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		var gid = player_slot_groups[slot_idx]
		if gid != -1:
			_remove_player_action_group(gid)

func _remove_player_action_group(target_gid: int) -> void:
	var skill_sequence: Array[String] = []
	var current_gid = -1
	for i in range(8):
		var g = player_slot_groups[i]
		if g != -1 and g != target_gid:
			if g != current_gid:
				skill_sequence.append(player_slot_skills[i])
				current_gid = g
				
	for i in range(8):
		player_slots[i] = SubAction.NONE
		player_slot_skills[i] = ""
		player_slot_groups[i] = -1
	player_current_slot = 0
	player_setup_chant_reduction = 0
	
	for skill_id in skill_sequence:
		var sub_actions = _get_sub_actions_for(skill_id, true)
		if player_current_slot + sub_actions.size() > 8:
			print("[BattleScene] 重新計算時行動格不足，捨棄後續技能")
			break
			
		var group_id = 0
		if player_current_slot > 0:
			group_id = player_slot_groups[player_current_slot - 1] + 1
			
		for sa in sub_actions:
			player_slot_skills[player_current_slot] = skill_id
			player_slots[player_current_slot] = sa
			player_slot_groups[player_current_slot] = group_id
			player_current_slot += 1
			
	_set_player_buttons_enabled(true)
	var start_btn = $PreparePhaseUI.get_node_or_null("StartBattleButton")
	if start_btn: start_btn.disabled = false
	
	_refresh_all_slots()
	_highlight_current_slot()

func _get_action_display_info(action: int, skill_id: String, phase_text: String = "") -> Dictionary:
	if action == SubAction.STUNNED:
		return {"icon": "😵", "name": "被打斷", "color": Color(0.5, 0.5, 0.5)}
		
	var skill_data = DatabaseManager.get_skill(skill_id)
	var cat = skill_data.get("category", "") if skill_data else ""
	var sname = skill_data.get("name", skill_id) if skill_data else skill_id
	
	if action == SubAction.CHANT:
		return {"icon": "⏳", "name": sname + "\n" + phase_text, "color": Color(0.8, 0.8, 0.8)}
		
	var color = Color(1, 1, 1)
	var icon = "⚪"
	if cat == "攻擊":
		color = Color(1.0, 0.4, 0.4)
		icon = "⚔️"
	elif cat == "閃避" or cat == "移動":
		color = Color(0.4, 0.8, 1.0)
		icon = "💨"
	elif cat == "格檔":
		color = Color(1.0, 0.8, 0.4)
		icon = "🛡️"
	elif cat == "斷檔":
		color = Color(1.0, 0.6, 0.2)
		icon = "✂️"
	elif cat == "效果":
		color = Color(0.4, 1.0, 0.6)
		icon = "✨"
		
	return {"icon": icon, "name": sname, "color": color}

func _get_phase_text(idx: int, is_player: bool) -> String:
	var groups = player_slot_groups if is_player else enemy_slot_groups
	var actions = player_slots if is_player else enemy_slots
	var gid = groups[idx]
	if gid == -1: return ""
	
	var total = 0
	var current = 0
	for i in range(8):
		if groups[i] == gid and actions[i] == SubAction.CHANT:
			total += 1
			if i <= idx: current += 1
			
	if actions[idx] == SubAction.CHANT:
		return "(詠唱 %d/%d)" % [current, total]
	elif actions[idx] == SubAction.EXECUTE:
		return "(發動)"
	return ""

func _refresh_player_slot(idx: int) -> void:
	if idx < 0 or idx >= 8 or idx >= player_slot_panels.size(): return
	var panel := player_slot_panels[idx]
	var label = panel.get_node_or_null("SlotLabel") as Label
	if not label: return
	var action := player_slots[idx]
	if action == SubAction.NONE:
		label.text = str(idx + 1)
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	else:
		var phase = _get_phase_text(idx, true)
		var info = _get_action_display_info(action, player_slot_skills[idx], phase)
		if action == SubAction.EXECUTE:
			label.text = "%s\n%s\n%s" % [info.icon, info.name, phase]
		else:
			label.text = "%s\n%s" % [info.icon, info.name]
		label.add_theme_color_override("font_color", info.color)

func _refresh_all_slots() -> void:
	for i in range(8):
		_refresh_player_slot(i)
	_refresh_enemy_slots()

func _update_hp_ui() -> void:
	var p_bar = $PreparePhaseUI/CharacterArea.get_node_or_null("PlayerHPBar")
	if p_bar:
		var p_fill = p_bar.get_node_or_null("Fill")
		if p_fill: p_fill.anchor_right = float(player_state.hp) / float(player_state.max_hp)
		var p_label = p_bar.get_node_or_null("HPLabel")
		if p_label: p_label.text = "%d / %d" % [player_state.hp, player_state.max_hp]
	
	var e_bar = $PreparePhaseUI/CharacterArea.get_node_or_null("EnemyHPBar")
	if e_bar:
		var e_fill = e_bar.get_node_or_null("Fill")
		if e_fill: e_fill.anchor_right = float(enemy_state.hp) / float(enemy_state.max_hp)
		var e_label = e_bar.get_node_or_null("HPLabel")
		if e_label: e_label.text = "%d / %d" % [enemy_state.hp, enemy_state.max_hp]

func _refresh_enemy_slots() -> void:
	for i in range(8):
		if i >= enemy_slot_panels.size(): break
		var panel := enemy_slot_panels[i]
		var label = panel.get_node_or_null("SlotLabel") as Label
		if not label: continue
		var action := enemy_slots[i]
		if action == SubAction.NONE:
			label.text = str(i + 1)
			label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		else:
			var phase = _get_phase_text(i, false)
			var info = _get_action_display_info(action, enemy_slot_skills[i], phase)
			if action == SubAction.EXECUTE:
				label.text = "%s\n%s\n%s" % [info.icon, info.name, phase]
			else:
				label.text = "%s\n%s" % [info.icon, info.name]
			label.add_theme_color_override("font_color", info.color)

func _highlight_current_slot() -> void:
	for i in range(8):
		if i >= player_slot_panels.size(): break
		var panel := player_slot_panels[i]
		var gid = player_slot_groups[i]
		
		var is_first_in_bar = (i == 0)
		var is_last_in_bar = (i == 7)
		var is_first_in_group = true
		if i > 0 and gid != -1 and player_slot_groups[i-1] == gid:
			is_first_in_group = false
		
		if i == player_current_slot:
			panel.add_theme_stylebox_override("panel", _make_slot_style(Color(0.4, 0.9, 1.0, 1.0), true, is_first_in_bar, is_last_in_bar, is_first_in_group))
		elif player_slots[i] != SubAction.NONE:
			panel.add_theme_stylebox_override("panel", _make_slot_style(Color(0.3, 0.6, 0.9, 1.0), false, is_first_in_bar, is_last_in_bar, is_first_in_group))
		else:
			panel.add_theme_stylebox_override("panel", _make_slot_style(Color(0.3, 0.3, 0.4, 1.0), false, is_first_in_bar, is_last_in_bar, is_first_in_group))

	for i in range(8):
		if i >= enemy_slot_panels.size(): break
		var panel := enemy_slot_panels[i]
		var gid = enemy_slot_groups[i]
		
		var is_first_in_bar = (i == 0)
		var is_last_in_bar = (i == 7)
		var is_first_in_group = true
		if i > 0 and gid != -1 and enemy_slot_groups[i-1] == gid:
			is_first_in_group = false
		
		if enemy_slots[i] != SubAction.NONE:
			panel.add_theme_stylebox_override("panel", _make_slot_style(Color(0.8, 0.3, 0.3, 1.0), false, is_first_in_bar, is_last_in_bar, is_first_in_group))
		else:
			panel.add_theme_stylebox_override("panel", _make_slot_style(Color(0.3, 0.3, 0.4, 1.0), false, is_first_in_bar, is_last_in_bar, is_first_in_group))
			
	_predict_execution_warning()

func _highlight_resolving_slot(idx: int) -> void:
	_highlight_current_slot()
	if idx < 8:
		if idx < player_slot_panels.size():
			var gid = player_slot_groups[idx]
			var is_first_in_bar = (idx == 0)
			var is_last_in_bar = (idx == 7)
			var is_first_in_group = true
			if idx > 0 and gid != -1 and player_slot_groups[idx-1] == gid:
				is_first_in_group = false
			player_slot_panels[idx].add_theme_stylebox_override("panel", _make_slot_style(Color(1.0, 0.8, 0.2, 1.0), true, is_first_in_bar, is_last_in_bar, is_first_in_group))
			
		if idx < enemy_slot_panels.size():
			var gid = enemy_slot_groups[idx]
			var is_first_in_bar = (idx == 0)
			var is_last_in_bar = (idx == 7)
			var is_first_in_group = true
			if idx > 0 and gid != -1 and enemy_slot_groups[idx-1] == gid:
				is_first_in_group = false
			enemy_slot_panels[idx].add_theme_stylebox_override("panel", _make_slot_style(Color(1.0, 0.8, 0.2, 1.0), true, is_first_in_bar, is_last_in_bar, is_first_in_group))

func _highlight_execution_slots(active: bool) -> void:
	var p_exec_slot = $PreparePhaseUI.get_node_or_null("PlayerExecutionSlot")
	var e_exec_slot = $PreparePhaseUI.get_node_or_null("EnemyExecutionSlot")
	if not p_exec_slot or not e_exec_slot: return
	
	if active:
		p_exec_slot.add_theme_stylebox_override("panel", _make_slot_style(Color(1.0, 0.8, 0.2, 1.0), true, true, true, true))
		e_exec_slot.add_theme_stylebox_override("panel", _make_slot_style(Color(1.0, 0.8, 0.2, 1.0), true, true, true, true))
	else:
		p_exec_slot.add_theme_stylebox_override("panel", _make_slot_style(Color(0.3, 0.3, 0.4, 1.0), false, true, true, true))
		e_exec_slot.add_theme_stylebox_override("panel", _make_slot_style(Color(0.3, 0.3, 0.4, 1.0), false, true, true, true))

func _make_warning_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.1, 0.1, 1.0)
	style.border_color = Color(1.0, 0.2, 0.2, 1.0)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	return style

func _predict_execution_warning() -> void:
	var total_predicted_dmg = 0
	var enemy_stats = GlobalBattleData.get_enemy_stats()
	var atk_stat = enemy_stats.get("total_atk", 0)
	
	for i in range(8):
		if enemy_slots[i] == SubAction.EXECUTE:
			var skill_id = enemy_slot_skills[i]
			var skill_data = DatabaseManager.get_skill(skill_id)
			if skill_data:
				var type = skill_data.get("type", "phys_attack")
				var base_dmg = skill_data.get("damage", 0)
				var final_base_dmg = 0
				if type == "phys_attack" or type == "magic_attack":
					var percentage = base_dmg * 10.0 / 100.0
					final_base_dmg = int(atk_stat * percentage)
				else:
					final_base_dmg = base_dmg
				total_predicted_dmg += final_base_dmg
				
	var p_max_hp = GlobalBattleData.get_player_stats().get("total_hp", 100)
	var current_hp = player_state.hp if player_state else p_max_hp
	var predicted_hp = current_hp - total_predicted_dmg
	var is_danger = predicted_hp <= GlobalBattleData.enemy_execution_threshold
	
	var e_exec_slot = $PreparePhaseUI.get_node_or_null("EnemyExecutionSlot")
	var p_hp_bar_fill = $PreparePhaseUI/CharacterArea/PlayerHPBar/Fill
	var e_exec_label = $PreparePhaseUI.get_node_or_null("EnemyExecutionSlot/Label")
	
	if is_danger:
		if e_exec_slot:
			e_exec_slot.add_theme_stylebox_override("panel", _make_warning_style())
		if e_exec_label:
			e_exec_label.text = "⚠️ 警告: 將觸發斬殺 ( 血量 <= %d )" % GlobalBattleData.enemy_execution_threshold
			e_exec_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
			
		if _hp_warning_tween and _hp_warning_tween.is_valid():
			_hp_warning_tween.kill()
		_hp_warning_tween = create_tween().set_loops()
		_hp_warning_tween.tween_property(p_hp_bar_fill, "color", Color(1.0, 0.0, 0.0, 1.0), 0.5)
		_hp_warning_tween.tween_property(p_hp_bar_fill, "color", Color(0.8, 0.2, 0.2, 1.0), 0.5)
	else:
		if e_exec_slot:
			e_exec_slot.add_theme_stylebox_override("panel", _make_slot_style(Color(0.4, 0.2, 0.2, 1.0), false, false, false, true))
		if e_exec_label:
			e_exec_label.text = "斬殺條件: 目標血量 <= %d" % GlobalBattleData.enemy_execution_threshold
			e_exec_label.remove_theme_color_override("font_color")
			
		if _hp_warning_tween and _hp_warning_tween.is_valid():
			_hp_warning_tween.kill()
		if p_hp_bar_fill:
			p_hp_bar_fill.color = Color(0.2, 0.8, 0.3, 1.0)


func _make_slot_style(border_color: Color, is_active: bool, is_first_in_bar: bool, is_last_in_bar: bool, is_first_in_group: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.20, 1.0) if not is_active else Color(0.15, 0.25, 0.35, 1.0)
	style.border_color = border_color
	style.border_width_left = 2 if is_first_in_group else 0
	style.border_width_right = 2 if is_last_in_bar else 0
	style.border_width_top = 2
	style.border_width_bottom = 2
	
	style.corner_radius_top_left = 6 if is_first_in_bar else 0
	style.corner_radius_bottom_left = 6 if is_first_in_bar else 0
	style.corner_radius_top_right = 6 if is_last_in_bar else 0
	style.corner_radius_bottom_right = 6 if is_last_in_bar else 0
	return style

func _set_player_buttons_enabled(enabled: bool) -> void:
	for btn in player_action_buttons:
		btn.disabled = not enabled

func _on_start_battle_pressed() -> void:
	if player_current_slot < 8:
		print("[BattleScene] 請先填完所有 8 個行動格！")
		return
		
	_set_player_buttons_enabled(false)
	var start_btn = $PreparePhaseUI.get_node_or_null("StartBattleButton")
	if start_btn: start_btn.disabled = true
	is_battling = true
	
	print("[BattleScene] 戰鬥開始！")
	await _resolve_battle()

func _spawn_floating_text(msg: String, color: Color, target_pos: Vector2) -> void:
	var label = Label.new()
	label.text = msg
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 36)
	label.position = target_pos + Vector2(0, -50)
	$PreparePhaseUI.add_child(label)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 80, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_callback(label.queue_free)

func _play_attack_dash(node: TextureRect, direction: int) -> void:
	if not node: return
	var original_x = node.position.x
	var tween = create_tween()
	tween.tween_property(node, "position:x", original_x + (30 * direction), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "position:x", original_x, 0.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _play_hit_shake(node: TextureRect) -> void:
	if not node: return
	var original_x = node.position.x
	var tween = create_tween()
	node.modulate = Color(1.0, 0.3, 0.3, 1.0)
	for i in range(3):
		tween.tween_property(node, "position:x", original_x - 15, 0.05)
		tween.tween_property(node, "position:x", original_x + 15, 0.05)
	tween.tween_property(node, "position:x", original_x, 0.05)
	tween.parallel().tween_property(node, "modulate", Color.WHITE, 0.2)

func _interrupt_entity(slots: Array[int], current_turn: int) -> void:
	slots[current_turn] = SubAction.STUNNED
	for i in range(current_turn + 1, 8):
		if slots[i] == SubAction.CHANT:
			slots[i] = SubAction.STUNNED
		elif slots[i] == SubAction.EXECUTE:
			slots[i] = SubAction.STUNNED
			break
		else:
			break

func _execute_attack(attacker: BattleEntity, defender: BattleEntity, action: int, is_player: bool, turn_idx: int):
	if action != SubAction.EXECUTE: return
	
	var attacker_name = "玩家" if is_player else "敵方"
	var defender_name = "敵方" if is_player else "玩家"
	
	var skill_id = player_slot_skills[turn_idx] if is_player else enemy_slot_skills[turn_idx]
	var skill_data = DatabaseManager.get_skill(skill_id)
	if not skill_data: return
	
	var base_dmg = skill_data.get("damage", 0)
	var type = skill_data.get("type", "phys_attack")
	var range_limit = skill_data.get("range_limit", 0)
	var attack_name = skill_data.get("name", "未知攻擊")
	
	# 屬性連動加成 (以 damage 欄位做為百分比)
	var attacker_stats = GlobalBattleData.get_player_stats() if is_player else GlobalBattleData.get_enemy_stats()
	var atk_stat = attacker_stats.get("total_atk", 0)
	
	var final_base_dmg = 0
	if type == "phys_attack" or type == "magic_attack":
		var percentage = base_dmg * 10.0 / 100.0
		final_base_dmg = int(atk_stat * percentage)
	else:
		final_base_dmg = base_dmg
		
	if final_base_dmg <= 0: return 
	
	var dist = abs(defender.pos - attacker.pos)
	print("%s 發動 %s！(距離: %d，範圍: %d)" % [attacker_name, attack_name, dist, range_limit])
	
	var attacker_node = $PreparePhaseUI/CharacterArea.get_node_or_null("PlayerSprite") if is_player else $PreparePhaseUI/CharacterArea.get_node_or_null("EnemySprite")
	var defender_node = $PreparePhaseUI/CharacterArea.get_node_or_null("EnemySprite") if is_player else $PreparePhaseUI/CharacterArea.get_node_or_null("PlayerSprite")
	var dash_dir = 1 if is_player else -1
	
	_play_attack_dash(attacker_node, dash_dir)
	await get_tree().create_timer(0.15).timeout
	
	var defender_center = Vector2(0, 0)
	if defender_node:
		defender_center = defender_node.global_position + defender_node.size / 2.0
	
	if defender.dodge_rate > 0.0 and randf() < defender.dodge_rate:
		print("%s 觸發完美閃避！攻擊 Miss！" % defender_name)
		_spawn_floating_text("Miss!", Color(0.7, 0.7, 0.7), defender_center)
		attacker.damage_boost = 0
		attacker.crit_rate = 0.0
		defender.dodge_rate = 0.0
		return
	
	if dist > range_limit:
		print("距離太遠，攻擊 Miss！")
		_spawn_floating_text("Miss!", Color(0.7, 0.7, 0.7), defender_center)
		attacker.damage_boost = 0
		attacker.crit_rate = 0.0
		return
		
	var is_crit = false
	if attacker.crit_rate > 0.0 and randf() < attacker.crit_rate:
		is_crit = true
		
	var dmg_multiplier = 1.0
	if defender.block_active:
		dmg_multiplier = max(0.0, 1.0 - defender.block_ratio)
		print("%s 正在格檔！減免 %d%% 傷害。" % [defender_name, int(defender.block_ratio * 100)])
		_spawn_floating_text("Block!", Color(0.5, 0.5, 0.8), defender_center + Vector2(0, -30))
		if defender.block_ratio >= 1.0:
			defender.damage_boost += 10
			print("%s 完美格檔！下次增傷 10。" % defender_name)
		
	var final_dmg = int((final_base_dmg + attacker.damage_boost) * dmg_multiplier)
	if is_crit:
		final_dmg = int(final_dmg * 1.5)
		print("爆擊！")
		_spawn_floating_text("Crit! %d" % final_dmg, Color(1.0, 0.8, 0.2), defender_center)
	else:
		_spawn_floating_text("%d" % final_dmg, Color(1.0, 0.3, 0.3), defender_center)
		
	defender.hp = max(0, defender.hp - final_dmg)
	_play_hit_shake(defender_node)
	_update_hp_ui()
	
	print("%s 命中！造成 %d 傷害。" % [attacker_name, final_dmg])
	attacker.damage_boost = 0
	attacker.crit_rate = 0.0
	defender.dodge_rate = 0.0
	
	await get_tree().create_timer(0.4).timeout

func _get_x_from_pos(pos: int) -> float:
	return 284.25 + (pos - 1) * 150.0

func _tween_character_to_pos(is_player: bool, target_pos: int) -> void:
	var target_center_x = _get_x_from_pos(target_pos)
	var char_nodes = []
	if is_player:
		char_nodes = [
			$PreparePhaseUI/CharacterArea.get_node_or_null("PlayerSprite"),
			$PreparePhaseUI/CharacterArea.get_node_or_null("PlayerNameLabel"),
			$PreparePhaseUI/CharacterArea.get_node_or_null("PlayerHPBar")
		]
	else:
		char_nodes = [
			$PreparePhaseUI/CharacterArea.get_node_or_null("EnemySprite"),
			$PreparePhaseUI/CharacterArea.get_node_or_null("EnemyNameLabel"),
			$PreparePhaseUI/CharacterArea.get_node_or_null("EnemyHPBar")
		]
		
	var tween = create_tween().set_parallel(true)
	for node in char_nodes:
		if not node: continue
		var current_width = node.size.x
		var target_x = target_center_x - current_width / 2.0
		tween.tween_property(node, "position:x", target_x, 0.4)\
			.set_ease(Tween.EASE_OUT)\
			.set_trans(Tween.TRANS_CUBIC)

func _get_clamped_pos(start: int, delta: int, other: int) -> int:
	var target = clamp(start + delta, 1, 10)
	if start < other:
		if target >= other:
			target = other - 1
	elif start > other:
		if target <= other:
			target = other + 1
	return target

func _resolve_interrupt_for(is_player: bool, turn_idx: int) -> void:
	var action = player_slots[turn_idx] if is_player else enemy_slots[turn_idx]
	if action != SubAction.EXECUTE: return
	
	var skill_id = player_slot_skills[turn_idx] if is_player else enemy_slot_skills[turn_idx]
	var skill_data = DatabaseManager.get_skill(skill_id)
	if not skill_data or skill_data.get("is_interrupt", 0) == 0: return
	
	var opponent_state = enemy_state if is_player else player_state
	var opponent_slots = enemy_slots if is_player else player_slots
	
	if opponent_state.is_chanting:
		var name = "玩家" if is_player else "敵方"
		print("%s 斷檔成功！獲得增傷 10。" % name)
		var state = player_state if is_player else enemy_state
		state.damage_boost += 10
		_interrupt_entity(opponent_slots, turn_idx)
		opponent_state.is_chanting = false

func _resolve_movement_for(is_player: bool, turn_idx: int) -> bool:
	var slots = player_slots if is_player else enemy_slots
	var skills = player_slot_skills if is_player else enemy_slot_skills
	if slots[turn_idx] != SubAction.EXECUTE: return false
	
	var skill_id = skills[turn_idx]
	var skill_data = DatabaseManager.get_skill(skill_id)
	if not skill_data: return false
	
	var forward = skill_data.get("move_forward", 0)
	var backward = skill_data.get("move_backward", 0)
	if forward == 0 and backward == 0: return false
	
	var delta = 0
	if is_player:
		delta = forward - backward
	else:
		delta = -(forward - backward)
		
	var state = player_state if is_player else enemy_state
	var other = enemy_state if is_player else player_state
	
	var new_pos = _get_clamped_pos(state.pos, delta, other.pos)
	if new_pos != state.pos:
		state.pos = new_pos
		var n = "玩家" if is_player else "敵方"
		print("%s 位移至 %d" % [n, state.pos])
		return true
	return false

func _resolve_battle() -> void:
	player_state.is_chanting = false
	enemy_state.is_chanting = false
	
	var player_speed = 100
	var enemy_speed = GlobalBattleData.enemy_speed
	var p_is_first = player_speed >= enemy_speed
	
	for turn_idx in range(8):
		print("--- 第 %d 回合 ---" % (turn_idx + 1))
		var p_action = player_slots[turn_idx]
		var e_action = enemy_slots[turn_idx]
		
		_highlight_resolving_slot(turn_idx)
		
		player_state.block_active = false
		enemy_state.block_active = false
		player_state.block_ratio = 0.0
		enemy_state.block_ratio = 0.0
		
		player_state.is_chanting = (p_action == SubAction.CHANT)
		enemy_state.is_chanting = (e_action == SubAction.CHANT)
		
		if p_action == SubAction.CHANT:
			var sname = DatabaseManager.get_skill(player_slot_skills[turn_idx])["name"] if DatabaseManager.get_skill(player_slot_skills[turn_idx]) else ""
			print("玩家 正在詠唱 %s..." % sname)
		elif p_action == SubAction.EXECUTE:
			var pd = DatabaseManager.get_skill(player_slot_skills[turn_idx])
			if pd:
				if pd.get("is_block", 0) == 1:
					player_state.block_active = true
					player_state.block_ratio = pd.get("block_ratio", 0.0)
					print("玩家 開啟格檔！")
				var dmg_b = pd.get("grant_damage_boost", 0)
				if dmg_b > 0:
					player_state.damage_boost += dmg_b
					print("玩家 獲得增傷 %d" % dmg_b)
				var crit_b = pd.get("grant_crit_rate", 0.0)
				if crit_b > 0.0:
					player_state.crit_rate += crit_b
					print("玩家 獲得爆擊機率 %d%%" % int(crit_b * 100))
				var dodge_b = pd.get("grant_dodge_rate", 0.0)
				if dodge_b > 0.0:
					player_state.dodge_rate += dodge_b
					print("玩家 獲得閃避機率 %d%%" % int(dodge_b * 100))
					
		if e_action == SubAction.CHANT:
			var sname = DatabaseManager.get_skill(enemy_slot_skills[turn_idx])["name"] if DatabaseManager.get_skill(enemy_slot_skills[turn_idx]) else ""
			print("敵方 正在詠唱 %s..." % sname)
		elif e_action == SubAction.EXECUTE:
			var ed = DatabaseManager.get_skill(enemy_slot_skills[turn_idx])
			if ed:
				if ed.get("is_block", 0) == 1:
					enemy_state.block_active = true
					enemy_state.block_ratio = ed.get("block_ratio", 0.0)
					print("敵方 開啟格檔！")
				var dmg_b = ed.get("grant_damage_boost", 0)
				if dmg_b > 0:
					enemy_state.damage_boost += dmg_b
					print("敵方 獲得增傷 %d" % dmg_b)
				var crit_b = ed.get("grant_crit_rate", 0.0)
				if crit_b > 0.0:
					enemy_state.crit_rate += crit_b
					print("敵方 獲得爆擊機率 %d%%" % int(crit_b * 100))
				var dodge_b = ed.get("grant_dodge_rate", 0.0)
				if dodge_b > 0.0:
					enemy_state.dodge_rate += dodge_b
					print("敵方 獲得閃避機率 %d%%" % int(dodge_b * 100))
			
		# Interrupt Phase
		_resolve_interrupt_for(p_is_first, turn_idx)
		_resolve_interrupt_for(not p_is_first, turn_idx)
		
		# Movement Phase
		var p_moved = false
		var e_moved = false
		
		if p_is_first:
			p_moved = _resolve_movement_for(true, turn_idx)
			e_moved = _resolve_movement_for(false, turn_idx)
		else:
			e_moved = _resolve_movement_for(false, turn_idx)
			p_moved = _resolve_movement_for(true, turn_idx)
			
		if p_moved:
			_tween_character_to_pos(true, player_state.pos)
		if e_moved:
			_tween_character_to_pos(false, enemy_state.pos)
			
		if p_moved or e_moved:
			await get_tree().create_timer(0.4).timeout
			
		# Execution Phase
		var first_act = player_slots[turn_idx] if p_is_first else enemy_slots[turn_idx]
		var second_act = enemy_slots[turn_idx] if p_is_first else player_slots[turn_idx]
		
		if p_is_first:
			await _execute_attack(player_state, enemy_state, first_act, true, turn_idx)
			if enemy_state.hp > 0:
				await _execute_attack(enemy_state, player_state, second_act, false, turn_idx)
		else:
			await _execute_attack(enemy_state, player_state, first_act, false, turn_idx)
			if player_state.hp > 0:
				await _execute_attack(player_state, enemy_state, second_act, true, turn_idx)
			
		_refresh_all_slots() # 更新可能被打斷的 UI
		_highlight_resolving_slot(turn_idx) # 重畫高亮
		_update_hp_ui()
		
		await get_tree().create_timer(1.0).timeout
		
		if player_state.hp <= 0 or enemy_state.hp <= 0:
			print("戰鬥結束！有人血量歸零。")
			break
			
	print("--- 結算完畢 ---")
	
	if player_state.hp > 0 and enemy_state.hp > 0:
		await _resolve_execution_phase()
	else:
		if player_state.hp <= 0:
			_show_battle_result(false, false)
		elif enemy_state.hp <= 0:
			_show_battle_result(true, true)

func _resolve_execution_phase() -> void:
	print("--- 進入終極斬殺階段 ---")
	_highlight_current_slot()
	_highlight_execution_slots(true)
	await get_tree().create_timer(0.5).timeout
	
	var player_speed = 60
	var enemy_speed = GlobalBattleData.enemy_execution_speed
	
	if player_speed >= enemy_speed:
		if await _try_execute(true): return
		if await _try_execute(false): return
	else:
		if await _try_execute(false): return
		if await _try_execute(true): return
		
	if player_state.hp == enemy_state.hp:
		print("--- 雙方血量相同，進入下一回合 ---")
		_reset_for_next_round()
	elif player_state.hp > enemy_state.hp:
		print("--- 玩家血量高於敵人，獲得勝利 ---")
		_show_battle_result(true, false)
	else:
		print("--- 玩家血量低於敵人，戰鬥失敗 ---")
		_show_battle_result(false, false)

func _reset_for_next_round() -> void:
	print("--- 雙方皆存活，進入下一回合 ---")
	_highlight_execution_slots(false)
	
	for i in range(8):
		player_slots[i] = SubAction.NONE
		player_slot_skills[i] = ""
		player_slot_groups[i] = -1
	player_current_slot = 0
	player_setup_chant_reduction = 0
	
	_setup_enemy_actions_ai()
	_refresh_all_slots()
	_highlight_current_slot()
	
	_set_player_buttons_enabled(true)
	var start_btn = $PreparePhaseUI.get_node_or_null("StartBattleButton")
	if start_btn: start_btn.disabled = false

func _try_execute(is_player: bool) -> bool:
	if is_player:
		if enemy_state.hp <= 50:
			print("玩家發動終極斬殺！")
			enemy_state.hp = 0
			_update_hp_ui()
			await get_tree().create_timer(1.0).timeout
			_show_battle_result(true, true)
			return true
	else:
		if player_state.hp <= GlobalBattleData.enemy_execution_threshold:
			print("敵方發動終極斬殺！")
			player_state.hp = 0
			_update_hp_ui()
			await get_tree().create_timer(1.0).timeout
			_show_battle_result(false, false)
			return true
	return false

func _show_battle_result(is_victory: bool, enemy_defeated: bool = true) -> void:
	var result_panel = $PreparePhaseUI.get_node_or_null("ResultPanel")
	if not result_panel: return
	
	var title = result_panel.get_node_or_null("TitleLabel")
	var loot_label = result_panel.get_node_or_null("LootLabel")
	
	result_panel.show()
	
	if is_victory:
		if title: 
			title.text = "戰鬥成功"
			title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		if loot_label: loot_label.show()
		if enemy_defeated and not GlobalBattleData.defeated_enemies.has(GlobalBattleData.current_enemy_name):
			GlobalBattleData.defeated_enemies.append(GlobalBattleData.current_enemy_name)
	else:
		if title:
			title.text = "戰鬥失敗"
			title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		if loot_label: loot_label.hide()

func _on_return_button_pressed() -> void:
	GlobalBattleData.current_hp = player_state.hp
	GlobalBattleData.is_returning_from_battle = true
	get_tree().change_scene_to_file(MAIN_SCENE)
