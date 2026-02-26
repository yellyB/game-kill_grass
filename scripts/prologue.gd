extends CanvasLayer

signal finished

const SLIDES: Array = [
  {"bg": Color(0.08, 0.14, 0.08), "text": "어느 날, 풀이 세상을 뒤덮기 시작했다."},
  {"bg": Color(0.06, 0.1, 0.06), "text": "마을도, 길도, 전부 풀에 잠식되었다.\n누군가는 베어야 했다."},
  {"bg": Color(0.05, 0.08, 0.12), "text": "...그게 나라고?"},
]

const FADE_DURATION: float = 0.4

var _current_slide: int = -1
var _transitioning: bool = false
var _bg_rect: ColorRect
var _text_label: Label
var _skip_btn: Button
var _touch_btn: Button

func _ready() -> void:
  layer = 100
  _build_ui()
  _advance_slide()

func _build_ui() -> void:
  # Full-screen background
  var control = Control.new()
  control.set_anchors_preset(Control.PRESET_FULL_RECT)
  add_child(control)

  _bg_rect = ColorRect.new()
  _bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
  _bg_rect.color = Color.BLACK
  control.add_child(_bg_rect)

  # Bottom text
  _text_label = Label.new()
  _text_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
  _text_label.offset_top = -300
  _text_label.offset_left = 40
  _text_label.offset_right = -40
  _text_label.offset_bottom = -120
  _text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  _text_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
  _text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  _text_label.add_theme_font_size_override("font_size", 40)
  _text_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.88))
  _text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
  _text_label.add_theme_constant_override("outline_size", 4)
  _text_label.add_theme_constant_override("line_spacing", 14)
  _text_label.modulate.a = 0.0
  control.add_child(_text_label)

  # Skip button (top-right)
  _skip_btn = Button.new()
  _skip_btn.text = "건너뛰기"
  _skip_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
  _skip_btn.offset_left = -200
  _skip_btn.offset_right = -30
  _skip_btn.offset_top = 40
  _skip_btn.offset_bottom = 100
  _skip_btn.add_theme_font_size_override("font_size", 28)
  _skip_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
  var skip_style = StyleBoxFlat.new()
  skip_style.bg_color = Color(0, 0, 0, 0)
  _skip_btn.add_theme_stylebox_override("normal", skip_style)
  _skip_btn.add_theme_stylebox_override("hover", skip_style)
  _skip_btn.add_theme_stylebox_override("pressed", skip_style)
  _skip_btn.pressed.connect(_on_skip)
  control.add_child(_skip_btn)

  # Tap hint at bottom
  var hint = Label.new()
  hint.text = "탭하여 계속"
  hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
  hint.offset_top = -80
  hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  hint.add_theme_font_size_override("font_size", 24)
  hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
  hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
  control.add_child(hint)

  # Invisible full-screen button for tap detection
  _touch_btn = Button.new()
  _touch_btn.flat = true
  _touch_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
  _touch_btn.pressed.connect(_on_tap)
  control.add_child(_touch_btn)

  # Make sure skip button is above touch button
  control.move_child(_skip_btn, -1)

func _advance_slide() -> void:
  _current_slide += 1
  if _current_slide >= SLIDES.size():
    _finish()
    return

  _transitioning = true
  var slide = SLIDES[_current_slide]

  # Fade out text
  var tween = create_tween()
  if _current_slide > 0:
    tween.tween_property(_text_label, "modulate:a", 0.0, FADE_DURATION * 0.5)
    tween.tween_property(_bg_rect, "color", slide.bg, FADE_DURATION * 0.5)
  else:
    _bg_rect.color = slide.bg

  # Update text and fade in
  tween.tween_callback(func():
    _text_label.text = slide.text
  )
  tween.tween_property(_text_label, "modulate:a", 1.0, FADE_DURATION)
  tween.tween_callback(func():
    _transitioning = false
  )

func _on_tap() -> void:
  if _transitioning:
    return
  _advance_slide()

func _on_skip() -> void:
  _finish()

func _finish() -> void:
  if _transitioning:
    return
  _transitioning = true

  var tween = create_tween()
  tween.tween_property(_text_label, "modulate:a", 0.0, FADE_DURATION)
  tween.tween_property(_bg_rect, "color", Color.BLACK, FADE_DURATION * 0.5)
  tween.tween_property(_bg_rect, "modulate:a", 0.0, FADE_DURATION)
  tween.tween_callback(func():
    finished.emit()
    queue_free()
  )
