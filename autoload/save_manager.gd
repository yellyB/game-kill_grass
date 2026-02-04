extends Node

const SAVE_PATH = "user://savegame.json"

signal game_saved()
signal game_loaded()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()

func save_game() -> void:
	var save_data = GameManager.get_save_data()

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data, "\t")
		file.store_string(json_string)
		file.close()
		game_saved.emit()
		print("[SaveManager] Game saved")

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveManager] No save file found")
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var save_data = json.get_data()
			GameManager.load_save_data(save_data)
			game_loaded.emit()
			print("[SaveManager] Game loaded")
		else:
			print("[SaveManager] Failed to parse save file")

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("[SaveManager] Save file deleted")

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
