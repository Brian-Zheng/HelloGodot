extends Node2D

## 戰鬥場景腳本
## 負責：
##   1. 進場淡入動畫（黑色遮罩 alpha 1 → 0）
##   2. 準備階段：Player 選擇行動填入格子，Enemy AI 自動填入
##   3. 「開始戰鬥」按鈕處理（預留）
##   4. 「返回地圖」按鈕處理

const MAIN_SCENE := "res://Scence/mainscence.tscn"

## 淡入動畫持續秒數
const FADE_DURATION := 0.8

## 行動名稱對照
const ACTION_NAMES := ["物理攻擊", "法術攻擊", "移動閃避", "移動詠唱", "格檔反擊", "詠唱斷檔"]
const ACTION_ICONS := ["⚔️", "🔮", "💨", "📖", "🛡️", "✂️"]

# --- 狀態變數 ---
var player_slots: Array[int] = [-1, -1, -1, -1, -1, -1, -1, -1]
var enemy_slots: Array[int] = [-1, -1, -1, -1, -1, -1, -1, -1]

var player_hp: int = 100
var player_max_hp: int = 100
var enemy_hp: int = 100
var enemy_max_hp: int = 100

## 目前 Player 正要填入第幾格（0-indexed）
var player_current_slot: int = 0

## 行動格 Panel 節點快取
var player_slot_panels: Array[Panel] = []
var enemy_slot_panels: Array[Panel] = []

## 行動按鈕節點快取
var player_action_buttons: Array[Button] = []


func _ready() -> void:
	_cache_nodes()
	_setup_enemy_actions_ai()
	_refresh_all_slots()
	_highlight_current_slot()
	_update_hp_ui()
	
	# 載入動態傳遞的圖片
	if GlobalBattleData.player_texture:
		$PreparePhaseUI/CharacterArea/PlayerSprite.texture = GlobalBattleData.player_texture
		print("[BattleScene] 成功載入 Player 圖片: ", GlobalBattleData.player_texture.resource_path)
	else:
		print("[BattleScene] GlobalBattleData 沒有 player_texture")

	if GlobalBattleData.enemy_texture:
		$PreparePhaseUI/CharacterArea/EnemySprite.texture = GlobalBattleData.enemy_texture
		print("[BattleScene] 成功載入 Enemy 圖片: ", GlobalBattleData.enemy_texture.resource_path)
	else:
		print("[BattleScene] GlobalBattleData 沒有 enemy_texture")
		
	_play_fade_in()


## 快取所有格子與按鈕節點，避免每幀重複搜尋
func _cache_nodes() -> void:
	var p_slots_root := $PreparePhaseUI/PlayerSlotsGrid
	for i in range(1, 9):
		player_slot_panels.append(p_slots_root.get_node("Slot_P%d" % i) as Panel)

	var e_slots_root := $PreparePhaseUI/EnemySlotsGrid
	for i in range(1, 9):
		enemy_slot_panels.append(e_slots_root.get_node("Slot_E%d" % i) as Panel)

	var p_actions_root := $PreparePhaseUI/PlayerActionsGrid
	var action_names_btn := ["Action_P1","Action_P2","Action_P3","Action_P4","Action_P5","Action_P6"]
	for n in action_names_btn:
		player_action_buttons.append(p_actions_root.get_node(n) as Button)


## Enemy AI 隨機填入 8 格行動
func _setup_enemy_actions_ai() -> void:
	for i in range(8):
		enemy_slots[i] = randi_range(0, 5)
	_refresh_enemy_slots()


## 播放淡入效果：FadeOverlay 從不透明到全透明
func _play_fade_in() -> void:
	var overlay: ColorRect = $PreparePhaseUI/FadeOverlay
	overlay.show()
	overlay.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, FADE_DURATION)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): overlay.hide())


## 玩家點擊行動按鈕（action_idx: 0~5）
func _on_player_action_pressed(action_idx: int) -> void:
	if player_current_slot >= 8:
		return  # 8 格已全部填滿

	player_slots[player_current_slot] = action_idx
	_refresh_player_slot(player_current_slot)

	player_current_slot += 1
	_highlight_current_slot()

	# 全填完後停用行動按鈕
	if player_current_slot >= 8:
		_set_player_buttons_enabled(false)


