extends CanvasLayer

var controller: Node
var root: Control
var menu_layer: Control
var briefing_layer: Control
var choice_layer: Control
var character_layer: Control
var character_selected_label: Label
var pause_layer: Control
var hud_layer: Control
var header: Panel
var mission_panel: Panel
var message_panel: Panel
var action_panel: Control
var last_toast_text: String = ""
var toast_tween: Tween
var action_hover_tween: Tween
var action_emergency_style: bool = false
var chapter_label: Label
var stage_label: Label
var budget_label: Label
var score_label: Label
var accessibility_label: Label
var objective_label: Label
var message_label: Label
var action_button: Button
var status_label: Label
var navigation_label: Label
var timeline_labels: Array[Label] = []
var timeline_chips: Array[Panel] = []
var last_timeline_stage: int = -1
var countdown_label: Label
var paused := false
var evaluation_panel: Panel
var evaluation_body: Label
var evaluation_button: Button
var character_preview_button: Button
var stage_progress_bar: ProgressBar
var phase_progress_label: Label
var stage_select_layer: Control
var settings_layer: Control
var status_panel: Panel
var minimap_panel: Panel
var minimap_overlay: Control
var minimap_player_marker: ColorRect
var minimap_objective_marker: ColorRect
var minimap_safe_marker: ColorRect
var minimap_camera: Camera3D
var minimap_subviewport: SubViewport
var minimap_world_extent: float = 154.0
var clock_label: Label
var weather_label: Label
var skin_panel: Panel
var selected_skin_index: int = 2

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func setup(game_controller: Node) -> void:
    controller = game_controller
    _build_hud()

func _build_hud() -> void:
    root = Control.new()
    root.name = "HUDRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.clip_contents = true
    root.theme = _build_hud_theme()
    add_child(root)
    hud_layer = root

    # Floating command capsule: larger legible type, compact labels, no stacked status text.
    header = _panel(root, Vector2.ZERO, Vector2(700, 82), Color(0.012, 0.035, 0.046, 0.48), Color("#00E5A3"), 18)
    header.name = "Header"
    header.add_theme_stylebox_override("panel", _style(Color(0.012, 0.035, 0.046, 0.48), Color("#00E5A3"), 18, 1))
    # Compact metric layout: no city-name heading and no vertical separators.
    chapter_label = _label(header, Vector2(0, 0), Vector2(1, 1), 1, Color.TRANSPARENT)
    chapter_label.visible = false
    stage_label = _label(header, Vector2(16, 21), Vector2(112, 30), 14, Color("#f0f8f4"))
    budget_label = _label(header, Vector2(132, 21), Vector2(130, 30), 14, Color("#f5d477"))
    score_label = _label(header, Vector2(276, 21), Vector2(82, 30), 14, Color("#f5d477"))
    accessibility_label = _label(header, Vector2(370, 21), Vector2(100, 30), 13, Color("#76e0bc"))
    clock_label = _label(header, Vector2(478, 12), Vector2(92, 23), 14, Color("#e1f2ec"))
    weather_label = _label(header, Vector2(478, 35), Vector2(92, 20), 12, Color("#8edec4"))
    countdown_label = _label(header, Vector2(576, 21), Vector2(110, 30), 12, Color("#ffc28b"))
    countdown_label.visible = false

    var timeline := _panel(header, Vector2(12, 61), Vector2(676, 15), Color(0.055, 0.10, 0.12, 0.55), Color(0.20, 0.60, 0.52, 0.70), 7)
    timeline.name = "ProgressTrack"
    stage_progress_bar = ProgressBar.new()
    stage_progress_bar.name = "StageProgressBar"
    stage_progress_bar.position = Vector2(2, 1)
    stage_progress_bar.size = Vector2(672, 13)
    stage_progress_bar.min_value = 0
    stage_progress_bar.max_value = 6
    stage_progress_bar.show_percentage = false
    stage_progress_bar.value = 0
    var progress_style := StyleBoxFlat.new()
    progress_style.bg_color = Color("#63ddb0")
    progress_style.set_corner_radius_all(4)
    stage_progress_bar.add_theme_stylebox_override("fill", progress_style)
    var progress_bg := StyleBoxFlat.new()
    progress_bg.bg_color = Color("#263e47")
    progress_bg.set_corner_radius_all(4)
    stage_progress_bar.add_theme_stylebox_override("background", progress_bg)
    timeline.add_child(stage_progress_bar)
    phase_progress_label = _label(timeline, Vector2(3, 0), Vector2(670, 15), 12, Color("#eefbf5"))
    phase_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    phase_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    phase_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    phase_progress_label.text = "01 / 06  •  PERSIAPAN"
    timeline_labels.clear()
    timeline_chips.clear()
    last_timeline_stage = -1

    mission_panel = _panel(root, Vector2.ZERO, Vector2(286, 112), Color(0.012, 0.045, 0.055, 0.44), Color("#00E5A3"), 8)
    mission_panel.name = "ObjectivePanel"
    var mission_title := _label(mission_panel, Vector2(11, 8), Vector2(264, 18), 12, Color("#78efc4"))
    mission_title.text = KotaLocale.t("mission_current")
    objective_label = _label(mission_panel, Vector2(11, 31), Vector2(264, 72), 12, Color("#e5f0ec"))
    objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    objective_label.clip_text = false

    status_panel = _panel(root, Vector2.ZERO, Vector2(286, 116), Color(0.012, 0.042, 0.060, 0.44), Color("#00E5A3"), 8)
    status_panel.name = "StatusPanel"
    var status_title := _label(status_panel, Vector2(10, 7), Vector2(264, 16), 11, Color("#83dce0"))
    status_title.text = KotaLocale.t("district_status")
    status_label = _label(status_panel, Vector2(10, 27), Vector2(264, 42), 12, Color("#e3efed"))
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.clip_text = true
    var nav_title := _label(status_panel, Vector2(10, 74), Vector2(264, 15), 10, Color("#75efc1"))
    nav_title.text = KotaLocale.t("navigation")
    navigation_label = _label(status_panel, Vector2(10, 92), Vector2(264, 19), 11, Color("#f3d27c"))
    navigation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    navigation_label.clip_text = true

    # Embedded live 3D radar. There is intentionally no full-screen map popup or map key.
    minimap_panel = _panel(root, Vector2.ZERO, Vector2(286, 230), Color(0.012, 0.042, 0.060, 0.44), Color("#00E5A3"), 8)
    minimap_panel.name = "MinimapPanel"

    minimap_overlay = Control.new()
    minimap_overlay.name = "MinimapOverlay"
    minimap_overlay.position = Vector2(5, 5)
    minimap_overlay.size = Vector2(276, 220)
    minimap_overlay.clip_contents = true
    minimap_panel.add_child(minimap_overlay)

    var map_viewport_container := SubViewportContainer.new()
    map_viewport_container.name = "MinimapViewportContainer"
    map_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    map_viewport_container.stretch = true
    map_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    minimap_overlay.add_child(map_viewport_container)

    var map_view := SubViewport.new()
    map_view.name = "MinimapWorldViewport"
    map_view.size = Vector2i(480, 480)
    map_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
    minimap_subviewport = map_view
    map_view.own_world_3d = false
    map_view.world_3d = get_viewport().world_3d
    map_viewport_container.add_child(map_view)

    minimap_camera = Camera3D.new()
    minimap_camera.name = "MinimapCamera"
    minimap_camera.set_script(load("res://scripts/ui/MinimapCameraBounds.gd"))
    minimap_camera.set("world_bounds_xz", Vector2(minimap_world_extent, minimap_world_extent))
    minimap_camera.set("map_center_xz", Vector2.ZERO)
    minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    minimap_camera.keep_aspect = Camera3D.KEEP_HEIGHT
    minimap_camera.size = minimap_world_extent
    minimap_camera.near = 0.1
    minimap_camera.far = 400.0
    map_view.add_child(minimap_camera)
    minimap_camera.current = true
    minimap_camera.make_current()

    minimap_safe_marker = _minimap_dot("SafeZoneMarker", Vector2(7, 7), Color("#6effb6"))
    minimap_overlay.add_child(minimap_safe_marker)
    minimap_safe_marker.position = _world_to_minimap_position(Vector3(42.0, 0.0, 42.0), minimap_safe_marker.size)
    minimap_objective_marker = _minimap_dot("ObjectiveMarker", Vector2(7, 7), Color("#ffad73"))
    minimap_overlay.add_child(minimap_objective_marker)
    minimap_player_marker = _minimap_dot("PlayerMarker", Vector2(8, 8), Color("#f8dc72"))
    minimap_overlay.add_child(minimap_player_marker)


    message_panel = _panel(root, Vector2.ZERO, Vector2(286, 54), Color(0.012, 0.044, 0.057, 0.44), Color("#00E5A3"), 8)
    message_panel.name = "MessagePanel"
    message_panel.visible = false
    var message_title := _label(message_panel, Vector2(10, 5), Vector2(266, 15), 11, Color("#6eeac0"))
    message_title.text = KotaLocale.t("system_message")
    message_label = _label(message_panel, Vector2(10, 22), Vector2(266, 26), 12, Color("#e2ecea"))
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.clip_text = true

    action_panel = Control.new()
    action_panel.name = "ActionPanel"
    action_panel.size = Vector2(206, 48)
    action_panel.mouse_filter = Control.MOUSE_FILTER_PASS
    root.add_child(action_panel)
    action_button = _button(action_panel, Vector2.ZERO, Vector2(206, 48), "LANJUTKAN", 12)
    action_button.pivot_offset = action_button.size * 0.5
    action_button.mouse_entered.connect(_animate_action_button.bind(true))
    action_button.mouse_exited.connect(_animate_action_button.bind(false))
    action_button.pressed.connect(_on_action_pressed)

    evaluation_panel = _panel(root, Vector2.ZERO, Vector2(560, 372), Color(0.012, 0.035, 0.046, 0.88), Color("#00E5A3"), 12)
    evaluation_panel.name = "EvaluationPanel"
    evaluation_panel.visible = false
    var eval_title := _label(evaluation_panel, Vector2(24, 18), Vector2(512, 32), 21, Color("#f0f8f4"))
    eval_title.text = KotaLocale.t("evaluation_title")
    evaluation_body = _label(evaluation_panel, Vector2(24, 58), Vector2(512, 244), 12, Color("#dce9e5"))
    evaluation_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    evaluation_body.clip_text = false
    evaluation_button = _button(evaluation_panel, Vector2(24, 318), Vector2(512, 38), KotaLocale.t("resume"), 10)
    evaluation_button.pressed.connect(_on_action_pressed)

    root.resized.connect(_layout_hud)
    call_deferred("_layout_hud")
    _hide_game_hud()

