extends Control

signal joystick_input(direction: Vector2)

@onready var base: TextureRect = $Base
@onready var knob: TextureRect = $Base/Knob

@export var max_distance: float = 100.0
@export var dead_zone: float = 20.0

var is_pressed: bool = false
var touch_index: int = -1

func _ready() -> void:
  add_to_group("virtual_joystick")
  # Only show on mobile
  if not OS.has_feature("mobile"):
    visible = false
    return

  knob.position = base.size / 2 - knob.size / 2

func _input(event: InputEvent) -> void:
  if not visible:
    return

  if event is InputEventScreenTouch:
    if event.pressed:
      if _is_point_inside_base(event.position):
        is_pressed = true
        touch_index = event.index
        _update_knob(event.position)
    else:
      if event.index == touch_index:
        _reset()

  elif event is InputEventScreenDrag:
    if event.index == touch_index and is_pressed:
      _update_knob(event.position)

func _is_point_inside_base(point: Vector2) -> bool:
  var base_center = base.global_position + base.size / 2
  return point.distance_to(base_center) <= base.size.x / 2 + 50

func _update_knob(touch_pos: Vector2) -> void:
  var base_center = base.global_position + base.size / 2
  var direction = touch_pos - base_center
  var distance = direction.length()

  if distance > max_distance:
    direction = direction.normalized() * max_distance

  knob.global_position = base_center + direction - knob.size / 2

  # Calculate input
  if distance > dead_zone:
    var input_strength = (distance - dead_zone) / (max_distance - dead_zone)
    input_strength = clamp(input_strength, 0, 1)
    joystick_input.emit(direction.normalized() * input_strength)
  else:
    joystick_input.emit(Vector2.ZERO)

func _reset() -> void:
  is_pressed = false
  touch_index = -1
  knob.position = base.size / 2 - knob.size / 2
  joystick_input.emit(Vector2.ZERO)
