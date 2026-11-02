extends Area3D

enum BuffType { HEALTH, DAMAGE, SPEED }

@export var buff_type: BuffType = BuffType.HEALTH

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_setup_visual()
	_setup_label()


func _setup_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	mesh_instance.mesh = sphere

	var material := StandardMaterial3D.new()
	match buff_type:
		BuffType.HEALTH:
			material.albedo_color = Color(0.2, 0.9, 0.3)
		BuffType.DAMAGE:
			material.albedo_color = Color(0.9, 0.2, 0.2)
		BuffType.SPEED:
			material.albedo_color = Color(0.2, 0.5, 0.95)
	material.emission_enabled = true
	material.emission = material.albedo_color
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.6
	collision.shape = shape
	add_child(collision)


func _setup_label() -> void:
	var label := Label3D.new()
	match buff_type:
		BuffType.HEALTH:
			label.text = "Vida +40"
		BuffType.DAMAGE:
			label.text = "Daño +10"
		BuffType.SPEED:
			label.text = "Velocidad +1"
	label.font_size = 32
	label.position = Vector3(0.0, 1.0, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 1, 1, 1)
	add_child(label)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	var health = body.get_node_or_null("HealthComponent")

	match buff_type:
		BuffType.HEALTH:
			if body.has_method("heal"):
				body.heal(40.0)
				print("¡Buff de vida recogido!")
		BuffType.DAMAGE:
			if body.has_method("apply_temp_buff"):
				body.apply_temp_buff("damage", 10.0, 8.0)
				print("¡Buff de daño temporal recogido!")
		BuffType.SPEED:
			if body.has_method("apply_temp_buff"):
				body.apply_temp_buff("speed", 1.0, 8.0)
				print("¡Buff de velocidad temporal recogido!")

	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_tone(880.0, 0.15, -6.0)

	queue_free()
