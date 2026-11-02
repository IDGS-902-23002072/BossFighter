
extends CharacterBody3D

enum State {
	APPROACH,
	WINDUP,
	ATTACK,
	SECOND_ATTACK,
	COOLDOWN
}
enum BossType { GUERRERO, ASESINO, DESTRUCTOR }

@export var boss_type: BossType = BossType.GUERRERO

@export var speed: float = 3.0
@export var gravity: float = 20.0
@export var attack_range: float = 2.0
@export var attack_damage: float = 15.0
@export var windup_time: float = 0.8
@export var cooldown_time: float = 1.2

@onready var health = $HealthComponent

var player: CharacterBody3D
var state: State = State.APPROACH
var state_timer: float = 0.0
@export var warning_color: Color = Color(1.0, 0.15, 0.1)
var original_material: Material
var warning_material: StandardMaterial3D

func _ready() -> void:
	_configure_boss()
	_setup_warning_material()
	add_to_group("enemies")
	add_to_group("bosses")

	# Diseño visual del jefe según su tipo.
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		var mat := StandardMaterial3D.new()
		match boss_type:
			BossType.GUERRERO:
				mat.albedo_color = Color(0.3, 0.6, 0.25)
			BossType.ASESINO:
				mat.albedo_color = Color(0.8, 0.85, 0.9, 0.8)
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			BossType.DESTRUCTOR:
				mat.albedo_color = Color(0.5, 0.15, 0.15)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color * 0.3
		mesh.material_override = mat
	health.died.connect(_on_died)

	player = get_tree().get_first_node_in_group("player") as CharacterBody3D

func _configure_boss() -> void:
	match boss_type:
		BossType.GUERRERO:
			speed = 2.6
			attack_damage = 12.0
			attack_range = 1.9
			windup_time = 0.9
			cooldown_time = 1.4
			health.max_health = 80.0

		BossType.ASESINO:
			speed = 3.8
			attack_damage = 16.0
			attack_range = 2.0
			windup_time = 0.6
			cooldown_time = 1.0
			health.max_health = 120.0

		BossType.DESTRUCTOR:
			speed = 3.0
			attack_damage = 22.0
			attack_range = 2.8
			windup_time = 0.8
			cooldown_time = 0.8
			health.max_health = 180.0

	health.current_health = health.max_health
	health.health_changed.emit(health.current_health, health.max_health)


func _setup_warning_material() -> void:
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D

	if mesh == null:
		return

	var material := mesh.get_active_material(0)

	if material is StandardMaterial3D:
		original_material = material.duplicate()
	else:
		original_material = material

	warning_material = StandardMaterial3D.new()
	warning_material.albedo_color = warning_color
	warning_material.emission_enabled = true
	warning_material.emission = warning_color


func _set_attack_warning(enabled: bool) -> void:
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D

	if mesh == null:
		return

	if enabled:
		mesh.material_override = warning_material
	else:
		mesh.material_override = original_material


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		move_and_slide()
		return

	state_timer -= delta

	var offset := player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()

	match state:
		State.APPROACH:
			if distance > attack_range:
				var direction := offset.normalized()
				velocity.x = direction.x * speed
				velocity.z = direction.z * speed
			else:
				_stop_horizontal()
				state = State.WINDUP
				state_timer = windup_time
				_set_attack_warning(true)
				print("¡El jefe se prepara para atacar!")

		State.WINDUP:
			_stop_horizontal()
			if state_timer <= 0.0:
				_set_attack_warning(false)
				state = State.ATTACK

		State.ATTACK:
			_stop_horizontal()

			match boss_type:
				BossType.GUERRERO:
					_try_damage_player(attack_range + 0.4, attack_damage)
					state = State.COOLDOWN
					state_timer = cooldown_time

				BossType.ASESINO:
					_try_damage_player(attack_range + 0.4, attack_damage)
					state = State.SECOND_ATTACK
					state_timer = 0.25
					print("¡El Asesino prepara el segundo golpe!")

				BossType.DESTRUCTOR:
					print("¡El Destructor libera una onda de choque!")
					_try_damage_player(4.0, attack_damage)
					state = State.COOLDOWN
					state_timer = cooldown_time

		State.SECOND_ATTACK:
			_stop_horizontal()

			if state_timer <= 0.0:
				_try_damage_player(attack_range + 0.4, attack_damage)
				print("¡Segundo golpe del Asesino!")
				state = State.COOLDOWN
				state_timer = cooldown_time

		State.COOLDOWN:
			_stop_horizontal()

			if state_timer <= 0.0:
				state = State.APPROACH

			_stop_horizontal()
			if state_timer <= 0.0:
				state = State.APPROACH

	move_and_slide()

func _stop_horizontal() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _try_damage_player(max_distance: float, damage: float) -> void:
	if not is_instance_valid(player):
		return

	var offset := player.global_position - global_position
	offset.y = 0.0

	if offset.length() > max_distance:
		print("El ataque no alcanzó al jugador.")
		return

	var player_health = player.get_node_or_null("HealthComponent")

	if player_health:
		player_health.take_damage(damage)
		print("¡El jefe golpeó al jugador!")

func _on_died() -> void:
	print("¡Jefe derrotado!")
	_set_attack_warning(false)
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_tone(220.0, 0.35, -4.0)
	queue_free()
