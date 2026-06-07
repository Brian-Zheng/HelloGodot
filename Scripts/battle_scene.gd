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

var player_equipped_skills: Array[String] = []
var enemy_equipped_skills: Array[String] = []

## 目前 Player 正要填入第幾格（0-indexed）
var player_current_slot: int = 0

## 行動格 Panel 節點快取
var player_slot_panels: Array[Panel] = []
var enemy_slot_panels: Array[Panel] = []
var player_action_buttons: Array[Button] = []

func _ready() -> void:
	player_state = BattleEntity.new(4)
	enemy_state = BattleEntity.new(7)
	
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
		for i in range(1, 9):
			player_slot_panels.append(p_slots_root.get_node("Slot_P%d" % i) as Panel)

	var e_slots_root = $PreparePhaseUI.get_node_or_null("EnemySlotsGrid")
	if e_slots_root:
		for i in range(1, 9):
			enemy_slot_panels.append(e_slots_root.get_node("Slot_E%d" % i) as Panel)

	var p_actions_root = $PreparePhaseUI.get_node_or_null("PlayerActionsGrid")
	if p_actions_root:
		var action_names_btn := ["Action_P1","Action_P2","Action_P3","Action_P4","Action_P5","Action_P6"]
		for n in action_names_btn:
			player_action_buttons.append(p_actions_root.get_node(n) as Button)

func _load_character_skills() -> void:
	player_equipped_skills = DatabaseManager.get_character_skills("player")
	
	var enemy_id = GlobalBattleData.current_enemy_name
	if enemy_id == "": enemy_id = "enemy"
	enemy_equipped_skills = DatabaseManager.get_character_skills(enemy_id)
	
	if enemy_equipped_skills.size() == 0:
		enemy_equipped_skills = DatabaseManager.get_character_skills("enemy")
	
	for i in range(player_action_buttons.size()):
		var btn = player_action_buttons[i]
		if i < player_equipped_skills.size():
			var skill_id = player_equipped_skills[i]
			var skill_data = DatabaseManager.get_skill(skill_id)
			btn.text = skill_data["name"] if skill_data else skill_id
			btn.disabled = false
		else:
			btn.text = "（無）"
			btn.disabled = true

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
			current_slot += 1
			
	while current_slot < 8:
		enemy_slot_skills[current_slot] = "move_dodge"
		enemy_slots[current_slot] = SubAction.EXECUTE
		current_slot += 1

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
		
	for sa in sub_actions:
		player_slot_skills[player_current_slot] = skill_id
		player_slots[player_current_slot] = sa
		_refresh_player_slot(player_current_slot)
		player_current_slot += 1
		
	_highlight_current_slot()
	if player_current_slot >= 8:
		_set_player_buttons_enabled(false)

func _get_action_display_info(action: int, skill_id: String) -> Dictionary:
	if action == SubAction.STUNNED:
		return {"icon": "😵", "name": "被打斷", "color": Color(0.5, 0.5, 0.5)}
		
	var skill_data = DatabaseManager.get_skill(skill_id)
	var cat = skill_data.get("category", "") if skill_data else ""
	var sname = skill_data.get("name", skill_id) if skill_data else skill_id
	
	if action == SubAction.CHANT:
		return {"icon": "⏳", "name": sname + "\n(詠唱)", "color": Color(0.8, 0.8, 0.8)}
		
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
		var info = _get_action_display_info(action, player_slot_skills[idx])
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
			var info = _get_action_display_info(action, enemy_slot_skills[i])
			label.text = "%s\n%s" % [info.icon, info.name]
			label.add_theme_color_override("font_color", info.color)