func _build_hud_theme() -> Theme:
    var theme := Theme.new()
    theme.default_font_size = 14
    theme.set_font_size("font_size", "Label", 13)
    theme.set_font_size("font_size", "Button", 14)
    theme.set_font_size("font_size", "CheckBox", 13)
    theme.set_font_size("font_size", "CheckButton", 13)
    theme.set_font_size("font_size", "OptionButton", 13)
    theme.set_font_size("font_size", "LineEdit", 13)
    theme.set_font_size("font_size", "SpinBox", 13)
    theme.set_font_size("font_size", "TextEdit", 13)
    theme.set_font_size("font_size", "RichTextLabel", 13)
    theme.set_font_size("font_size", "TabBar", 13)
    return theme

func _layout_hud() -> void:
    if root == null or not is_instance_valid(root) or header == null or not is_instance_valid(header):
        return
    var viewport_size := get_viewport().get_visible_rect().size
    if root.size.x > 0.0 and root.size.y > 0.0:
        viewport_size = root.size

    # Scale the fixed-size tactical cards gently on narrow windows while preserving readable desktop sizing.
    var header_scale := clampf((viewport_size.x - 24.0) / header.size.x, 0.40, 1.0)
    var side_scale := clampf((viewport_size.x - 24.0) / 572.0, 0.50, 1.0)
    var action_scale := clampf((viewport_size.x - 24.0) / action_panel.size.x, 0.75, 1.0) if action_panel != null else 1.0
    header.scale = Vector2(header_scale, header_scale)
    header.position = Vector2((viewport_size.x - header.size.x * header_scale) * 0.5, 10.0)

    if mission_panel != null:
        mission_panel.scale = Vector2(side_scale, side_scale)
        mission_panel.position = Vector2(12.0, header.position.y + header.size.y * header_scale + 10.0)
    if message_panel != null and mission_panel != null:
        message_panel.scale = Vector2(side_scale, side_scale)
        message_panel.position = Vector2(mission_panel.position.x, mission_panel.position.y + mission_panel.size.y * side_scale + 5.0)
    if status_panel != null:
        status_panel.scale = Vector2(side_scale, side_scale)
        status_panel.position = Vector2(maxf(12.0, viewport_size.x - status_panel.size.x * side_scale - 12.0), header.position.y + header.size.y * header_scale + 10.0)
    if minimap_panel != null and status_panel != null:
        minimap_panel.scale = Vector2(side_scale, side_scale)
        minimap_panel.position = Vector2(status_panel.position.x, status_panel.position.y + status_panel.size.y * side_scale + 5.0)
    if action_panel != null:
        action_panel.scale = Vector2(action_scale, action_scale)
        action_panel.position = Vector2(maxf(12.0, viewport_size.x - action_panel.size.x * action_scale - 12.0), maxf(12.0, viewport_size.y - action_panel.size.y * action_scale - 12.0))
    if evaluation_panel != null:
        evaluation_panel.position = (viewport_size - evaluation_panel.size) * 0.5

func _keep_centered(layer: Control, panel: Control) -> void:
    # Recenter every modal when its viewport is resized; initial positions are also
    # assigned at creation so there is no one-frame left/top flash on standard sizes.
    if layer.size.x > 0.0 and layer.size.y > 0.0:
        panel.position = (layer.size - panel.size) * 0.5
    layer.resized.connect(func():
        if is_instance_valid(layer) and is_instance_valid(panel) and layer.size.x > 0.0 and layer.size.y > 0.0:
            panel.position = (layer.size - panel.size) * 0.5
    )

func _minimap_dot(node_name: String, dot_size: Vector2, dot_color: Color) -> ColorRect:
    var dot := ColorRect.new()
    dot.name = node_name
    dot.size = dot_size
    dot.color = dot_color
    dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return dot

func _world_to_minimap_position(world_position: Vector3, marker_size: Vector2) -> Vector2:
    var map_size := minimap_overlay.size if minimap_overlay != null else Vector2(240, 240)
    var world_x := (world_position.x / minimap_world_extent + 0.5) * map_size.x
    var world_z := (world_position.z / minimap_world_extent + 0.5) * map_size.y
    return Vector2(
        clampf(world_x - marker_size.x * 0.5, 0.0, map_size.x - marker_size.x),
        clampf(world_z - marker_size.y * 0.5, 0.0, map_size.y - marker_size.y)
    )

func show_main_menu() -> void:
    close_overlay()
    AudioManager.set_game_mode(false)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _hide_game_hud()
    if menu_layer != null and is_instance_valid(menu_layer):
        menu_layer.queue_free()
    menu_layer = Control.new()
    menu_layer.name = "MainMenuLayer"
    menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_layer.clip_contents = true
    root.add_child(menu_layer)

    var background := TextureRect.new()
    background.name = "CinematicCityBackground"
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.texture = load("res://assets/KotaSiaga_CyberpunkMainMenu_BG.png") as Texture2D
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu_layer.add_child(background)

    var scrim := ColorRect.new()
    scrim.name = "LeftCinematicScrim"
    scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var scrim_shader := load("res://assets/shaders/MainMenuLeftScrim.gdshader") as Shader
    if scrim_shader != null:
        var shade_material := ShaderMaterial.new()
        shade_material.shader = scrim_shader
        scrim.material = shade_material
    else:
        scrim.color = Color(0.008, 0.018, 0.035, 0.48)
    menu_layer.add_child(scrim)

    var viewport_size := get_viewport().get_visible_rect().size
    var content_width := clampf(viewport_size.x * 0.30, 340.0, 430.0)
    var left_margin := clampf(viewport_size.x * 0.075, 42.0, 112.0)
    var content_height := minf(570.0, viewport_size.y - 42.0)
    var content_y := maxf(20.0, (viewport_size.y - content_height) * 0.5)

    # Narrow editorial rail instead of a large neon box around every element.
    var rail := ColorRect.new()
    rail.name = "MenuAccentRail"
    rail.position = Vector2(left_margin, content_y + 4.0)
    rail.size = Vector2(2.0, content_height - 10.0)
    rail.color = Color("#57d7c2")
    rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu_layer.add_child(rail)

    var margin := MarginContainer.new()
    margin.name = "MenuContentMargin"
    margin.position = Vector2(left_margin + 22.0, content_y)
    margin.size = Vector2(content_width - 22.0, content_height)
    margin.add_theme_constant_override("margin_left", 0)
    margin.add_theme_constant_override("margin_right", 8)
    margin.add_theme_constant_override("margin_top", 7)
    margin.add_theme_constant_override("margin_bottom", 4)
    menu_layer.add_child(margin)

    var content := VBoxContainer.new()
    content.name = "MenuContent"
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 4)
    margin.add_child(content)

    var eyebrow := _container_label(content, "ARUNIKA  /  EMERGENCY NETWORK", 9, Color("#83d8cc"), 20)
    eyebrow.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))

    var title := _container_label(content, "KOTA SIAGA", 31, Color("#f2f5f1"), 45)
    title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.60))
    title.add_theme_constant_override("shadow_offset_y", 1)

    var subtitle := _container_label(content, "ARUNIKA METROPOLITAN", 11, Color("#d1e1dd"), 22)
    subtitle.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))

    var strapline := _container_label(content, "KESIAPSIAGAAN  •  RESPON  •  PEMULIHAN" if KotaLocale.language_code == "id" else "PREPAREDNESS  •  RESPONSE  •  RECOVERY", 8, Color("#a4c1bd"), 22)
    strapline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    strapline.clip_text = false

    var rule := ColorRect.new()
    rule.custom_minimum_size = Vector2(0.0, 1.0)
    rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rule.color = Color(0.30, 0.72, 0.66, 0.64)
    content.add_child(rule)

    var section_gap := Control.new()
    section_gap.custom_minimum_size = Vector2(0.0, 8.0)
    content.add_child(section_gap)

    var continue_text := ("LANJUTKAN  ›" if KotaLocale.language_code == "id" else "CONTINUE  ›")
    var continue_button := _container_button(content, continue_text, 13, 45)
    _style_editorial_menu_button(continue_button, true)
    continue_button.pressed.connect(func():
        if menu_layer != null and is_instance_valid(menu_layer):
            menu_layer.queue_free()
        menu_layer = null
        controller.call("load_level", clampi(GameState.unlocked_level, 1, 3), true)
        root.visible = true
        _hide_game_hud()
    )

    var new_text := "PERMAINAN BARU" if KotaLocale.language_code == "id" else "NEW CAMPAIGN"
    var new_button := _container_button(content, new_text, 12, 40)
    _style_editorial_menu_button(new_button, false)
    new_button.pressed.connect(func():
        GameState.reset_campaign()
        _show_stage_select()
    )

    var load_text := "MUAT PERMAINAN" if KotaLocale.language_code == "id" else "LOAD GAME"
    var load_button := _container_button(content, load_text, 12, 40)
    _style_editorial_menu_button(load_button, false)
    load_button.pressed.connect(_show_stage_select)

    var middle_gap := Control.new()
    middle_gap.custom_minimum_size = Vector2(0.0, 5.0)
    content.add_child(middle_gap)

    var settings_text := "PENGATURAN" if KotaLocale.language_code == "id" else "SETTINGS"
    var settings_button := _container_button(content, settings_text, 11, 36)
    _style_editorial_menu_button(settings_button, false, true)
    settings_button.pressed.connect(_show_settings)

    var character_text := "KARAKTER" if KotaLocale.language_code == "id" else "PERSONNEL"
    var character_button := _container_button(content, character_text, 11, 36)
    _style_editorial_menu_button(character_button, false, true)
    character_button.pressed.connect(_show_character_select)

    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(spacer)

    var bottom_rule := ColorRect.new()
    bottom_rule.custom_minimum_size = Vector2(0.0, 1.0)
    bottom_rule.color = Color(0.42, 0.62, 0.60, 0.30)
    content.add_child(bottom_rule)

    var bottom_row := HBoxContainer.new()
    bottom_row.add_theme_constant_override("separation", 12)
    content.add_child(bottom_row)
    var quit_text := "KELUAR" if KotaLocale.language_code == "id" else "QUIT"
    var quit_button := _container_button(bottom_row, quit_text, 10, 32)
    quit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _style_editorial_menu_button(quit_button, false, true)
    quit_button.pressed.connect(func(): get_tree().quit())
    var version := _container_label(bottom_row, "SIAP  /  TANGGAP  /  SELAMAT", 7, Color("#afc5c0"), 32)
    version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    version.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    root.visible = true
    _fade_in_layer(menu_layer, 0.42)

