extends Control
## Menú inicial de BossFighter 3D.
## Se construye por código (igual que el HUD) y carga la escena del juego al pulsar JUGAR.

const GAME_SCENE := "res://scenes/main.tscn"
const SETTINGS_PATH := "user://settings.cfg"

const COLOR_BG_TOP := Color(0.03, 0.04, 0.08)
const COLOR_BG_BOTTOM := Color(0.14, 0.07, 0.10)
const COLOR_ACCENT := Color(0.95, 0.38, 0.22)
const COLOR_BUTTON := Color(0.17, 0.18, 0.26)
const COLOR_PANEL := Color(0.08, 0.09, 0.14, 0.92)
const COLOR_TEXT := Color(0.93, 0.93, 0.96)
const COLOR_TEXT_DIM := Color(0.68, 0.70, 0.78)

const CONTROLS := [
	["W A S D / Flechas", "Mover"],
	["Mouse", "Mirar"],
	["J", "Atacar"],
	["Shift", "Esquivar"],
	["Espacio", "Saltar"],
	["C", "Cambiar cámara"],
	["Esc", "Liberar el mouse"],
]

var _main_panel: Control
var _controls_panel: Control
var _options_panel: Control
var _current_panel: Control

var _play_button: Button
var _controls_back_button: Button
var _volume_slider: HSlider
var _volume_value_label: Label
var _fullscreen_check: CheckButton

var _starting := false


func _ready() -> void:
	# Si venimos de una partida (pausada o con el mouse capturado), restablece el estado.
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_ui()
	_load_settings()
	_show_panel(_main_panel)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _current_panel != _main_panel:
		_go_back()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Construcción de la interfaz
# ---------------------------------------------------------------------------

func _build_background() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, COLOR_BG_TOP)
	gradient.set_color(1, COLOR_BG_BOTTOM)

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)

	var background := TextureRect.new()
	background.texture = texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	column.add_child(_make_label("BOSS FIGHTER 3D", 64, COLOR_ACCENT))
	column.add_child(_make_label("Sobrevive a las oleadas y derrota a los jefes", 20, COLOR_TEXT_DIM))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 28)
	column.add_child(spacer)

	_controls_panel = _build_controls_panel()
	_options_panel = _build_options_panel()
	_main_panel = _build_main_panel()

	column.add_child(_main_panel)
	column.add_child(_controls_panel)
	column.add_child(_options_panel)


func _build_main_panel() -> Control:
	var box := _make_box()

	_play_button = _make_button("JUGAR", _on_play_pressed, true)
	box.add_child(_play_button)
	box.add_child(_make_button("CONTROLES", func(): _show_panel(_controls_panel)))
	box.add_child(_make_button("OPCIONES", func(): _show_panel(_options_panel)))

	# En la versión web no tiene sentido cerrar el juego.
	if not OS.has_feature("web"):
		box.add_child(_make_button("SALIR", _on_quit_pressed))

	return box


func _build_controls_panel() -> Control:
	var box := _make_box()
	box.add_child(_make_label("CONTROLES", 30, COLOR_TEXT))

	var panel := _make_panel()
	box.add_child(panel)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(grid)

	for row in CONTROLS:
		var key_label := _make_label(row[0], 20, COLOR_ACCENT)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(key_label)

		var action_label := _make_label(row[1], 20, COLOR_TEXT)
		action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(action_label)

	_controls_back_button = _make_button("VOLVER", _go_back)
	box.add_child(_controls_back_button)
	return box


func _build_options_panel() -> Control:
	var box := _make_box()
	box.add_child(_make_label("OPCIONES", 30, COLOR_TEXT))

	var panel := _make_panel()
	box.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)

	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 16)
	content.add_child(volume_row)

	var volume_label := _make_label("Volumen", 20, COLOR_TEXT)
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	volume_row.add_child(volume_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.custom_minimum_size = Vector2(240, 28)
	_volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volume_slider.value_changed.connect(_on_volume_changed)
	volume_row.add_child(_volume_slider)

	_volume_value_label = _make_label("100%", 20, COLOR_TEXT_DIM)
	_volume_value_label.custom_minimum_size = Vector2(60, 0)
	volume_row.add_child(_volume_value_label)

	_fullscreen_check = CheckButton.new()
	_fullscreen_check.text = "Pantalla completa"
	_fullscreen_check.add_theme_font_size_override("font_size", 20)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	content.add_child(_fullscreen_check)

	box.add_child(_make_button("VOLVER", _go_back))
	return box


# ---------------------------------------------------------------------------
# Helpers de UI
# ---------------------------------------------------------------------------

func _make_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	return box


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button(text: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 22)

	var base := COLOR_ACCENT if primary else COLOR_BUTTON
	button.add_theme_stylebox_override("normal", _make_button_style(base, false))
	button.add_theme_stylebox_override("hover", _make_button_style(base.lightened(0.15), false))
	button.add_theme_stylebox_override("pressed", _make_button_style(base.darkened(0.2), false))
	button.add_theme_stylebox_override("focus", _make_button_style(base.lightened(0.15), true))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, COLOR_TEXT)

	button.pressed.connect(callback)
	return button


func _make_button_style(color: Color, outlined: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	if outlined:
		style.set_border_width_all(3)
		style.border_color = COLOR_TEXT
	return style


# ---------------------------------------------------------------------------
# Navegación entre paneles
# ---------------------------------------------------------------------------

func _show_panel(panel: Control) -> void:
	_current_panel = panel
	for p: Control in [_main_panel, _controls_panel, _options_panel]:
		p.visible = (p == panel)

	if panel == _main_panel:
		_play_button.grab_focus()
	elif panel == _controls_panel:
		_controls_back_button.grab_focus()
	else:
		_volume_slider.grab_focus()


func _go_back() -> void:
	if _current_panel == _options_panel:
		_save_settings()
	_show_panel(_main_panel)


# ---------------------------------------------------------------------------
# Acciones
# ---------------------------------------------------------------------------

func _on_play_pressed() -> void:
	if _starting:
		return
	_starting = true
	_save_settings()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	await tween.finished

	var error := get_tree().change_scene_to_file(GAME_SCENE)
	if error != OK:
		push_error("MainMenu: no se pudo cargar %s (error %d)." % [GAME_SCENE, error])
		_starting = false
		modulate.a = 1.0


func _on_quit_pressed() -> void:
	_save_settings()
	get_tree().quit()


func _on_volume_changed(value: float) -> void:
	_apply_volume(value)


func _on_fullscreen_toggled(enabled: bool) -> void:
	_apply_fullscreen(enabled)


# ---------------------------------------------------------------------------
# Ajustes (se guardan en user://settings.cfg)
# ---------------------------------------------------------------------------

func _apply_volume(value: float) -> void:
	_volume_value_label.text = "%d%%" % roundi(value * 100.0)
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, value <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(value, 0.001)))


func _apply_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _load_settings() -> void:
	var volume := 1.0
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		volume = db_to_linear(AudioServer.get_bus_volume_db(bus))

	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		volume = float(config.get_value("audio", "master_volume", volume))
		fullscreen = bool(config.get_value("video", "fullscreen", fullscreen))
		_apply_fullscreen(fullscreen)

	# Fijar el valor del slider dispara value_changed y aplica el volumen.
	_volume_slider.set_value_no_signal(clampf(volume, 0.0, 1.0))
	_apply_volume(_volume_slider.value)
	_fullscreen_check.set_pressed_no_signal(fullscreen)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", _volume_slider.value)
	config.set_value("video", "fullscreen", _fullscreen_check.button_pressed)
	config.save(SETTINGS_PATH)
