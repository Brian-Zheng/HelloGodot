extends CharacterBody2D

## 角色移動速度（像素/秒）
const SPEED = 300.0


func _ready() -> void:
	# 加入 "player" 群組，讓 Enemy 可以透過群組找到此節點
	add_to_group("player")

func _physics_process(delta: float) -> void:
	# 取得水平與垂直輸入方向
	# ui_left / ui_right 對應 A、D 鍵或左右方向鍵
	# ui_up   / ui_down  對應 W、S 鍵或上下方向鍵
	var input_dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up",   "ui_down")
	)

	# 將輸入向量正規化，避免斜向移動速度過快
	if input_dir != Vector2.ZERO:
		velocity = input_dir.normalized() * SPEED
	else:
		# 沒有輸入時，讓角色逐漸停止
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)

	move_and_slide()

	# 根據水平方向翻轉 Sprite2D
	# input_dir.x > 0 → 往右（不翻轉）
	# input_dir.x < 0 → 往左（翻轉）
	if input_dir.x != 0:
		$Sprite2D.flip_h = input_dir.x < 0
