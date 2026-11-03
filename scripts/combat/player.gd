
extends CharacterBody3D

@export var speed: float = 7.0
@export var jump_force: float = 7.5
@export var gravity: float = 20.0

@export var attack_damage: float = 40.0
@export var attack_range: float = 2.8

@export var dodge_speed: float = 12.0
@export var dodge_duration: float = 0.35
@export var dodge_cooldown: float = 1.0

# Duraciones originales de las animaciones, en segundos.
@export var jump_animation_duration: float = 2.0333
@export var idle_animation_duration: float = 3.6333
@export var dodge_matrix_animation_duration: float = 2.2333
@export var dodge_animation_duration: float = 2.3667
@export var attack_animation_duration: float = 2.6667
@export var walk_animation_duration: float = 1.1667
@export var attack_animation_speed: float = 4.0

@onready var animation_player: AnimationPlayer = $girl/AnimationPlayer
@onready var head: Node3D = $Head
@onready var camera_fps: Camera3D = $Head/CameraFPS

const MOUSE_SENSITIVITY := 0.003
const VERTICAL_LIMIT := 80.0

var is_dodging: bool = false
var first_person: bool = false

var active_buffs := {}
var previous_health: float = 0.0
var dodge_timer: float = 0.0
var dodge_cooldown_timer: float = 0.0
var dodge_direction := Vector3.ZERO

var is_attacking: bool = false
var jump_animation_started: bool = false

var walk_animation: StringName = &"walk"
var idle_animation: StringName = &"Idle"
var attack_animation: StringName = &"kick"
var dodge_animation: StringName = &"dodge_matrix"
var jump_animation: StringName = &"jump"

var facing_direction := Vector3(0.0, 0.0, -1.0)


func _ready() -> void:
	add_to_group("player")

	animation_player.animation_finished.connect(_on_animation_finished)

	var health = get_node_or_null("HealthComponent")
	if health:
		health.died.connect(_on_player_died)
		health.health_changed.connect(_on_health_changed)
		previous_health = health.current_health

	_play_animation(idle_animation)

	# Asegura que la cámara FPS empiece desactivada.
	if camera_fps:
		camera_fps.current = false


func _process(delta: float) -> void:
	# Gestiona buffs temporales sin acumularse.
	var to_remove: Array = []
	for stat in active_buffs.keys():
		active_buffs[stat]["time"] -= delta
		if active_buffs[stat]["time"] <= 0.0:
			to_remove.append(stat)

	for stat in to_remove:
		var amount: float = active_buffs[stat]["amount"]
		if stat == "damage":
			attack_damage -= amount
		elif stat == "speed":
			speed -= amount
		active_buffs.erase(stat)


func heal(amount: float) -> void:
	var health = get_node_or_null("HealthComponent")
	if health:
		health.current_health = minf(
			health.current_health + amount, health.max_health
		)
		health.health_changed.emit(health.current_health, health.max_health)


func apply_temp_buff(stat: String, amount: float, duration: float) -> void:
	# Si ya está activo, solo refresca el tiempo (no se acumula).
	if active_buffs.has(stat):
		active_buffs[stat]["time"] = duration
		return

	active_buffs[stat] = {"amount": amount, "time": duration}
	if stat == "damage":
		attack_damage += amount
	elif stat == "speed":
		speed += amount


func _on_health_changed(current: float, maximum: float) -> void:
	if current < previous_health and has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_sound("res://addons/cogito/Assets/Audio/Kenney/error_004.ogg", -8.0)
	previous_health = current


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):
		first_person = not first_person
		_apply_camera_mode()

	# Control de vista con mouse (estilo FPS), solo en primera persona.
	if not first_person:
		return

	if not (event is InputEventMouseMotion):
		if event.is_action_pressed("ui_cancel"):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event is InputEventMouseButton and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
	head.rotation.x -= event.relative.y * MOUSE_SENSITIVITY
	var limite := deg_to_rad(VERTICAL_LIMIT)
	head.rotation.x = clamp(head.rotation.x, -limite, limite)

	# Mantén la dirección de ataque alineada con la vista.
	facing_direction = -head.global_transform.basis.z
	facing_direction.y = 0.0
	if facing_direction.length() > 0.0:
		facing_direction = facing_direction.normalized()


func _apply_camera_mode() -> void:
	var arena_cam := _find_arena_camera()

	if arena_cam:
		arena_cam.current = not first_person

	if camera_fps:
		camera_fps.current = first_person

	if first_person:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _find_arena_camera() -> Camera3D:
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and "current_camera" in gm and gm.current_camera:
		return gm.current_camera as Camera3D

	for node in get_tree().get_nodes_in_group("arena_camera"):
		if node is Camera3D:
			return node as Camera3D

	# Búsqueda por nombre como último recurso.
	for node in get_tree().get_nodes_in_group(""):
		pass

	var root := get_tree().current_scene
	if root:
		return _find_camera_by_name(root, "CamaraVista")
	return null


