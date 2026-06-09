extends Button

func _make_custom_tooltip(for_text: String) -> Object:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.02, 0.98) # 深黑色，近乎不透明
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.4)
	style.content_margin_left = 20
	style.content_margin_top = 16
	style.content_margin_right = 20
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = for_text
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)
	
	return panel
