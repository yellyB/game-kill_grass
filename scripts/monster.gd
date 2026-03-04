extends Node2D

const DroppedItemScene = preload("res://scenes/world/dropped_item.tscn")
const PowerupScene = preload("res://scenes/world/powerup.tscn")
const SFX_SLASH = preload("res://resources/sounds/effect/monster_slash.wav")
const SFX_DEATH = preload("res://resources/sounds/effect/monster_death.wav")

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Sprite2D = $Shadow
@onready var hit_area: Area2D = $HitArea
@onready var hit_shape: CollisionShape2D = $HitArea/CollisionShape2D

static var _texture_cache: Dictionary = {}
var textures: Array[Texture2D] = []

# Configurable via setup()
var sprite_path: String = "res://resources/images/monster/slime/"
var effect_scene_path: String = ""
var effect_node: Node2D = null
var drop_table: Array = [
  {"item_id": "질긴 슬라임 조각", "image_path": "res://resources/images/items/질긴 슬라임 조각.png", "weight": 30},
  {"item_id": "번개 먹은 배터리 껍질", "image_path": "res://resources/images/items/번개 먹은 배터리 껍질.png", "weight": 70},
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
var penalty_min: int = 5
var penalty_max: int = 10
var sprite_scale: float = 0.24
var collision_shape_path: String = ""
var collision_base_scale: float = 0.0
var collision_rotation: float = 0.0
var key_world_index: int = -1  # >= 0 이면 사망 시 해당 월드 열쇠 드롭
var boss_reward: int = 0  # > 0 이면 사망 시 해당 금액 코인 드롭 (클리어 후 보상)
var boss_potion: String = ""  # 비어있지 않으면 사망 시 해당 아이템 드롭
var is_fury_boss: bool = false  # 분노 보스 여부 (사망 시 세션 종료)
var is_boss_entering: bool = false  # 보스 등장 애니메이션 중
var sfx_hit: AudioStreamPlayer

func setup(config: Dictionary) -> void:
  sprite_path = config.sprite_path
  max_health = config.max_health
  health = config.max_health
  wander_speed = config.wander_speed
  drop_table = config.drop_table
  effect_scene_path = config.get("effect_scene", "")
  penalty_min = config.get("penalty_min", 5)
  penalty_max = config.get("penalty_max", 10)
  sprite_scale = config.get("sprite_scale", 0.24)
  collision_shape_path = config.get("collision_shape", "")
  collision_base_scale = config.get("collision_base_scale", 0.0)
  collision_rotation = config.get("collision_rotation", 0.0)
  key_world_index = config.get("key_world_index", -1)
  boss_reward = config.get("boss_reward", 0)
  boss_potion = config.get("boss_potion", "")
  is_fury_boss = config.get("is_fury_boss", false)

func _ready() -> void:
  add_to_group("monsters")
  sfx_hit = AudioStreamPlayer.new()
  sfx_hit.stream = SFX_SLASH
  sfx_hit.volume_db = -3.0
  add_child(sfx_hit)
  _load_textures()
  if sprite and not textures.is_empty():
    sprite.texture = textures[0]
    sprite.scale = Vector2(sprite_scale, sprite_scale)
  if shadow and not textures.is_empty():
    shadow.texture = textures[0]
    shadow.scale = Vector2(sprite_scale * 0.67, sprite_scale * 0.25)
  # Load collision shape from .tres resource
  if collision_shape_path != "":
    var shape_res = load(collision_shape_path)
    hit_shape.shape = shape_res.duplicate()
    hit_shape.rotation = collision_rotation
    # Scale collision for bosses: .tres is designed at base sprite_scale
    if collision_base_scale > 0 and abs(sprite_scale - collision_base_scale) > 0.001:
      var s = sprite_scale / collision_base_scale
      hit_shape.scale = Vector2(s, s)
  _pick_new_wander()
  # Dynamically load effect scene
  if effect_scene_path != "":
    var scene = load(effect_scene_path)
    if scene:
      effect_node = scene.instantiate()
      var effect_scale = sprite_scale / 0.24
      effect_node.scale = Vector2(effect_scale, effect_scale)
      add_child(effect_node)

func _load_textures() -> void:
  if _texture_cache.has(sprite_path):
    textures = _texture_cache[sprite_path].duplicate()
    return
  for i in range(1, 6):
    var path = "%s%d.png" % [sprite_path, i]
    var tex = _load_texture_from_file(path)
    if tex:
      textures.append(tex)
  _texture_cache[sprite_path] = textures.duplicate()

func _load_texture_from_file(res_path: String) -> Texture2D:
  var tex = load(res_path)
  if tex:
    return tex
  return null

func _process(delta: float) -> void:
  if is_boss_entering:
    return

  # Animation
  frame_timer += delta
  if frame_timer >= FRAME_DURATION:
    frame_timer = 0.0
    _advance_frame()

  # Knockback
  if knockback_velocity.length() > 1.0:
    position += knockback_velocity * delta
    knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
    return

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
var knockback_velocity: Vector2 = Vector2.ZERO
const KNOCKBACK_FRICTION: float = 5.0
const ITEM_DROP_CHANCE: float = 0.7

func play_boss_entrance() -> void:
  is_boss_entering = true
  # 스프라이트를 위로 올려놓고 떨어뜨리기
  var drop_height = -600.0
  sprite.position.y = drop_height
  if shadow:
    shadow.modulate.a = 0.1
    shadow.scale = Vector2(sprite_scale * 0.2, sprite_scale * 0.08)
  # 히트박스 비활성화 (착지까지)
  hit_area.set_deferred("monitoring", false)
  hit_area.set_deferred("monitorable", false)

  # 떨어지는 애니메이션
  var tween = create_tween()
  tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
  tween.set_parallel(true)
  tween.tween_property(sprite, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
  if shadow:
    tween.tween_property(shadow, "scale", Vector2(sprite_scale * 0.67, sprite_scale * 0.25), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(shadow, "modulate:a", 0.3, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

  await tween.finished

  # 착지: 카메라 흔들림 + 진동
  var camera = get_tree().get_first_node_in_group("camera")
  if camera and camera.has_method("shake"):
    camera.shake(0.8)
  Input.vibrate_handheld(200)

  # 히트박스 활성화 (행동 시작은 spawner가 is_boss_entering을 해제)
  hit_area.set_deferred("monitoring", true)
  hit_area.set_deferred("monitorable", true)

func take_damage(amount: int, from_global_pos: Variant = null) -> void:
  if is_dead or is_boss_entering:
    return
  health -= amount
  sfx_hit.play()
  # Knockback away from attacker
  if from_global_pos is Vector2:
    var knock_dir = (global_position - from_global_pos).normalized()
    knockback_velocity = knock_dir * GameManager.get_monster_knockback_strength()
  # Hit flash
  sprite.modulate = Color(1, 0.3, 0.3)
  var tween = create_tween()
  tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
  # Effect burst on hit
  if effect_node and effect_node.has_method("burst"):
    effect_node.burst(2)
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

  # Effect burst on death
  if effect_node and effect_node.has_method("burst"):
    effect_node.burst(3)

  # Death effect: slight expand → shake + fade out
  sprite.modulate = Color(1.5, 1.5, 1.5, 1)  # Brief flash

  # Phase 1: Slightly expand (0.1s)
  var tween = create_tween()
  tween.set_parallel(true)
  var death_scale = sprite_scale * 1.33
  tween.tween_property(sprite, "scale", Vector2(death_scale, death_scale), 0.1).set_ease(Tween.EASE_OUT)
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

  # Stop effect
  if effect_node and effect_node.has_method("stop"):
    effect_node.stop()

  await tween2.finished

  if key_world_index >= 0:
    _drop_key()
  elif boss_potion != "":
    _drop_potion()
  elif boss_reward > 0:
    _drop_boss_reward()
  elif is_fury_boss:
    # 분노 보스: 드롭 없이 세션 종료
    GameManager.boss_key_collected.emit(-1)
  else:
    _drop_item()
    # 30% chance to drop a powerup
    if randf() < 0.3:
      var powerup = PowerupScene.instantiate()
      powerup.position = position
      get_parent().add_child(powerup)

  queue_free()

func _drop_item() -> void:
  if randf() > ITEM_DROP_CHANCE:
    return
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

func _drop_boss_reward() -> void:
  GameManager.add_money(boss_reward)
  var FloatingTextScene = preload("res://scenes/ui/floating_text.tscn")
  var ft = FloatingTextScene.instantiate()
  ft.position = position
  get_parent().add_child(ft)
  ft.setup(boss_reward)
  GameManager.boss_key_collected.emit(-1)

func _drop_potion() -> void:
  var player = get_tree().get_first_node_in_group("player")
  if not player:
    return
  var item = DroppedItemScene.instantiate()
  item.setup_potion(boss_potion, player)
  item.ends_session = true
  item.position = position
  get_parent().add_child(item)

func _drop_key() -> void:
  var player = get_tree().get_first_node_in_group("player")
  if not player:
    return
  var item = DroppedItemScene.instantiate()
  item.setup_key(key_world_index, player)
  item.ends_session = true
  item.position = position
  get_parent().add_child(item)

func _roll_drop() -> Variant:
  var total_weight: int = 0
  for drop in drop_table:
    total_weight += drop.weight
  if total_weight <= 0:
    return null
  var roll = randi() % total_weight
  var cumulative: int = 0
  for drop in drop_table:
    cumulative += drop.weight
    if roll < cumulative:
      return drop
  return drop_table[0]

func _draw() -> void:
  pass
