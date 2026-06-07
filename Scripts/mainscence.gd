extends Node2D

func _ready() -> void:
	for enemy_name in GlobalBattleData.defeated_enemies:
		var enemy_node = get_node_or_null(enemy_name)
		if enemy_node:
			enemy_node.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_S:
			if get_node_or_null("SkillEquipUI"): return
			var ui = load("res://Scripts/skill_equip_ui.gd").new()
			ui.name = "SkillEquipUI"
			add_child(ui)
		elif event.keycode == KEY_B:
			if get_node_or_null("CharacterStatsUI"): return
			var ui = load("res://Scripts/character_stats_ui.gd").new()
			ui.name = "CharacterStatsUI"
			add_child(ui)
