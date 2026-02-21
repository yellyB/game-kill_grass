extends CanvasLayer

const POWERUP_DATA = [
	{
		"type": "attack_speed",
		"name": "어택 부스트",
		"desc": "공격 속도 +25%",
		"color": Color(1.0, 0.5, 0.2),
		"stackable": true,
	},
	{
		"type": "attack_range",
		"name": "와이드 어택",
		"desc": "공격 범위 +25%",
		"color": Color(0.3, 0.6, 1.0),
		"stackable": true,
	},
	{
		"type": "magnet_range",
		"name": "메가 마그넷",
		"desc": "수집 범위 +30%",
		"color": Color(0.2, 1.0, 0.8),
		"stackable": true,
	},
	{
		"type": "move_speed",
		"name": "라이트닝 대시",
		"desc": "이동 속도 +25%",
		"color": Color(1.0, 1.0, 0.3),
		"stackable": true,
	},
	{
		"type": "extra_time",
		"name": "엑스트라 타임",
		"desc": "세션 시간 +5초",
		"color": Color(0.4, 1.0, 0.4),
		"stackable": false,
	},
	{
		"type": "gold_rush",
		"name": "골드 러시",
		"desc": "10초간 코인 2배",
		"color": Color(1.0, 0.85, 0.0),
		"stackable": false,
	},
	{
		"type": "golden_bloom",
		"name": "골든 블룸",
		"desc": "주변 풀을 황금풀로",
		"color": Color(1.0, 0.9, 0.2),
		"stackable": false,
	},
	{
		"type": "double_or_dust",
		"name": "더블 오어 더스트",
		"desc": "50% 코인 2배 / 50% 전부 증발",
		"color": Color(0.8, 0.2, 0.8),
		"stackable": false,
	},
	{
		"type": "beast_rush",
		"name": "비스트 러시",
		"desc": "5초간 몬스터 대량 스폰, 드롭 3배",
		"color": Color(0.9, 0.2, 0.2),
		"stackable": false,
	},
	{
		"type": "overdrive",
		"name": "오버드라이브",
		"desc": "공속 2배, 이속 -80%",
		"color": Color(1.0, 0.3, 0.5),
		"stackable": false,
	},
	{
		"type": "harvest_madness",
		"name": "하베스트 매드니스",
		"desc": "5초간 모든 스탯 대폭 증가",
		"color": Color(1.0, 0.5, 1.0),
		"stackable": false,
	},
	{
		"type": "field_clear",
		"name": "필드 클리어",
		"desc": "맵 전체 풀 클리어",
		"color": Color(0.3, 1.0, 0.3),
		"stackable": false,
	},
	{
		"type": "blackhole",
		"name": "블랙홀",
		"desc": "모든 드롭 코인 흡수",
		"color": Color(0.2, 0.0, 0.4),
		"stackable": false,
	},
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build_ui()

func _pick_random_powerups(count: int) -> Array:
	var pool = POWERUP_DATA.duplicate()
	# Filter out non-stackable powerups already active
	var filtered: Array = []
	for data in pool:
		if not data.stackable:
			# Overdrive: once per session
			if data.type == "overdrive" and GameManager.session_buff_overdrive:
				continue
		filtered.append(data)
	filtered.shuffle()
	return filtered.slice(0, count)

func _build_ui() -> void:
	var selected = _pick_random_powerups(3)

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
	for data in selected:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(400, 120)
		btn.add_theme_font_size_override("font_size", 26)

		if data.stackable:
			var level = _get_current_level(data.type)
			var next_level = level + 1
			btn.text = "%s\nLv.%d → Lv.%d  (%s)" % [data.name, level, next_level, data.desc]
		else:
			btn.text = "%s\n%s" % [data.name, data.desc]

		# Color tint via stylebox (main menu button style)
		var main_color = Color(data.color, 0.35)
		var shadow_color = data.color.darkened(0.4)

		var style = StyleBoxFlat.new()
		style.bg_color = main_color
		style.set_corner_radius_all(18)
		style.border_width_bottom = 6
		style.border_color = shadow_color
		style.content_margin_left = 24
		style.content_margin_right = 24
		style.content_margin_top = 12
		style.content_margin_bottom = 14
		btn.add_theme_stylebox_override("normal", style)

		var hover_style = style.duplicate()
		hover_style.bg_color = Color(data.color, 0.5)
		btn.add_theme_stylebox_override("hover", hover_style)

		var pressed_style = StyleBoxFlat.new()
		pressed_style.bg_color = Color(data.color, 0.6)
		pressed_style.set_corner_radius_all(18)
		pressed_style.border_width_bottom = 2
		pressed_style.border_color = shadow_color
		pressed_style.content_margin_left = 24
		pressed_style.content_margin_right = 24
		pressed_style.content_margin_top = 16
		pressed_style.content_margin_bottom = 10
		btn.add_theme_stylebox_override("pressed", pressed_style)

		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)

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
		"move_speed":
			return GameManager.session_buff_move_speed
	return 0

func _on_selected(type: String) -> void:
	GameManager.play_confirm_click()
	GameManager.apply_powerup(type)
	get_tree().paused = false
	queue_free()
