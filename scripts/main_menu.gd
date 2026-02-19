extends Control

@onready var play_btn: Button = $VBoxContainer/PlayBtn
@onready var weapon_btn: Button = $VBoxContainer/WeaponBtn
@onready var upgrade_btn: Button = $VBoxContainer/UpgradeBtn
@onready var item_btn: Button = $VBoxContainer/ItemBtn
@onready var quit_btn: Button = $VBoxContainer/QuitBtn
@onready var title_label: Label = $TitleLabel
@onready var money_label: Label = $MoneyLabel
@onready var upgrade_panel: Control = $UpgradePanel/Control
@onready var weapon_shop: Control = $WeaponShop/Control
@onready var item_panel: Control = $ItemPanel/Control

# World selection overlay (built dynamically)
var world_overlay: Control = null
var _ws_selected: int = -1  # Currently highlighted world index in panel
var _ws_cards_container: VBoxContainer = null
var _ws_action_btn: Button = null

const WORLD_DATA: Array = [
	{"name": "슬라임 늪", "monsters": "슬라임"},
	{"name": "들판", "monsters": "멧돼지, 잔디 기사"},
	{"name": "마법의 숲", "monsters": "마도사, 골렘"},
	{"name": "용의 봉우리", "monsters": "수정 사슴, 드래곤"},
]

func _ready() -> void:
	play_btn.pressed.connect(_on_play_pressed)
	weapon_btn.pressed.connect(_on_weapon_pressed)
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	item_btn.pressed.connect(_on_item_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	# Hide the toggle buttons on panels (we use menu buttons instead)
	upgrade_panel.set_toggle_button_visible(false)
	weapon_shop.set_toggle_button_visible(false)
	item_panel.set_toggle_button_visible(false)

	# Connect panel signals for mutual exclusion
	upgrade_panel.panel_opened.connect(_on_panel_opened)
	upgrade_panel.panel_closed.connect(_on_panel_closed)
	weapon_shop.panel_opened.connect(_on_panel_opened)
	weapon_shop.panel_closed.connect(_on_panel_closed)
	item_panel.panel_opened.connect(_on_panel_opened)
	item_panel.panel_closed.connect(_on_panel_closed)

	# Money display
	update_money_display()
	GameManager.money_changed.connect(_on_money_changed)

	# Debug buttons (bottom of screen, debug builds only)
	if OS.is_debug_build():
		_build_debug_buttons()

	# Title animation
	animate_title()

func animate_title() -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(title_label, "scale", Vector2(1.05, 1.05), 1.0)
	tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 1.0)

func _on_play_pressed() -> void:
	_open_world_select()

func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/core/main.tscn")

func _on_weapon_pressed() -> void:
	weapon_shop.open_panel()

func _on_upgrade_pressed() -> void:
	upgrade_panel.open_panel()

func _on_item_pressed() -> void:
	item_panel.open_panel()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_panel_opened() -> void:
	play_btn.disabled = true
	weapon_btn.disabled = true
	upgrade_btn.disabled = true
	item_btn.disabled = true
	quit_btn.disabled = true

func _on_panel_closed() -> void:
	play_btn.disabled = false
	weapon_btn.disabled = false
	upgrade_btn.disabled = false
	item_btn.disabled = false
	quit_btn.disabled = false

func _on_money_changed(_amount: int) -> void:
	update_money_display()

func update_money_display() -> void:
	money_label.text = "$" + format_number(GameManager.money)

# ── World Selection Panel ──

