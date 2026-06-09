extends "res://Scripts/skill_tooltip_button.gd"

var slot_idx: int = -1
var skill_id: String = ""
var main_ui: Node = null

func _get_drag_data(at_position: Vector2) -> Variant:
	if skill_id == "": return null
	
	var data = {
		"source": "slot",
		"slot_idx": slot_idx,
		"skill_id": skill_id
	}
	
	var preview = Label.new()
	preview.text = text
	preview.add_theme_font_size_override("font_size", 18)
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.4, 0.8)
	bg.size = preview.get_minimum_size() + Vector2(20, 10)
	preview.position = Vector2(10, 5)
	bg.add_child(preview)
	
	var control = Control.new()
	control.add_child(bg)
	bg.position = -bg.size / 2.0
	
	set_drag_preview(control)
	return data

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("skill_id"):
		return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if main_ui and main_ui.has_method("_handle_skill_drop"):
		main_ui._handle_skill_drop(data, slot_idx)
