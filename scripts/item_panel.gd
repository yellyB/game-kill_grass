extends Control

signal panel_opened
signal panel_closed

@onready var panel: Panel = $Panel
@onready var toggle_btn: Button = $ToggleBtn
@onready var close_btn: Button = $Panel/CloseBtn
@onready var money_label: Label = $Panel/MoneyLabel
@onready var empty_label: Label = $Panel/EmptyLabel
@onready var item_grid: GridContainer = $Panel/ItemGrid

var is_open: bool = false
var show_toggle_button: bool = true

# Item image paths
const ITEM_IMAGES: Dictionary = {
	"질긴 슬라임 조각": "res://resources/images/items/질긴 슬라임 조각.png",
	"번개 먹은 배터리 껍질": "res://resources/images/items/번개 먹은 배터리 껍질.png",
}

func _ready() -> void:
	panel.visible = false
	toggle_btn.pressed.connect(_on_toggle_pressed)
	close_btn.pressed.connect(_on_close_pressed)

	GameManager.money_changed.connect(_on_money_changed)
	GameManager.inventory_changed.connect(_on_inventory_changed)
	update_money_display()
	toggle_btn.visible = show_toggle_button

func set_toggle_button_visible(should_show: bool) -> void:
	show_toggle_button = should_show
	if toggle_btn:
		toggle_btn.visible = should_show

func open_panel() -> void:
	if is_open:
		return
	is_open = true
	panel.visible = true
	update_money_display()
	_refresh_grid()
	panel_opened.emit()

func _on_toggle_pressed() -> void:
	is_open = !is_open
	panel.visible = is_open
	if is_open:
		update_money_display()
		_refresh_grid()
		panel_opened.emit()
	else:
		panel_closed.emit()

func _on_close_pressed() -> void:
	is_open = false
	panel.visible = false
	panel_closed.emit()

func _on_other_panel_opened() -> void:
	toggle_btn.disabled = true

func _on_other_panel_closed() -> void:
	toggle_btn.disabled = false

func _on_money_changed(_amount: int) -> void:
	update_money_display()

func _on_inventory_changed() -> void:
	if is_open:
		_refresh_grid()

func update_money_display() -> void:
	money_label.text = "$%s" % format_number(GameManager.money)

func _refresh_grid() -> void:
	# Clear existing items
	for child in item_grid.get_children():
		child.queue_free()

	var inv = GameManager.inventory
	empty_label.visible = inv.is_empty()

	for item_id in inv:
		var count = inv[item_id]
		if count <= 0:
			continue
		var slot = _create_item_slot(item_id, count)
		item_grid.add_child(slot)

func _create_item_slot(item_id: String, count: int) -> PanelContainer:
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(170, 200)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.25, 1.0)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	slot.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	slot.add_child(vbox)

	# Item image
	var tex_rect = TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(120, 120)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	var image_path = ITEM_IMAGES.get(item_id, "")
	if image_path != "":
		var tex = _load_texture(image_path)
		if tex:
			tex_rect.texture = tex
	vbox.add_child(tex_rect)

	# Item name
	var name_label = Label.new()
	name_label.text = item_id
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(name_label)

	# Item count
	var count_label = Label.new()
	count_label.text = "x%d" % count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 22)
	count_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	vbox.add_child(count_label)

	return slot

func _load_texture(res_path: String) -> ImageTexture:
	var abs_path = ProjectSettings.globalize_path(res_path)
	var image = Image.new()
	var err = image.load(abs_path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)

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
