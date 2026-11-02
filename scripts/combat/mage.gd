extends CharacterBody3D

@export var speed: float = 2.4
@export var gravity: float = 20.0
@export var attack_range: float = 10.0
@export var attack_damage: float = 12.0
@export var attack_cooldown_time: float = 2.2
@export var max_health_value: float = 25.0

@onready var health = $HealthComponent

var player: CharacterBody3D
var attack_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("mages")

	health.max_health = max_health_value
	health.current_health = health.max_health
	health.health_changed.emit(health.current_health, health.max_health)
	health.died.connect(_on_died)

	player = get_tree().get_first_node_in_group("player") as CharacterBody3D

	# Diseño visual del mago.
	scale = Vector3(0.9, 0.9, 0.9)
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.7, 0.85, 1.0, 0.7)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.6, 0.9)
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

	if distance > attack_range * 0.7:
		var direction := offset.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if attack_cooldown <= 0.0:
			_ranged_attack()

	move_and_slide()


func _ranged_attack() -> void:
	if not is_instance_valid(player):
		return

	var projectile := Area3D.new()
	projectile.set_script(load("res://scripts/combat/projectile.gd"))
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + Vector3(0.0, 1.0, 0.0)
	var target := player.global_position + Vector3(0.0, 1.0, 0.0)
	projectile.direction = (target - projectile.global_position).normalized()
	projectile.damage = attack_damage

	attack_cooldown = attack_cooldown_time

	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_tone(520.0, 0.1, -10.0)


func _on_died() -> void:
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_tone(260.0, 0.2, -8.0)
	queue_free()
