extends Area3D

var direction := Vector3.FORWARD
var speed := 20.0
var damage := 10.0
var lifetime := 4.0
var timer := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	mesh_instance.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.9, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.7, 1.0)
	mesh_instance.material_override = mat
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.3
	collision.shape = shape
	add_child(collision)

	monitoring = true


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	timer += delta
	if timer >= lifetime:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var health = body.get_node_or_null("HealthComponent")
		if health:
			health.take_damage(damage)
	if not body.is_in_group("mages") and not body.is_in_group("enemies"):
		queue_free()