## 更新單一 Player 格子顯示
func _refresh_player_slot(idx: int) -> void:
	if idx < 0 or idx >= 8:
		return
	var panel := player_slot_panels[idx]
	var label := panel.get_node("SlotLabel") as Label
	var action := player_slots[idx]
	if action == -1:
		label.text = str(idx + 1)
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	else:
		label.text = "%s\n%s" % [ACTION_ICONS[action], ACTION_NAMES[action]]
		label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 1))


## 更新所有 Player 格子顯示
func _refresh_all_slots() -> void:
	for i in range(8):
		_refresh_player_slot(i)
	_refresh_enemy_slots()

## 更新血量顯示
func _update_hp_ui() -> void:
	var p_bar = $PreparePhaseUI/CharacterArea/PlayerHPBar
	var p_fill = p_bar.get_node("Fill")
	p_fill.anchor_right = float(player_hp) / float(player_max_hp)
	p_bar.get_node("HPLabel").text = "%d / %d" % [player_hp, player_max_hp]
	
	var e_bar = $PreparePhaseUI/CharacterArea/EnemyHPBar
	var e_fill = e_bar.get_node("Fill")
	e_fill.anchor_right = float(enemy_hp) / float(enemy_max_hp)
	e_bar.get_node("HPLabel").text = "%d / %d" % [enemy_hp, enemy_max_hp]


## 更新所有 Enemy 格子顯示
func _refresh_enemy_slots() -> void:
	for i in range(8):
		var panel := enemy_slot_panels[i]
		var label := panel.get_node("SlotLabel") as Label
		var action := enemy_slots[i]
		if action == -1:
			label.text = str(i + 1)
			label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		else:
			label.text = "%s\n%s" % [ACTION_ICONS[action], ACTION_NAMES[action]]
			label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55, 1))


## 高亮目前等待填入的 Player 格子
func _highlight_current_slot() -> void:
	for i in range(8):
		var panel := player_slot_panels[i]
		if i == player_current_slot:
			# 目前格子：亮邊框
			panel.add_theme_stylebox_override("panel", _make_slot_style(Color(0.3, 0.8, 1.0, 0.9), true))
		elif player_slots[i] != -1:
			# 已填入的格子
			panel.add_theme_stylebox_override("panel", _make_slot_style(Color(0.2, 0.6, 0.8, 0.5), false))
		else:
			# 空格子
			panel.add_theme_stylebox_override("panel", _make_slot_style(Color(0.25, 0.25, 0.35, 1.0), false))

	# Enemy 格子樣式（固定橘紅色，已填入）
	for i in range(8):
		var panel := enemy_slot_panels[i]
		if enemy_slots[i] != -1:
			panel.add_theme_stylebox_override("panel", _make_slot_style(Color(0.8, 0.3, 0.3, 0.5), false))
		else:
			panel.add_theme_stylebox_override("panel", _make_slot_style(Color(0.25, 0.25, 0.35, 1.0), false))


## 建立格子的 StyleBoxFlat
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


## 啟用/停用 Player 行動按鈕
func _set_player_buttons_enabled(enabled: bool) -> void:
	for btn in player_action_buttons:
		btn.disabled = not enabled


## 「開始戰鬥」按鈕 — 預留給下一階段
func _on_start_battle_pressed() -> void:
	if player_current_slot < 8:
		# 尚未填完全部格子
		print("[BattleScene] 請先填完所有 8 個行動格！")
		return
	print("[BattleScene] 戰鬥開始！")
	print("Player 行動序列：", player_slots.map(func(i): return ACTION_NAMES[i] if i >= 0 else "空"))
	print("Enemy  行動序列：", enemy_slots.map(func(i): return ACTION_NAMES[i] if i >= 0 else "空"))
	# TODO: 切換至戰鬥執行階段


## 「返回地圖」按鈕按下時，切回探索場景
func _on_return_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)
