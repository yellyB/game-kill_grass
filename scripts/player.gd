extends CharacterBody2D

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

@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var player_visual: Node2D = $PlayerVisual
@onready var attack_timer: Timer = $AttackTimer
@onready var weapon_pivot: Node2D = $WeaponPivot

# Weapon visual nodes (created dynamically)
var blade: Node2D = null
var blade2: Node2D = null  # For double scythe
var aura_effect: Node2D = null

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
var spin_angle: float = 0.0  # For continuous spinning weapons
var current_visual_type: String = ""
var weapon_base_scale: Vector2 = Vector2.ONE  # Store weapon's base scale
var grass_spawner: Node2D = null
var attack_radius: float = 80.0

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
  attack_timer.timeout.connect(_on_attack_timer_timeout)
  update_attack_range()
  create_weapon_visual()
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

  # Invincible timer + blinking
  if is_invincible:
    invincible_timer -= delta
    player_visual.modulate.a = 0.3 if fmod(invincible_timer, 0.2) < 0.1 else 1.0
    if invincible_timer <= 0:
      is_invincible = false
      player_visual.modulate.a = 1.0

  input_direction = get_input_direction()
  input_direction_changed.emit(input_direction)

  if input_direction != Vector2.ZERO:
    update_sprite_direction()
    update_weapon_direction(delta)
    update_walk_animation(delta)
    try_attack()
  else:
    reset_walk_animation(delta)

  # Handle continuous weapon animations
  update_continuous_weapon_animation(delta)

  # Coin text batch timer
  if batch_active:
    batch_timer -= delta
    if batch_timer <= 0:
      _finish_batch()

func _physics_process(_delta: float) -> void:
  pass

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

  can_attack = false
  var weapon_speed = WeaponManager.get_weapon_speed() * GameManager.get_session_attack_speed_mult()
  var wait = 0.2 / weapon_speed
  attack_timer.wait_time = wait
  attack_timer.start()

  # Calculate attack position (slightly in front of player in movement direction)
  var attack_center = global_position
  if input_direction != Vector2.ZERO:
    attack_center += input_direction * (attack_radius * 0.5)

  # Convert to grass spawner local coordinates
  var local_attack_center = attack_center - grass_spawner.global_position

  # Attack grass and get total value
  grass_spawner.attack_grass_in_area(local_attack_center, attack_radius)

  # Attack monsters in range
  _attack_monsters_in_area(attack_center, attack_radius)

  # Play attack sound
  sfx_grass_player.play()

  # Swing animation
  var target_pos = attack_center + input_direction * 30
  swing_weapon(target_pos)

func swing_weapon(target_pos: Vector2) -> void:
  var attack_type = WeaponManager.get_attack_type()

  # Different animations based on attack type
  match attack_type:
    "single":
      await swing_single(target_pos)
    "double":
      await swing_double(target_pos)
    "spin":
      # Spin weapons don't need swing animation - they continuously spin
      pass
    "aura", "flame":
      await pulse_attack()
    "screen":
      await screen_attack()
    "world":
      await world_attack()
    _:
      await swing_single(target_pos)

func swing_single(target_pos: Vector2) -> void:
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

func swing_double(target_pos: Vector2) -> void:
  is_swinging = true

  var direction_to_target = (target_pos - global_position).normalized()
  var target_angle = direction_to_target.angle() + PI / 2

  # Full 360 spin for double attack
  weapon_pivot.rotation = target_angle

  var tween = create_tween()
  tween.set_ease(Tween.EASE_IN_OUT)
  tween.set_trans(Tween.TRANS_SINE)
  tween.tween_property(weapon_pivot, "rotation", target_angle + PI * 2, 0.15)

  if blade:
    blade.scale = weapon_base_scale * 1.2
    tween.parallel().tween_property(blade, "scale", weapon_base_scale, 0.15)
  if blade2:
    blade2.scale = weapon_base_scale * 1.2
    tween.parallel().tween_property(blade2, "scale", weapon_base_scale, 0.15)

  await tween.finished
  is_swinging = false

func pulse_attack() -> void:
  is_swinging = true

  # Pulse outward effect - use fixed base scale to prevent accumulation
  if blade:
    var tween = create_tween()
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(blade, "scale", weapon_base_scale * 1.5, 0.05)
    tween.tween_property(blade, "scale", weapon_base_scale, 0.1)
    await tween.finished

  if aura_effect:
    var aura_tween = create_tween()
    aura_tween.set_ease(Tween.EASE_OUT)
    aura_tween.tween_property(aura_effect, "scale", Vector2(1.5, 1.5), 0.05)
    aura_tween.tween_property(aura_effect, "scale", Vector2.ONE, 0.1)

  is_swinging = false

