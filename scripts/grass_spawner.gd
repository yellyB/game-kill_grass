extends Node2D

signal grass_cut(position: Vector2, value: int)

@export var chunk_size: float = 400.0
@export var render_distance: int = 2  # Reduced for performance

# Visual rendering with MultiMesh (ONE draw call for all grass!)
var multimesh_instance: MultiMeshInstance2D
var multimesh: MultiMesh

# 황금풀 주변 반짝이 파티클
var sparkle_mm_instance: MultiMeshInstance2D
var sparkle_mm: MultiMesh
const SPARKLES_PER_GOLDEN: int = 3
const SPARKLE_RADIUS: float = 30.0

# Grass data storage (no nodes, just data)
var grass_data: Dictionary = {}  # Key: Vector2i (grid pos), Value: {cut: bool, type: int, regen_time: float}
var loaded_chunks: Dictionary = {}  # Key: Vector2i, Value: Array of grid positions

# Grid-based positioning (no spacing calculation needed)
var grid_cell_size: float = 40.0  # Base spacing between grass

# 월드별 풀 메시 색상 (base=밑동, tip=끝)
const WORLD_GRASS_TINTS: Array = [
  {"base": Color(0.3, 0.7, 0.3), "tip": Color(0.2, 0.5, 0.2)},    # 0: 슬라임 늪
  {"base": Color(0.82, 0.7, 0.45), "tip": Color(0.72, 0.6, 0.35)}, # 1: 들판 - 밝은 갈색
  {"base": Color(0.55, 0.68, 0.85), "tip": Color(0.45, 0.58, 0.78)}, # 2: 마법의 숲 - 밝은 청남색
  {"base": Color(0.75, 0.48, 0.4), "tip": Color(0.6, 0.38, 0.3)}, # 3: 용의 봉우리 - 채도 낮은 빨강
]

# 월드별 풀 타입(0기본,1강한,2센,3황금) 인스턴스 색상
# null이면 원본 GrassData.color 사용
const WORLD_GRASS_COLORS: Array = [
  # 0: 슬라임 늪 - 기본/강한풀 밝게, 센풀 약간 어둡게
  [Color(0.22, 0.5, 0.22), Color(0.32, 0.65, 0.32), Color(0.45, 0.85, 0.45), null],
  # 1: 들판 - 배경 대비 밝게, 센 풀일수록 더 밝은 갈색
  [Color(0.8, 0.65, 0.42), Color(0.88, 0.74, 0.5), Color(0.95, 0.82, 0.58), null],
  # 2: 마법의 숲 - 배경 대비 확 밝게, 센 풀일수록 더 밝은 파란빛
  [Color(0.5, 0.6, 0.8), Color(0.6, 0.72, 0.9), Color(0.72, 0.82, 1.0), null],
  # 3: 용의 봉우리 - 채도 낮춤, 명도 차이 확연
  [Color(0.58, 0.38, 0.32), Color(0.75, 0.45, 0.35), Color(0.92, 0.55, 0.42), null],
]

var player: Node2D = null
var player_attack_area: Area2D = null

func _ready() -> void:
  setup_multimesh()
  setup_sparkle_multimesh()
  call_deferred("find_player")
  GameManager.upgrade_purchased.connect(_on_upgrade_purchased)
  GameManager.golden_bloom_requested.connect(_on_golden_bloom)
  GameManager.field_clear_requested.connect(_on_field_clear)
  GameManager.blackhole_requested.connect(_on_blackhole)

func setup_multimesh() -> void:
  # Create MultiMesh for efficient grass rendering
  multimesh = MultiMesh.new()
  multimesh.transform_format = MultiMesh.TRANSFORM_2D
  multimesh.use_colors = true
  multimesh.mesh = create_grass_mesh()
  multimesh.instance_count = 0

  multimesh_instance = MultiMeshInstance2D.new()
  multimesh_instance.multimesh = multimesh

  # Apply grass sway shader (GPU-based animation - zero CPU cost!)
  var grass_shader = load("res://resources/shaders/grass_sway.gdshader")
  if grass_shader:
    var shader_mat = ShaderMaterial.new()
    shader_mat.shader = grass_shader
    multimesh_instance.material = shader_mat

  add_child(multimesh_instance)

