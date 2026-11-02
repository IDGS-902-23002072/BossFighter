
extends Node

@export var max_health: float = 100.0

var current_health: float
var is_invulnerable: bool = false

signal health_changed(current: float, maximum: float)
signal died

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func set_invulnerable(value: bool) -> void:
	is_invulnerable = value

func take_damage(amount: float) -> void:
	if current_health <= 0.0 or is_invulnerable:
		return

	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)

	if current_health <= 0.0:
		died.emit()