func screen_attack() -> void:
  is_swinging = true

  # Bright flash effect - use fixed base scale
  if blade and blade.has_node("Core"):
    var core = blade.get_node("Core")
    core.scale = Vector2(3.0, 3.0)

    var tween = create_tween()
    tween.tween_property(core, "scale", Vector2.ONE, 0.2)
    await tween.finished

  if aura_effect:
    var ring_tween = create_tween()
    ring_tween.set_ease(Tween.EASE_OUT)
    ring_tween.tween_property(aura_effect, "scale", Vector2(3.0, 3.0), 0.1)
    ring_tween.tween_property(aura_effect, "scale", Vector2.ONE, 0.2)

  is_swinging = false

func world_attack() -> void:
  is_swinging = true

  # Intense glow burst - use fixed base scale
  if blade:
    blade.scale = weapon_base_scale * 2.0

    var tween = create_tween()
    tween.tween_property(blade, "scale", weapon_base_scale, 0.15)
    await tween.finished

  if aura_effect:
    for child in aura_effect.get_children():
      var particle_tween = create_tween()
      var original_pos = child.position
      child.position = original_pos * 0.5
      particle_tween.tween_property(child, "position", original_pos, 0.2)

  is_swinging = false

func update_attack_range() -> void:
  const BASE_ATTACK_RANGE: float = 80.0
  var weapon_range = WeaponManager.get_weapon_range() * GameManager.get_session_attack_range_mult()
  attack_radius = BASE_ATTACK_RANGE * weapon_range

func create_weapon_visual() -> void:
  var visual_type = WeaponManager.get_visual_type()
  var weapon_color = WeaponManager.get_weapon_color()
  var blade_length = WeaponManager.get_blade_length()

  # Clear existing weapon visuals
  if blade:
    blade.queue_free()
    blade = null
  if blade2:
    blade2.queue_free()
    blade2 = null
  if aura_effect:
    aura_effect.queue_free()
    aura_effect = null

  current_visual_type = visual_type

  # Create sprite-based weapon
  blade = create_weapon_sprite()

  # For double scythe, create second blade
  if visual_type == "double_scythe":
    blade2 = create_weapon_sprite()
    blade2.position = Vector2(0, blade_length)
    blade2.rotation = PI

  # Create aura effects for certain weapon types
  match visual_type:
    "machine":
      aura_effect = create_aura_ring(weapon_color)
    "device":
      aura_effect = create_pulse_ring(weapon_color)
    "orb":
      aura_effect = create_world_aura(weapon_color)

  if blade:
    weapon_pivot.add_child(blade)
  if blade2:
    weapon_pivot.add_child(blade2)
  if aura_effect:
    add_child(aura_effect)

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

func create_scythe_blade(color: Color, length: int, width: int) -> Polygon2D:
  var poly = Polygon2D.new()
  var w := float(width)
  var l := float(length)
  # Curved scythe shape
  poly.polygon = PackedVector2Array([
    Vector2(-w / 2.0, 0),
    Vector2(-w / 4.0, -l * 0.3),
    Vector2(0, -l * 0.7),
    Vector2(w / 3.0, -l),
    Vector2(w / 2.0, -l * 0.9),
    Vector2(w / 4.0, -l * 0.6),
    Vector2(w / 4.0, 0)
  ])
  poly.color = color
  return poly

func create_heavy_scythe_blade(color: Color, length: int, width: int) -> Polygon2D:
  var poly = Polygon2D.new()
  var w := float(width)
  var l := float(length)
  # Thicker, heavier scythe
  poly.polygon = PackedVector2Array([
    Vector2(-w / 2.0, 5),
    Vector2(-w / 2.0, -l * 0.2),
    Vector2(-w / 3.0, -l * 0.5),
    Vector2(0, -l * 0.8),
    Vector2(w / 2.0, -l),
    Vector2(w / 2.0, -l * 0.85),
    Vector2(w / 4.0, -l * 0.6),
    Vector2(w / 4.0, 5)
  ])
  poly.color = color
  return poly

func create_spinner_blade(color: Color, length: int, width: int) -> Node2D:
  var container = Node2D.new()
  var w := float(width)
  var l := float(length)
  # Create 3 blades for spinner effect
  for i in 3:
    var poly = Polygon2D.new()
    poly.polygon = PackedVector2Array([
      Vector2(-w / 2.0, 0),
      Vector2(0, -l),
      Vector2(w / 2.0, 0)
    ])
    poly.color = color
    poly.rotation = (2.0 * PI / 3.0) * i
    container.add_child(poly)
  return container