func setup_sparkle_multimesh() -> void:
  sparkle_mm = MultiMesh.new()
  sparkle_mm.transform_format = MultiMesh.TRANSFORM_2D
  sparkle_mm.use_colors = true
  sparkle_mm.mesh = create_sparkle_mesh()
  sparkle_mm.instance_count = 0

  sparkle_mm_instance = MultiMeshInstance2D.new()
  sparkle_mm_instance.multimesh = sparkle_mm

  var sparkle_shader = load("res://resources/shaders/golden_sparkle.gdshader")
  if sparkle_shader:
    var mat = ShaderMaterial.new()
    mat.shader = sparkle_shader
    sparkle_mm_instance.material = mat

  add_child(sparkle_mm_instance)

func create_sparkle_mesh() -> ArrayMesh:
  var mesh = ArrayMesh.new()
  var s = 5.0  # 반짝이 크기
  var vertices = PackedVector2Array([
    Vector2(-s, -s), Vector2(s, -s), Vector2(s, s),
    Vector2(-s, -s), Vector2(s, s), Vector2(-s, s),
  ])
  var colors = PackedColorArray([
    Color.WHITE, Color.WHITE, Color.WHITE,
    Color.WHITE, Color.WHITE, Color.WHITE,
  ])
  var arrays = []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX] = vertices
  arrays[Mesh.ARRAY_COLOR] = colors
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
  return mesh

func create_grass_mesh() -> ArrayMesh:
  # Simple triangle mesh for grass blade
  var mesh = ArrayMesh.new()
  var vertices = PackedVector2Array([
    Vector2(-6, 0),
    Vector2(6, 0),
    Vector2(0, -50)
  ])
  var world = GameManager.selected_world
  var tint = WORLD_GRASS_TINTS[world] if world < WORLD_GRASS_TINTS.size() else WORLD_GRASS_TINTS[0]
  var colors = PackedColorArray([
    tint.base,
    tint.base,
    tint.tip,
  ])
  var arrays = []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX] = vertices
  arrays[Mesh.ARRAY_COLOR] = colors
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
  return mesh

func find_player() -> void:
  player = get_tree().get_first_node_in_group("player")
  if player:
    player_attack_area = player.get_node_or_null("AttackArea")
    update_chunks()

func _on_upgrade_purchased(upgrade_type: String, _level: int) -> void:
  if upgrade_type == "grass_density":
    # Clear and rebuild all
    grass_data.clear()
    loaded_chunks.clear()
    update_chunks()

func _process(delta: float) -> void:
  if not player:
    return

  update_chunks()
  process_regen(delta)
  update_multimesh()

func get_chunk_coord(world_pos: Vector2) -> Vector2i:
  return Vector2i(floori(world_pos.x / chunk_size), floori(world_pos.y / chunk_size))

func update_chunks() -> void:
  var relative_player_pos = player.global_position - global_position
  var player_chunk = get_chunk_coord(relative_player_pos)
  var chunks_to_keep: Dictionary = {}

  for x in range(-render_distance, render_distance + 1):
    for y in range(-render_distance, render_distance + 1):
      var chunk_coord = Vector2i(player_chunk.x + x, player_chunk.y + y)
      chunks_to_keep[chunk_coord] = true
      if not loaded_chunks.has(chunk_coord):
        load_chunk(chunk_coord)

  # Unload distant chunks
  for chunk_coord in loaded_chunks.keys():
    if not chunks_to_keep.has(chunk_coord):
      unload_chunk(chunk_coord)

