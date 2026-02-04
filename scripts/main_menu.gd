extends Control

@onready var play_btn: Button = $VBoxContainer/PlayBtn
@onready var quit_btn: Button = $VBoxContainer/QuitBtn
@onready var title_label: Label = $TitleLabel

func _ready() -> void:
	play_btn.pressed.connect(_on_play_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	# Title animation
	animate_title()

func animate_title() -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(title_label, "scale", Vector2(1.05, 1.05), 1.0)
	tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 1.0)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/core/main.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
