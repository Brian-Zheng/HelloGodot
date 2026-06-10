extends Node2D

func _ready() -> void:
	for enemy_name in GlobalBattleData.defeated_enemies:
		var enemy_node = get_node_or_null(enemy_name)
		if enemy_node:
			enemy_node.queue_free()
			
	_setup_map_limits()
	_setup_player_hud()
	_setup_hotkey_hints()

func _setup_map_limits() -> void:
	var bg = get_node_or_null("GroundLayer")
	var player = get_node_or_null("Player")
	if bg and player and bg is TileMapLayer:
		var used_rect = bg.get_used_rect()
		var tile_size = bg.tile_set.tile_size if bg.tile_set else Vector2i(64, 64)
		var pixel_rect = Rect2(
			used_rect.position.x * tile_size.x,
			used_rect.position.y * tile_size.y,
			used_rect.size.x * tile_size.x,
			used_rect.size.y * tile_size.y
		)
		if player.has_method("set_camera_limits"):
			player.set_camera_limits(pixel_rect)


func _setup_player_hud() -> void:
	GlobalBattleData.init_current_stats_if_needed()
	var stats = GlobalBattleData.get_player_stats()
	var max_hp = stats["total_hp"]
	var max_mp = stats["total_mp"]
	var cur_hp = GlobalBattleData.current_hp
	var cur_mp = GlobalBattleData.current_mp
	
	var canvas = CanvasLayer.new()
	canvas.layer = 90
	add_child(canvas)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(margin)
	
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 15
	style.content_margin_top = 10
	style.content_margin_right = 15
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	panel.add_child(hbox)
	
	var texture_rect = TextureRect.new()
	var player_node = get_node_or_null("Player")
	if player_node:
		var sprite = player_node.get_node_or_null("Sprite2D")
		if sprite and sprite.texture:
			var atlas = AtlasTexture.new()
			atlas.atlas = sprite.texture
			
			# 如果圖片有切分影格 (SpriteSheet)，計算單一影格大小
			var frame_w = sprite.texture.get_width() / sprite.hframes if "hframes" in sprite else sprite.texture.get_width()
			var frame_h = sprite.texture.get_height() / sprite.vframes if "vframes" in sprite else sprite.texture.get_height()
			
			# 只取上半身 (Y 軸長度除以 2)
			atlas.region = Rect2(0, 0, frame_w, frame_h * 0.6)
			texture_rect.texture = atlas
			
	texture_rect.custom_minimum_size = Vector2(85, 85)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(texture_rect)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(vbox)
	
	var hp_label = Label.new()
	hp_label.text = "血量: %d / %d" % [cur_hp, max_hp]
	hp_label.add_theme_font_size_override("font_size", 18)
	hp_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	vbox.add_child(hp_label)
	
	var mp_label = Label.new()
	mp_label.text = "氣力: %d / %d" % [cur_mp, max_mp]
	mp_label.add_theme_font_size_override("font_size", 18)
	mp_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	vbox.add_child(mp_label)

func _setup_hotkey_hints() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100 # Ensure it's on top
	add_child(canvas)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	hbox.size_flags_vertical = Control.SIZE_SHRINK_END
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 20
	style.content_margin_top = 15
	style.content_margin_right = 20
	style.content_margin_bottom = 15
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	
	var buttons_info = [
		{"text": "[K] 技能介面", "action": _toggle_skill_ui},
		{"text": "[P] 角色狀態", "action": _toggle_stats_ui},
		{"text": "[B] 角色背包", "action": _toggle_inventory_ui}
	]
	
	for info in buttons_info:
		var btn = Button.new()
		btn.text = info["text"]
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.pressed.connect(info["action"])
		hbox.add_child(btn)

func _toggle_skill_ui() -> void:
	var existing = get_node_or_null("SkillEquipUI")
	if existing:
		existing.queue_free()
	else:
		var ui = load("res://Scripts/skill_equip_ui.gd").new()
		ui.name = "SkillEquipUI"
		add_child(ui)

func _toggle_stats_ui() -> void:
	var existing = get_node_or_null("CharacterStatsUI")
	if existing:
		existing.queue_free()
	else:
		var ui = load("res://Scripts/character_stats_ui.gd").new()
		ui.name = "CharacterStatsUI"
		add_child(ui)

func _toggle_inventory_ui() -> void:
	var existing = get_node_or_null("InventoryUI")
	if existing:
		existing.queue_free()
	else:
		var ui = load("res://Scripts/inventory_ui.gd").new()
		ui.name = "InventoryUI"
		add_child(ui)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K:
			_toggle_skill_ui()
		elif event.keycode == KEY_P:
			_toggle_stats_ui()
		elif event.keycode == KEY_B:
			_toggle_inventory_ui()