func load_chunk(chunk_coord: Vector2i) -> void:
  if loaded_chunks.has(chunk_coord):
    return

  var positions: Array[Vector2i] = []
  var chunk_origin = Vector2(chunk_coord.x * chunk_size, chunk_coord.y * chunk_size)

  # Get density - affects grid spacing
  # Level 0: cell_size = 100 (very sparse), Level 10: cell_size = 16 (dense)
  var density_level = GameManager.get_grass_density_level()
  var cell_size = grid_cell_size * 2.5 / (1.0 + density_level * 0.525)

  var rng = RandomNumberGenerator.new()
  rng.seed = hash(chunk_coord)

  # Grid-based spawning with randomized positions for natural look
  var cells_per_side = int(chunk_size / cell_size)
  for gx in cells_per_side:
    for gy in cells_per_side:
      # Random offset symmetric around cell center for seamless chunk transitions
      var offset_x = rng.randf_range(-cell_size * 0.5, cell_size * 0.5)
      var offset_y = rng.randf_range(-cell_size * 0.5, cell_size * 0.5)
      var world_x = chunk_origin.x + gx * cell_size + cell_size * 0.5 + offset_x
      var world_y = chunk_origin.y + gy * cell_size + cell_size * 0.5 + offset_y
      var grid_pos = Vector2i(int(world_x), int(world_y))

      if not grass_data.has(grid_pos):
        var gd = GameManager.get_random_grass_data()
        var base_regen = gd.regen_time if gd else 5.0
        grass_data[grid_pos] = {
          "cut": false,
          "type": get_grass_type_index(gd),
          "health": gd.max_health if gd else 1,
          "max_health": gd.max_health if gd else 1,
          "regen_time": GameManager.get_grass_regen_time(base_regen),
          "regen_timer": 0.0,
          "value": randi_range(gd.min_drop_value, gd.max_drop_value) if gd else 1
        }
        positions.append(grid_pos)

  loaded_chunks[chunk_coord] = positions

func unload_chunk(chunk_coord: Vector2i) -> void:
  if not loaded_chunks.has(chunk_coord):
    return

  var positions = loaded_chunks[chunk_coord]
  for grid_pos in positions:
    grass_data.erase(grid_pos)

  loaded_chunks.erase(chunk_coord)

func get_grass_type_index(gd: GrassData) -> int:
  if not gd:
    return 0
  for i in GameManager.grass_data_list.size():
    if GameManager.grass_data_list[i] == gd:
      return i
  return 0

func process_regen(delta: float) -> void:
  for grid_pos in grass_data:
    var data = grass_data[grid_pos]
    # Process hit flash timer
    if data.has("hit_timer") and data.hit_timer > 0:
      data.hit_timer -= delta
    if data.cut:
      data.regen_timer += delta
      if data.regen_timer >= data.regen_time:
        # Regenerate with new random type
        var gd = GameManager.get_random_grass_data()
        var base_regen = gd.regen_time if gd else 5.0
        data.cut = false
        data.type = get_grass_type_index(gd)
        data.health = gd.max_health if gd else 1
        data.max_health = gd.max_health if gd else 1
        data.regen_time = GameManager.get_grass_regen_time(base_regen)
        data.regen_timer = 0.0
        data.value = randi_range(gd.min_drop_value, gd.max_drop_value) if gd else 1

func _get_grass_color(grass_type: int) -> Color:
  # 황금풀(3): 월드 무관 샛노란색 + alpha 마커(셰이더 반짝이용)
  if grass_type == 3:
    return Color(1.0, 0.95, 0.1, 0.5)
  var world = GameManager.selected_world
  if world < WORLD_GRASS_COLORS.size() and WORLD_GRASS_COLORS[world] != null:
    var world_colors = WORLD_GRASS_COLORS[world]
    if grass_type < world_colors.size() and world_colors[grass_type] != null:
      return world_colors[grass_type]
  # 월드 오버라이드 없으면 GrassData 원본 사용
  var gd = GameManager.grass_data_list[grass_type] if grass_type < GameManager.grass_data_list.size() else null
  return gd.color if gd else Color(0.3, 0.7, 0.3)

func update_multimesh() -> void:
  var visible_grass: Array = []
  var colors_list: Array = []
  var golden_positions: Array = []

  for grid_pos in grass_data:
    var data = grass_data[grid_pos]
    # Skip cut grass - don't render it
    if data.cut:
      continue

    var world_pos = Vector2(grid_pos.x, grid_pos.y)
    visible_grass.append(world_pos)

    # Check if grass was recently hit - show white flash (preserve golden alpha marker)
    if data.has("hit_timer") and data.hit_timer > 0:
      var flash_alpha = 0.5 if data.type == 3 else 1.0
      colors_list.append(Color(1.0, 1.0, 1.0, flash_alpha))
    else:
      colors_list.append(_get_grass_color(data.type))

    if data.type == 3:
      golden_positions.append(world_pos)

  multimesh.instance_count = visible_grass.size()

  for i in visible_grass.size():
    var t = Transform2D()
    t.origin = visible_grass[i]
    multimesh.set_instance_transform_2d(i, t)
    multimesh.set_instance_color(i, colors_list[i])

  # 황금풀 주변 반짝이 업데이트
  update_sparkles(golden_positions)

