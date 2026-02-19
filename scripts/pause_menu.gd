extends Control

@onready var panel: Panel = $Panel
@onready var resume_btn: Button = $Panel/VBoxContainer/ResumeBtn
@onready var save_quit_btn: Button = $Panel/VBoxContainer/SaveQuitBtn
@onready var pause_btn: Button = $PauseBtn

var is_paused: bool = false

func _ready() -> void:
	panel.visible = false
	pause_btn.pressed.connect(_on_pause_pressed)
	resume_btn.pressed.connect(_on_resume_pressed)
	save_quit_btn.pressed.connect(_on_save_quit_pressed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause() -> void:
	is_paused = !is_paused
	panel.visible = is_paused
	get_tree().paused = is_paused

func _on_pause_pressed() -> void:
	GameManager.play_button_click()
	toggle_pause()

func _on_resume_pressed() -> void:
	GameManager.play_button_click()
	toggle_pause()

func _on_save_quit_pressed() -> void:
	GameManager.play_confirm_click()
	get_tree().paused = false
	SessionManager.quit_to_menu()