func _open_world_select() -> void:
	if world_overlay != null:
		return
	_on_panel_opened()
	_ws_selected = GameManager.selected_world

	world_overlay = Control.new()
	world_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(world_overlay)

	# Dim background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.05, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_overlay.add_child(bg)

	# Center panel
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.13, 0.1)
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_color = Color(0.3, 0.5, 0.3)
	panel_style.content_margin_left = 30
	panel_style.content_margin_right = 30
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "월드 선택"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 40)
	header.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	header.add_theme_constant_override("outline_size", 3)
	vbox.add_child(header)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	# World cards container (for rebuilding cards on selection change)
	_ws_cards_container = VBoxContainer.new()
	_ws_cards_container.add_theme_constant_override("separation", 12)
	vbox.add_child(_ws_cards_container)

	_ws_rebuild_cards()

	# Action button (게임 입장 / 해금)
	var action_center = CenterContainer.new()
	action_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(action_center)

	_ws_action_btn = Button.new()
	_ws_action_btn.custom_minimum_size = Vector2(300, 65)
	_ws_action_btn.add_theme_font_size_override("font_size", 28)
	_ws_action_btn.pressed.connect(_on_action_btn_pressed)
	action_center.add_child(_ws_action_btn)
	_ws_update_action_btn()

	# Close button
	var close_center = CenterContainer.new()
	close_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(close_center)

	var close_btn = Button.new()
	close_btn.text = "닫기"
	close_btn.custom_minimum_size = Vector2(200, 55)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(_close_world_select)
	close_center.add_child(close_btn)

func _ws_rebuild_cards() -> void:
	for child in _ws_cards_container.get_children():
		child.queue_free()
	for i in range(WORLD_DATA.size()):
		var card = _create_world_card(i)
		_ws_cards_container.add_child(card)

func _create_world_card(index: int) -> PanelContainer:
	var world = WORLD_DATA[index]
	var unlocked = index in GameManager.unlocked_worlds
	var cost = GameManager.WORLD_UNLOCK_COSTS[index]
	var selected = index == _ws_selected

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 90)

	var style = StyleBoxFlat.new()
	if selected:
		if unlocked:
			style.bg_color = Color(0.15, 0.28, 0.15)
			style.border_color = Color(0.4, 0.9, 0.4)
		else:
			style.bg_color = Color(0.18, 0.15, 0.22)
			style.border_color = Color(0.5, 0.4, 0.7)
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_width_left = 3
		style.border_width_right = 3
	else:
		if unlocked:
			style.bg_color = Color(0.12, 0.2, 0.12)
			style.border_color = Color(0.3, 0.6, 0.3)
		else:
			style.bg_color = Color(0.1, 0.1, 0.14)
			style.border_color = Color(0.25, 0.25, 0.35)
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_width_left = 2
		style.border_width_right = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	card.add_child(hbox)

	# Status icon
	var icon_label = Label.new()
	icon_label.add_theme_font_size_override("font_size", 32)
	if unlocked:
		icon_label.text = "O"
		icon_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	else:
		icon_label.text = "X"
		icon_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	hbox.add_child(icon_label)

	# Info column
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = world.name
	name_label.add_theme_font_size_override("font_size", 28)
	if unlocked:
		name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	else:
		name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	name_label.add_theme_constant_override("outline_size", 2)
	info_vbox.add_child(name_label)

	var monster_label = Label.new()
	monster_label.text = world.monsters
	monster_label.add_theme_font_size_override("font_size", 18)
	if unlocked:
		monster_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	else:
		monster_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	info_vbox.add_child(monster_label)

	# Cost / key status (locked only)
	if not unlocked:
		var status_vbox = VBoxContainer.new()
		status_vbox.add_theme_constant_override("separation", 2)
		hbox.add_child(status_vbox)

		var cost_label = Label.new()
		cost_label.text = "$" + format_number(cost)
		cost_label.add_theme_font_size_override("font_size", 24)
		if GameManager.money >= cost:
			cost_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		else:
			cost_label.add_theme_color_override("font_color", Color(0.5, 0.4, 0.4))
		status_vbox.add_child(cost_label)

		var key_label = Label.new()
		key_label.add_theme_font_size_override("font_size", 18)
		if GameManager.has_key(index):
			key_label.text = "열쇠 O"
			key_label.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0))
		else:
			key_label.text = "열쇠 X"
			key_label.add_theme_color_override("font_color", Color(0.5, 0.4, 0.4))
		status_vbox.add_child(key_label)

	# Clickable overlay button
	var btn = Button.new()
	btn.flat = true
	btn.anchors_preset = Control.PRESET_FULL_RECT
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(_on_world_card_pressed.bind(index))
	card.add_child(btn)

	return card

