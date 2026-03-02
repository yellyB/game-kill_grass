extends Node2D

const MonsterScene = preload("res://scenes/world/monster.tscn")
const ChestScene = preload("res://scenes/world/chest.tscn")

@export var spawn_count: int = 2  # Alias for respawn_max (initial wave)
@export var spawn_radius: float = 800.0
@export var min_distance: float = 300.0  # Minimum distance from player
@export var respawn_interval: float = 10.0  # Seconds between respawn waves
@export var respawn_min: int = 1
@export var respawn_max: int = 2

const MONSTER_TYPES: Array = [
	{
		"type": "slime",
		"sprite_path": "res://resources/images/monster/slime/",
		"max_health": 3,
		"wander_speed": 80,
		"drop_table": [
			{"item_id": "질긴 슬라임 조각", "image_path": "res://resources/images/items/질긴 슬라임 조각.png", "weight": 40},
			{"item_id": "번개 먹은 배터리 껍질", "image_path": "res://resources/images/items/번개 먹은 배터리 껍질.png", "weight": 70},
		],
		"has_lightning": true,
		"penalty_min": 1,
		"penalty_max": 2,
		"spawn_weight": 30,
		"hit_radius_scale": 0.8,
	},
	{
		"type": "boar",
		"sprite_path": "res://resources/images/monster/boar/",
		"max_health": 8,
		"wander_speed": 124,
		"sprite_scale": 0.36,
		"drop_table": [
			{"item_id": "차축 뼈대", "image_path": "res://resources/images/items/차축 뼈대.png", "weight": 25},
			{"item_id": "굴러다니는 바퀴 잔해", "image_path": "res://resources/images/items/굴러다니는 바퀴 잔해.png", "weight": 50},
			{"item_id": "과성장 생체 응축체", "image_path": "res://resources/images/items/과성장 생체 응축체.png", "weight": 25},
		],
		"has_lightning": false,
		"penalty_min": 50,
		"penalty_max": 120,
		"spawn_weight": 20,
	},
	{
		"type": "knight",
		"sprite_path": "res://resources/images/monster/knight/",
		"max_health": 15,
		"wander_speed": 96,
		"sprite_scale": 0.36,
		"drop_table": [
			{"item_id": "왜곡된 볼트 조각", "image_path": "res://resources/images/items/왜곡된 볼트 조각.png", "weight": 65},
			{"item_id": "압축된 이세계 철편", "image_path": "res://resources/images/items/압축된 이세계 철편.png", "weight": 35},
		],
		"has_lightning": false,
		"penalty_min": 80,
		"penalty_max": 150,
		"spawn_weight": 20,
		"hit_radius_scale": 0.85,
	},
	{
		"type": "mage",
		"sprite_path": "res://resources/images/monster/mage/",
		"max_health": 12,
		"wander_speed": 108,
		"drop_table": [
			{"item_id": "생체 연료 포자", "image_path": "res://resources/images/items/생체 연료 포자.png", "weight": 15},
			{"item_id": "뒤틀린 시간 포자", "image_path": "res://resources/images/items/뒤틀린 시간 포자.png", "weight": 15},
			{"item_id": "바람 머금은 잔디 섬유", "image_path": "res://resources/images/items/바람 머금은 잔디 섬유.png", "weight": 77},
		],
		"has_lightning": false,
		"penalty_min": 400,
		"penalty_max": 800,
		"spawn_weight": 10,
		"hit_radius_scale": 0.7,
	},
	{
		"type": "deer",
		"sprite_path": "res://resources/images/monster/deer/",
		"max_health": 20,
		"wander_speed": 144,
		"sprite_scale": 0.36,
		"drop_table": [
			{"item_id": "투명 수정 파편", "image_path": "res://resources/images/items/투명 수정 파편.png", "weight": 89},
			{"item_id": "강화 유리 결정핵", "image_path": "res://resources/images/items/강화 유리 결정핵.png", "weight": 18},
		],
		"has_lightning": false,
		"penalty_min": 500,
		"penalty_max": 1000,
		"spawn_weight": 10,
	},
	{
		"type": "golem",
		"sprite_path": "res://resources/images/monster/golem/",
		"max_health": 35,
		"wander_speed": 80,
		"sprite_scale": 0.48,
		"drop_table": [
			{"item_id": "몬스터 핵", "image_path": "res://resources/images/items/몬스터 핵.png", "weight": 22},
			{"item_id": "압축된 이세계 철편", "image_path": "res://resources/images/items/압축된 이세계 철편.png", "weight": 52},
			{"item_id": "침식된 백골 프레임", "image_path": "res://resources/images/items/침식된 백골 프레임.png", "weight": 39},
		],
		"has_lightning": false,
		"penalty_min": 6000,
		"penalty_max": 12000,
		"spawn_weight": 5,
	},
	{
		"type": "dragon",
		"sprite_path": "res://resources/images/monster/dragon/",
		"max_health": 40,
		"wander_speed": 160,
		"sprite_scale": 0.48,
		"drop_table": [
			{"item_id": "과열된 엔진 심장", "image_path": "res://resources/images/items/과열된 엔진 심장.png", "weight": 33},
			{"item_id": "드래곤 배기가스 결정", "image_path": "res://resources/images/items/드래곤 배기가스 결정.png", "weight": 67},
		],
		"has_lightning": false,
		"penalty_min": 10000,
		"penalty_max": 20000,
		"spawn_weight": 3,
	},
]

