extends "res://Scripts/skill_tooltip_button.gd"

var skill_id: String = ""

func _get_drag_data(at_position: Vector2) -> Variant:
	if skill_id == "": return null
	
	var data = {
		"source": "library",
		"skill_id": skill_id
	}
	
	var preview = Label.new()
	preview.text = text
	preview.add_theme_font_size_override("font_size", 18)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.size = preview.get_minimum_size() + Vector2(20, 10)
	preview.position = Vector2(10, 5)
	bg.add_child(preview)
	
	var control = Control.new()
	control.add_child(bg)
	bg.position = -bg.size / 2.0
	
	set_drag_preview(control)
	return data
