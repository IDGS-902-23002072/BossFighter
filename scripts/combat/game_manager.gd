
extends Node

signal boss_spawned(boss: Node, boss_number: int, total: int)
signal game_finished(victory: bool)

@export var boss_scenes: Array[PackedScene] = []
@export var boss_spawn_position := Vector3(0, 1, -3)

var current_boss_index: int = 0
var game_over: bool = false

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_error("GameManager: no se encontró al jugador.")
		return

	var health = player.get_node_or_null("HealthComponent")

	if health == null:
		push_error("GameManager: el jugador no tiene HealthComponent.")
		return

	health.died.connect(_on_player_died)

	if boss_scenes.is_empty():
		push_error("GameManager: asigna las escenas de los jefes.")
		return

	_spawn_boss()

func _spawn_boss() -> void:
	if current_boss_index >= boss_scenes.size():
		_finish_game(true)
		return

	var scene := boss_scenes[current_boss_index]

	if scene == null:
		push_error("No se asignó la escena del jefe.")
		return

	var boss = scene.instantiate()

	# Asigna el tipo antes de añadirlo a la escena.
	boss.set("boss_type", current_boss_index)

	add_child(boss)
	boss.global_position = boss_spawn_position

	var health = boss.get_node_or_null("HealthComponent")

	if health == null:
		push_error("El jefe no tiene HealthComponent.")
		boss.queue_free()
		return

	boss_spawned.emit(
		boss,
		current_boss_index + 1,
		boss_scenes.size()
	)

	health.died.connect(_on_boss_died)

	print("Comienza el jefe ", current_boss_index + 1)

func _on_boss_died() -> void:
	if game_over:
		return

	current_boss_index += 1
	call_deferred("_advance_boss")

func _advance_boss() -> void:
	if game_over:
		return

	if current_boss_index >= boss_scenes.size():
		_finish_game(true)
	else:
		_spawn_boss()

func _on_player_died() -> void:
	_finish_game(false)

func _finish_game(victory: bool) -> void:
	if game_over:
		return

	game_over = true

	if victory:
		print("¡VICTORIA! Has derrotado a los tres jefes.")
	else:
		print("DERROTA. El jugador ha sido vencido.")

	game_finished.emit(victory)
