extends Node2D

signal input_direction_changed(direction: Vector2)
signal player_hit

const FloatingTextScene = preload("res://scenes/ui/floating_text.tscn")
const SFX_GRASS = preload("res://resources/sounds/effect/grass_swoosh.wav")
const SFX_COIN = preload("res://resources/sounds/effect/pick_coin.wav")

@export var move_speed: float = 300.0

# Debug settings
const DEBUG_SHOW_RANGES: bool = true

# Hit penalty
var is_hit_debuffed: bool = false
var is_invincible: bool = false
var hit_debuff_timer: float = 0.0
var invincible_timer: float = 0.0
const HIT_DEBUFF_DURATION: float = 1.5
const INVINCIBLE_DURATION: float = 3.0
const MONSTER_HIT_RADIUS: float = 45.0
var _hit_overlay_canvas: CanvasLayer = null

@onready var player_visual: Node2D = $PlayerVisual
@onready var attack_timer: Timer = $AttackTimer
@onready var weapon_pivot: Node2D = $WeaponPivot

# Weapon visual nodes (created dynamically)
var blade: Node2D = null

# Body parts for animation
@onready var left_leg: Polygon2D = $PlayerVisual/LeftLeg
@onready var right_leg: Polygon2D = $PlayerVisual/RightLeg
@onready var left_arm: Polygon2D = $PlayerVisual/LeftArm
@onready var right_arm: Polygon2D = $PlayerVisual/RightArm
@onready var body: Polygon2D = $PlayerVisual/Body

var input_direction: Vector2 = Vector2.ZERO
var can_attack: bool = true
var target_weapon_angle: float = 0.0
var is_swinging: bool = false
var walk_time: float = 0.0
var weapon_base_scale: Vector2 = Vector2.ONE  # Store weapon's base scale
var grass_spawner: Node2D = null
var attack_radius: float = 80.0
var attack_area: Area2D = null
var attack_shape: CollisionShape2D = null

# Coin text batching
const BATCH_TIMEOUT: float = 0.3
var batch_total: int = 0
var batch_timer: float = 0.0
var batch_active: bool = false
var batch_floating_text: Node2D = null
var sfx_grass_player: AudioStreamPlayer
var sfx_coin_player: AudioStreamPlayer

func _ready() -> void:
  sfx_grass_player = AudioStreamPlayer.new()
  sfx_grass_player.stream = SFX_GRASS
  sfx_grass_player.volume_db = -5.0
  add_child(sfx_grass_player)
  sfx_coin_player = AudioStreamPlayer.new()
  sfx_coin_player.stream = SFX_COIN
  sfx_coin_player.volume_db = -8.0
  add_child(sfx_coin_player)
  # Create attack area for collision-based hit detection
  attack_area = Area2D.new()
  attack_area.collision_layer = 0
  attack_area.collision_mask = 8  # layer 4: hittable
  attack_shape = CollisionShape2D.new()
  attack_shape.debug_color = Color(1.0, 0.2, 0.2, 0.3)
  var shape = CircleShape2D.new()
  shape.radius = attack_radius
  attack_shape.shape = shape
  attack_area.add_child(attack_shape)
  add_child(attack_area)
  attack_timer.timeout.connect(_on_attack_timer_timeout)
  update_attack_range()
  create_weapon_visual()
  # 세션 시작 후 1초간 행동 불가 + 하늘에서 떨어지는 애니메이션
  set_process(false)
  player_visual.visible = false
  weapon_pivot.visible = false
  await get_tree().process_frame
  player_visual.visible = true
  weapon_pivot.visible = true
  _play_drop_animation()
  GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
  GameManager.powerup_acquired.connect(_on_powerup_acquired)
  GameManager.timed_buff_started.connect(_on_timed_buff_changed)
  GameManager.timed_buff_ended.connect(_on_timed_buff_ended)
  WeaponManager.weapon_changed.connect(_on_weapon_changed)
  queue_redraw()  # For debug drawing
  # Find grass spawner
  call_deferred("find_grass_spawner")

func find_grass_spawner() -> void:
  grass_spawner = get_tree().get_first_node_in_group("grass_spawner")
  if not grass_spawner:
    # Try to find by path
    var world_root = get_parent()
    if world_root:
      grass_spawner = world_root.get_node_or_null("GrassSpawner")

