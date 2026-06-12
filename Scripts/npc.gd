extends CharacterBody2D

signal interacted(npc_node)

@export var npc_name: String = "顧翁"
@export var is_patrolling: bool = false
@export var patrol_distance: float = 130.0
@export var patrol_interval: float = 6.0
@export var patrol_speed: float = 150.0
@export var texture_left: Texture2D
@export var texture_right: Texture2D

var _player_in_range := false
var _prompt_ui: Control
var _start_pos: Vector2
var _last_pos: Vector2
var _patrol_tween: Tween
var _sprite: Sprite2D
var _texture_front: Texture2D
var _original_scale: Vector2
var _base_visual_height: float

func _ready() -> void:
	# 加入 npc 群組方便辨識
	add_to_group("npc")
	
	# 尋找並綁定感應區
	var interact_area = get_node_or_null("InteractArea")
	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)
	
	# 尋找並初始化提示 UI
	_prompt_ui = get_node_or_null("PromptUI")
	if _prompt_ui:
		_prompt_ui.visible = false

	_sprite = get_node_or_null("Sprite2D")
	if _sprite:
		_texture_front = _sprite.texture
		_original_scale = _sprite.scale
		if _texture_front:
			_base_visual_height = _texture_front.get_height() * _original_scale.y
		
	if is_patrolling:
		_start_pos = global_position
		_last_pos = global_position
		_start_patrol()

func _start_patrol() -> void:
	if _patrol_tween and _patrol_tween.is_running():
		_patrol_tween.kill()
	_patrol_tween = create_tween().set_loops()
	var target_pos = _start_pos + Vector2(patrol_distance, 0)
	var duration = patrol_distance / patrol_speed
	
	_patrol_tween.tween_interval(patrol_interval)
	_patrol_tween.tween_property(self, "global_position", target_pos, duration).set_trans(Tween.TRANS_LINEAR)
	_patrol_tween.tween_interval(patrol_interval)
	_patrol_tween.tween_property(self, "global_position", _start_pos, duration).set_trans(Tween.TRANS_LINEAR)

func _set_texture(new_tex: Texture2D) -> void:
	if _sprite.texture == new_tex:
		return
	_sprite.texture = new_tex
	if new_tex and _base_visual_height > 0:
		var new_h = new_tex.get_height()
		var new_scale = _base_visual_height / new_h
		# 維護 X 和 Y 的比例相同
		_sprite.scale = Vector2(new_scale, new_scale)
	else:
		_sprite.scale = _original_scale

func _physics_process(_delta: float) -> void:
	if not is_patrolling or not _sprite:
		return
		
	if _player_in_range:
		if _patrol_tween and _patrol_tween.is_running():
			_patrol_tween.pause()
			if _texture_front:
				_set_texture(_texture_front)
	else:
		if _patrol_tween and not _patrol_tween.is_running():
			_patrol_tween.play()
			
		var dir_x = global_position.x - _last_pos.x
		if dir_x > 0.5 and texture_right:
			_set_texture(texture_right)
		elif dir_x < -0.5 and texture_left:
			_set_texture(texture_left)
		elif abs(dir_x) <= 0.5 and _texture_front:
			# If stopped moving (in interval)
			_set_texture(_texture_front)
			
		_last_pos = global_position

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if _prompt_ui:
			_prompt_ui.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		if _prompt_ui:
			_prompt_ui.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event is InputEventKey:
		# 檢查是否按下 E 鍵 (並且不是長按觸發的 echo)
		if event.pressed and not event.echo and event.keycode == KEY_E:
			get_viewport().set_input_as_handled()
			print("觸發與 ", npc_name, " 的對話！")
			
			var story_mgr = get_node_or_null("/root/StoryManager")
			if story_mgr:
				var script_data = story_mgr.get_dialogue_for_npc(npc_name)
				if script_data.size() > 0:
					var dialog_mgr = get_node_or_null("/root/DialogManager")
					if dialog_mgr:
						dialog_mgr.play_dialog(script_data)
				else:
					print("目前進度下沒有 ", npc_name, " 的對話。")
			else:
				print("找不到 StoryManager！")
			
			interacted.emit(self)
