extends CharacterBody3D

@export var speed: float = 2.6
@export var gravity: float = 20.0
@export var attack_range: float = 1.6
@export var attack_damage: float = 5.0
@export var attack_cooldown_time: float = 1.6
@export var max_health_value: float = 20.0

@onready var health = $HealthComponent

var player: CharacterBody3D
var attack_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("minions")

	health.max_health = max_health_value
	health.current_health = health.max_health
	health.health_changed.emit(health.current_health, health.max_health)
	health.died.connect(_on_died)

	player = get_tree().get_first_node_in_group("player") as CharacterBody3D

	# Escala visual ligeramente menor que el jefe.
	scale = Vector3(0.85, 0.85, 0.85)

	# Diseño visual del enemigo.
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.55, 0.25)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.2, 0.05)
		mesh.material_override = mat


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		move_and_slide()
		return

	attack_cooldown = maxf(attack_cooldown - delta, 0.0)

	var offset := player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()

	if distance > attack_range:
		var direction := offset.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if attack_cooldown <= 0.0:
			_try_damage_player()

	move_and_slide()


func _try_damage_player() -> void:
	if not is_instance_valid(player):
		return
	var player_health = player.get_node_or_null("HealthComponent")
	if player_health:
		player_health.take_damage(attack_damage)
		print("¡Un enemigo golpeó al jugador!")
	attack_cooldown = attack_cooldown_time


func _on_died() -> void:
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_tone(330.0, 0.12, -10.0)
	queue_free()