const FURY_BOSS_TYPES: Dictionary = {
	0: {
		"type": "slime",
		"sprite_path": "res://resources/images/monster/slime/",
		"max_health": 40,
		"wander_speed": 50,
		"sprite_scale": 0.96,
		"drop_table": [],
		"has_lightning": true,
		"penalty_min": 0,
		"penalty_max": 0,
		"spawn_weight": 1,
		"hit_radius_scale": 0.84,
	},
	1: {
		"type": "boar",
		"sprite_path": "res://resources/images/monster/boar/",
		"max_health": 60,
		"wander_speed": 60,
		"sprite_scale": 0.84,
		"drop_table": [],
		"has_lightning": false,
		"penalty_min": 0,
		"penalty_max": 0,
		"spawn_weight": 1,
	},
	2: {
		"type": "knight",
		"sprite_path": "res://resources/images/monster/knight/",
		"max_health": 80,
		"wander_speed": 48,
		"sprite_scale": 0.84,
		"drop_table": [],
		"has_lightning": false,
		"penalty_min": 0,
		"penalty_max": 0,
		"spawn_weight": 1,
		"hit_radius_scale": 0.85,
	},
	3: {
		"type": "mage",
		"sprite_path": "res://resources/images/monster/mage/",
		"max_health": 100,
		"wander_speed": 54,
		"sprite_scale": 0.96,
		"drop_table": [],
		"has_lightning": false,
		"penalty_min": 0,
		"penalty_max": 0,
		"spawn_weight": 1,
		"hit_radius_scale": 0.7,
	},
	4: {
		"type": "deer",
		"sprite_path": "res://resources/images/monster/deer/",
		"max_health": 150,
		"wander_speed": 72,
		"sprite_scale": 0.84,
		"drop_table": [],
		"has_lightning": false,
		"penalty_min": 0,
		"penalty_max": 0,
		"spawn_weight": 1,
	},
	5: {
		"type": "golem",
		"sprite_path": "res://resources/images/monster/golem/",
		"max_health": 200,
		"wander_speed": 40,
		"sprite_scale": 0.96,
		"drop_table": [],
		"has_lightning": false,
		"penalty_min": 0,
		"penalty_max": 0,
		"spawn_weight": 1,
	},
	6: {
		"type": "dragon",
		"sprite_path": "res://resources/images/monster/dragon/",
		"max_health": 300,
		"wander_speed": 80,
		"sprite_scale": 0.96,
		"drop_table": [],
		"has_lightning": false,
		"penalty_min": 0,
		"penalty_max": 0,
		"spawn_weight": 1,
	},
}

const WORLD_MONSTER_MAP: Array = [
	[],  # 월드 0: 슬라임 늪 - 보스만
	[],  # 월드 1: 들판 - 보스만
	[],  # 월드 2: 기사의 성벽 - 보스만
	[],  # 월드 3: 마법의 숲 - 보스만
	[],  # 월드 4: 수정 호수 - 보스만
	[],  # 월드 5: 고대 유적 - 보스만
	[],  # 월드 6: 용의 봉우리 - 보스만
]

# 청크당 상자 스폰 확률 (~10세션에 1개 = 1/(30청크*10세션) ≈ 0.003)
const CHEST_CHUNK_CHANCE: float = 0.1
var chest_on_field: bool = false

var player: Node2D = null
var spawned: bool = false
var respawn_timer: float = 0.0
var grass_spawner: Node2D = null

func _ready() -> void:
	call_deferred("_find_player_and_spawn")
	GameManager.beast_rush_requested.connect(_on_beast_rush)
	GameManager.fury_boss_requested.connect(_on_fury_boss_requested)

func _process(delta: float) -> void:
	if not spawned:
		return
	respawn_timer += delta
	if respawn_timer >= respawn_interval:
		respawn_timer = 0.0
		_spawn_wave(randi_range(respawn_min, respawn_max))