func update_sparkles(golden_positions: Array) -> void:
  var total = golden_positions.size() * SPARKLES_PER_GOLDEN
  sparkle_mm.instance_count = total
  var idx = 0
  for gpos in golden_positions:
    # 위치 기반 시드로 안정적인 랜덤 오프셋
    var seed_val = hash(Vector2i(int(gpos.x), int(gpos.y)))
    for j in SPARKLES_PER_GOLDEN:
      var angle = fmod(float(seed_val + j * 2654435761) / 2147483647.0, 1.0) * TAU
      var dist = fmod(float(seed_val + j * 1013904223) / 2147483647.0, 1.0) * SPARKLE_RADIUS + 10.0
      var offset = Vector2(cos(angle) * dist, sin(angle) * dist - 20.0)
      var t = Transform2D()
      t.origin = gpos + offset
      sparkle_mm.set_instance_transform_2d(idx, t)
      sparkle_mm.set_instance_color(idx, Color(1.0, 1.0, 0.7, 1.0))
      idx += 1

# Called by player to attack grass in range
func attack_grass_in_area(center: Vector2, radius: float) -> int:
  var total_value = 0
  var attacked_positions: Array = []
  var damage = WeaponManager.get_weapon_damage()

  for grid_pos in grass_data:
    var data = grass_data[grid_pos]
    if data.cut:
      continue

    var world_pos = Vector2(grid_pos.x, grid_pos.y)
    var distance = center.distance_to(world_pos)

    if distance <= radius:
      data.health -= damage
      data.hit_timer = 0.1  # White flash for 0.1 seconds
      if data.health <= 0:
        data.cut = true
        data.regen_timer = 0.0
        total_value += data.value
        attacked_positions.append(world_pos)

  # Spawn coins for cut grass (20% drop chance, 황금풀 100%)
  for pos in attacked_positions:
    var grid_pos = Vector2i(int(pos.x), int(pos.y))
    if grass_data.has(grid_pos):
      var is_golden = grass_data[grid_pos].type == 3
      if is_golden or randf() < 0.2:
        spawn_coin(pos, grass_data[grid_pos].value)
      # 1% chance to drop a powerup
      if randf() < 0.01:
        spawn_powerup(pos)

  return total_value

func spawn_coin(pos: Vector2, value: int) -> void:
  var CoinScene = preload("res://scenes/world/coin.tscn")
  var coin = CoinScene.instantiate()
  coin.position = pos
  coin.set_value(value)
  get_parent().add_child(coin)

func spawn_powerup(pos: Vector2) -> void:
  var PowerupScene = preload("res://scenes/world/powerup.tscn")
  var powerup = PowerupScene.instantiate()
  powerup.position = pos
  get_parent().add_child(powerup)

func _on_golden_bloom() -> void:
  if not player:
    return
  var center = player.global_position - global_position
  var bloom_radius = chunk_size * 0.5  # ~1/4 of a grid area
  var golden_data = GameManager.grass_data_list[3]
  for grid_pos in grass_data:
    var data = grass_data[grid_pos]
    if data.cut or data.type == 3:
      continue
    var world_pos = Vector2(grid_pos.x, grid_pos.y)
    if center.distance_to(world_pos) <= bloom_radius:
      data.type = 3
      data.health = golden_data.max_health
      data.max_health = golden_data.max_health
      data.value = randi_range(golden_data.min_drop_value, golden_data.max_drop_value)

func _on_field_clear() -> void:
  for grid_pos in grass_data:
    var data = grass_data[grid_pos]
    if data.cut:
      continue
    data.cut = true
    data.regen_timer = 0.0
    var pos = Vector2(grid_pos.x, grid_pos.y)
    # Spawn coins for valuable grass
    if data.type == 3 or randf() < 0.2:
      spawn_coin(pos, data.value)

func _on_blackhole() -> void:
  var coins = get_tree().get_nodes_in_group("coins")
  for coin in coins:
    if is_instance_valid(coin) and not coin.is_collected:
      coin.is_being_collected = true