func _on_world_card_pressed(index: int) -> void:
	_ws_selected = index
	_ws_rebuild_cards()
	_ws_update_action_btn()

func _ws_update_action_btn() -> void:
	if _ws_action_btn == null:
		return

	var unlocked = _ws_selected in GameManager.unlocked_worlds
	if unlocked:
		_ws_action_btn.text = "게임 입장"
		_ws_action_btn.disabled = false
	else:
		var cost = GameManager.WORLD_UNLOCK_COSTS[_ws_selected]
		var has_key = GameManager.has_key(_ws_selected)
		if has_key:
			_ws_action_btn.text = "해금  $" + format_number(cost)
			_ws_action_btn.disabled = GameManager.money < cost
		else:
			_ws_action_btn.text = "열쇠 필요  $" + format_number(cost)
			_ws_action_btn.disabled = true

func _on_action_btn_pressed() -> void:
	if _ws_selected < 0:
		return
	var unlocked = _ws_selected in GameManager.unlocked_worlds
	if unlocked:
		GameManager.selected_world = _ws_selected
		_close_world_select()
		_start_game()
	else:
		if GameManager.unlock_world(_ws_selected):
			update_money_display()
			_ws_rebuild_cards()
			_ws_update_action_btn()

func _close_world_select() -> void:
	if world_overlay != null:
		world_overlay.queue_free()
		world_overlay = null
	_ws_cards_container = null
	_ws_action_btn = null
	_on_panel_closed()

func format_number(num: int) -> String:
	var str_num = str(num)
	var result = ""
	var count = 0
	for i in range(str_num.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = str_num[i] + result
		count += 1
	return result

# ── Debug Buttons ──

const DEBUG_ALL_ITEMS: Array = [
	"질긴 슬라임 조각", "번개 먹은 배터리 껍질", "차축 뼈대",
	"굴러다니는 바퀴 잔해", "과성장 생체 응축체", "왜곡된 볼트 조각",
	"압축된 이세계 철편", "생체 연료 포자", "뒤틀린 시간 포자",
	"바람 머금은 잔디 섬유", "몬스터 핵", "침식된 백골 프레임",
	"투명 수정 파편", "강화 유리 결정핵", "과열된 엔진 심장",
	"드래곤 배기가스 결정",
]

func _build_debug_buttons() -> void:
	var container = HBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	container.offset_top = -50.0
	container.offset_left = 20.0
	container.offset_right = -20.0
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 12)
	add_child(container)

	var reset_btn = Button.new()
	reset_btn.text = "초기화"
	reset_btn.add_theme_font_size_override("font_size", 18)
	reset_btn.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	reset_btn.pressed.connect(_on_debug_reset)
	container.add_child(reset_btn)

	var money_btn = Button.new()
	money_btn.text = "+$100000"
	money_btn.add_theme_font_size_override("font_size", 18)
	money_btn.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	money_btn.pressed.connect(_on_debug_add_money)
	container.add_child(money_btn)

	var items_btn = Button.new()
	items_btn.text = "아이템+10"
	items_btn.add_theme_font_size_override("font_size", 18)
	items_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	items_btn.pressed.connect(_on_debug_add_items)
	container.add_child(items_btn)

func _on_debug_reset() -> void:
	SaveManager.reset_all_data()
	update_money_display()

func _on_debug_add_money() -> void:
	GameManager.money += 100000
	GameManager.money_changed.emit(GameManager.money)
	SaveManager.save_game()

func _on_debug_add_items() -> void:
	for item_id in DEBUG_ALL_ITEMS:
		GameManager.add_item(item_id, 10)
	SaveManager.save_game()