func _fade_in_layer(layer: Control, duration: float = 0.22) -> void:
    if layer == null or not is_instance_valid(layer):
        return
    layer.modulate.a = 0.0
    var tween := create_tween()
    tween.tween_property(layer, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _style_editorial_menu_button(button: Button, primary: bool, quiet: bool = false) -> void:
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.add_theme_font_size_override("font_size", 13 if primary else 11)
    button.add_theme_color_override("font_color", Color("#eff8f4") if primary else Color("#c2d7d2"))
    button.add_theme_color_override("font_hover_color", Color("#ffffff"))
    button.add_theme_color_override("font_pressed_color", Color("#a0e7d9"))
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.02, 0.055, 0.065, 0.35 if primary else 0.08)
    normal.set_border_width_all(0)
    normal.border_width_left = 2 if primary else 0
    normal.border_color = Color("#65d8c4")
    normal.set_corner_radius_all(2)
    normal.content_margin_left = 14.0
    normal.content_margin_right = 8.0
    normal.content_margin_top = 8.0
    normal.content_margin_bottom = 8.0
    button.add_theme_stylebox_override("normal", normal)
    var hover := StyleBoxFlat.new()
    hover.bg_color = Color(0.055, 0.16, 0.16, 0.66)
    hover.set_border_width_all(0)
    hover.border_width_left = 3
    hover.border_color = Color("#8ee8d9")
    hover.set_corner_radius_all(2)
    hover.content_margin_left = 17.0
    hover.content_margin_right = 8.0
    hover.content_margin_top = 8.0
    hover.content_margin_bottom = 8.0
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", _style(Color(0.045, 0.13, 0.14, 0.82), Color("#7adcca"), 2, 1))
    button.add_theme_stylebox_override("focus", _style(Color(0.05, 0.12, 0.13, 0.75), Color("#7adcca"), 2, 1))
    if quiet:
        button.add_theme_color_override("font_color", Color("#9ebbb5"))

func show_briefing(level: int) -> void:
    close_overlay()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _hide_game_hud()
    briefing_layer = Control.new()
    briefing_layer.name = "BriefingLayer"
    briefing_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    briefing_layer.clip_contents = true
    root.add_child(briefing_layer)

    var dim := ColorRect.new()
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.color = Color(0.015, 0.035, 0.045, 0.76)
    briefing_layer.add_child(dim)

    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    var panel_size := Vector2(minf(920.0, viewport_size.x - 32.0), minf(575.0, viewport_size.y - 32.0))
    var panel := _panel(briefing_layer, (viewport_size - panel_size) * 0.5, panel_size, Color(0.025, 0.075, 0.095, 0.97), Color(0.30, 0.70, 0.61, 0.9), 18)
    panel.name = "BriefingDialog"
    _keep_centered(briefing_layer, panel)

    var kicker := _label(panel, Vector2(26, 17), Vector2(850, 16), 9, Color("#67dcb4"))
    kicker.text = KotaLocale.t("story_heading")
    var title := _label(panel, Vector2(26, 39), Vector2(850, 34), 23, Color("#f1f7f4"))
    title.text = GameState.level_title()
    var line := ColorRect.new()
    line.position = Vector2(26, 80)
    line.size = Vector2(panel_size.x - 52.0, 2)
    line.color = Color("#345660")
    panel.add_child(line)

    var story_scroll := ScrollContainer.new()
    story_scroll.name = "StoryScroll"
    story_scroll.position = Vector2(26, 94)
    story_scroll.size = Vector2(panel_size.x - 52.0, 260)
    story_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    story_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    story_scroll.clip_contents = true
    panel.add_child(story_scroll)

    var story_content := VBoxContainer.new()
    story_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    story_content.add_theme_constant_override("separation", 0)
    story_scroll.add_child(story_content)
    var story := Label.new()
    story.name = "StoryText"
    story.text = GameState.story_text()
    story.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    story.clip_text = false
    story.add_theme_font_size_override("font_size", 13)
    story.add_theme_color_override("font_color", Color("#dce9e5"))
    story.add_theme_constant_override("line_spacing", 4)
    story_content.add_child(story)

    var goals_title := _label(panel, Vector2(26, 365), Vector2(470, 16), 9, Color("#73ddb8"))
    goals_title.text = "STAGE OBJECTIVES" if KotaLocale.language_code == "en" else "TARGET STAGE"
    var goals := _label(panel, Vector2(26, 386), Vector2(470, 66), 11, Color("#dce9e5"))
    goals.text = _goals_for_level(level)
    goals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    goals.clip_text = false

    var bonus_hint := _label(panel, Vector2(26, 493), Vector2(480, 30), 9, Color("#efca79"))
    bonus_hint.text = "OPTIONAL  •  Complete side objectives for a special campaign ending." if KotaLocale.language_code == "en" else "OPSIONAL  •  Selesaikan misi sampingan untuk ending spesial kampanye."
    bonus_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var start := _button(panel, Vector2(panel_size.x - 326.0, 484), Vector2(300, 46), ("DEPLOY TO DISTRICT  →" if KotaLocale.language_code == "en" else "MASUK KAWASAN  →"), 12)
    start.pressed.connect(func():
        briefing_layer.queue_free()
        briefing_layer = null
        controller.call("begin_mission")
        _show_game_hud()
        refresh()
    )
    root.visible = true
    _fade_in_layer(briefing_layer, 0.24)


func show_citizen_choice(index: int, citizen_name: String, dialogue: String, reassured: bool) -> void:
    close_overlay()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    choice_layer = Control.new()
    choice_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(choice_layer)
    var dim := ColorRect.new(); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); dim.color = Color(0.01,0.035,0.04,0.74); choice_layer.add_child(dim)
    var panel := _panel(choice_layer, Vector2(390, 205), Vector2(500, 315), Color("#0d222b"), Color("#50d7ab"), 18)
    _keep_centered(choice_layer, panel)
    var header := _label(panel, Vector2(24, 20), Vector2(440, 24), 18, Color("#f0f6f3")); header.text = citizen_name
    var role := _label(panel, Vector2(24, 51), Vector2(440, 18), 10, Color("#70dfb9")); role.text = "RESIDENT NEEDS HELP" if KotaLocale.language_code == "en" else "WARGA MEMBUTUHKAN BANTUAN"
    var quote := _label(panel, Vector2(24, 78), Vector2(448, 105), 14, Color("#dbe8e5"))
    quote.text = "“%s”" % dialogue
    quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    quote.clip_text = false
    var reassurance_text := ("REASSURE (+5 TRUST)" if not reassured else "RESIDENT CALM") if KotaLocale.language_code == "en" else ("TENANGKAN (+5 TRUST)" if not reassured else "WARGA SUDAH TENANG")
    var reassurance_button := _button(panel, Vector2(24, 215), Vector2(210, 48), reassurance_text, 10)
    reassurance_button.disabled = reassured
    reassurance_button.pressed.connect(func():
        choice_layer.queue_free(); choice_layer = null
        controller.call("resolve_citizen_choice", index, "reassure")
    )
    var evacuate_button := _button(panel, Vector2(247, 215), Vector2(228, 48), "GUIDE TO SAFE POINT  →" if KotaLocale.language_code == "en" else "TUNTUN KE TITIK AMAN  →", 10)
    evacuate_button.pressed.connect(func():
        choice_layer.queue_free(); choice_layer = null
        controller.call("resolve_citizen_choice", index, "evacuate")
    )
    if controller != null:
        controller.get("player").set("input_enabled", false)
    _fade_in_layer(choice_layer, 0.20)