func _find_player_and_spawn() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player:
		spawn_monsters()

func spawn_monsters() -> void:
	if spawned:
		return
	spawned = true

	_spawn_wave(randi_range(respawn_min, respawn_max))

	# Connect to grass_spawner's new_chunk_entered signal for chest spawning
	grass_spawner = get_tree().get_first_node_in_group("grass_spawner")
	if not grass_spawner:
		# Fallback: find by name in parent
		grass_spawner = get_parent().get_node_or_null("GrassSpawner")
	if grass_spawner and grass_spawner.has_signal("new_chunk_entered"):
		grass_spawner.new_chunk_entered.connect(_on_new_chunk_entered)

func _get_offscreen_position() -> Vector2:
	var viewport_size = get_viewport().get_visible_rect().size
	var half_diag = viewport_size.length() * 0.5
	var margin = 80.0  # Extra margin outside screen edge
	var dist = half_diag + margin + randf_range(0, 150)
	var angle = randf() * TAU
	# Player position in WorldRoot local coords
	var player_local = get_parent().to_local(player.global_position) if player else Vector2.ZERO
	return player_local + Vector2(cos(angle), sin(angle)) * dist

func _spawn_wave(count: int) -> void:
	for i in count:
		var config = _pick_random_type()
		if config.is_empty():
			return
		var monster = MonsterScene.instantiate()
		monster.setup(config)
		monster.position = _get_offscreen_position()
		get_parent().add_child(monster)

func _pick_random_type() -> Dictionary:
	var world = GameManager.selected_world
	var allowed_types: Array = WORLD_MONSTER_MAP[world] if world < WORLD_MONSTER_MAP.size() else []

	var filtered: Array = []
	for m in MONSTER_TYPES:
		if m.type in allowed_types:
			filtered.append(m)
	if filtered.is_empty():
		return {}

	var total_weight: int = 0
	for m in filtered:
		total_weight += m.spawn_weight

	var roll = randi() % total_weight
	var cumulative: int = 0
	for m in filtered:
		cumulative += m.spawn_weight
		if roll < cumulative:
			return m
	return filtered[0]

func _on_new_chunk_entered(chunk_coord: Vector2i) -> void:
	if chest_on_field:
		return
	if randf() > CHEST_CHUNK_CHANCE:
		return
	_spawn_chest_at_chunk(chunk_coord)

func _spawn_chest_at_chunk(chunk_coord: Vector2i) -> void:
	var chunk_size = 400.0
	if grass_spawner:
		chunk_size = grass_spawner.chunk_size
	var chunk_origin = Vector2(chunk_coord.x * chunk_size, chunk_coord.y * chunk_size)
	var pos = chunk_origin + Vector2(randf() * chunk_size, randf() * chunk_size)

	var chest = ChestScene.instantiate()
	chest.position = pos
	chest.tree_exited.connect(func(): chest_on_field = false)
	chest_on_field = true
	get_parent().add_child(chest)

func _on_beast_rush() -> void:
	_spawn_wave(10)

func _on_fury_boss_requested() -> void:
	var world = GameManager.selected_world
	if not FURY_BOSS_TYPES.has(world):
		return
	var config = FURY_BOSS_TYPES[world].duplicate()
	# 마지막 월드가 아니면 다음 월드 열쇠 드롭
	if world + 1 < GameManager.WORLD_UNLOCK_COSTS.size():
		config["key_world_index"] = world + 1
	var monster = MonsterScene.instantiate()
	monster.setup(config)
	# 보스 위치: 플레이어 위쪽 (화면 상단 ~20% 지점)
	var player_local = get_parent().to_local(player.global_position) if player else Vector2.ZERO
	var viewport_size = get_viewport().get_visible_rect().size
	var boss_y_offset = -viewport_size.y * 0.3  # 플레이어 위쪽으로 화면 30%
	monster.position = player_local + Vector2(0, boss_y_offset)
	# 씬 추가 전에 보스 등장 상태 설정 (움직임 방지)
	monster.is_boss_entering = true
	monster.visible = false
	get_parent().add_child(monster)
	# 1초 멈춤 + 보스 등장 애니메이션
	_play_boss_entrance(monster)

func _play_boss_entrance(monster: Node2D) -> void:
	get_tree().paused = true
	monster.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	# 1초 멈춤
	await get_tree().create_timer(1.0).timeout
	# 보스 등장 애니메이션 (0.6초)
	monster.visible = true
	monster.play_boss_entrance()
	await get_tree().create_timer(0.6).timeout
	# 1초 멈춤 후 게임 재개
	await get_tree().create_timer(1.0).timeout
	monster.is_boss_entering = false
	monster.process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().paused = false
