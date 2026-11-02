
extends CharacterBody3D

@export var speed: float = 6.0
@export var jump_force: float = 7.0
@export var gravity: float = 20.0

@export var attack_damage: float = 25.0
@export var attack_range: float = 2.5

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

var is_dodging: bool = false
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

	_play_animation(idle_animation)


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

	# Movimiento normal.
	else:
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
