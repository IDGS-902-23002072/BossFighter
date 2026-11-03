extends Node

signal boss_spawned(boss: Node, boss_number: int, total: int)
signal game_finished(victory: bool)
signal stage_changed(stage_number: int, total: int)
signal waves_progress(wave: int, total: int)
signal minions_remaining(count: int)
signal upgrades_offered(options: Array)

@export var boss_scenes: Array[PackedScene] = []
@export var arena_scenes: Array[PackedScene] = []
@export var minion_scene: PackedScene
@export var mage_scene: PackedScene
@export var boss_spawn_position := Vector3(0, 1, -3)
@export var arena_scale := Vector3(1.5, 1.5, 1.5)

@export var waves_per_stage: int = 3
@export var base_minions_per_wave: int = 3

var current_boss_index: int = 0
var game_over: bool = false
var current_arena: Node = null
var current_camera: Camera3D = null

var current_phase: int = 0 # 0 = oleadas, 1 = jefe, 2 = mejora
var current_wave: int = 0
var total_waves: int = 3
var minions_alive: int = 0
var awaiting_upgrade: bool = false
var offered_options: Array = []

const UPGRADE_POOL := [
	{"id": "speed", "title": "Velocidad +20%", "desc": "Te mueves más rápido."},
	{"id": "damage", "title": "Daño +25%", "desc": "Tus ataques hacen más daño."},
	{"id": "health", "title": "Vida +30", "desc": "Aumenta la vida máxima."},
	{"id": "range", "title": "Alcance +0.5", "desc": "Golpeas desde más lejos."},
	{"id": "cooldown", "title": "Esquiva rápida", "desc": "Reduce el enfriamiento de esquiva."},
]

func _ready() -> void:
	add_to_group("game_manager")

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

	if minion_scene == null:
		minion_scene = load("res://scenes/characters/minion.tscn")

	if mage_scene == null:
		mage_scene = load("res://scenes/characters/mage.tscn")

	call_deferred("start_game")


func start_game() -> void:
	if game_over:
		return
	call_deferred("start_stage", 0)


func start_stage(index: int) -> void:
	if game_over:
		return

	if index >= boss_scenes.size():
		_finish_game(true)
		return

	current_boss_index = index
	current_phase = 0
	current_wave = 0
	total_waves = waves_per_stage
	minions_alive = 0
	awaiting_upgrade = false

	var arena := _load_arena(index)

	var player = get_tree().get_first_node_in_group("player")
	if player:
		var player_spawn := _get_marker(arena, "Puntos/InicioJugador")
		if player_spawn:
			player.global_position = player_spawn.global_position
		else:
			player.global_position = Vector3(0, 0, 6)
		if player is CharacterBody3D:
			player.velocity = Vector3.ZERO

	stage_changed.emit(index + 1, boss_scenes.size())

	# Pequeña pausa antes de la primera oleada.
	get_tree().create_timer(1.2).timeout.connect(_spawn_wave, CONNECT_ONE_SHOT)
	print("Inicia etapa ", index + 1)


