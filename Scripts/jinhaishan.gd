extends Node2D

func _ready() -> void:
	_setup_map_limits()

func _setup_map_limits() -> void:
	var player = get_node_or_null("Player")
	var bg = get_node_or_null("BackgroundMap")
	if player and bg and bg.texture:
		var cam = player.get_node_or_null("Camera2D")
		if cam:
			var tex_size = bg.texture.get_size()
			cam.limit_left = 0
			cam.limit_top = 0
			cam.limit_right = int(tex_size.x)
			cam.limit_bottom = int(tex_size.y)