func _find_camera_by_name(node: Node, target: String) -> Camera3D:
	if node.name == target and node is Camera3D:
		return node as Camera3D
	for child in node.get_children():
		var found := _find_camera_by_name(child, target)
		if found:
			return found
	return null


func set_camera_mode(fp: bool, arena_cam: Camera3D) -> void:
	first_person = fp
	if arena_cam:
		arena_cam.current = not fp
	if camera_fps:
		camera_fps.current = fp

	if fp:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	# Gravedad.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Enfriamiento de la esquiva.
	if dodge_cooldown_timer > 0.0:
		dodge_cooldown_timer = maxf(
			dodge_cooldown_timer - delta, 0.0
		)

	# Iniciar esquiva.
	if Input.is_action_just_pressed("dodge"):
		if not is_dodging and dodge_cooldown_timer <= 0.0:
			if not is_attacking:
				_start_dodge()

	# Ejecutar desplazamiento de esquiva.
	if is_dodging:
		dodge_timer -= delta

		velocity.x = dodge_direction.x * dodge_speed
		velocity.z = dodge_direction.z * dodge_speed

		if dodge_timer <= 0.0:
			is_dodging = false

			var health = get_node_or_null("HealthComponent")
			if health:
				health.set_invulnerable(false)

	# Movimiento normal (relativo a la vista).
	else:
		var input_vector := Input.get_vector(
			"move_left", "move_right",
			"move_forward", "move_back"
		)

		var direction := (
			transform.basis * Vector3(
				input_vector.x, 0.0, input_vector.y
			)
		).normalized()

		if direction.length() > 0.0:
			facing_direction = direction

		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

		# Saltar.
		if Input.is_action_just_pressed("jump"):
			if is_on_floor() and not is_attacking:
				velocity.y = jump_force
				jump_animation_started = true
				_play_animation(jump_animation)

		# Atacar.
		if Input.is_action_just_pressed("attack"):
			if not is_attacking and not is_dodging:
				attack()

	# Aplicar movimiento y actualizar colisiones.
	move_and_slide()

	# La cámara FPS se mantiene como hija de Head; no se sobrescribe aquí.

	# Al aterrizar, permitir que la animación de suelo
	# sustituya a Jump en este mismo fotograma.
	if is_on_floor() and velocity.y <= 0.0:
		jump_animation_started = false

	# Prioridad de animaciones.
	if is_dodging:
		pass
	elif is_attacking:
		pass
	elif not is_on_floor():
		# No reiniciar Jump si termina antes de aterrizar.
		if not jump_animation_started:
			jump_animation_started = true
			_play_animation(jump_animation)
	else:
		var horizontal_speed := Vector2(
			velocity.x, velocity.z
		).length()

		if horizontal_speed > 0.1:
			_play_animation(walk_animation)
		else:
			_play_animation(idle_animation)


func _start_dodge() -> void:
	var input_x := Input.get_axis(
		"move_left", "move_right"
	)
	var input_z := Input.get_axis(
		"move_forward", "move_back"
	)

	var direction := Vector3(
		input_x, 0.0, input_z
	).normalized()

	if direction.length() > 0.0:
		dodge_direction = direction
	else:
		dodge_direction = facing_direction

	is_dodging = true
	dodge_timer = dodge_duration
	dodge_cooldown_timer = dodge_cooldown

	var health = get_node_or_null("HealthComponent")
	if health:
		health.set_invulnerable(true)

	# Acelerar la animación para ajustarla a la duración
	# del desplazamiento de esquiva.
	var dodge_playback_speed := (
		dodge_animation_duration / maxf(dodge_duration, 0.01)
	)

	animation_player.play(
		dodge_animation, -1.0, dodge_playback_speed
	)


func attack() -> void:
	if is_attacking or is_dodging:
		return

	is_attacking = true

	animation_player.play(
		attack_animation,
		-1.0,
		attack_animation_speed
	)

	print("¡Ataque!")
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_sound("res://addons/cogito/Assets/Audio/Kenney/woosh1.ogg", -10.0)

	# Comprobar enemigos en alcance y delante del jugador.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var offset: Vector3 = (
			enemy.global_position - global_position
		)
		offset.y = 0.0

		var distance := offset.length()

		if distance > attack_range or distance == 0.0:
			continue

		var direction_to_enemy := offset.normalized()

		if facing_direction.dot(direction_to_enemy) > 0.3:
			var enemy_health = enemy.get_node_or_null(
				"HealthComponent"
			)

			if enemy_health:
				enemy_health.take_damage(attack_damage)
				print("¡Golpe conectado!")
				return

	print("El ataque no alcanzó a ningún enemigo.")


func _play_animation(animation_name: StringName) -> void:
	if animation_player.current_animation != animation_name:
		animation_player.play(animation_name)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == attack_animation:
		is_attacking = false


func _on_player_died() -> void:
	print("¡Jugador derrotado!")
