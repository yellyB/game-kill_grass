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
		"wander_speed": 40,
		"hit_radius": 30,
		"drop_table": [
			{"item_id": "질긴 슬라임 조각", "image_path": "res://resources/images/items/질긴 슬라임 조각.png", "weight": 30},
			{"item_id": "번개 먹은 배터리 껍질", "image_path": "res://resources/images/items/번개 먹은 배터리 껍질.png", "weight": 70},
		],
		"has_lightning": true,
		"penalty_min": 5,
		"penalty_max": 10,
		"spawn_weight": 30,
	},
	{
		"type": "boar",
		"sprite_path": "res://resources/images/monster/boar/",
		"max_health": 8,
		"wander_speed": 55,
		"hit_radius": 30,
		"drop_table": [
			{"item_id": "차축 뼈대", "image_path": "res://resources/images/items/차축 뼈대.png", "weight": 25},
			{"item_id": "굴러다니는 바퀴 잔해", "image_path": "res://resources/images/items/굴러다니는 바퀴 잔해.png", "weight": 50},
			{"item_id": "과성장 생체 응축체", "image_path": "res://resources/images/items/과성장 생체 응축체.png", "weight": 25},
		],
		"has_lightning": false,
		"penalty_min": 80,
		"penalty_max": 150,
		"spawn_weight": 25,
	},
	{
		"type": "knight",
		"sprite_path": "res://resources/images/monster/knight/",
		"max_health": 15,
		"wander_speed": 35,
		"hit_radius": 30,
		"drop_table": [
			{"item_id": "왜곡된 볼트 조각", "image_path": "res://resources/images/items/왜곡된 볼트 조각.png", "weight": 65},
			{"item_id": "압축된 이세계 철편", "image_path": "res://resources/images/items/압축된 이세계 철편.png", "weight": 35},
		],
		"has_lightning": false,
		"penalty_min": 100,
		"penalty_max": 200,
		"spawn_weight": 15,
	},
	{
		"type": "mage",
		"sprite_path": "res://resources/images/monster/mage/",
		"max_health": 12,
		"wander_speed": 45,
		"hit_radius": 30,
		"drop_table": [
			{"item_id": "생체 연료 포자", "image_path": "res://resources/images/items/생체 연료 포자.png", "weight": 8},
			{"item_id": "뒤틀린 시간 포자", "image_path": "res://resources/images/items/뒤틀린 시간 포자.png", "weight": 15},
			{"item_id": "바람 머금은 잔디 섬유", "image_path": "res://resources/images/items/바람 머금은 잔디 섬유.png", "weight": 77},
		],
		"has_lightning": false,
		"penalty_min": 400,
		"penalty_max": 800,
		"spawn_weight": 15,
	},
	{
		"type": "deer",
		"sprite_path": "res://resources/images/monster/deer/",
		"max_health": 20,
		"wander_speed": 60,
		"hit_radius": 30,
		"drop_table": [
			{"item_id": "투명 수정 파편", "image_path": "res://resources/images/items/투명 수정 파편.png", "weight": 89},
			{"item_id": "강화 유리 결정핵", "image_path": "res://resources/images/items/강화 유리 결정핵.png", "weight": 11},
		],
		"has_lightning": false,
		"penalty_min": 500,
		"penalty_max": 1000,
		"spawn_weight": 5,
	},
	{
		"type": "golem",
		"sprite_path": "res://resources/images/monster/golem/",
		"max_health": 35,
		"wander_speed": 22,
		"hit_radius": 30,
		"drop_table": [
			{"item_id": "몬스터 핵", "image_path": "res://resources/images/items/몬스터 핵.png", "weight": 10},
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
		"wander_speed": 30,
		"hit_radius": 30,
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

const WORLD_MONSTER_MAP: Array = [
	["slime"],
	["boar", "knight"],
	["mage", "deer"],
	["golem", "dragon"],
]

const CHEST_SPAWN_CHANCE: float = 1.0  # 디버깅용 100%, 나중에 낮춤

var player: Node2D = null
var spawned: bool = false
var respawn_timer: float = 0.0

func _ready() -> void:
	call_deferred("_find_player_and_spawn")
	GameManager.timed_buff_started.connect(_on_timed_buff_started)

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
	_spawn_chest()

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
		var monster = MonsterScene.instantiate()
		monster.setup(config)
		monster.position = _get_offscreen_position()
		get_parent().add_child(monster)

func _pick_random_type() -> Dictionary:
	var world = GameManager.selected_world
	var allowed_types: Array = WORLD_MONSTER_MAP[world] if world < WORLD_MONSTER_MAP.size() else ["slime"]

	var filtered: Array = []
	for m in MONSTER_TYPES:
		if m.type in allowed_types:
			filtered.append(m)
	if filtered.is_empty():
		filtered = [MONSTER_TYPES[0]]

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

const LAST_WORLD_CHEST_ITEM: String = "졸음 약"

func _spawn_chest() -> void:
	var world = GameManager.selected_world
	var is_last_world = world >= GameManager.WORLD_UNLOCK_COSTS.size() - 1

	if is_last_world:
		# 마지막 월드: 졸음 약 상자
		if GameManager.get_item_count(LAST_WORLD_CHEST_ITEM) >= 1:
			return
	else:
		var next_world = world + 1
		# 이미 열쇠 보유 시 상자 미출현
		if GameManager.has_key(next_world):
			return
		# 이미 해금된 월드면 열쇠 불필요
		if next_world in GameManager.unlocked_worlds:
			return

	# 확률 체크
	if randf() > CHEST_SPAWN_CHANCE:
		return

	var chest = ChestScene.instantiate()
	if is_last_world:
		chest.drop_item_id = LAST_WORLD_CHEST_ITEM
	else:
		chest.key_world_index = world + 1
	var angle = randf() * TAU
	var dist = randf_range(min_distance, spawn_radius)
	chest.position = Vector2(cos(angle), sin(angle)) * dist
	get_parent().add_child(chest)

func _on_timed_buff_started(type: String, _duration: float) -> void:
	if type == "beast_rush":
		_spawn_beast_rush_monsters()

func _spawn_beast_rush_monsters() -> void:
	_spawn_wave(spawn_count * 2)