func _goals_for_level(level: int) -> String:
    if KotaLocale.language_code == "en":
        match level:
            1: return "01  Prepare key facilities\n02  Clear drains and standing water\n03  Inspect damage and repair the district"
            2: return "01  Reopen blocked access\n02  Guide four residents to the Safe Point\n03  Deliver the first-aid kit for a bonus"
            3: return "01  Clear debris from the route\n02  Evacuate residents safely\n03  Repair facilities and restore the siren"
    match level:
        1: return "01  Siapkan fasilitas prioritas\n02  Tangani saluran dan genangan\n03  Inspeksi kerusakan dan perbaiki kawasan"
        2: return "01  Buka akses yang terhambat\n02  Tuntun empat warga ke Titik Aman\n03  Antar kotak P3K untuk bonus"
        3: return "01  Bersihkan puing dari jalur\n02  Evakuasi warga dengan aman\n03  Perbaiki fasilitas dan aktifkan sirene"
    return ""

func refresh() -> void:
    if root == null or controller == null: return
    # Keep the chapter identifier short; the former combined chapter/disaster string
    # exceeded its fixed block and overlapped the budget separator at readable font sizes.
    chapter_label.text = ""
    stage_label.text = "%s %02d" % [KotaLocale.t("stage_prefix"), GameState.level]
    if GameState.stage == GameState.DISASTER:
        countdown_label.visible = true
        countdown_label.text = "⏱ %.0f %s" % [maxf(0.0, float(controller.get("disaster_duration")) - float(controller.get("disaster_timer"))), ("sec" if KotaLocale.language_code == "en" else "dtk")]
        countdown_label.add_theme_color_override("font_color", Color("#ffc28b"))
    else:
        countdown_label.text = ""
        countdown_label.visible = false
    budget_label.text = "%s  %s" % [KotaLocale.t("funds"), _compact_budget(GameState.budget)]
    budget_label.tooltip_text = "%s: %s" % [KotaLocale.t("funds"), KotaLocale.format_money(GameState.budget)]
    score_label.text = "%s %d" % [KotaLocale.t("points"), GameState.score]
    score_label.tooltip_text = "Poin diperoleh dari objektif; dipakai untuk menghitung rating stage." if KotaLocale.language_code == "id" else "Earned from objectives; used to calculate the stage rating."
    accessibility_label.text = "%s %d%%" % [KotaLocale.t("access"), int(controller.call("accessibility_score"))]
    objective_label.text = GameState.objective()
    if GameState.message != last_toast_text:
        var hud_is_active := header != null and header.visible and menu_layer == null and briefing_layer == null and choice_layer == null and pause_layer == null
        if hud_is_active:
            _show_message_toast(GameState.message)
        else:
            last_toast_text = GameState.message
    status_label.text = "%s %d%%  •  %s %d%%\n%s %d/4  •  %s %d\n%s %d  •  %s %d/%d" % [KotaLocale.t("trust"), GameState.trust, KotaLocale.t("access"), int(controller.call("accessibility_score")), KotaLocale.t("assets"), GameState.facilities_ready, KotaLocale.t("upgrade"), GameState.facilities_upgraded, KotaLocale.t("damaged"), GameState.damaged_count, KotaLocale.t("civilians_safe"), GameState.citizens_safe, GameState.citizens_total]
    if navigation_label != null:
        navigation_label.text = str(controller.call("navigation_hint_text"))
    var stage_index := GameState.stage
    if last_timeline_stage >= 0 and stage_index != last_timeline_stage:
        AudioManager.play_stage_transition()
    if stage_progress_bar != null:
        stage_progress_bar.value = float(stage_index + 1)
    last_timeline_stage = stage_index
    if phase_progress_label != null:
        var phase_names_id: Array[String] = ["PERSIAPAN", "BENCANA AKTIF", "RESPONS", "INSPEKSI", "PERBAIKAN", "EVALUASI"]
        var phase_names_en: Array[String] = ["PREPARATION", "ACTIVE DISASTER", "RESPONSE", "INSPECTION", "REPAIR", "DEBRIEF"]
        var phase_index: int = clampi(stage_index, 0, 5)
        var phase_name: String
        if KotaLocale.language_code == "en":
            phase_name = phase_names_en[phase_index]
        else:
            phase_name = phase_names_id[phase_index]
        phase_progress_label.text = "%02d / 06  •  %s" % [clampi(stage_index + 1, 1, 6), phase_name]
    action_button.text = str(controller.call("action_label"))
    action_button.disabled = not bool(controller.call("can_advance"))
    action_button.visible = GameState.stage != GameState.EVALUATION
    var active_emergency := false
    var current_world: Variant = controller.get("world")
    if GameState.stage == GameState.DISASTER and current_world != null:
        active_emergency = bool(current_world.get("weather_active")) and int(current_world.get("current_weather_level")) in [1, 2, 3]
    elif GameState.stage == GameState.PREPARATION:
        # Highlight the hazard trigger once the player has completed a prep action.
        active_emergency = bool(controller.call("can_advance"))
    _set_action_emergency_style(active_emergency)
    if clock_label != null:
        var world: Variant = controller.get("world")
        if world != null and world.has_method("get_clock_text"):
            clock_label.text = "%s  •  %s" % [str(world.call("get_clock_text")), str(world.call("get_period_text"))]
            weather_label.text = str(world.call("get_weather_text"))
    if skin_panel != null:
        skin_panel.visible = header.visible and not paused and menu_layer == null and briefing_layer == null and choice_layer == null and pause_layer == null
    if GameState.stage == GameState.EVALUATION:
        _show_evaluation()
    else:
        _hide_evaluation()

func _compact_budget(amount: int) -> String:
    # Keep the HUD block readable; the exact currency value remains available in its tooltip.
    if KotaLocale.language_code == "en":
        if amount >= 1000000:
            return "Rp %.1fM" % (float(amount) / 1000000.0)
        if amount >= 1000:
            return "Rp %dK" % int(round(float(amount) / 1000.0))
    else:
        if amount >= 1000000:
            return "Rp %.1f jt" % (float(amount) / 1000000.0)
        if amount >= 1000:
            return "Rp %d rb" % int(round(float(amount) / 1000.0))
    return KotaLocale.format_money(amount)

func _format_rupiah(amount: int) -> String:
    return KotaLocale.format_money(amount)

func set_disaster_countdown(seconds: float) -> void:
    if countdown_label:
        countdown_label.text = ("⏱ %.0f sec" % seconds if KotaLocale.language_code == "en" else "⏱ %.0f dtk" % seconds) if GameState.stage == GameState.DISASTER else ""

func _on_action_pressed() -> void:
    if GameState.campaign_complete:
        get_tree().reload_current_scene()
        return
    controller.call("advance_stage")
    refresh()

func _show_evaluation() -> void:
    if evaluation_panel == null: return
    if briefing_layer != null or choice_layer != null or menu_layer != null or pause_layer != null:
        evaluation_panel.visible = false
        return
    evaluation_panel.visible = true
    var stars := GameState.stars_for_current_chapter()
    var star_display := "★".repeat(stars) + "☆".repeat(3 - stars)
    if KotaLocale.language_code == "en":
        var grade_en := "DISTRICT ELITE" if stars == 3 else ("FIELD READY" if stars == 2 else "ROOM TO IMPROVE")
        var evac_en := "District stage: preparedness and repairs." if GameState.citizens_total == 0 else "Residents at Safe Point: %d / %d" % [GameState.citizens_safe, GameState.citizens_total]
        evaluation_body.text = "%s\n%s  |  %d / 3 stars\nStage points: %d  •  Public trust: %d%% (%s)\nFacilities ready: %d / 4  •  upgraded: %d\nDamaged: %d  •  inspected: %d  •  repaired: %d\n%s\nFunds remaining: %s\nCampaign side objectives: %d / 3\n\nYour calls determine how ready Arunika is for the next incident." % [grade_en, star_display, stars, GameState.score, GameState.trust, GameState.trust_status(), GameState.facilities_ready, GameState.facilities_upgraded, GameState.damaged_count, GameState.inspected_count, GameState.repaired_count, evac_en, _format_rupiah(GameState.budget), GameState.side_events_completed]
        if GameState.campaign_complete:
            evaluation_body.text += "\n\nCAMPAIGN COMPLETE — Arunika is safer, but the city still needs regular readiness checks."
        evaluation_button.text = KotaLocale.t("back_menu") if GameState.campaign_complete else KotaLocale.t("next_stage")
    else:
        var grade := "ARUNIKA TANGGUH" if stars == 3 else ("SIAP BERTUMBUH" if stars == 2 else "CATATAN UNTUK STAGE BERIKUTNYA")
        var evac_text := "Stage ini berfokus pada kesiapsiagaan dan perbaikan." if GameState.citizens_total == 0 else "Warga di Titik Aman: %d / %d" % [GameState.citizens_safe, GameState.citizens_total]
        var bonus_summary := "Misi sampingan kampanye: %d / 3" % GameState.side_events_completed
        evaluation_body.text = "%s\n%s  |  %d / 3 bintang\nSkor stage: %d  •  Kepercayaan warga: %d%% (%s)\nFasilitas siap: %d / 4  •  upgrade: %d\nRusak: %d  •  diperiksa: %d  •  diperbaiki: %d\n%s\nAnggaran tersisa: %s\n%s\n\nKeputusanmu menentukan kesiapan Arunika menghadapi ancaman berikutnya." % [grade, star_display, stars, GameState.score, GameState.trust, GameState.trust_status(), GameState.facilities_ready, GameState.facilities_upgraded, GameState.damaged_count, GameState.inspected_count, GameState.repaired_count, evac_text, _format_rupiah(GameState.budget), bonus_summary]
        if GameState.campaign_complete:
            if GameState.side_events_completed >= 3:
                evaluation_body.text += "\n\nENDING SPESIAL: KOORDINATOR TELADAN — seluruh objective sampingan selesai."
            else:
                evaluation_body.text += "\n\nKAMPANYE SELESAI — Arunika belajar dari hujan, banjir, dan puting beliung. Kamu masih bisa mengulang stage untuk menuntaskan objective sampingan."
        evaluation_button.text = KotaLocale.t("back_menu") if GameState.campaign_complete else KotaLocale.t("next_stage")
    evaluation_button.visible = true
    evaluation_button.disabled = false

