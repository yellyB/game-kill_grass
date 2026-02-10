extends Control

@onready var play_btn: Button = $VBoxContainer/PlayBtn
@onready var weapon_btn: Button = $VBoxContainer/WeaponBtn
@onready var upgrade_btn: Button = $VBoxContainer/UpgradeBtn
@onready var quit_btn: Button = $VBoxContainer/QuitBtn
@onready var title_label: Label = $TitleLabel
@onready var upgrade_panel: Control = $UpgradePanel/Control
@onready var weapon_shop: Control = $WeaponShop/Control

func _ready() -> void:
	play_btn.pressed.connect(_on_play_pressed)
	weapon_btn.pressed.connect(_on_weapon_pressed)
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	# Hide the toggle buttons on panels (we use menu buttons instead)
	upgrade_panel.set_toggle_button_visible(false)
	weapon_shop.set_toggle_button_visible(false)

	# Connect panel signals for mutual exclusion
	upgrade_panel.panel_opened.connect(_on_panel_opened)
	upgrade_panel.panel_closed.connect(_on_panel_closed)
	weapon_shop.panel_opened.connect(_on_panel_opened)
	weapon_shop.panel_closed.connect(_on_panel_closed)

	# Title animation
	animate_title()

func animate_title() -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(title_label, "scale", Vector2(1.05, 1.05), 1.0)
	tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 1.0)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/core/main.tscn")

func _on_weapon_pressed() -> void:
	weapon_shop.open_panel()

func _on_upgrade_pressed() -> void:
	upgrade_panel.open_panel()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_panel_opened() -> void:
	play_btn.disabled = true
	weapon_btn.disabled = true
	upgrade_btn.disabled = true
	quit_btn.disabled = true

func _on_panel_closed() -> void:
	play_btn.disabled = false
	weapon_btn.disabled = false
	upgrade_btn.disabled = false
	quit_btn.disabled = false