func _highlight_current_slot() -> void:
	for i in range(8):
		if i >= player_slot_panels.size(): break
		var panel := player_slot_panels[i]
		if i == player_current_slot:
			panel.add_theme_stylebox_override("panel", _make_slot_style(Color(0.3, 0.8, 1.0, 0.9), true))
		elif player_slots[i] != SubAction.NONE:
			panel.add_theme_stylebox_override("panel", _make_slot_style(Color(0.2, 0.6, 0.8, 0.5), false))
		else:
			panel.add_theme_stylebox_override("panel", _make_slot_style(Color(0.25, 0.25, 0.35, 1.0), false))

	for i in range(8):
		if i >= enemy_slot_panels.size(): break
		var panel := enemy_slot_panels[i]
		if enemy_slots[i] != SubAction.NONE:
			panel.add_theme_stylebox_override("panel", _make_slot_style(Color(0.8, 0.3, 0.3, 0.5), false))
		else:
			panel.add_theme_stylebox_override("panel", _make_slot_style(Color(0.25, 0.25, 0.35, 1.0), false))

func _highlight_resolving_slot(idx: int) -> void:
	_highlight_current_slot()
	if idx < 8:
		if idx < player_slot_panels.size():
			player_slot_panels[idx].add_theme_stylebox_override("panel", _make_slot_style(Color(1.0, 0.8, 0.2, 1.0), true))
		if idx < enemy_slot_panels.size():
			enemy_slot_panels[idx].add_theme_stylebox_override("panel", _make_slot_style(Color(1.0, 0.8, 0.2, 1.0), true))

func _highlight_execution_slots(active: bool) -> void:
	var p_exec_slot = $PreparePhaseUI.get_node_or_null("PlayerExecutionSlot")
	var e_exec_slot = $PreparePhaseUI.get_node_or_null("EnemyExecutionSlot")
	if not p_exec_slot or not e_exec_slot: return
	
	if active:
		p_exec_slot.add_theme_stylebox_override("panel", _make_slot_style(Color(1.0, 0.8, 0.2, 1.0), true))
		e_exec_slot.add_theme_stylebox_override("panel", _make_slot_style(Color(1.0, 0.8, 0.2, 1.0), true))
	else:
		p_exec_slot.add_theme_stylebox_override("panel", _make_slot_style(Color(0.25, 0.25, 0.35, 1.0), false))
		e_exec_slot.add_theme_stylebox_override("panel", _make_slot_style(Color(0.25, 0.25, 0.35, 1.0), false))

func _make_slot_style(border_color: Color, is_active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.20, 1.0) if not is_active else Color(0.08, 0.18, 0.28, 1.0)
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2 if not is_active else 3
	style.border_width_bottom = 2 if not is_active else 3
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
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
	
	print("[BattleScene] 戰鬥開始！")
	await _resolve_battle()

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
	var range_limit = skill_data.get("range_limit", 0)
	var attack_name = skill_data.get("name", "未知攻擊")
	
	if base_dmg <= 0: return 
	
	var dist = abs(defender.pos - attacker.pos)
	print("%s 發動 %s！(距離: %d，範圍: %d)" % [attacker_name, attack_name, dist, range_limit])
	
	if defender.dodge_rate > 0.0 and randf() < defender.dodge_rate:
		print("%s 觸發完美閃避！攻擊 Miss！" % defender_name)
		attacker.damage_boost = 0
		attacker.crit_rate = 0.0
		defender.dodge_rate = 0.0
		return
	
	if dist > range_limit:
		print("距離太遠，攻擊 Miss！")
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
		if defender.block_ratio >= 1.0:
			defender.damage_boost += 10
			print("%s 完美格檔！下次增傷 10。" % defender_name)
		
	var final_dmg = int((base_dmg + attacker.damage_boost) * dmg_multiplier)
	if is_crit:
		final_dmg = int(final_dmg * 1.5)
		print("爆擊！")
		
	defender.hp = max(0, defender.hp - final_dmg)
	print("%s 命中！造成 %d 傷害。" % [attacker_name, final_dmg])
	attacker.damage_boost = 0
	attacker.crit_rate = 0.0
	defender.dodge_rate = 0.0

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
		
		if p_action == SubAction.EXECUTE:
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
					
		if e_action == SubAction.EXECUTE:
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
	get_tree().change_scene_to_file(MAIN_SCENE)
