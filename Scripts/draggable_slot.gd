extends ColorRect

var item_data: Dictionary

func _get_drag_data(at_position: Vector2) -> Variant:
	if item_data.is_empty():
		return null
		
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.2, 0.8)
	bg.custom_minimum_size = Vector2(60, 60)
	
	var lbl = Label.new()
	lbl.text = item_data["name"]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 12)
	bg.add_child(lbl)
	
	set_drag_preview(bg)
	
	return {"source": "inventory", "item_data": item_data}

func _make_custom_tooltip(for_text: String) -> Object:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.02, 0.98) # 更深色的黑，近乎不透明
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
