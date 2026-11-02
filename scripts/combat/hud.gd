
extends CanvasLayer

var player_bar: ProgressBar
var boss_bar: ProgressBar
var player_label: Label
var boss_label: Label
var end_overlay: Control
var end_title: Label

func _ready() -> void:
	_create_ui()
	_create_end_screen()
	call_deferred("_connect_characters")

func _create_ui() -> void:
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui)

	player_label = Label.new()
	player_label.text = "JUGADOR"
	player_label.position = Vector2(30, 20)
	player_label.add_theme_font_size_override("font_size", 22)
	ui.add_child(player_label)

	player_bar = ProgressBar.new()
	player_bar.position = Vector2(30, 55)
	player_bar.size = Vector2(300, 26)
	player_bar.show_percentage = false
	ui.add_child(player_bar)

	boss_label = Label.new()
	boss_label.text = "JEFE"
	boss_label.anchor_left = 0.5
	boss_label.anchor_right = 0.5
	boss_label.offset_left = -150
	boss_label.offset_right = 150
	boss_label.offset_top = 20
	boss_label.offset_bottom = 50
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override("font_size", 22)
	ui.add_child(boss_label)

	boss_bar = ProgressBar.new()
	boss_bar.anchor_left = 0.5
	boss_bar.anchor_right = 0.5
	boss_bar.offset_left = -200
	boss_bar.offset_right = 200
	boss_bar.offset_top = 55
	boss_bar.offset_bottom = 81
	boss_bar.show_percentage = false
	ui.add_child(boss_bar)


func _connect_characters() -> void:
	var player = get_tree().get_first_node_in_group("player")

	if player:
		var health = player.get_node_or_null("HealthComponent")

		if health:
			if not health.health_changed.is_connected(_on_player_health_changed):
				health.health_changed.connect(_on_player_health_changed)

			if not health.died.is_connected(_on_player_died):
				health.died.connect(_on_player_died)

			_on_player_health_changed(
				health.current_health,
				health.max_health
			)

	var manager = get_parent().get_node_or_null("GameManager")

	if manager:
		if not manager.boss_spawned.is_connected(_on_boss_spawned):
			manager.boss_spawned.connect(_on_boss_spawned)

		if not manager.game_finished.is_connected(_on_game_finished):
			manager.game_finished.connect(_on_game_finished)

		# Recuperar el primer jefe si ya fue creado.
		var current_boss = get_tree().get_first_node_in_group("bosses")

		if current_boss:
			_on_boss_spawned(
				current_boss,
				manager.current_boss_index + 1,
				manager.boss_scenes.size()
			)

func _on_player_health_changed(current: float, maximum: float) -> void:
	player_bar.max_value = maximum
	player_bar.value = current
	player_label.text = "JUGADOR  %d / %d" % [
		int(current), int(maximum)
	]

func _on_boss_health_changed(current: float, maximum: float) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current
	boss_label.text = "JEFE  %d / %d" % [
		int(current), int(maximum)
	]

func _on_player_died() -> void:
	player_label.text = "JUGADOR DERROTADO"

func _on_boss_died() -> void:
	boss_label.text = "¡JEFE DERROTADO!"
	boss_bar.value = 0


func _on_boss_spawned(
	boss: Node,
	boss_number: int,
	total: int
) -> void:
	var health = boss.get_node_or_null("HealthComponent")

	if health == null:
		return

	boss_label.text = "JEFE %d / %d" % [boss_number, total]
	boss_bar.max_value = health.max_health
	boss_bar.value = health.current_health

	if not health.health_changed.is_connected(_on_boss_health_changed):
		health.health_changed.connect(_on_boss_health_changed)

	if not health.died.is_connected(_on_boss_died):
		health.died.connect(_on_boss_died)


func _on_game_finished(victory: bool) -> void:
	end_overlay.visible = true

	if victory:
		end_title.text = "¡VICTORIA!\n¡Derrotaste a los tres jefes!"
		boss_label.text = "¡VICTORIA!"
		boss_bar.value = 0
	else:
		end_title.text = "¡DERROTA!\nTu personaje ha sido vencido."
		player_label.text = "JUGADOR DERROTADO"


func _create_end_screen() -> void:
	# Fondo oscuro que cubre toda la pantalla.
	end_overlay = Control.new()
	end_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_overlay.visible = false
	end_overlay.z_index = 10
	add_child(end_overlay)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0, 0, 0, 0.75)
	end_overlay.add_child(background)

	# Panel centrado.
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -180
	panel.offset_top = -100
	panel.offset_right = 180
	panel.offset_bottom = 100
	end_overlay.add_child(panel)

	var container := VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 24)
	panel.add_child(container)

	end_title = Label.new()
	end_title.text = "FIN DEL COMBATE"
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.add_theme_font_size_override("font_size", 30)
	container.add_child(end_title)

	var restart_button := Button.new()
	restart_button.text = "VOLVER A JUGAR"
	restart_button.custom_minimum_size = Vector2(220, 45)
	restart_button.pressed.connect(_on_restart_pressed)
	container.add_child(restart_button)


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
