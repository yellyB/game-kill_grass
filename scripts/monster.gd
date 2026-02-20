extends Node2D

const DroppedItemScene = preload("res://scenes/world/dropped_item.tscn")
const SFX_SLASH = preload("res://resources/sounds/effect/monster_slash.wav")
const SFX_DEATH = preload("res://resources/sounds/effect/monster_death.wav")

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Sprite2D = $Shadow
@onready var lightning_effect: Node2D = $LightningEffect

var textures: Array[Texture2D] = []

# Configurable via setup()
var sprite_path: String = "res://resources/images/monster/slime/"
var has_lightning: bool = true
var drop_table: Array = [
  {"item_id": "질긴 슬라임 조각", "image_path": "res://resources/images/items/질긴 슬라임 조각.png", "weight": 70},
  {"item_id": "번개 먹은 배터리 껍질", "image_path": "res://resources/images/items/번개 먹은 배터리 껍질.png", "weight": 30},
]

# Animation
const FRAME_DURATION: float = 0.18
var frame_timer: float = 0.0
var sequence_index: int = 0
var anim_sequence: Array = [0, 1, 2, 3, 4]  # base → compress → tilt left → expand → tilt right
var is_moving: bool = false

# Wandering AI
var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var wander_speed: float = 40.0

# Health (placeholder)
var max_health: int = 1
var health: int = 1
var sfx_hit: AudioStreamPlayer

func setup(config: Dictionary) -> void:
  sprite_path = config.sprite_path
  max_health = config.max_health
  health = config.max_health
  wander_speed = config.wander_speed
  drop_table = config.drop_table
  has_lightning = config.get("has_lightning", false)

func _ready() -> void:
  add_to_group("monsters")
  sfx_hit = AudioStreamPlayer.new()
  sfx_hit.stream = SFX_SLASH
  sfx_hit.volume_db = -3.0
  add_child(sfx_hit)
  _load_textures()
  if sprite and not textures.is_empty():
    sprite.texture = textures[0]
  if shadow and not textures.is_empty():
    shadow.texture = textures[0]
  _pick_new_wander()
  # Disable lightning for non-slime monsters
  if not has_lightning and lightning_effect:
    lightning_effect.set_process(false)
    lightning_effect.visible = false

func _load_textures() -> void:
  for i in range(1, 6):
    var path = "%s%d.png" % [sprite_path, i]
    var tex = _load_texture_from_file(path)
    if tex:
      textures.append(tex)

func _load_texture_from_file(res_path: String) -> ImageTexture:
  var abs_path = ProjectSettings.globalize_path(res_path)
  var image = Image.new()
  var err = image.load(abs_path)
  if err != OK:
    return null
  return ImageTexture.create_from_image(image)

func _process(delta: float) -> void:
  # Animation
  frame_timer += delta
  if frame_timer >= FRAME_DURATION:
    frame_timer = 0.0
    _advance_frame()

  # Chase player
  var player = get_tree().get_first_node_in_group("player")
  if player:
    var player_local = get_parent().to_local(player.global_position)
    var dir = (player_local - position).normalized()
    position += dir * wander_speed * delta
    if sprite:
      sprite.flip_h = dir.x > 0

func _advance_frame() -> void:
  if textures.is_empty():
    return
  sequence_index = (sequence_index + 1) % anim_sequence.size()
  var frame_index = anim_sequence[sequence_index]
  if frame_index < textures.size():
    sprite.texture = textures[frame_index]

func _pick_new_wander() -> void:
  if randf() < 0.4:
    # Idle
    is_moving = false
    wander_timer = randf_range(1.5, 3.0)
  else:
    # Move
    is_moving = true
    wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
    wander_timer = randf_range(1.0, 2.5)
  sequence_index = 0

var is_dead: bool = false

func take_damage(amount: int) -> void:
  if is_dead:
    return
  health -= amount
  sfx_hit.play()
  # Hit flash
  sprite.modulate = Color(1, 0.3, 0.3)
  var tween = create_tween()
  tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
  # Lightning burst on hit (slime only)
  if has_lightning and lightning_effect and lightning_effect.has_method("_spawn_bolts"):
    lightning_effect._spawn_bolts()
    lightning_effect._spawn_bolts()
  if health <= 0:
    die()

func die() -> void:
  is_dead = true
  remove_from_group("monsters")
  set_process(false)

  # Play death sound (on root so it persists after queue_free)
  var sfx = AudioStreamPlayer.new()
  sfx.stream = SFX_DEATH
  sfx.volume_db = -3.0
  get_tree().root.add_child(sfx)
  sfx.play()
  sfx.finished.connect(sfx.queue_free)

  # Lightning burst on death (slime only)
  if has_lightning and lightning_effect:
    for i in 3:
      lightning_effect._spawn_bolts()

  # Death effect: slight expand → shake + fade out
  sprite.modulate = Color(1.5, 1.5, 1.5, 1)  # Brief flash

  # Phase 1: Slightly expand (0.1s)
  var tween = create_tween()
  tween.set_parallel(true)
  tween.tween_property(sprite, "scale", Vector2(0.16, 0.16), 0.1).set_ease(Tween.EASE_OUT)
  tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.08)
  await tween.finished

  # Phase 2: Shake + fade out (0.35s)
  var tween2 = create_tween()
  tween2.set_parallel(true)
  tween2.tween_property(sprite, "modulate:a", 0.0, 0.35)
  if shadow:
    tween2.tween_property(shadow, "modulate:a", 0.0, 0.25)

  # Shake effect
  var shake_tween = create_tween()
  for i in 5:
    var offset = Vector2(randf_range(-4, 4), randf_range(-4, 4))
    shake_tween.tween_property(sprite, "position", offset, 0.035)
    shake_tween.tween_property(sprite, "position", Vector2.ZERO, 0.035)

  # Stop lightning
  if has_lightning and lightning_effect:
    lightning_effect.set_process(false)
    lightning_effect.bolts.clear()
    lightning_effect.queue_redraw()

  await tween2.finished

  # Drop item (3x during beast rush)
  var drop_count = 3 if GameManager.is_beast_rush_active() else 1
  for i in drop_count:
    _drop_item()

  queue_free()

func _drop_item() -> void:
  var drop = _roll_drop()
  if not drop:
    return

  var tex = _load_texture_from_file(drop.image_path)
  if not tex:
    return

  var player = get_tree().get_first_node_in_group("player")
  if not player:
    return

  var item = DroppedItemScene.instantiate()
  item.setup(drop.item_id, tex, player)
  item.position = position  # 같은 부모(WorldRoot) 기준 로컬 좌표
  get_parent().add_child(item)

func _roll_drop() -> Variant:
  var total_weight: int = 0
  for drop in drop_table:
    total_weight += drop.weight

  var roll = randi() % total_weight
  var cumulative: int = 0
  for drop in drop_table:
    cumulative += drop.weight
    if roll < cumulative:
      return drop
  return drop_table[0]
