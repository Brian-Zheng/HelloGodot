extends Node

const RES_DB_PATH = "res://data.db"
const USER_DB_PATH = "user://game_data.db"
var db: SQLite = null

func _ready():
	_init_database()

func _init_database():
	# 實作開機複製大法 (Copy on boot)
	if not FileAccess.file_exists(USER_DB_PATH):
		if FileAccess.file_exists(RES_DB_PATH):
			DirAccess.copy_absolute(RES_DB_PATH, USER_DB_PATH)
			print("【DatabaseManager】成功將 res://data.db 複製到 user://game_data.db")
		else:
			print("【DatabaseManager】找不到 res://data.db，將在 user:// 建立全新資料庫")

	db = SQLite.new()
	db.path = USER_DB_PATH
	db.open_db()
	
	# Create skills table
	var create_skills_table_query = """
		CREATE TABLE IF NOT EXISTS skills (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			skill_id TEXT UNIQUE,
			name TEXT,
			type TEXT,
			category TEXT,
			damage INTEGER,
			move_forward INTEGER,
			move_backward INTEGER,
			range_limit INTEGER,
			chant_turns INTEGER,
			is_interrupt INTEGER,
			is_block INTEGER,
			block_ratio REAL,
			grant_chant_reduction INTEGER,
			grant_damage_boost INTEGER,
			grant_crit_rate REAL,
			grant_dodge_rate REAL
		);
	"""
	db.query(create_skills_table_query)
	
	
	
	# Create character_skills table
	var create_char_skills_table_query = """
		CREATE TABLE IF NOT EXISTS character_skills (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			character_id TEXT,
			skill_id TEXT
		);
	"""
	db.query(create_char_skills_table_query)
	
	# Create enemy_action_sequence table (For fixed enemy behaviors)
	var create_enemy_seq_table_query = """
		CREATE TABLE IF NOT EXISTS enemy_action_sequence (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			character_id TEXT,
			sequence_index INTEGER,
			skill_id TEXT
		);
	"""
	db.query(create_enemy_seq_table_query)
	
	# Check if default data exists
	db.query("SELECT COUNT(*) as cnt FROM skills")
	var count = 0
	if db.query_result.size() > 0:
		count = db.query_result[0]["cnt"]
		
	if count == 0:
		_insert_default_data()