func _hide_evaluation() -> void:
    if evaluation_panel != null: evaluation_panel.visible = false

func show_finale() -> void:
    _show_evaluation()

func show_pause() -> void:
    if pause_layer != null or briefing_layer != null or choice_layer != null:
        return
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    get_tree().paused = true
    if controller != null and controller.get("player") != null:
        controller.get("player").set("input_enabled", false)
    pause_layer = Control.new()
    pause_layer.name = "PauseLayer"
    pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
    pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(pause_layer)

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.006, 0.018, 0.028, 0.68)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    pause_layer.add_child(shade)

    var viewport_size := get_viewport().get_visible_rect().size
    var panel_size := Vector2(minf(410.0, viewport_size.x - 32.0), minf(304.0, viewport_size.y - 28.0))
    var panel := _panel(pause_layer, (viewport_size - panel_size) * 0.5, panel_size, Color(0.018, 0.032, 0.040, 0.94), Color(0.28, 0.58, 0.54, 0.68), 10)
    panel.name = "PauseDialog"
    _keep_centered(pause_layer, panel)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 22)
    margin.add_theme_constant_override("margin_right", 22)
    margin.add_theme_constant_override("margin_top", 17)
    margin.add_theme_constant_override("margin_bottom", 16)
    panel.add_child(margin)
    var content := VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 5)
    margin.add_child(content)

    var eyebrow := _container_label(content, "ARUNIKA  /  OPERASI DITAHAN" if KotaLocale.language_code == "id" else "ARUNIKA  /  OPERATION ON HOLD", 9, Color("#7cc9bd"), 18)
    var heading := _container_label(content, KotaLocale.t("pause_title"), 24, Color("#f0f4f1"), 38)
    var desc := _container_label(content, "Progress stage tetap tersimpan." if KotaLocale.language_code == "id" else "Your stage progress is preserved.", 11, Color("#a9bcb8"), 21)
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    var divider := ColorRect.new()
    divider.custom_minimum_size = Vector2(0.0, 1.0)
    divider.color = Color(0.34, 0.54, 0.52, 0.38)
    content.add_child(divider)

    var resume := _container_button(content, KotaLocale.t("resume") + "   ›", 13, 43)
    resume.pressed.connect(close_overlay)
    var settings := _container_button(content, KotaLocale.t("settings"), 11, 36)
    _style_editorial_menu_button(settings, false, true)
    settings.pressed.connect(_show_settings)
    var secondary := HBoxContainer.new()
    secondary.add_theme_constant_override("separation", 8)
    content.add_child(secondary)
    var restart := _container_button(secondary, KotaLocale.t("restart_stage"), 10, 35)
    restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _style_editorial_menu_button(restart, false, true)
    restart.pressed.connect(func():
        close_overlay()
        controller.call("load_level", GameState.level, true)
    )
    var menu := _container_button(secondary, KotaLocale.t("main_menu"), 10, 35)
    menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _style_editorial_menu_button(menu, false, true)
    menu.pressed.connect(func():
        get_tree().paused = false
        get_tree().reload_current_scene()
    )
    _fade_in_layer(pause_layer, 0.20)

func close_overlay() -> void:
    for key in ["briefing_layer", "choice_layer", "character_layer", "pause_layer", "settings_layer", "stage_select_layer"]:
        var instance: Variant = get(key)
        if instance != null and is_instance_valid(instance): instance.queue_free()
        set(key, null)
    paused = false
    get_tree().paused = false
    if controller != null and bool(controller.get("mission_started")):
        controller.get("player").set("input_enabled", true)
        var scene_root := get_tree().current_scene
        if scene_root != null and scene_root.has_method("set_mouse_capture"):
            scene_root.call("set_mouse_capture", true)

func _hide_game_hud() -> void:
    if header: header.visible = false
    for child_name in ["ObjectivePanel", "StatusPanel", "MinimapPanel", "MessagePanel", "ActionPanel"]:
        var node := root.get_node_or_null(child_name)
        if node: node.visible = false
    var timeline := header.get_node_or_null("ProgressTrack") if header != null else null
    if timeline != null: timeline.visible = false
    if skin_panel != null: skin_panel.visible = false
    _hide_evaluation()

func _show_game_hud() -> void:
    if header: header.visible = true
    for child_name in ["ObjectivePanel", "StatusPanel", "MinimapPanel", "ActionPanel"]:
        var node := root.get_node_or_null(child_name)
        if node: node.visible = true
    if message_panel != null:
        message_panel.visible = not last_toast_text.is_empty() and message_panel.modulate.a > 0.01
    var timeline := header.get_node_or_null("ProgressTrack") if header != null else null
    if timeline != null: timeline.visible = true
    if skin_panel != null: skin_panel.visible = true

func _show_message_toast(message_text: String) -> void:
    last_toast_text = message_text
    if message_panel == null or not is_instance_valid(message_panel) or message_label == null:
        return
    if toast_tween != null and toast_tween.is_running():
        toast_tween.kill()
    if message_text.strip_edges().is_empty():
        message_panel.visible = false
        return
    var viewport_size := get_viewport().get_visible_rect().size
    var card_width := minf(286.0, maxf(224.0, viewport_size.x * 0.36))
    var estimated_chars_per_line := maxf(25.0, (card_width - 20.0) / 5.8)
    var line_count := clampi(int(ceil(float(message_text.length()) / estimated_chars_per_line)), 1, 3)
    var toast_height := 35.0 + float(line_count) * 17.0
    message_panel.size = Vector2(card_width, toast_height)
    message_label.position = Vector2(10, 22)
    message_label.size = Vector2(card_width - 20.0, toast_height - 26.0)
    message_label.text = message_text
    AudioManager.play_notification()
    message_panel.modulate.a = 1.0
    message_panel.visible = true
    _layout_hud()
    toast_tween = create_tween()
    toast_tween.tween_interval(4.2)
    toast_tween.tween_property(message_panel, "modulate:a", 0.0, 0.4)
    toast_tween.tween_callback(func():
        if is_instance_valid(message_panel) and message_panel.modulate.a <= 0.02:
            message_panel.visible = false
    )

func _animate_action_button(hovered: bool) -> void:
    if action_button == null or not is_instance_valid(action_button):
        return
    if action_hover_tween != null and action_hover_tween.is_running():
        action_hover_tween.kill()
    action_hover_tween = create_tween()
    var target_scale := Vector2(1.035, 1.035) if hovered and not action_button.disabled else Vector2.ONE
    action_hover_tween.tween_property(action_button, "scale", target_scale, 0.13).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _set_action_emergency_style(active_emergency: bool) -> void:
    if action_button == null or action_emergency_style == active_emergency:
        return
    action_emergency_style = active_emergency
    if active_emergency:
        var emergency_normal := _style(Color(0.30, 0.16, 0.055, 0.84), Color("#ffc477"), 8, 1)
        var emergency_hover := _style(Color(0.48, 0.24, 0.065, 0.96), Color("#ffe0a0"), 8, 2)
        emergency_hover.shadow_color = Color(1.0, 0.55, 0.12, 0.24)
        emergency_hover.shadow_size = 5
        action_button.add_theme_stylebox_override("normal", emergency_normal)
        action_button.add_theme_stylebox_override("hover", emergency_hover)
        action_button.add_theme_stylebox_override("pressed", _style(Color(0.22, 0.105, 0.04, 0.95), Color("#ffcb7e"), 8, 2))
        action_button.add_theme_color_override("font_color", Color("#fff5e4"))
    else:
        var normal_style := _style(Color(0.025, 0.26, 0.20, 0.78), Color("#00E5A3"), 8, 1)
        var hover_style := _style(Color(0.025, 0.40, 0.29, 0.94), Color("#75ffd0"), 8, 2)
        hover_style.shadow_color = Color(0.0, 0.90, 0.64, 0.18)
        hover_style.shadow_size = 4
        action_button.add_theme_stylebox_override("normal", normal_style)
        action_button.add_theme_stylebox_override("hover", hover_style)
        action_button.add_theme_stylebox_override("pressed", _style(Color(0.015, 0.20, 0.16, 0.92), Color("#77e7bd"), 8, 2))
        action_button.add_theme_color_override("font_color", Color("#f4fff8"))

func _panel(parent: Control, pos: Vector2, size: Vector2, fill: Color, border: Color, radius: int) -> Panel:
    var panel := Panel.new()
    panel.position = pos
    panel.size = size
    panel.clip_contents = true
    panel.add_theme_stylebox_override("panel", _style(fill, border, radius, 1))
    parent.add_child(panel)
    return panel