func _process(delta: float) -> void:
  # Monster collision check
  _check_monster_collision()

  # Hit debuff timer
  if is_hit_debuffed:
    hit_debuff_timer -= delta
    if hit_debuff_timer <= 0:
      is_hit_debuffed = false
      GameManager.hit_penalty_active = false
      _remove_hit_overlay()

  # Invincible timer
  if is_invincible:
    invincible_timer -= delta
    if invincible_timer <= 0:
      is_invincible = false

  # Update attack area position
  input_direction = get_input_direction()
  if input_direction != Vector2.ZERO:
    attack_area.position = input_direction * (attack_radius * 0.5)
  else:
    attack_area.position = Vector2.ZERO
  input_direction_changed.emit(input_direction)

  if input_direction != Vector2.ZERO:
    update_sprite_direction()
    update_weapon_direction(delta)
    update_walk_animation(delta)
  else:
    reset_walk_animation(delta)

  try_attack()

  # Coin text batch timer
  if batch_active:
    batch_timer -= delta
    if batch_timer <= 0:
      _finish_batch()

func get_input_direction() -> Vector2:
  var direction = Vector2.ZERO

  # Keyboard input
  direction.x = Input.get_axis("move_left", "move_right")
  direction.y = Input.get_axis("move_up", "move_down")

  return direction.normalized()

func update_sprite_direction() -> void:
  if input_direction.x < 0:
    player_visual.scale.x = -1
  elif input_direction.x > 0:
    player_visual.scale.x = 1

func update_walk_animation(delta: float) -> void:
  walk_time += delta * 12.0  # Speed of animation

  var leg_swing = sin(walk_time) * 0.4
  var arm_swing = sin(walk_time) * 0.3
  var body_bob = abs(sin(walk_time * 2)) * 2.0

  # Legs swing opposite to each other
  left_leg.rotation = leg_swing
  right_leg.rotation = -leg_swing

  # Arms swing opposite to legs
  left_arm.rotation = -arm_swing
  right_arm.rotation = arm_swing

  # Slight body bob
  body.position.y = -body_bob

func reset_walk_animation(delta: float) -> void:
  # Smoothly return to idle pose
  var lerp_speed = delta * 8.0

  left_leg.rotation = lerp(left_leg.rotation, 0.0, lerp_speed)
  right_leg.rotation = lerp(right_leg.rotation, 0.0, lerp_speed)
  left_arm.rotation = lerp(left_arm.rotation, 0.0, lerp_speed)
  right_arm.rotation = lerp(right_arm.rotation, 0.0, lerp_speed)
  body.position.y = lerp(body.position.y, 0.0, lerp_speed)

func update_weapon_direction(delta: float) -> void:
  if is_swinging:
    return
  # Point weapon in movement direction
  target_weapon_angle = input_direction.angle() + PI / 2
  weapon_pivot.rotation = lerp_angle(weapon_pivot.rotation, target_weapon_angle, delta * 15.0)

func try_attack() -> void:
  if not can_attack:
    return
  if not grass_spawner:
    return

  # Calculate attack position (slightly in front of player in movement direction)
  var attack_center = global_position
  if input_direction != Vector2.ZERO:
    attack_center += input_direction * (attack_radius * 0.5)

  # Check if anything is in range before attacking
  if not _has_targets_in_range(attack_center, attack_radius):
    return

  can_attack = false
  var weapon_speed = GameManager.get_session_attack_speed_mult()
  var wait = 0.38 / weapon_speed
  attack_timer.wait_time = wait
  attack_timer.start()

  # Attack monsters first (priority)
  _attack_monsters_in_area(attack_center, attack_radius)

  # Then attack grass
  var local_attack_center = attack_center - grass_spawner.global_position
  var result = grass_spawner.attack_grass_in_area(local_attack_center, attack_radius)

  # Play sound when weapon hits grass
  if result.hit:
    sfx_grass_player.play()

  # Swing animation
  var target_pos = attack_center + input_direction * 30
  swing_weapon(target_pos)

  # Weapon-specific visual effect
  _spawn_weapon_effect(input_direction)

func _has_targets_in_range(center: Vector2, radius: float) -> bool:
  # Check hittable objects via collision overlap
  if attack_area.get_overlapping_areas().size() > 0:
    return true
  # Check grass (no collision shape, use distance)
  var local_center = center - grass_spawner.global_position
  for grid_pos in grass_spawner.grass_data:
    var data = grass_spawner.grass_data[grid_pos]
    if data.cut:
      continue
    var world_pos = Vector2(grid_pos.x, grid_pos.y)
    if local_center.distance_to(world_pos) <= radius:
      return true
  return false

