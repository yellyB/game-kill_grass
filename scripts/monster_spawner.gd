extends Node2D

const MonsterScene = preload("res://scenes/world/monster.tscn")

@export var spawn_count: int = 8
@export var spawn_radius: float = 800.0
@export var min_distance: float = 300.0  # Minimum distance from player

var player: Node2D = null
var spawned: bool = false

func _ready() -> void:
	call_deferred("_find_player_and_spawn")

func _find_player_and_spawn() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player:
		spawn_monsters()

func spawn_monsters() -> void:
	if spawned:
		return
	spawned = true

	for i in spawn_count:
		var monster = MonsterScene.instantiate()
		# Random position around origin in WorldRoot coordinates
		var angle = randf() * TAU
		var dist = randf_range(min_distance, spawn_radius)
		monster.position = Vector2(cos(angle), sin(angle)) * dist
		get_parent().add_child(monster)