func create_machine_visual(color: Color, size: int) -> Node2D:
  var container = Node2D.new()
  var s := float(size)
  # Circular machine body
  var machine_body = Polygon2D.new()
  var points: PackedVector2Array = []
  for i in 12:
    var angle = (2.0 * PI / 12.0) * i
    points.append(Vector2(cos(angle), sin(angle)) * (s / 2.0))
  machine_body.polygon = points
  machine_body.color = color
  container.add_child(machine_body)

  # Inner circle
  var inner = Polygon2D.new()
  var inner_points: PackedVector2Array = []
  for i in 12:
    var angle = (2.0 * PI / 12.0) * i
    inner_points.append(Vector2(cos(angle), sin(angle)) * (s / 4.0))
  inner.polygon = inner_points
  inner.color = color.darkened(0.3)
  container.add_child(inner)
  return container

func create_flamethrower_visual(color: Color, length: int, width: int) -> Node2D:
  var container = Node2D.new()
  var w := float(width)
  var l := float(length)
  # Nozzle shape
  var nozzle = Polygon2D.new()
  nozzle.polygon = PackedVector2Array([
    Vector2(-w / 3.0, 0),
    Vector2(-w / 2.0, -l * 0.3),
    Vector2(-w / 4.0, -l * 0.6),
    Vector2(0, -l),
    Vector2(w / 4.0, -l * 0.6),
    Vector2(w / 2.0, -l * 0.3),
    Vector2(w / 3.0, 0)
  ])
  nozzle.color = color.darkened(0.2)
  container.add_child(nozzle)

  # Flame tip
  var flame = Polygon2D.new()
  flame.polygon = PackedVector2Array([
    Vector2(-w / 4.0, -l * 0.5),
    Vector2(0, -l * 1.2),
    Vector2(w / 4.0, -l * 0.5)
  ])
  flame.color = Color(1.0, 0.8, 0.2)
  flame.name = "Flame"
  container.add_child(flame)
  return container

func create_device_visual(color: Color, size: int) -> Node2D:
  var container = Node2D.new()
  var s := float(size)
  # Hexagonal device
  var hex = Polygon2D.new()
  var points: PackedVector2Array = []
  for i in 6:
    var angle = (2.0 * PI / 6.0) * i - PI / 6.0
    points.append(Vector2(cos(angle), sin(angle)) * (s / 2.0))
  hex.polygon = points
  hex.color = color
  container.add_child(hex)

  # Core
  var core = Polygon2D.new()
  var core_points: PackedVector2Array = []
  for i in 6:
    var angle = (2.0 * PI / 6.0) * i
    core_points.append(Vector2(cos(angle), sin(angle)) * (s / 5.0))
  core.polygon = core_points
  core.color = Color(1, 1, 1, 0.8)
  core.name = "Core"
  container.add_child(core)
  return container

func create_orb_visual(color: Color, size: int) -> Node2D:
  var container = Node2D.new()
  var s := float(size)
  # Glowing orb (circular)
  var orb = Polygon2D.new()
  var points: PackedVector2Array = []
  for i in 16:
    var angle = (2.0 * PI / 16.0) * i
    points.append(Vector2(cos(angle), sin(angle)) * (s / 2.0))
  orb.polygon = points
  orb.color = color
  orb.name = "Orb"
  container.add_child(orb)

  # Inner glow
  var glow = Polygon2D.new()
  var glow_points: PackedVector2Array = []
  for i in 16:
    var angle = (2.0 * PI / 16.0) * i
    glow_points.append(Vector2(cos(angle), sin(angle)) * (s / 3.0))
  glow.polygon = glow_points
  glow.color = Color(1, 1, 0.8, 0.9)
  glow.name = "Glow"
  container.add_child(glow)
  return container

func create_aura_ring(color: Color) -> Node2D:
  var container = Node2D.new()
  container.name = "AuraEffect"
  # Ring effect
  for i in 8:
    var particle = Polygon2D.new()
    particle.polygon = PackedVector2Array([
      Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5)
    ])
    particle.color = Color(color.r, color.g, color.b, 0.5)
    var angle = (2.0 * PI / 8.0) * i
    particle.position = Vector2(cos(angle), sin(angle)) * 50.0
    particle.name = "Particle" + str(i)
    container.add_child(particle)
  return container

func create_pulse_ring(color: Color) -> Node2D:
  var container = Node2D.new()
  container.name = "PulseRing"
  var ring = Polygon2D.new()
  var points: PackedVector2Array = []
  for i in 24:
    var angle = (2.0 * PI / 24.0) * i
    points.append(Vector2(cos(angle), sin(angle)) * 60.0)
  ring.polygon = points
  ring.color = Color(color.r, color.g, color.b, 0.3)
  ring.name = "Ring"
  container.add_child(ring)
  return container

