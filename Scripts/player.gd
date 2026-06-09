extends CharacterBody2D

## 角色移動速度（像素/秒）
const SPEED = 300.0


var invulnerable := false

func _ready() -> void:
	# 加入 "player" 群組，讓 Enemy 可以透過群組找到此節點
	add_to_group("player")
	
	if GlobalBattleData.last_player_position != Vector2.ZERO:
		global_position = GlobalBattleData.last_player_position
		
	if GlobalBattleData.is_returning_from_battle:
		GlobalBattleData.is_returning_from_battle = false
		invulnerable = true
		
		# 閃爍特效
		var tween = create_tween().set_loops(6)
		tween.tween_property($Sprite2D, "modulate:a", 0.3, 0.25)
		tween.tween_property($Sprite2D, "modulate:a", 1.0, 0.25)
		
		await get_tree().create_timer(3.0).timeout
		invulnerable = false
		if is_instance_valid(tween):
			tween.kill()
		if is_instance_valid($Sprite2D):
			$Sprite2D.modulate.a = 1.0

func _physics_process(_delta: float) -> void:
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

	# 限制玩家不超出畫面邊界 (需考慮 Sprite 的本地偏移)
	var screen_size = get_viewport_rect().size
	var pad = 60.0
	var offset_x = $Sprite2D.position.x
	var offset_y = $Sprite2D.position.y
	global_position.x = clamp(global_position.x, pad - offset_x, screen_size.x - pad - offset_x)
	global_position.y = clamp(global_position.y, pad - offset_y, screen_size.y - pad - offset_y)

	# 根據水平方向翻轉 Sprite2D
	# input_dir.x > 0 → 往右（不翻轉）
	# input_dir.x < 0 → 往左（翻轉）
	if input_dir.x != 0:
		$Sprite2D.flip_h = input_dir.x < 0
