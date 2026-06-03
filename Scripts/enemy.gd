extends CharacterBody2D

@export var execution_threshold: int = 20
@export var execution_speed: int = 30
@export var base_speed: int = 20

## 敵人移動速度（像素/秒）
const SPEED = 150.0

## 每次移動前的等待秒數
const IDLE_TIME := 3.0

## 每次隨機移動的最大距離（像素）
const MOVE_RANGE := 200.0

## 判定「抵達目標點」的容許誤差（像素）
const ARRIVE_THRESHOLD := 5.0

## 戰鬥場景路徑
const BATTLE_SCENE := "res://Scence/battle_scene.tscn"

enum State { IDLE, MOVING }

var _state: State = State.IDLE
var _idle_timer := 0.0       # 倒數等待時間
var _target_pos: Vector2     # 目標位置
var _battle_triggered := false  # 防止重複觸發


func _ready() -> void:
	_target_pos = global_position
	_start_idle()


func _physics_process(delta: float) -> void:
	# 已觸發戰鬥時停止所有移動邏輯
	if _battle_triggered:
		return

	match _state:
		State.IDLE:
			velocity = Vector2.ZERO
			_idle_timer -= delta
			if _idle_timer <= 0.0:
				_start_moving()

		State.MOVING:
			var to_target := _target_pos - global_position
			if to_target.length() <= ARRIVE_THRESHOLD:
				# 抵達目標點，停下來並開始等待
				velocity = Vector2.ZERO
				_start_idle()
			else:
				velocity = to_target.normalized() * SPEED

	move_and_slide()

	# 根據水平移動方向翻轉 Sprite2D
	if velocity.x != 0:
		$Sprite2D.flip_h = velocity.x < 0


## 進入等待狀態，重置倒數計時器
func _start_idle() -> void:
	_state = State.IDLE
	_idle_timer = IDLE_TIME


## 挑選隨機目標點並進入移動狀態
func _start_moving() -> void:
	var angle := randf_range(0.0, TAU)
	var dist  := randf_range(50.0, MOVE_RANGE)
	var raw_target = global_position + Vector2(cos(angle), sin(angle)) * dist
	
	# 取得畫面大小，並考慮 Sprite 偏移量
	var screen_size = get_viewport_rect().size
	var pad = 60.0
	var offset_x = $Sprite2D.position.x
	var offset_y = $Sprite2D.position.y
	
	_target_pos.x = clamp(raw_target.x, pad - offset_x, screen_size.x - pad - offset_x)
	_target_pos.y = clamp(raw_target.y, pad - offset_y, screen_size.y - pad - offset_y)
	
	_state = State.MOVING


## Hitbox（Area2D）偵測到物體進入時呼叫
## 確認是 Player 群組後，觸發場景切換
func _on_hitbox_body_entered(body: Node2D) -> void:
	if _battle_triggered:
		return
	if not body.is_in_group("player"):
		return

	_battle_triggered = true
	# 停止 Enemy 移動
	velocity = Vector2.ZERO
	set_physics_process(false)

	# 儲存角色圖片資料供戰鬥場景使用
	var player_sprite = body.get_node_or_null("Sprite2D")
	if player_sprite and player_sprite.texture:
		GlobalBattleData.player_texture = player_sprite.texture
	
	var enemy_sprite = $Sprite2D
	if enemy_sprite and enemy_sprite.texture:
		GlobalBattleData.enemy_texture = enemy_sprite.texture
		
	GlobalBattleData.enemy_execution_threshold = execution_threshold
	GlobalBattleData.enemy_execution_speed = execution_speed
	GlobalBattleData.enemy_speed = base_speed
	GlobalBattleData.current_enemy_name = name

	# 延遲到物理幀結束後再切換場景，避免在物理回呼中移除節點
	get_tree().call_deferred("change_scene_to_file", BATTLE_SCENE)
