extends CanvasLayer

const POWERUP_DATA = [
	{
		"type": "attack_speed",
		"name": "어택 부스트",
		"desc": "공격 속도 +25%",
		"color": Color(1.0, 0.5, 0.2),
	},
	{
		"type": "attack_range",
		"name": "와이드 어택",
		"desc": "공격 범위 +25%",
		"color": Color(0.3, 0.6, 1.0),
	},
	{
		"type": "magnet_range",
		"name": "메가 마그넷",
		"desc": "수집 범위 +30%",
		"color": Color(0.2, 1.0, 0.8),
	},
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build_ui()

func _build_ui() -> void:
	# Full-screen root
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Dim overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	root.add_child(overlay)

	# Center container
	var center = VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.offset_left = -200
	center.offset_right = 200
	center.offset_top = -260
	center.offset_bottom = 260
	center.add_theme_constant_override("separation", 20)
	root.add_child(center)

	# Title
	var title = Label.new()
	title.text = "강화 선택"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 4)
	center.add_child(title)

	# Buttons
	for data in POWERUP_DATA:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(400, 120)
		btn.add_theme_font_size_override("font_size", 26)

		var level = _get_current_level(data.type)
		var next_level = level + 1
		btn.text = "%s\nLv.%d → Lv.%d  (%s)" % [data.name, level, next_level, data.desc]

		# Color tint via stylebox
		var style = StyleBoxFlat.new()
		style.bg_color = Color(data.color, 0.25)
		style.border_color = data.color
		style.set_border_width_all(3)
		style.set_corner_radius_all(12)
		style.set_content_margin_all(12)
		btn.add_theme_stylebox_override("normal", style)

		var hover_style = style.duplicate()
		hover_style.bg_color = Color(data.color, 0.45)
		btn.add_theme_stylebox_override("hover", hover_style)

		var pressed_style = style.duplicate()
		pressed_style.bg_color = Color(data.color, 0.6)
		btn.add_theme_stylebox_override("pressed", pressed_style)

		btn.pressed.connect(_on_selected.bind(data.type))
		center.add_child(btn)

	# Fade in
	root.modulate = Color(1, 1, 1, 0)
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(root, "modulate:a", 1.0, 0.15)

func _get_current_level(type: String) -> int:
	match type:
		"attack_speed":
			return GameManager.session_buff_attack_speed
		"attack_range":
			return GameManager.session_buff_attack_range
		"magnet_range":
			return GameManager.session_buff_magnet_range
	return 0

func _on_selected(type: String) -> void:
	GameManager.play_confirm_click()
	GameManager.apply_powerup(type)
	get_tree().paused = false
	queue_free()