func swing_weapon(target_pos: Vector2) -> void:
  is_swinging = true

  var direction_to_target = (target_pos - global_position).normalized()
  var target_angle = direction_to_target.angle() + PI / 2

  var swing_start = target_angle - PI / 3
  var swing_end = target_angle + PI / 3

  weapon_pivot.rotation = swing_start

  var tween = create_tween()
  tween.set_ease(Tween.EASE_OUT)
  tween.set_trans(Tween.TRANS_QUART)
  tween.tween_property(weapon_pivot, "rotation", swing_end, 0.1)

  if blade:
    blade.scale = weapon_base_scale * 1.3
    tween.parallel().tween_property(blade, "scale", weapon_base_scale, 0.1)

  await tween.finished
  is_swinging = false

func update_attack_range() -> void:
  const BASE_ATTACK_RANGE: float = 80.0
  var weapon_range = GameManager.get_session_attack_range_mult()
  attack_radius = BASE_ATTACK_RANGE * weapon_range
  if attack_shape and attack_shape.shape:
    (attack_shape.shape as CircleShape2D).radius = attack_radius

func create_weapon_visual() -> void:
  if blade:
    blade.queue_free()
    blade = null

  blade = create_weapon_sprite()
  if blade:
    weapon_pivot.add_child(blade)

func create_weapon_sprite() -> Sprite2D:
  var sprite = Sprite2D.new()
  var texture = WeaponManager.get_weapon_texture()
  if texture == null:
    push_warning("Weapon texture not loaded!")
    return sprite
  sprite.texture = texture
  # Scale to match player size
  var target_size = 140.0
  var max_dimension = max(texture.get_width(), texture.get_height())
  var scale_factor = target_size / max_dimension
  weapon_base_scale = Vector2(scale_factor, scale_factor)
  sprite.scale = weapon_base_scale
  # Offset is in local space (before scale), so use original texture size
  sprite.offset = Vector2(0, -texture.get_height() / 2.0)
  return sprite


func _attack_monsters_in_area(_center: Vector2, _radius: float) -> void:
  var damage = WeaponManager.get_weapon_damage()
  for area in attack_area.get_overlapping_areas():
    var target = area.get_parent()
    if is_instance_valid(target) and target.has_method("take_damage"):
      target.take_damage(damage, global_position)

