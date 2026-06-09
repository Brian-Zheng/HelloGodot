extends ColorRect

var slot_name: String = ""
var current_item: Dictionary = {}

func _get_drag_data(at_position: Vector2) -> Variant:
	if current_item.is_empty():
		return null
		
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.2, 0.8)
	bg.custom_minimum_size = Vector2(60, 60)
	
	var lbl = Label.new()
	lbl.text = current_item["name"]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 12)
	bg.add_child(lbl)
	
	set_drag_preview(bg)
	
	return {"source": "character_slot", "item_data": current_item, "slot_name": slot_name}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("item_data"):
		var item = data["item_data"]
		var item_type = item["type"]
		if item_type == "weapon" and slot_name.begins_with("武器"): return true
		if item_type == "armor" and slot_name == "護甲": return true
		if item_type == "shoes" and slot_name == "鞋子": return true
		if item_type == "talisman" and slot_name == "符祿": return true
		if item_type == "zhou_yuan" and slot_name == "周圓": return true
		if item_type == "treasure" and slot_name.begins_with("至寶"): return true
		if item_type == "accessory" and slot_name == "飾品": return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var item = data["item_data"]
	DatabaseManager.equip_item(item["char_equip_id"], slot_name)

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