func _spawn_wave() -> void:
	if game_over or current_phase != 0:
		return

	current_wave += 1
	var count := base_minions_per_wave + (current_wave - 1) + current_boss_index
	waves_progress.emit(current_wave, total_waves)
	print("Oleada ", current_wave, " / ", total_waves, " con ", count, " enemigos")
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_sound("res://addons/cogito/Assets/Audio/Kenney/doorOpen_1.ogg", -8.0)

	var arena := current_arena
	var center := Vector3.ZERO
	var boss_spawn := _get_marker(arena, "Puntos/AparicionJefe")
	if boss_spawn:
		center = boss_spawn.global_position
	else:
		center = Vector3(0, 0, -6)

	minions_alive = count

	var mage_count := 0
	if mage_scene != null:
		mage_count = 1 if current_wave < 3 else 2
		minions_alive += mage_count

	minions_remaining.emit(minions_alive)

	# Buffs aparecen con menos frecuencia.
	if current_wave % 2 == 0:
		_spawn_buffs(1)

	for i in range(count):
		if minion_scene == null:
			continue

		var minion = minion_scene.instantiate()
		var angle := randf() * TAU
		var radius := 1.5 + randf() * 2.5
		var pos := center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

		# Añade el minion al escenario actual para que se limpie con él.
		if is_instance_valid(arena):
			arena.add_child(minion)
		else:
			get_parent().add_child(minion)

		minion.global_position = pos

		var health = minion.get_node_or_null("HealthComponent")
		if health and not health.died.is_connected(_on_minion_died):
			health.died.connect(_on_minion_died)

	# Magos a distancia.
	if mage_count > 0 and is_instance_valid(arena):
		for m in range(mage_count):
			var mage = mage_scene.instantiate()
			arena.add_child(mage)
			var mage_center_marker := _get_marker(arena, "Puntos/AparicionJefe")
			var mage_center := mage_center_marker.global_position if mage_center_marker else Vector3(0, 0, -6)
			mage.global_position = mage_center + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
			var mage_health = mage.get_node_or_null("HealthComponent")
			if mage_health and not mage_health.died.is_connected(_on_minion_died):
				mage_health.died.connect(_on_minion_died)


func _on_minion_died() -> void:
	if game_over:
		return

	minions_alive = maxi(minions_alive - 1, 0)
	minions_remaining.emit(minions_alive)

	if current_phase != 0:
		return

	if minions_alive <= 0:
		if current_wave < total_waves:
			_heal_player()
			get_tree().create_timer(1.5).timeout.connect(_spawn_wave, CONNECT_ONE_SHOT)
		else:
			current_phase = 1
			_spawn_boss()


func _spawn_boss() -> void:
	if current_boss_index >= boss_scenes.size():
		_finish_game(true)
		return

	var scene := boss_scenes[current_boss_index]

	if scene == null:
		push_error("No se asignó la escena del jefe.")
		return

	var arena := _load_arena(current_boss_index)

	var boss = scene.instantiate()
	boss.set("boss_type", current_boss_index)

	add_child(boss)

	var boss_spawn := _get_marker(arena, "Puntos/AparicionJefe")
	if boss_spawn:
		boss.global_position = boss_spawn.global_position + Vector3.UP
	else:
		boss.global_position = boss_spawn_position

	var player = get_tree().get_first_node_in_group("player")
	if player:
		var player_spawn := _get_marker(arena, "Puntos/InicioJugador")
		if player_spawn:
			player.global_position = player_spawn.global_position
			if player is CharacterBody3D:
				player.velocity = Vector3.ZERO

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

	_spawn_buffs(1)

	print("Comienza el jefe ", current_boss_index + 1)
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_sound("res://addons/cogito/Assets/Audio/Kenney/phaserUp5.ogg", -6.0)


func _on_boss_died() -> void:
	if game_over:
		return

	if current_boss_index + 1 < boss_scenes.size():
		_offer_upgrades()
	else:
		_finish_game(true)


func _offer_upgrades() -> void:
	awaiting_upgrade = true
	current_phase = 2

	offered_options = _pick_upgrade_options(3)
	get_tree().paused = true
	upgrades_offered.emit(offered_options)


func apply_upgrade(option_id: String) -> void:
	if not awaiting_upgrade:
		return

	awaiting_upgrade = false
	get_tree().paused = false

	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		call_deferred("start_stage", current_boss_index + 1)
		return

	match option_id:
		"speed":
			player.speed *= 1.2
		"damage":
			player.attack_damage *= 1.25
		"health":
			var h = player.get_node_or_null("HealthComponent")
			if h:
				h.max_health += 30.0
				h.current_health = minf(h.current_health + 30.0, h.max_health)
				h.health_changed.emit(h.current_health, h.max_health)
		"range":
			player.attack_range += 0.5
		"cooldown":
			player.dodge_cooldown *= 0.85

	call_deferred("start_stage", current_boss_index + 1)


