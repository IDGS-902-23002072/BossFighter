
extends CanvasLayer

var player_bar: ProgressBar
var boss_bar: ProgressBar
var player_label: Label
var boss_label: Label
var wave_label: Label
var end_overlay: Control
var end_title: Label
var upgrade_panel: Control
var main_menu: Control

func _ready() -> void:
	_create_ui()
	_create_end_screen()
	call_deferred("_connect_characters")

func _create_ui() -> void:
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	wave_label = Label.new()
	wave_label.text = ""
	wave_label.anchor_left = 0.5
	wave_label.anchor_right = 0.5
	wave_label.offset_left = -200
	wave_label.offset_right = 200
	wave_label.offset_top = 90
	wave_label.offset_bottom = 120
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.add_theme_font_size_override("font_size", 18)
	ui.add_child(wave_label)

	var hint_label := Label.new()
	hint_label.text = "WASD mover | Mouse mirar | J atacar | Shift esquivar | Espacio saltar | C cambiar cámara | Esc liberar mouse"
	hint_label.anchor_left = 0.5
	hint_label.anchor_right = 0.5
	hint_label.anchor_top = 1.0
	hint_label.anchor_bottom = 1.0
	hint_label.offset_left = -360
	hint_label.offset_right = 360
	hint_label.offset_top = -30
	hint_label.offset_bottom = 0
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 14)
	ui.add_child(hint_label)


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

		if not manager.stage_changed.is_connected(_on_stage_changed):
			manager.stage_changed.connect(_on_stage_changed)

		if not manager.waves_progress.is_connected(_on_waves_progress):
			manager.waves_progress.connect(_on_waves_progress)

		if not manager.minions_remaining.is_connected(_on_minions_remaining):
			manager.minions_remaining.connect(_on_minions_remaining)

		if not manager.upgrades_offered.is_connected(_on_upgrades_offered):
			manager.upgrades_offered.connect(_on_upgrades_offered)

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
		end_title.text = "¡VICTORIA!\n¡Derrotaste a todos los jefes!"
		boss_label.text = "¡VICTORIA!"
		boss_bar.value = 0
	else:
		end_title.text = "¡DERROTA!\nTu personaje ha sido vencido."
		player_label.text = "JUGADOR DERROTADO"

	if upgrade_panel:
		upgrade_panel.visible = false


func _on_stage_changed(stage_number: int, total: int) -> void:
	wave_label.text = "Etapa %d / %d" % [stage_number, total]


func _on_waves_progress(wave: int, total: int) -> void:
	wave_label.text = "Etapa en curso - Oleada %d / %d" % [wave, total]


func _on_minions_remaining(count: int) -> void:
	if count > 0:
		wave_label.text += "  |  Enemigos: %d" % count
	else:
		wave_label.text = "¡Oleadas completadas! Preparando al jefe..."


func _on_upgrades_offered(options: Array) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_upgrade_panel(options)


func _show_upgrade_panel(options: Array) -> void:
	if upgrade_panel and is_instance_valid(upgrade_panel):
		upgrade_panel.queue_free()

	upgrade_panel = Control.new()
	upgrade_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	upgrade_panel.z_index = 20
	add_child(upgrade_panel)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0, 0, 0, 0.7)
	upgrade_panel.add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_panel.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "¡Jefe derrotado! Elige una mejora"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	for option in options:
		var btn := Button.new()
		btn.text = "%s\n%s" % [option.title, option.desc]
		btn.custom_minimum_size = Vector2(320, 60)
		btn.process_mode = Node.PROCESS_MODE_ALWAYS
		var option_id: String = option.id
		btn.pressed.connect(func():
			_on_upgrade_pressed(option_id)
		)
		vbox.add_child(btn)


func _on_upgrade_pressed(option_id: String) -> void:
	if upgrade_panel and is_instance_valid(upgrade_panel):
		upgrade_panel.queue_free()
		upgrade_panel = null

	var manager = get_parent().get_node_or_null("GameManager")
	if manager and manager.has_method("apply_upgrade"):
		manager.apply_upgrade(option_id)

	var player = get_tree().get_first_node_in_group("player")
	if player and player.first_person:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _create_main_menu() -> void:
	main_menu = Control.new()
	main_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	main_menu.z_index = 30
	add_child(main_menu)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.05, 0.06, 0.1, 0.92)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_menu.add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "BOSS FIGHTER 3D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Sobrevive a las oleadas y derrota a los jefes"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	vbox.add_child(subtitle)

	var play_button := Button.new()
	play_button.text = "JUGAR"
	play_button.custom_minimum_size = Vector2(220, 50)
	play_button.process_mode = Node.PROCESS_MODE_ALWAYS
	play_button.pressed.connect(_on_play_pressed)
	vbox.add_child(play_button)
	play_button.grab_focus()

	var quit_button := Button.new()
	quit_button.text = "SALIR"
	quit_button.custom_minimum_size = Vector2(220, 50)
	quit_button.process_mode = Node.PROCESS_MODE_ALWAYS
	quit_button.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_button)


func _on_play_pressed() -> void:
	if main_menu and is_instance_valid(main_menu):
		main_menu.visible = false

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var manager = get_parent().get_node_or_null("GameManager")
	if manager and manager.has_method("start_game"):
		manager.start_game()


func _on_quit_pressed() -> void:
	get_tree().quit()


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