func _label(parent: Control, pos: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.position = pos
    label.size = size
    label.clip_text = false
    label.add_theme_font_size_override("font_size", maxi(font_size, 12))
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func _button(parent: Control, pos: Vector2, size: Vector2, text_value: String, font_size: int) -> Button:
    var button := Button.new()
    button.position = pos
    button.size = size
    button.text = text_value
    button.clip_contents = true
    button.add_theme_font_size_override("font_size", maxi(font_size, 13))
    button.add_theme_color_override("font_color", Color("#f4fff8"))
    button.add_theme_color_override("font_hover_color", Color("#ffffff"))
    button.add_theme_color_override("font_pressed_color", Color("#d7fff0"))
    button.add_theme_stylebox_override("normal", _style(Color(0.025, 0.26, 0.20, 0.78), Color("#00E5A3"), 8, 1))
    var hover_style := _style(Color(0.025, 0.40, 0.29, 0.92), Color("#75ffd0"), 8, 2)
    hover_style.shadow_color = Color(0.0, 0.90, 0.64, 0.18)
    hover_style.shadow_size = 4
    button.add_theme_stylebox_override("hover", hover_style)
    button.add_theme_stylebox_override("pressed", _style(Color(0.015, 0.20, 0.16, 0.92), Color("#77e7bd"), 8, 2))
    button.add_theme_stylebox_override("focus", _style(Color(0.08, 0.25, 0.21, 0.95), Color("#b1f5d9"), 8, 2))
    button.add_theme_stylebox_override("disabled", _style(Color(0.035, 0.10, 0.095, 0.85), Color(0.22, 0.44, 0.37, 0.65), 8, 1))
    button.add_theme_constant_override("h_separation", 8)
    button.mouse_entered.connect(AudioManager.play_ui_hover)
    button.pressed.connect(AudioManager.play_ui_confirm)
    parent.add_child(button)
    return button

func _style(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(width)
    style.set_corner_radius_all(radius)
    style.anti_aliasing = true
    style.anti_aliasing_size = 1.0
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.16)
    style.shadow_size = 3
    return style

func _glass_style(opacity: float = 0.44, radius: int = 8, border: Color = Color(0.0, 0.90, 0.64, 1.0)) -> StyleBoxFlat:
    # Canonical 40-45% dark glass; 1px teal outline; compact 8px corners.
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.012, 0.035, 0.045, clampf(opacity, 0.40, 0.45))
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.anti_aliasing = true
    style.anti_aliasing_size = 1.0
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
    style.shadow_size = 3
    return style

func _glass_card(parent: Control, opacity: float = 0.44, border: Color = Color(0.0, 0.90, 0.64, 1.0)) -> PanelContainer:
    var card := PanelContainer.new()
    card.add_theme_stylebox_override("panel", _glass_style(opacity, 8, border))
    parent.add_child(card)
    return card

func _show_character_select() -> void:
    if character_layer != null and is_instance_valid(character_layer):
        AudioManager.play_ui_back()
        character_layer.queue_free()
    character_layer = Control.new()
    character_layer.name = "CharacterRosterLayer"
    character_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(character_layer)

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.004, 0.014, 0.024, 0.80)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    character_layer.add_child(shade)

    var viewport_size := get_viewport().get_visible_rect().size
    var panel_size := Vector2(minf(930.0, viewport_size.x - 32.0), minf(480.0, viewport_size.y - 28.0))
    var panel := _panel(character_layer, (viewport_size - panel_size) * 0.5, panel_size, Color(0.018, 0.033, 0.041, 0.96), Color(0.30, 0.58, 0.53, 0.64), 10)
    panel.name = "CharacterRosterDialog"
    _keep_centered(character_layer, panel)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 15)
    margin.add_theme_constant_override("margin_bottom", 13)
    panel.add_child(margin)
    var content := VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 7)
    margin.add_child(content)

    var header_row := HBoxContainer.new()
    header_row.add_theme_constant_override("separation", 12)
    content.add_child(header_row)
    var title_col := VBoxContainer.new()
    title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_col.add_theme_constant_override("separation", 1)
    header_row.add_child(title_col)
    _container_label(title_col, "PERSONEL LAPANGAN" if KotaLocale.language_code == "id" else "FIELD PERSONNEL", 20, Color("#eef4f0"), 28)
    _container_label(title_col, "Pilih peran; perubahan diterapkan langsung." if KotaLocale.language_code == "id" else "Choose a role; changes apply immediately.", 10, Color("#a5bab5"), 19)
    var active_chip := _container_label(header_row, ("AKTIF  ·  %s" if KotaLocale.language_code == "id" else "ACTIVE  ·  %s") % GameState.player_skin.to_upper(), 9, Color("#78d8c5"), 30)
    active_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    active_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    var divider := ColorRect.new()
    divider.custom_minimum_size = Vector2(0.0, 1.0)
    divider.color = Color(0.32, 0.54, 0.51, 0.40)
    content.add_child(divider)

    var ids: Array[String] = ["logistics", "paramedic", "firefighter", "police"]
    var names_id: Array[String] = ["LOGISTIK", "PARAMEDIS", "PEMADAM", "POLISI"]
    var names_en: Array[String] = ["LOGISTICS", "PARAMEDIC", "FIREFIGHTER", "POLICE"]
    var desc_id: Array[String] = ["Distribusi bantuan dan evakuasi.", "Pertolongan pertama dan triase.", "Penanganan api dan penyelamatan.", "Keamanan akses dan lalu lintas."]
    var desc_en: Array[String] = ["Supplies and evacuation routes.", "First aid and casualty support.", "Fire suppression and rescue.", "Access control and traffic safety."]

    var grid := GridContainer.new()
    grid.name = "PersonnelGrid"
    grid.columns = 4
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 9)
    grid.add_theme_constant_override("v_separation", 0)
    content.add_child(grid)

    for i in range(ids.size()):
        var active := GameState.player_skin == ids[i]
        var border := Color("#63cdb8") if active else Color(0.25, 0.40, 0.41, 0.36)
        var card := _glass_card(grid, 0.30, border)
        card.name = "RoleCard_%s" % ids[i]
        card.custom_minimum_size = Vector2(0.0, 325.0)
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var card_margin := _card_margin(card, 9, 8)
        var role_box := VBoxContainer.new()
        role_box.alignment = BoxContainer.ALIGNMENT_CENTER
        role_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        role_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
        role_box.add_theme_constant_override("separation", 5)
        card_margin.add_child(role_box)

        var marker := _container_label(role_box, "01" if i == 0 else ("02" if i == 1 else ("03" if i == 2 else "04")), 9, Color("#80b8b0"), 15)
        marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        var preview_row := HBoxContainer.new()
        preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
        role_box.add_child(preview_row)
        _add_skin_model_preview(preview_row, ids[i])

        var role_name := _container_label(role_box, names_id[i] if KotaLocale.language_code == "id" else names_en[i], 12, Color("#f0f4f1"), 22)
        role_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        var role_desc := _container_label(role_box, desc_id[i] if KotaLocale.language_code == "id" else desc_en[i], 10, Color("#a9bfba"), 38)
        role_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        role_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        role_desc.clip_text = false

        var role_state := _container_label(role_box, ("PERAN AKTIF" if KotaLocale.language_code == "id" else "ACTIVE ROLE") if active else ("SIAP BERTUGAS" if KotaLocale.language_code == "id" else "READY FOR DUTY"), 8, Color("#76d7c1") if active else Color("#8da7a2"), 16)
        role_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        var choose := _container_button(role_box, ("DIPILIH ✓" if KotaLocale.language_code == "id" else "SELECTED ✓") if active else ("PILIH PERAN" if KotaLocale.language_code == "id" else "SELECT ROLE"), 10, 34)
        choose.disabled = active
        if active:
            choose.add_theme_stylebox_override("normal", _style(Color(0.06, 0.16, 0.15, 0.72), Color(0.35, 0.66, 0.59, 0.40), 4, 1))
        else:
            _style_editorial_menu_button(choose, false)
        choose.pressed.connect(_select_character.bind(ids[i]))

    var bottom_row := HBoxContainer.new()
    bottom_row.add_theme_constant_override("separation", 12)
    content.add_child(bottom_row)
    character_selected_label = _container_label(bottom_row, ("PERSONEL AKTIF  ·  %s" if KotaLocale.language_code == "id" else "ACTIVE PERSONNEL  ·  %s") % GameState.player_skin.to_upper(), 9, Color("#78d8c5"), 34)
    character_selected_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    character_selected_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var close := _container_button(bottom_row, KotaLocale.t("close"), 10, 34)
    close.custom_minimum_size.x = 120.0
    close.pressed.connect(func():
        if character_layer != null and is_instance_valid(character_layer):
            character_layer.queue_free()
        character_layer = null
        character_selected_label = null
    )
    _fade_in_layer(character_layer, 0.20)

func _select_character(skin_id: String) -> void:
    if skin_id not in ["logistics", "paramedic", "firefighter", "police"]:
        return
    GameState.player_skin = skin_id
    GameState.save_progress()
    if controller != null:
        var player: Variant = controller.get("player")
        if player is Node and player.has_method("set_skin"):
            player.call("set_skin", skin_id)
    _show_character_select()