func _insert_default_data():
	var default_skills = [
		# --- 效果 (Effect) ---
		{"skill_id": "focus", "name": "專注", "type": "buff", "category": "效果", "damage": 0, "move_forward": 0, "move_backward": 0, "range_limit": 0, "chant_turns": 0, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 2, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "berserk", "name": "狂化", "type": "buff", "category": "效果", "damage": 0, "move_forward": 0, "move_backward": 0, "range_limit": 0, "chant_turns": 0, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 20, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "eagle_eye", "name": "鷹眼", "type": "buff", "category": "效果", "damage": 0, "move_forward": 0, "move_backward": 0, "range_limit": 0, "chant_turns": 0, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 1.0, "grant_dodge_rate": 0.0},
		{"skill_id": "mirage", "name": "幻影", "type": "buff", "category": "效果", "damage": 0, "move_forward": 0, "move_backward": 0, "range_limit": 0, "chant_turns": 1, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 1.0},
		{"skill_id": "meditate", "name": "冥想", "type": "buff", "category": "效果", "damage": 0, "move_forward": 0, "move_backward": 0, "range_limit": 0, "chant_turns": 0, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 1, "grant_damage_boost": 10, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},

		# --- 攻擊 (Attack) ---
		{"skill_id": "phys_attack", "name": "基礎斬擊", "type": "phys_attack", "category": "攻擊", "damage": 20, "move_forward": 1, "move_backward": 0, "range_limit": 4, "chant_turns": 1, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "magic_attack", "name": "魔法飛彈", "type": "magic_attack", "category": "攻擊", "damage": 40, "move_forward": 0, "move_backward": 0, "range_limit": 6, "chant_turns": 2, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "fireball", "name": "火球術", "type": "magic_attack", "category": "攻擊", "damage": 25, "move_forward": 0, "move_backward": 0, "range_limit": 5, "chant_turns": 1, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "assassinate", "name": "瞬影殺", "type": "phys_attack", "category": "攻擊", "damage": 15, "move_forward": 3, "move_backward": 0, "range_limit": 4, "chant_turns": 0, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		# 敵人專屬攻擊
		{"skill_id": "enemy_rend", "name": "撕裂狂擊", "type": "phys_attack", "category": "攻擊", "damage": 30, "move_forward": 1, "move_backward": 0, "range_limit": 2, "chant_turns": 1, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "enemy_acid", "name": "酸液噴吐", "type": "magic_attack", "category": "攻擊", "damage": 15, "move_forward": 0, "move_backward": 0, "range_limit": 5, "chant_turns": 0, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "enemy_phantom", "name": "幻影突刺", "type": "phys_attack", "category": "攻擊", "damage": 45, "move_forward": 2, "move_backward": 0, "range_limit": 8, "chant_turns": 2, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "enemy_thunder", "name": "雷霆萬鈞", "type": "magic_attack", "category": "攻擊", "damage": 70, "move_forward": 0, "move_backward": 0, "range_limit": 10, "chant_turns": 3, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},

		# --- 閃避 (Dodge) ---
		{"skill_id": "move_dodge", "name": "極限閃避", "type": "move_dodge", "category": "閃避", "damage": 0, "move_forward": 0, "move_backward": 4, "range_limit": 0, "chant_turns": 0, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "light_retreat", "name": "輕巧後撤", "type": "move_dodge", "category": "閃避", "damage": 0, "move_forward": 0, "move_backward": 2, "range_limit": 0, "chant_turns": 0, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "phantom_step", "name": "幻影步", "type": "move_dodge", "category": "閃避", "damage": 0, "move_forward": 0, "move_backward": 6, "range_limit": 0, "chant_turns": 1, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "backflip", "name": "後空翻", "type": "move_dodge", "category": "閃避", "damage": 0, "move_forward": 0, "move_backward": 3, "range_limit": 0, "chant_turns": 0, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},

		# --- 移動 (Move) ---
		{"skill_id": "move_chant", "name": "移動詠唱", "type": "move_chant", "category": "移動", "damage": 0, "move_forward": 0, "move_backward": 2, "range_limit": 0, "chant_turns": 0, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "dash", "name": "衝刺", "type": "move_chant", "category": "移動", "damage": 0, "move_forward": 3, "move_backward": 0, "range_limit": 0, "chant_turns": 0, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "step", "name": "踏步", "type": "move_chant", "category": "移動", "damage": 0, "move_forward": 1, "move_backward": 0, "range_limit": 0, "chant_turns": 0, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "teleport_fwd", "name": "縮地", "type": "move_chant", "category": "移動", "damage": 0, "move_forward": 5, "move_backward": 0, "range_limit": 0, "chant_turns": 1, "is_interrupt": 0, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},

		# --- 格檔 (Block) ---
		{"skill_id": "block_counter", "name": "格檔反擊", "type": "block_counter", "category": "格檔", "damage": 0, "move_forward": 0, "move_backward": 0, "range_limit": 0, "chant_turns": 0, "is_interrupt": 0, "is_block": 1, "block_ratio": 1.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "light_shield", "name": "輕盾格檔", "type": "block_counter", "category": "格檔", "damage": 0, "move_forward": 0, "move_backward": 0, "range_limit": 0, "chant_turns": 0, "is_interrupt": 0, "is_block": 1, "block_ratio": 0.5, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "iron_wall", "name": "鐵壁防禦", "type": "block_counter", "category": "格檔", "damage": 0, "move_forward": 0, "move_backward": 0, "range_limit": 0, "chant_turns": 0, "is_interrupt": 0, "is_block": 1, "block_ratio": 0.8, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "magic_shield", "name": "魔法護盾", "type": "block_counter", "category": "格檔", "damage": 0, "move_forward": 0, "move_backward": 0, "range_limit": 0, "chant_turns": 1, "is_interrupt": 0, "is_block": 1, "block_ratio": 1.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},

		# --- 斷檔 (Interrupt) ---
		{"skill_id": "chant_interrupt", "name": "詠唱斷檔", "type": "chant_interrupt", "category": "斷檔", "damage": 0, "move_forward": 0, "move_backward": 0, "range_limit": 0, "chant_turns": 0, "is_interrupt": 1, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "throwing_knife", "name": "飛刀打斷", "type": "chant_interrupt", "category": "斷檔", "damage": 5, "move_forward": 0, "move_backward": 0, "range_limit": 8, "chant_turns": 0, "is_interrupt": 1, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "shockwave", "name": "震盪波", "type": "chant_interrupt", "category": "斷檔", "damage": 0, "move_forward": 0, "move_backward": 0, "range_limit": 0, "chant_turns": 1, "is_interrupt": 1, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0},
		{"skill_id": "sonic_raid", "name": "音速突襲", "type": "chant_interrupt", "category": "斷檔", "damage": 10, "move_forward": 2, "move_backward": 0, "range_limit": 3, "chant_turns": 0, "is_interrupt": 1, "is_block": 0, "block_ratio": 0.0, "grant_chant_reduction": 0, "grant_damage_boost": 0, "grant_crit_rate": 0.0, "grant_dodge_rate": 0.0}
	]
	
	for skill in default_skills:
		db.insert_row("skills", skill)
		
	var default_char_skills = [
		{"character_id": "player", "skill_id": "phys_attack"},
		{"character_id": "player", "skill_id": "magic_attack"},
		{"character_id": "player", "skill_id": "move_dodge"},
		{"character_id": "player", "skill_id": "move_chant"},
		{"character_id": "player", "skill_id": "block_counter"},
		{"character_id": "player", "skill_id": "chant_interrupt"},
		{"character_id": "enemy", "skill_id": "enemy_rend"},
		{"character_id": "enemy", "skill_id": "enemy_acid"},
		{"character_id": "enemy", "skill_id": "move_dodge"},
		{"character_id": "enemy", "skill_id": "move_chant"},
		{"character_id": "enemy", "skill_id": "block_counter"},
		{"character_id": "enemy", "skill_id": "chant_interrupt"},
		{"character_id": "Enemy2", "skill_id": "enemy_phantom"},
		{"character_id": "Enemy2", "skill_id": "enemy_thunder"},
		{"character_id": "Enemy2", "skill_id": "move_dodge"},
		{"character_id": "Enemy2", "skill_id": "move_chant"},
		{"character_id": "Enemy2", "skill_id": "block_counter"},
		{"character_id": "Enemy2", "skill_id": "chant_interrupt"}
	]
	
	for cs in default_char_skills:
		db.insert_row("character_skills", cs)
		
	var default_enemy_seq = [
		# Enemy 1: 撕裂狂擊 -> 移動閃避 -> 酸液噴吐 -> 格檔反擊 -> 移動詠唱
		{"character_id": "enemy", "sequence_index": 1, "skill_id": "enemy_rend"},
		{"character_id": "enemy", "sequence_index": 2, "skill_id": "move_dodge"},
		{"character_id": "enemy", "sequence_index": 3, "skill_id": "enemy_acid"},
		{"character_id": "enemy", "sequence_index": 4, "skill_id": "block_counter"},
		{"character_id": "enemy", "sequence_index": 5, "skill_id": "move_chant"},
		# Enemy 2: 幻影突刺 -> 詠唱斷檔 -> 雷霆萬鈞 -> 移動閃避 -> 格檔反擊
		{"character_id": "Enemy2", "sequence_index": 1, "skill_id": "enemy_phantom"},
		{"character_id": "Enemy2", "sequence_index": 2, "skill_id": "chant_interrupt"},
		{"character_id": "Enemy2", "sequence_index": 3, "skill_id": "enemy_thunder"},
		{"character_id": "Enemy2", "sequence_index": 4, "skill_id": "move_dodge"},
		{"character_id": "Enemy2", "sequence_index": 5, "skill_id": "block_counter"}
	]
	
	for es in default_enemy_seq:
		db.insert_row("enemy_action_sequence", es)

func get_skill(skill_id: String) -> Dictionary:
	if db == null:
		return {}
		
	db.query("SELECT * FROM skills WHERE skill_id = '" + skill_id + "'")
	if db.query_result.size() > 0:
		return db.query_result[0]
	return {}

func get_character_skills(character_id: String) -> Array[String]:
	var result: Array[String] = []
	if db == null:
		return result
		
	db.query("SELECT skill_id FROM character_skills WHERE character_id = '" + character_id + "'")
	for row in db.query_result:
		result.append(row["skill_id"])
	return result

func get_all_skills() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if db == null:
		return result
	
	db.query("SELECT * FROM skills")
	for row in db.query_result:
		result.append(row)
	return result

func get_enemy_action_sequence(character_id: String) -> Array[String]:
	var result: Array[String] = []
	if db == null:
		return result
	
	db.query("SELECT skill_id FROM enemy_action_sequence WHERE character_id = '" + character_id + "' ORDER BY sequence_index ASC")
	for row in db.query_result:
		result.append(row["skill_id"])
	return result

func save_character_skills(character_id: String, skill_ids: Array[String]) -> void:
	if db == null:
		return
	
	db.query("DELETE FROM character_skills WHERE character_id = '" + character_id + "'")
	for sid in skill_ids:
		db.insert_row("character_skills", {"character_id": character_id, "skill_id": sid})