func _play_drop_animation() -> void:
  var start_offset = -800.0
  player_visual.position.y = start_offset
  weapon_pivot.position.y = start_offset
  # 그림자 (착지 지점 = 발 위치에 고정)
  var shadow = Sprite2D.new()
  shadow.texture = PlaceholderTexture2D.new()
  shadow.texture.size = Vector2(60, 16)
  shadow.position = Vector2(0, 28)
  shadow.modulate = Color(0, 0, 0, 0.15)
  shadow.scale = Vector2(0.3, 0.3)
  add_child(shadow)
  # 떨어지는 애니메이션 (바운스 이징)
  var tween = create_tween()
  tween.set_parallel(true)
  tween.tween_property(player_visual, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
  tween.tween_property(weapon_pivot, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
  # 그림자: 스케일만 변화 (위치 고정)
  tween.tween_property(shadow, "scale", Vector2(1.0, 1.0), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  tween.tween_property(shadow, "modulate:a", 0.3, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  tween.chain().tween_property(shadow, "modulate:a", 0.0, 0.3)
  tween.chain().tween_callback(shadow.queue_free)
  tween.chain().tween_callback(func(): set_process(true))

func _on_attack_timer_timeout() -> void:
  can_attack = true

func _on_upgrade_purchased(_upgrade_type: String, _level: int) -> void:
  pass

func _on_powerup_acquired(type: String, _level: int) -> void:
  if type == "attack_range":
    update_attack_range()
  if type == "magnet_range":
    queue_redraw()

func _on_timed_buff_changed(_type: String, _duration: float) -> void:
  update_attack_range()
  queue_redraw()

func _on_timed_buff_ended(_type: String) -> void:
  update_attack_range()
  queue_redraw()

func _on_weapon_changed(_level: int) -> void:
  update_attack_range()
  create_weapon_visual()

func _on_magnet_range_changed() -> void:
  queue_redraw()

# Mobile touch input support
var touch_start_pos: Vector2 = Vector2.ZERO
var is_touching: bool = false

func _input(event: InputEvent) -> void:
  if event is InputEventScreenTouch:
    if event.pressed:
      is_touching = true
      touch_start_pos = event.position
    else:
      is_touching = false
      input_direction = Vector2.ZERO
  elif event is InputEventScreenDrag:
    if is_touching:
      var drag_vector = event.position - touch_start_pos
      if drag_vector.length() > 20:
        input_direction = drag_vector.normalized()

func accumulate_coin_text(value: int) -> void:
  sfx_coin_player.play()
  if batch_active and is_instance_valid(batch_floating_text):
    # Add to existing batch
    batch_total += value
    batch_timer = BATCH_TIMEOUT
    batch_floating_text.update_batch(batch_total)
  else:
    # Start new batch
    batch_total = value
    batch_timer = BATCH_TIMEOUT
    batch_active = true
    _spawn_batch_text()

func _spawn_batch_text() -> void:
  batch_floating_text = FloatingTextScene.instantiate()
  # Position above player head
  batch_floating_text.position = Vector2(0, -70)
  add_child(batch_floating_text)
  batch_floating_text.start_batch(batch_total)

func _finish_batch() -> void:
  batch_active = false
  if is_instance_valid(batch_floating_text):
    batch_floating_text.finish_batch()
  batch_floating_text = null
  batch_total = 0

func _check_monster_collision() -> void:
  if is_invincible:
    return
  for monster in get_tree().get_nodes_in_group("monsters"):
    if not is_instance_valid(monster):
      continue
    if global_position.distance_to(monster.global_position) < MONSTER_HIT_RADIUS:
      _on_monster_hit(monster)
      return

func _on_monster_hit(monster: Node2D) -> void:
  is_hit_debuffed = true
  is_invincible = true
  hit_debuff_timer = HIT_DEBUFF_DURATION
  invincible_timer = INVINCIBLE_DURATION
  GameManager.hit_penalty_active = true
  player_hit.emit()
  var penalty_amount = int(randi_range(monster.penalty_min, monster.penalty_max) * GameManager.get_part_penalty_mult())
  _drop_penalty_coins(penalty_amount)
  # Red screen overlay for debuff duration
  _show_hit_overlay()

func _drop_penalty_coins(penalty: int) -> void:
  # Always show scatter coins visual
  var coin_count = randi_range(7, 10)
  for i in coin_count:
    _spawn_scatter_coin()
  if penalty <= 0 or GameManager.session_money <= 0:
    return
  penalty = mini(penalty, GameManager.session_money)
  GameManager.add_money(-penalty)
  # Show penalty floating text
  var penalty_text = FloatingTextScene.instantiate()
  penalty_text.position = Vector2(0, -70)
  add_child(penalty_text)
  penalty_text.setup_penalty(penalty)

func _spawn_scatter_coin() -> void:
  var coin = Node2D.new()
  coin.position = Vector2.ZERO
  coin.z_index = 10
  add_child(coin)

  # Coin visual (circle)
  var poly = Polygon2D.new()
  var points: PackedVector2Array = []
  for j in 10:
    var angle = TAU / 10.0 * j
    points.append(Vector2(cos(angle), sin(angle)) * 12.0)
  poly.polygon = points
  poly.color = Color(1.0, 0.85, 0.0)
  coin.add_child(poly)

  # Random outward direction
  var dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
  var fly_dist = randf_range(80, 160)
  var target = coin.position + dir * fly_dist

  # Fly outward then fade
  var tw = create_tween()
  tw.tween_property(coin, "position", target, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
  tw.tween_property(coin, "modulate:a", 0.0, 0.3)
  tw.tween_callback(coin.queue_free)

func _show_hit_overlay() -> void:
  _remove_hit_overlay()
  _hit_overlay_canvas = CanvasLayer.new()
  _hit_overlay_canvas.layer = 90
  get_tree().root.add_child(_hit_overlay_canvas)
  var overlay = ColorRect.new()
  overlay.color = Color(1, 0, 0, 0.15)
  overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
  overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _hit_overlay_canvas.add_child(overlay)

func _remove_hit_overlay() -> void:
  if is_instance_valid(_hit_overlay_canvas):
    _hit_overlay_canvas.queue_free()
    _hit_overlay_canvas = null

# ── Weapon Effects ──────────────────────────────────────────────

func _spawn_weapon_effect(dir: Vector2) -> void:
  var level = WeaponManager.current_weapon_level
  var fx_offset = dir * (attack_radius * 0.5)
  match level:
    0: pass
    1: _fx_slash_arc(fx_offset, dir)
    2: _fx_spin_circle(fx_offset)
    3: _fx_electric_flash(fx_offset)
    4: _fx_heat_glow(fx_offset)
    5: _fx_scratch_lines(fx_offset, dir)
    6: _fx_chainsaw_blur(fx_offset, dir)
    7: _fx_magic_orb(fx_offset, dir)
    8: _fx_wind_beam(fx_offset, dir)
    9: _fx_satellite_laser(fx_offset)

# Lv1 녹슨 식칼 — white slash arc
func _fx_slash_arc(pos: Vector2, dir: Vector2) -> void:
  var line = Line2D.new()
  line.position = pos
  line.width = 4.0
  line.default_color = Color(1, 1, 1, 0.8)
  var base_angle = dir.angle()
  var arc_radius = 40.0
  for i in range(9):
    var a = base_angle - PI / 6 + (PI / 3) * (float(i) / 8.0)
    line.add_point(Vector2(cos(a), sin(a)) * arc_radius)
  add_child(line)
  var tw = create_tween()
  tw.tween_property(line, "modulate:a", 0.0, 0.15)
  tw.tween_callback(line.queue_free)

# Lv2 피자 커터 — spinning circle
func _fx_spin_circle(pos: Vector2) -> void:
  var line = Line2D.new()
  line.position = pos
  line.width = 3.0
  line.default_color = Color(0.8, 0.8, 0.85, 0.8)
  var radius = 35.0
  for i in range(17):
    var a = TAU / 16.0 * i
    line.add_point(Vector2(cos(a), sin(a)) * radius)
  add_child(line)
  var tw = create_tween()
  tw.tween_property(line, "rotation", TAU, 0.2)
  tw.parallel().tween_property(line, "modulate:a", 0.0, 0.2)
  tw.tween_callback(line.queue_free)

# Lv3 전기 파리채 — blue lightning + flash
func _fx_electric_flash(pos: Vector2) -> void:
  var electric_color = Color(0.3, 0.6, 1.0, 0.9)
  for i in range(4):
    var line = Line2D.new()
    line.position = pos
    line.width = 2.0
    line.default_color = electric_color
    var angle = randf() * TAU
    var length = randf_range(30, 60)
    var p = Vector2.ZERO
    line.add_point(p)
    var segs = randi_range(3, 5)
    for j in range(segs):
      var step = length / segs
      p += Vector2(cos(angle), sin(angle)) * step
      p += Vector2(randf_range(-8, 8), randf_range(-8, 8))
      line.add_point(p)
    add_child(line)
    var tw = create_tween()
    tw.tween_property(line, "modulate:a", 0.0, 0.12)
    tw.tween_callback(line.queue_free)
  # Blue circle flash
  var flash = _create_circle_polygon(15.0, 12)
  flash.position = pos
  flash.color = Color(0.3, 0.6, 1.0, 0.6)
  add_child(flash)
  var tw2 = create_tween()
  tw2.tween_property(flash, "scale", Vector2(2.5, 2.5), 0.1)
  tw2.parallel().tween_property(flash, "modulate:a", 0.0, 0.1)
  tw2.tween_callback(flash.queue_free)

# Lv4 뜨거운 다리미 — red heat glow + camera shake
func _fx_heat_glow(pos: Vector2) -> void:
  var glow = _create_circle_polygon(30.0, 16)
  glow.position = pos
  glow.color = Color(1.0, 0.2, 0.1, 0.4)
  add_child(glow)
  var tw = create_tween()
  tw.tween_property(glow, "scale", Vector2(1.5, 1.5), 0.2)
  tw.parallel().tween_property(glow, "modulate:a", 0.0, 0.2)
  tw.tween_callback(glow.queue_free)
  var cam = get_viewport().get_camera_2d()
  if cam and cam.has_method("shake"):
    cam.shake(0.15)

# Lv5 매우 화난 고양이 — 3 scratch lines
func _fx_scratch_lines(pos: Vector2, dir: Vector2) -> void:
  var perp = Vector2(-dir.y, dir.x)
  for i in range(3):
    var line = Line2D.new()
    line.position = pos
    line.width = 3.0
    line.default_color = Color(1, 1, 1, 0.9)
    var base_angle = dir.angle() + PI / 4 + randf_range(-0.2, 0.2)
    var offset_perp = perp * (i - 1) * 12.0
    var start_p = offset_perp + Vector2(cos(base_angle), sin(base_angle)) * -25.0
    var end_p = offset_perp + Vector2(cos(base_angle), sin(base_angle)) * 25.0
    line.add_point(start_p)
    line.add_point(end_p)
    add_child(line)
    var tw = create_tween()
    tw.tween_property(line, "modulate:a", 0.0, 0.12)
    tw.tween_callback(line.queue_free)

# Lv6 체인소 — camera shake + orange motion lines
func _fx_chainsaw_blur(pos: Vector2, dir: Vector2) -> void:
  var cam = get_viewport().get_camera_2d()
  if cam and cam.has_method("shake"):
    cam.shake(0.3)
  var orange = Color(1.0, 0.6, 0.2, 0.7)
  var perp = Vector2(-dir.y, dir.x)
  for i in range(3):
    var line = Line2D.new()
    line.position = pos
    line.width = 4.0
    line.default_color = orange
    var p = perp * (i - 1) * 8.0
    line.add_point(p)
    line.add_point(p + dir * randf_range(40, 70))
    add_child(line)
    var tw = create_tween()
    tw.tween_property(line, "modulate:a", 0.0, 0.15)
    tw.tween_callback(line.queue_free)

# Lv7 마법 지팡이 — purple orb with trail
func _fx_magic_orb(pos: Vector2, dir: Vector2) -> void:
  var purple = Color(0.6, 0.2, 1.0, 0.8)
  var container = Node2D.new()
  container.position = pos
  add_child(container)
  # Main orb
  var orb = _create_circle_polygon(10.0, 10)
  orb.color = purple
  container.add_child(orb)
  # Trail orbs
  for i in range(3):
    var trail = _create_circle_polygon(7.0 - i * 2.0, 8)
    trail.color = Color(0.6, 0.2, 1.0, 0.5 - i * 0.15)
    trail.position = -dir * (i + 1) * 15.0
    container.add_child(trail)
  var tw = create_tween()
  tw.tween_property(container, "position", pos + dir * 150.0, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
  tw.parallel().tween_property(container, "modulate:a", 0.0, 0.2).set_delay(0.1)
  tw.tween_callback(container.queue_free)

# Lv8 날개달린 선풍기 — yellow beam with glow
func _fx_wind_beam(pos: Vector2, dir: Vector2) -> void:
  # Glow (wider, behind)
  var glow = Line2D.new()
  glow.position = pos
  glow.width = 16.0
  glow.default_color = Color(1.0, 0.95, 0.3, 0.3)
  glow.add_point(Vector2.ZERO)
  glow.add_point(dir * 200.0)
  add_child(glow)
  # Main beam
  var beam = Line2D.new()
  beam.position = pos
  beam.width = 6.0
  beam.default_color = Color(1.0, 0.95, 0.3, 0.9)
  beam.add_point(Vector2.ZERO)
  beam.add_point(dir * 200.0)
  add_child(beam)
  var tw = create_tween()
  tw.tween_property(beam, "modulate:a", 0.0, 0.15)
  tw.parallel().tween_property(glow, "modulate:a", 0.0, 0.15)
  tw.tween_callback(beam.queue_free)
  tw.tween_callback(glow.queue_free)

# Lv9 위성 레이저 제초기 — red beam
func _fx_satellite_laser(pos: Vector2) -> void:
  # Red vertical beam
  var beam = Line2D.new()
  beam.position = pos
  beam.width = 8.0
  beam.default_color = Color(1.0, 0.15, 0.1, 0.9)
  beam.add_point(Vector2(0, -500))
  beam.add_point(Vector2(0, 500))
  add_child(beam)
  var tw_beam = create_tween()
  tw_beam.tween_property(beam, "modulate:a", 0.0, 0.2)
  tw_beam.tween_callback(beam.queue_free)

# Helper: create a circle Polygon2D
func _create_circle_polygon(radius: float, segments: int) -> Polygon2D:
  var poly = Polygon2D.new()
  var points: PackedVector2Array = []
  for i in range(segments):
    var a = TAU / segments * i
    points.append(Vector2(cos(a), sin(a)) * radius)
  poly.polygon = points
  return poly

func _draw() -> void:
  if not DEBUG_SHOW_RANGES:
    return

  # Draw coin magnet range (blue)
  var magnet_range = GameManager.get_magnet_range()
  draw_arc(Vector2.ZERO, magnet_range, 0, TAU, 32, Color(0.3, 0.5, 1.0, 0.5), 2.0)

  # Draw attack range (red)
  var attack_offset = Vector2.ZERO
  if input_direction != Vector2.ZERO:
    attack_offset = input_direction * (attack_radius * 0.5)
  draw_arc(attack_offset, attack_radius, 0, TAU, 32, Color(1.0, 0.3, 0.3, 0.5), 2.0)