func _add_skin_model_preview(parent: Control, skin_id: String) -> void:
    var model_paths := {
        "logistics": "res://assets/characters/rigged/player_logistics.glb",
        "paramedic": "res://assets/characters/rigged/player_paramedic.glb",
        "firefighter": "res://assets/characters/rigged/player_firefighter.glb",
        "police": "res://assets/characters/rigged/player_police.glb"
    }
    var preview_container := SubViewportContainer.new()
    preview_container.name = "Preview_%s" % skin_id
    preview_container.custom_minimum_size = Vector2(118, 150)
    preview_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    preview_container.stretch = true
    preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(preview_container)

    var view := SubViewport.new()
    view.size = Vector2i(236, 300)
    view.own_world_3d = true
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    view.transparent_bg = false
    preview_container.add_child(view)

    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#142a32")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#bfd8d5")
    environment.ambient_light_energy = 0.9
    environment_node.environment = environment
    view.add_child(environment_node)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
    light.light_color = Color("#fff0dc")
    light.light_energy = 1.5
    view.add_child(light)
    var fill := OmniLight3D.new()
    fill.position = Vector3(-1.5, 2.0, 2.0)
    fill.light_color = Color("#79c9d7")
    fill.light_energy = 0.8
    fill.omni_range = 7.0
    view.add_child(fill)

    var character_resource := load(str(model_paths.get(skin_id, model_paths["logistics"])))
    if character_resource is PackedScene:
        var character := (character_resource as PackedScene).instantiate() as Node3D
        if character != null:
            view.add_child(character)
            var bounds := _calculate_model_bounds(character, character)
            if bounds.size.y > 0.001:
                var scale_factor := 2.05 / maxf(bounds.size.y, 0.01)
                var center := bounds.position + bounds.size * 0.5
                character.scale = Vector3.ONE * scale_factor
                character.position = Vector3(-center.x * scale_factor, -bounds.position.y * scale_factor, -center.z * scale_factor)

    var camera := Camera3D.new()
    camera.position = Vector3(0.0, 1.15, 2.25)
    camera.near = 0.05
    camera.far = 30.0
    camera.current = true
    camera.look_at(Vector3(0.0, 1.04, 0.0), Vector3.UP)
    view.add_child(camera)

func _calculate_model_bounds(node: Node, model_root: Node3D) -> AABB:
    var combined := AABB()
    var has_bounds := false
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            var relative_transform: Transform3D = model_root.global_transform.affine_inverse() * mesh_instance.global_transform
            var part := mesh_instance.get_aabb() * relative_transform
            combined = part
            has_bounds = true
    for child in node.get_children():
        var child_bounds := _calculate_model_bounds(child, model_root)
        if child_bounds.size.length_squared() > 0.0:
            if has_bounds:
                combined = combined.merge(child_bounds)
            else:
                combined = child_bounds
                has_bounds = true
    return combined if has_bounds else AABB()

func _show_stage_select() -> void:
    if stage_select_layer != null and is_instance_valid(stage_select_layer):
        AudioManager.play_ui_back()
        stage_select_layer.queue_free()
    stage_select_layer = Control.new()
    stage_select_layer.name = "StageSelectLayer"
    stage_select_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(stage_select_layer)

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.01, 0.025, 0.04, 0.82)
    stage_select_layer.add_child(shade)

    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    var panel_size := Vector2(minf(720.0, viewport_size.x - 32.0), minf(390.0, viewport_size.y - 32.0))
    var panel := _panel(stage_select_layer, (viewport_size - panel_size) * 0.5, panel_size, Color(0.025, 0.07, 0.09, 0.96), Color(0.30, 0.70, 0.61, 0.9), 18)
    panel.name = "StageSelectDialog"
    _keep_centered(stage_select_layer, panel)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.offset_left = 24.0
    margin.offset_top = 18.0
    margin.offset_right = -24.0
    margin.offset_bottom = -18.0
    panel.add_child(margin)
    var content := VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 8)
    margin.add_child(content)

    _container_label(content, KotaLocale.t("story_heading"), 25, Color("#f4f7f4"), 31)
    var sub := _container_label(content, KotaLocale.t("story_sub"), 10, Color("#9fbdbb"), 18)
    sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    var titles := [KotaLocale.t("stage_1"), KotaLocale.t("stage_2"), KotaLocale.t("stage_3")]
    var descs := [KotaLocale.t("stage_desc_1"), KotaLocale.t("stage_desc_2"), KotaLocale.t("stage_desc_3")]
    for i in range(3):
        var idx: int = i + 1
        var card := _glass_card(content, 0.76 if idx <= GameState.unlocked_level else 0.50)
        card.custom_minimum_size = Vector2(0, 70)
        var row_margin := _card_margin(card, 12, 8)
        var row := HBoxContainer.new()
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", 12)
        row_margin.add_child(row)
        var info := VBoxContainer.new()
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        info.alignment = BoxContainer.ALIGNMENT_CENTER
        info.add_theme_constant_override("separation", 3)
        row.add_child(info)
        var stage_title := _container_label(info, "%02d  /  %s" % [idx, titles[i]], 12, Color("#edf6f1") if idx <= GameState.unlocked_level else Color("#78888c"), 21)
        stage_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        var detail := _container_label(info, descs[i], 9, Color("#a8c7bf"), 18)
        detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        var button := _container_button(row, KotaLocale.t("play_stage") if idx <= GameState.unlocked_level else KotaLocale.t("locked"), 9, 40)
        button.custom_minimum_size = Vector2(132, 40)
        button.disabled = idx > GameState.unlocked_level
        button.pressed.connect(func():
            if stage_select_layer != null and is_instance_valid(stage_select_layer):
                stage_select_layer.queue_free()
            stage_select_layer = null
            if menu_layer != null and is_instance_valid(menu_layer):
                menu_layer.queue_free()
            menu_layer = null
            controller.call("load_level", idx, true)
            root.visible = true
            _hide_game_hud()
        )

    var back := _container_button(content, KotaLocale.t("back_menu"), 10, 38)
    back.pressed.connect(func():
        if stage_select_layer != null and is_instance_valid(stage_select_layer):
            stage_select_layer.queue_free()
        stage_select_layer = null
    )

func _show_settings() -> void:
    if settings_layer != null and is_instance_valid(settings_layer):
        AudioManager.play_ui_back()
        settings_layer.queue_free()
    settings_layer = Control.new()
    settings_layer.name = "SettingsLayer"
    settings_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    settings_layer.process_mode = Node.PROCESS_MODE_ALWAYS
    root.add_child(settings_layer)

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.004, 0.014, 0.024, 0.78)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    settings_layer.add_child(shade)

    var viewport_size := get_viewport().get_visible_rect().size
    var panel_size := Vector2(minf(650.0, viewport_size.x - 32.0), minf(470.0, viewport_size.y - 24.0))
    var panel := _panel(settings_layer, (viewport_size - panel_size) * 0.5, panel_size, Color(0.018, 0.033, 0.041, 0.96), Color(0.28, 0.54, 0.51, 0.60), 10)
    panel.name = "SettingsDialog"
    _keep_centered(settings_layer, panel)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 22)
    margin.add_theme_constant_override("margin_right", 22)
    margin.add_theme_constant_override("margin_top", 17)
    margin.add_theme_constant_override("margin_bottom", 15)
    panel.add_child(margin)
    var content := VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 7)
    margin.add_child(content)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 12)
    content.add_child(header)
    var title_column := VBoxContainer.new()
    title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_column.add_theme_constant_override("separation", 0)
    header.add_child(title_column)
    _container_label(title_column, "PENGATURAN" if KotaLocale.language_code == "id" else "SETTINGS", 22, Color("#f0f4f1"), 31)
    _container_label(title_column, "Preferensi sistem dan kontrol operasi." if KotaLocale.language_code == "id" else "System preferences and operation controls.", 10, Color("#a4b8b3"), 19)
    var section_tag := _container_label(header, "ARUNIKA  /  PREFERENSI" if KotaLocale.language_code == "id" else "ARUNIKA  /  PREFERENCES", 8, Color("#77cabc"), 25)
    section_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    section_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    var divider := ColorRect.new()
    divider.custom_minimum_size = Vector2(0.0, 1.0)
    divider.color = Color(0.32, 0.54, 0.51, 0.42)
    content.add_child(divider)

    var language_card := _glass_card(content, 0.28, Color(0.24, 0.47, 0.45, 0.42))
    language_card.custom_minimum_size = Vector2(0.0, 58.0)
    var language_margin := _card_margin(language_card, 12, 7)
    var language_row := HBoxContainer.new()
    language_row.alignment = BoxContainer.ALIGNMENT_CENTER
    language_row.add_theme_constant_override("separation", 14)
    language_margin.add_child(language_row)
    var lang_info := VBoxContainer.new()
    lang_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lang_info.add_theme_constant_override("separation", 1)
    language_row.add_child(lang_info)
    _container_label(lang_info, KotaLocale.t("language"), 12, Color("#e5efeb"), 19)
    _container_label(lang_info, "Bahasa untuk kabeh teks game" if KotaLocale.language_code == "id" else "Language used throughout the game", 9, Color("#a5bbb6"), 16)
    var language_picker := OptionButton.new()
    language_picker.custom_minimum_size = Vector2(164, 34)
    language_picker.add_item("Bahasa Indonesia", 0)
    language_picker.add_item("English", 1)
    language_picker.select(1 if KotaLocale.language_code == "en" else 0)
    language_picker.add_theme_font_size_override("font_size", 12)
    language_picker.add_theme_color_override("font_color", Color("#edf5f1"))
    language_picker.add_theme_stylebox_override("normal", _style(Color(0.045, 0.095, 0.102, 0.84), Color(0.32, 0.56, 0.52, 0.54), 5, 1))
    language_row.add_child(language_picker)
    language_picker.pressed.connect(AudioManager.play_ui_open)
    language_picker.item_selected.connect(func(index: int):
        AudioManager.play_ui_confirm()
        KotaLocale.set_language("en" if index == 1 else "id")
        call_deferred("_rebuild_after_language_change")
    )

    _container_label(content, "KONTROL OPERASI" if KotaLocale.language_code == "id" else "OPERATION CONTROLS", 10, Color("#79cabc"), 18)
    var controls_row := HBoxContainer.new()
    controls_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    controls_row.add_theme_constant_override("separation", 10)
    content.add_child(controls_row)

    var movement_card := _glass_card(controls_row, 0.26, Color(0.24, 0.42, 0.42, 0.35))
    movement_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var movement_margin := _card_margin(movement_card, 12, 9)
    var movement_box := VBoxContainer.new()
    movement_box.add_theme_constant_override("separation", 4)
    movement_margin.add_child(movement_box)
    _container_label(movement_box, "GERAKAN" if KotaLocale.language_code == "id" else "MOVEMENT", 11, Color("#dbe8e3"), 20)
    _add_compact_key_row(movement_box, "W A S D", "Bergerak" if KotaLocale.language_code == "id" else "Move")
    _add_compact_key_row(movement_box, "SHIFT", "Lari" if KotaLocale.language_code == "id" else "Sprint")
    _add_compact_key_row(movement_box, "SPACE", "Lompat" if KotaLocale.language_code == "id" else "Jump")

    var interaction_card := _glass_card(controls_row, 0.26, Color(0.24, 0.42, 0.42, 0.35))
    interaction_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var interaction_margin := _card_margin(interaction_card, 12, 9)
    var interaction_box := VBoxContainer.new()
    interaction_box.add_theme_constant_override("separation", 4)
    interaction_margin.add_child(interaction_box)
    _container_label(interaction_box, "INTERAKSI" if KotaLocale.language_code == "id" else "INTERACTION", 11, Color("#dbe8e3"), 20)
    _add_compact_key_row(interaction_box, "E", "Aksi objek" if KotaLocale.language_code == "id" else "Interact")
    _add_compact_key_row(interaction_box, "ESC", "Jeda" if KotaLocale.language_code == "id" else "Pause")
    _add_compact_key_row(interaction_box, "TAB", "Cursor mouse" if KotaLocale.language_code == "id" else "Mouse cursor")

    _container_label(content, "AUDIO DAN SUARA" if KotaLocale.language_code == "id" else "AUDIO", 10, Color("#79cabc"), 18)
    var audio_card := _glass_card(content, 0.26, Color(0.24, 0.42, 0.42, 0.35))
    audio_card.custom_minimum_size = Vector2(0.0, 68.0)
    var audio_margin := _card_margin(audio_card, 12, 7)
    var audio_row := HBoxContainer.new()
    audio_row.add_theme_constant_override("separation", 14)
    audio_margin.add_child(audio_row)
    _add_audio_slider(audio_row, "UTAMA" if KotaLocale.language_code == "id" else "MASTER", AudioManager.get_master_volume(), AudioManager.set_master_volume)
    _add_audio_slider(audio_row, "MUSIK", AudioManager.get_music_volume(), AudioManager.set_music_volume)
    _add_audio_slider(audio_row, "EFEK SUARA" if KotaLocale.language_code == "id" else "SFX", AudioManager.get_sfx_volume(), AudioManager.set_sfx_volume)

    var footer_row := HBoxContainer.new()
    footer_row.alignment = BoxContainer.ALIGNMENT_END
    footer_row.add_theme_constant_override("separation", 9)
    content.add_child(footer_row)
    var close := _container_button(footer_row, KotaLocale.t("close"), 11, 36)
    close.custom_minimum_size.x = 130.0
    _style_editorial_menu_button(close, false)
    close.pressed.connect(func():
        if settings_layer != null and is_instance_valid(settings_layer):
            settings_layer.queue_free()
        settings_layer = null
    )
    _fade_in_layer(settings_layer, 0.18)

