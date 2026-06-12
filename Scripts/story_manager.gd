extends Node

var dialogue_database: Dictionary = {}
var current_chapter: int = 1
var quests_completed: Array = []

func _ready() -> void:
	_load_dialogue_database()

func _load_dialogue_database() -> void:
	if not FileAccess.file_exists("res://Data/dialogues.json"):
		push_warning("Dialogue database not found!")
		return
		
	var file = FileAccess.open("res://Data/dialogues.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			dialogue_database = json.data
		else:
			push_error("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())

func get_dialogue_for_npc(npc_name: String) -> Array:
	if not dialogue_database.has(npc_name):
		return []
		
	var npc_dialogs = dialogue_database[npc_name]
	
	# Priority 1: Check Quests
	for quest in quests_completed:
		if npc_dialogs.has("quest_" + quest + "_done"):
			return npc_dialogs["quest_" + quest + "_done"]
			
	# Priority 2: Check Chapter
	var chapter_key = "chapter_" + str(current_chapter)
	if npc_dialogs.has(chapter_key):
		return npc_dialogs[chapter_key]
		
	# Priority 3: Default fallback
	if npc_dialogs.has("default"):
		return npc_dialogs["default"]
		
	return []
