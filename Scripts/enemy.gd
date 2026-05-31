extends CharacterBody2D

## 敵人移動速度（像素/秒）
const SPEED = 150.0

## 每次移動前的等待秒數
const IDLE_TIME := 3.0

## 每次隨機移動的最大距離（像素）
const MOVE_RANGE := 200.0

## 判定「抵達目標點」的容許誤差（像素）
const ARRIVE_THRESHOLD := 5.0

enum State { IDLE, MOVING }

var _state: State = State.IDLE
var _idle_timer := 0.0       # 倒數等待時間
var _target_pos: Vector2     # 目標位置


func _ready() -> void:
	_target_pos = global_position
	_start_idle()


func _physics_process(delta: float) -> void:
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
	_target_pos = global_position + Vector2(cos(angle), sin(angle)) * dist
	_state = State.MOVING