func _add_audio_slider(parent: Control, label_text: String, initial_value: float, callback: Callable) -> void:
    var group := VBoxContainer.new()
    group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    group.add_theme_constant_override("separation", 2)
    parent.add_child(group)
    var title := _container_label(group, label_text, 9, Color("#dbe8e3"), 18)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var slider := HSlider.new()
    slider.min_value = 0.0
    slider.max_value = 100.0
    slider.step = 1.0
    slider.value = clampf(initial_value * 100.0, 0.0, 100.0)
    slider.custom_minimum_size = Vector2(120.0, 22.0)
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.mouse_entered.connect(AudioManager.play_ui_hover)
    slider.drag_started.connect(AudioManager.play_ui_open)
    slider.value_changed.connect(func(value: float): callback.call(value / 100.0))
    group.add_child(slider)

func _container_label(parent: Control, text_value: String, font_size: int, color: Color, min_height: float = 0.0) -> Label:
    var label := Label.new()
    label.text = text_value
    label.custom_minimum_size = Vector2(0, maxf(min_height, 17.0))
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.add_theme_font_size_override("font_size", maxi(font_size, 11))
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_OFF
    label.clip_text = false
    parent.add_child(label)
    return label

func _container_button(parent: Control, text_value: String, font_size: int, min_height: float = 44.0) -> Button:
    var button := _button(parent, Vector2.ZERO, Vector2(0, min_height), text_value, font_size)
    button.custom_minimum_size = Vector2(0, min_height)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return button

func _card_margin(parent: Control, horizontal: int = 12, vertical: int = 10) -> MarginContainer:
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", horizontal)
    margin.add_theme_constant_override("margin_right", horizontal)
    margin.add_theme_constant_override("margin_top", vertical)
    margin.add_theme_constant_override("margin_bottom", vertical)
    parent.add_child(margin)
    return margin

func _add_compact_key_row(parent: Control, key_text: String, description: String) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    row.custom_minimum_size = Vector2(0, 25)
    parent.add_child(row)
    var key_panel := PanelContainer.new()
    key_panel.custom_minimum_size = Vector2(74, 24)
    key_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.19, 0.20, 0.95), Color(0.27, 0.48, 0.44, 0.9), 6, 1))
    row.add_child(key_panel)
    var key_label := _container_label(key_panel, key_text, 8, Color("#f1f7f2"), 22)
    key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var desc := _container_label(row, description, 9, Color("#d0e1dc"), 24)
    desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _add_control_row(parent: Control, row_y: float, key_text: String, description: String) -> void:
    var key_card := _panel(parent, Vector2(14, row_y), Vector2(96, 29), Color("#1b3b43"), Color("#4d766f"), 7)
    var key_label := _label(key_card, Vector2(5, 6), Vector2(86, 16), 9, Color("#f0f6f2"))
    key_label.text = key_text
    key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var desc := _label(parent, Vector2(120, row_y + 6), Vector2(182, 18), 10, Color("#d0e1dc"))
    desc.text = description

func _rebuild_after_language_change() -> void:
    var was_paused := pause_layer != null and is_instance_valid(pause_layer)
    var was_in_game := header != null and is_instance_valid(header) and header.visible
    close_overlay()
    if root != null and is_instance_valid(root):
        root.queue_free()
    await get_tree().process_frame
    if controller != null and is_instance_valid(controller) and controller.has_method("load_level"):
        controller.call("load_level", clampi(GameState.level, 1, 3), false)
    timeline_labels.clear()
    menu_layer = null
    briefing_layer = null
    choice_layer = null
    character_layer = null
    character_selected_label = null
    pause_layer = null
    hud_layer = null
    header = null
    mission_panel = null
    message_panel = null
    action_panel = null
    last_toast_text = ""
    toast_tween = null
    action_hover_tween = null
    action_emergency_style = false
    stage_select_layer = null
    settings_layer = null
    status_panel = null
    minimap_panel = null
    minimap_overlay = null
    minimap_player_marker = null
    minimap_objective_marker = null
    minimap_safe_marker = null
    minimap_camera = null
    minimap_subviewport = null
    skin_panel = null
    evaluation_panel = null
    evaluation_body = null
    evaluation_button = null
    action_button = null
    stage_progress_bar = null
    phase_progress_label = null
    root = null
    paused = false
    _build_hud()
    if was_paused:
        _show_game_hud()
        refresh()
        show_pause()
    elif was_in_game:
        _show_game_hud()
        refresh()
    else:
        show_main_menu()
        refresh()


func _process(_delta: float) -> void:
    if controller != null and clock_label != null and header != null and header.visible:
        var world: Variant = controller.get("world")
        if world != null and world.has_method("get_clock_text"):
            clock_label.text = "%s  •  %s" % [str(world.call("get_clock_text")), str(world.call("get_period_text"))]
            weather_label.text = str(world.call("get_weather_text"))
    if minimap_overlay == null or not is_instance_valid(minimap_overlay) or minimap_player_marker == null or not is_instance_valid(minimap_player_marker):
        return
    if controller == null:
        return
    var actor: Variant = controller.get("player")
    if actor is Node3D:
        minimap_player_marker.position = _world_to_minimap_position((actor as Node3D).global_position, minimap_player_marker.size)
        if minimap_objective_marker != null and is_instance_valid(minimap_objective_marker) and controller.has_method("get_minimap_objective_position"):
            var objective_position: Variant = controller.call("get_minimap_objective_position")
            if objective_position is Vector3:
                minimap_objective_marker.position = _world_to_minimap_position(objective_position, minimap_objective_marker.size)

func _input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    if event.keycode != KEY_ESCAPE:
        return

    # ESC closes the topmost dialog first. It never opens a separate map overlay.
    if settings_layer != null and is_instance_valid(settings_layer):
        AudioManager.play_ui_back()
        settings_layer.queue_free()
        settings_layer = null
        get_viewport().set_input_as_handled()
        return
    if character_layer != null and is_instance_valid(character_layer):
        AudioManager.play_ui_back()
        character_layer.queue_free()
        character_layer = null
        character_selected_label = null
        get_viewport().set_input_as_handled()
        return
    if stage_select_layer != null and is_instance_valid(stage_select_layer):
        AudioManager.play_ui_back()
        stage_select_layer.queue_free()
        stage_select_layer = null
        get_viewport().set_input_as_handled()
        return
    if menu_layer != null or briefing_layer != null or choice_layer != null:
        return
    if pause_layer != null:
        AudioManager.play_ui_back()
        close_overlay()
    else:
        AudioManager.play_ui_confirm()
        show_pause()
    get_viewport().set_input_as_handled()