func _spawn_buffs(count: int) -> void:
	if not is_instance_valid(current_arena):
		return

	var buff_script := load("res://scripts/combat/buff.gd")
	if buff_script == null:
		return

	for i in range(count):
		var buff := Area3D.new()
		buff.set_script(buff_script)
		buff.buff_type = randi() % 3
		current_arena.add_child(buff)
		buff.global_position = Vector3(
			randf_range(-8.0, 8.0),
			0.5,
			randf_range(-8.0, 8.0)
		)


func _heal_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var health = player.get_node_or_null("HealthComponent")
	if health:
		health.current_health = health.max_health
		health.health_changed.emit(health.current_health, health.max_health)
		print("¡Jugador curado completamente!")
		if has_node("/root/SoundManager"):
			get_node("/root/SoundManager").play_sound("res://addons/cogito/Assets/Audio/Kenney/jingles-pizzicato_14.ogg", -8.0)


func _pick_upgrade_options(count: int) -> Array:
	var pool := UPGRADE_POOL.duplicate()
	pool.shuffle()
	var result: Array = []
	for i in range(min(count, pool.size())):
		result.append(pool[i])
	return result


func _on_player_died() -> void:
	_finish_game(false)


func _finish_game(victory: bool) -> void:
	if game_over:
		return
	game_over = true
	get_tree().paused = false

	if victory:
		print("¡VICTORIA! Has derrotado a todos los jefes.")
	else:
		print("DERROTA. El jugador ha sido vencido.")

	game_finished.emit(victory)


func _load_arena(index: int) -> Node:
	if arena_scenes.is_empty():
		return null

	var arena_scene := arena_scenes[index % arena_scenes.size()]

	if arena_scene == null:
		push_warning("GameManager: falta el escenario para el jefe %d." % (index + 1))
		return null

	if is_instance_valid(current_arena):
		var old_parent := current_arena.get_parent()
		if old_parent:
			old_parent.remove_child(current_arena)
		current_arena.queue_free()

	current_arena = arena_scene.instantiate()
	current_arena.name = "ArenaActual"
	current_arena.scale = arena_scale
	get_parent().add_child(current_arena)

	_add_invisible_walls(current_arena)

	# Registra la cámara del escenario.
	current_camera = _find_camera_in_node(current_arena, "CamaraVista")
	if current_camera:
		current_camera.add_to_group("arena_camera")
		# Aplica la preferencia de cámara del jugador.
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("set_camera_mode"):
			player.set_camera_mode(player.first_person, current_camera)

	return current_arena


func _find_camera_in_node(node: Node, target: String) -> Camera3D:
	if node.name == target and node is Camera3D:
		return node as Camera3D
	for child in node.get_children():
		var found := _find_camera_in_node(child, target)
		if found:
			return found
	return null


func _add_invisible_walls(arena: Node) -> void:
	if not is_instance_valid(arena):
		return

	var walls := StaticBody3D.new()
	walls.name = "InvisibleWalls"
	arena.add_child(walls)

	var extent := 22.0
	var height := 6.0

	var sides := [
		{"pos": Vector3(0, height * 0.5, -extent), "size": Vector3(extent * 2, height, 1)},
		{"pos": Vector3(0, height * 0.5, extent), "size": Vector3(extent * 2, height, 1)},
		{"pos": Vector3(-extent, height * 0.5, 0), "size": Vector3(1, height, extent * 2)},
		{"pos": Vector3(extent, height * 0.5, 0), "size": Vector3(1, height, extent * 2)},
	]

	for side in sides:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = side["size"]
		collision.shape = shape
		body.add_child(collision)
		body.position = side["pos"]
		walls.add_child(body)


func _get_marker(arena: Node, path: String) -> Marker3D:
	if not is_instance_valid(arena):
		return null
	return arena.get_node_or_null(path) as Marker3D