func create_world_aura(color: Color) -> Node2D:
  var container = Node2D.new()
  container.name = "WorldAura"
  # Multiple orbiting particles
  for i in 12:
    var particle = Polygon2D.new()
    var particle_points: PackedVector2Array = []
    for j in 8:
      var angle = (2.0 * PI / 8.0) * j
      particle_points.append(Vector2(cos(angle), sin(angle)) * 8.0)
    particle.polygon = particle_points
    particle.color = Color(color.r, color.g, color.b, 0.6)
    var orbit_angle = (2.0 * PI / 12.0) * i
    particle.position = Vector2(cos(orbit_angle), sin(orbit_angle)) * 70.0
    particle.name = "OrbitParticle" + str(i)
    container.add_child(particle)
  return container

func update_continuous_weapon_animation(delta: float) -> void:
  var attack_type = WeaponManager.get_attack_type()

  match attack_type:
    "spin":
      # Continuous spinning
      spin_angle += delta * 15.0
      if blade:
        blade.rotation = spin_angle
    "aura":
      # Pulsing aura effect
      if aura_effect:
        var pulse = (sin(Time.get_ticks_msec() * 0.005) + 1.0) / 2.0
        aura_effect.scale = Vector2(1.0 + pulse * 0.3, 1.0 + pulse * 0.3)
        for child in aura_effect.get_children():
          child.rotation += delta * 2.0
      if blade:
        blade.rotation += delta * 3.0
    "flame":
      # Flickering flame
      if blade and blade.has_node("Flame"):
        var flame_node = blade.get_node("Flame")
        var flicker = randf_range(0.8, 1.2)
        flame_node.scale = Vector2(flicker, flicker)
    "screen":
      # Pulsing device
      if blade and blade.has_node("Core"):
        var core_node = blade.get_node("Core")
        var pulse = (sin(Time.get_ticks_msec() * 0.008) + 1.0) / 2.0
        core_node.scale = Vector2(1.0 + pulse * 0.5, 1.0 + pulse * 0.5)
      if aura_effect:
        var ring_pulse = (sin(Time.get_ticks_msec() * 0.003) + 1.0) / 2.0
        aura_effect.scale = Vector2(0.8 + ring_pulse * 0.4, 0.8 + ring_pulse * 0.4)
    "world":
      # Orbiting particles and glowing orb
      if blade and blade.has_node("Orb"):
        var orb_pulse = (sin(Time.get_ticks_msec() * 0.004) + 1.0) / 2.0
        blade.scale = Vector2(1.0 + orb_pulse * 0.2, 1.0 + orb_pulse * 0.2)
      if aura_effect:
        aura_effect.rotation += delta * 1.5
        for child in aura_effect.get_children():
          child.rotation -= delta * 3.0

func _attack_monsters_in_area(center: Vector2, radius: float) -> void:
  var monsters = get_tree().get_nodes_in_group("monsters")
  var damage = WeaponManager.get_weapon_damage()
  for monster in monsters:
    if not is_instance_valid(monster):
      continue
    var dist = monster.global_position.distance_to(center)
    if dist <= radius:
      monster.take_damage(damage)

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
      if drag_vector.length() > 20:  # Dead zone
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
      _on_monster_hit()
      return

func _on_monster_hit() -> void:
  is_hit_debuffed = true
  is_invincible = true
  hit_debuff_timer = HIT_DEBUFF_DURATION
  invincible_timer = INVINCIBLE_DURATION
  GameManager.hit_penalty_active = true
  player_hit.emit()
  _drop_penalty_coins()
  # Red flash
  player_visual.modulate = Color(1, 0.3, 0.3)
  var tween = create_tween()
  tween.tween_property(player_visual, "modulate", Color(1, 1, 1, 1), 0.15)

func _drop_penalty_coins() -> void:
  var penalty = int(GameManager.session_money * 0.05)
  # Always show scatter coins visual
  var coin_count = randi_range(7, 10)
  for i in coin_count:
    _spawn_scatter_coin()
  if penalty <= 0:
    return
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

func _draw() -> void:
  if not DEBUG_SHOW_RANGES:
    return

  # Draw coin magnet range (blue)
  var magnet_range = GameManager.get_magnet_range()
  draw_arc(Vector2.ZERO, magnet_range, 0, TAU, 32, Color(0.3, 0.5, 1.0, 0.5), 2.0)
