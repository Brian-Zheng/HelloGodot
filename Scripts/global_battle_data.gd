extends Node

## 跨場景儲存戰鬥資料
@warning_ignore("unused_signal")
signal equipment_changed

var player_texture: Texture2D = null
var enemy_texture: Texture2D = null
var enemy_execution_threshold: int = 20
var enemy_execution_speed: int = 30
var enemy_speed: int = 20
var current_enemy_name: String = ""
var defeated_enemies: Array[String] = []

var last_player_position: Vector2 = Vector2.ZERO
var is_returning_from_battle: bool = false

var current_hp: int = -1
var current_mp: int = -1

func init_current_stats_if_needed() -> void:
	if current_hp == -1:
		var stats = get_player_stats()
		current_hp = stats["total_hp"]
		current_mp = stats["total_mp"]

func get_player_stats() -> Dictionary:
	var base_hp = 500
	var base_mp = 150
	var base_atk = 100
	var base_def = 50
	var base_agi = 20
	var base_mind = 40
	var base_crit = 5.0
	var base_dodge = 5.0
	
	var total_hp = base_hp
	var total_mp = base_mp
	var total_atk = base_atk
	var total_def = base_def
	var total_agi = base_agi
	var total_mind = base_mind
	var total_crit = base_crit
	var total_dodge = base_dodge
	
	if DatabaseManager.db != null:
		var all_equipments = DatabaseManager.get_character_equipments("player")
		for eq in all_equipments:
			if eq["equipped_slot"] != null and str(eq["equipped_slot"]) != "":
				total_hp += eq.get("bonus_hp", 0)
				total_mp += eq.get("bonus_mp", 0)
				total_atk += eq.get("bonus_attack", 0)
				total_def += eq.get("bonus_defense", 0)
				total_agi += eq.get("bonus_agility", 0)
				total_mind += eq.get("bonus_mind", 0)
				total_crit += eq.get("bonus_crit_rate", 0.0) * 100.0
				total_dodge += eq.get("bonus_dodge_rate", 0.0) * 100.0
	
	return {
		"base_hp": base_hp, "total_hp": total_hp,
		"base_mp": base_mp, "total_mp": total_mp,
		"base_atk": base_atk, "total_atk": total_atk,
		"base_def": base_def, "total_def": total_def,
		"base_agi": base_agi, "total_agi": total_agi,
		"base_mind": base_mind, "total_mind": total_mind,
		"base_crit": base_crit, "total_crit": total_crit,
		"base_dodge": base_dodge, "total_dodge": total_dodge
	}

func get_enemy_stats() -> Dictionary:
	# 敵人目前給予預設固定數值，後續可擴充為從資料庫讀取
	return {
		"base_hp": 800, "total_hp": 800,
		"base_mp": 100, "total_mp": 100,
		"base_atk": 80, "total_atk": 80,
		"base_def": 40, "total_def": 40,
		"base_agi": 15, "total_agi": 15,
		"base_mind": 30, "total_mind": 30,
		"base_crit": 5.0, "total_crit": 5.0,
		"base_dodge": 5.0, "total_dodge": 5.0
	}
var ui_window_positions: Dictionary = {}
