extends Control

func _ready() -> void:
	$VBoxContainer/BtnHaiShan.pressed.connect(_on_haishan_pressed)
	$VBoxContainer/BtnJinhaiShan.pressed.connect(_on_jinhaishan_pressed)

func _on_haishan_pressed() -> void:
	# 海山村的入口位置 (傳送門在 850, 1350，我們讓主角生在往上 100 像素的安全區)
	GlobalBattleData.target_spawn_position = Vector2(850, 1200)
	get_tree().change_scene_to_file("res://Scence/mainscence.tscn")

func _on_jinhaishan_pressed() -> void:
	# 津海山的入口位置 (傳送門在 1200, 1600，我們讓主角生在往上 200 像素的安全區)
	GlobalBattleData.target_spawn_position = Vector2(1200, 1400)
	get_tree().change_scene_to_file("res://Scence/jinhaishan.tscn")
