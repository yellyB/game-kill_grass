extends Node2D

signal grass_cut(position: Vector2, value: int)

@export var chunk_size: float = 400.0
@export var render_distance: int = 2  # Reduced for performance

# Visual rendering with MultiMesh (ONE draw call for all grass!)
var multimesh_instance: MultiMeshInstance2D
var multimesh: MultiMesh

# Grass data storage (no nodes, just data)
var grass_data: Dictionary = {}  # Key: Vector2i (grid pos), Value: {cut: bool, type: int, regen_time: float}
var loaded_chunks: Dictionary = {}  # Key: Vector2i, Value: Array of grid positions

# Grid-based positioning (no spacing calculation needed)
var grid_cell_size: float = 40.0  # Base spacing between grass

# 월드별 풀 메시 색상 (base=밑동, tip=끝)
const WORLD_GRASS_TINTS: Array = [
  {"base": Color(0.3, 0.7, 0.3), "tip": Color(0.2, 0.5, 0.2)},    # 0: 슬라임 늪
  {"base": Color(0.7, 0.58, 0.35), "tip": Color(0.6, 0.48, 0.25)}, # 1: 들판 - 밝은 갈색
  {"base": Color(0.45, 0.55, 0.68), "tip": Color(0.35, 0.45, 0.6)}, # 2: 마법의 숲 - 청남색
  {"base": Color(0.65, 0.4, 0.35), "tip": Color(0.52, 0.32, 0.25)}, # 3: 용의 봉우리 - 채도 낮은 빨강
]

# 월드별 풀 타입(0기본,1강한,2센,3황금) 인스턴스 색상
# null이면 원본 GrassData.color 사용
const WORLD_GRASS_COLORS: Array = [
  # 0: 슬라임 늪 - 기본/강한풀 밝게, 센풀 약간 어둡게
  [Color(0.22, 0.5, 0.22), Color(0.32, 0.65, 0.32), Color(0.45, 0.85, 0.45), null],
  # 1: 들판 - 밝은 갈색, 센 풀일수록 더 밝은 갈색
  [Color(0.65, 0.52, 0.32), Color(0.75, 0.6, 0.38), Color(0.85, 0.7, 0.45), null],
  # 2: 마법의 숲 - 기본풀 어둡고, 센 풀일수록 파란빛 밝은 색 (명도 차이 확연)
  [Color(0.3, 0.38, 0.48), Color(0.42, 0.55, 0.75), Color(0.58, 0.72, 0.95), null],
  # 3: 용의 봉우리 - 채도 낮춤, 명도 차이 확연
  [Color(0.5, 0.32, 0.28), Color(0.68, 0.38, 0.3), Color(0.88, 0.48, 0.38), null],
]

var player: Node2D = null
var player_attack_area: Area2D = null

func _ready() -> void:
  setup_multimesh()
  call_deferred("find_player")
  GameManager.upgrade_purchased.connect(_on_upgrade_purchased)

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
      # Random offset that can extend beyond cell boundaries for seamless transitions
      var offset_x = rng.randf_range(-cell_size * 0.3, cell_size * 0.9)
      var offset_y = rng.randf_range(-cell_size * 0.3, cell_size * 0.9)
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

  for grid_pos in grass_data:
    var data = grass_data[grid_pos]
    # Skip cut grass - don't render it
    if data.cut:
      continue

    var world_pos = Vector2(grid_pos.x, grid_pos.y)
    visible_grass.append(world_pos)

    # Check if grass was recently hit - show white flash
    if data.has("hit_timer") and data.hit_timer > 0:
      colors_list.append(Color(1.0, 1.0, 1.0, 1.0))  # White flash
    else:
      colors_list.append(_get_grass_color(data.type))

  multimesh.instance_count = visible_grass.size()

  for i in visible_grass.size():
    var t = Transform2D()
    t.origin = visible_grass[i]
    multimesh.set_instance_transform_2d(i, t)
    multimesh.set_instance_color(i, colors_list[i])

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

  # Spawn coins for cut grass
  for pos in attacked_positions:
    var grid_pos = Vector2i(int(pos.x), int(pos.y))
    if grass_data.has(grid_pos):
      spawn_coin(pos, grass_data[grid_pos].value)

  return total_value

func spawn_coin(pos: Vector2, value: int) -> void:
  var CoinScene = preload("res://scenes/world/coin.tscn")
  var coin = CoinScene.instantiate()
  coin.position = pos
  coin.set_value(value)
  get_parent().add_child(coin)
