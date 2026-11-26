extends Node3D

const CHARACTER_CATALOG = preload("res://scripts/data/CharacterCatalog.gd")
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"

var all_characters: Array[Dictionary] = []
var visible_characters: Array[Dictionary] = []
var current_index: int = 0
var current_category: String = "PLAYER"
var model_pivot: Node3D
var model_root: Node3D
var camera: Camera3D
var info_title: Label
var info_role: Label
var info_description: Label
var counter_label: Label
var category_player_button: Button
var category_npc_button: Button
var dragging: bool = false
var drag_origin: Vector2 = Vector2.ZERO
var start_yaw: float = 0.0
var preview_zoom: float = 5.8

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _build_stage()
    _build_interface()
    all_characters = CHARACTER_CATALOG.all_characters()
    _set_category("PLAYER")

func _build_stage() -> void:
    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#273b48")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#bdd0d5")
    environment.ambient_light_energy = 0.85
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 1.0
    environment_node.environment = environment
    add_child(environment_node)

    var sun := DirectionalLight3D.new()
    sun.name = "KeyLight"
    sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    sun.light_color = Color("#fff1dc")
    sun.light_energy = 1.45
    sun.shadow_enabled = true
    add_child(sun)

    var fill := OmniLight3D.new()
    fill.name = "FillLight"
    fill.position = Vector3(-3.2, 3.0, 2.4)
    fill.light_color = Color("#80c6e5")
    fill.light_energy = 1.0
    fill.omni_range = 9.0
    add_child(fill)

    var floor := MeshInstance3D.new()
    floor.name = "ShowroomFloor"
    var floor_mesh := PlaneMesh.new()
    floor_mesh.size = Vector2(80.0, 80.0)
    floor.mesh = floor_mesh
    floor.position.y = -0.22
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color("#17262e")
    floor_material.roughness = 0.88
    floor.material_override = floor_material
    add_child(floor)

    var plinth := MeshInstance3D.new()
    plinth.name = "CharacterPlinth"
    var plinth_mesh := CylinderMesh.new()
    plinth_mesh.top_radius = 1.05
    plinth_mesh.bottom_radius = 1.17
    plinth_mesh.height = 0.20
    plinth_mesh.radial_segments = 64
    plinth.mesh = plinth_mesh
    plinth.position.y = -0.12
    var plinth_material := StandardMaterial3D.new()
    plinth_material.albedo_color = Color("#3d5964")
    plinth_material.metallic = 0.22
    plinth_material.roughness = 0.42
    plinth.material_override = plinth_material
    add_child(plinth)

    model_pivot = Node3D.new()
    model_pivot.name = "PreviewModelPivot"
    add_child(model_pivot)

    camera = Camera3D.new()
    camera.name = "PreviewCamera"
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 4.25
    camera.near = 0.05
    camera.far = 100.0
    camera.position = Vector3(0.0, 1.45, preview_zoom)
    camera.look_at(Vector3(0.0, 1.28, 0.0), Vector3.UP)
    camera.current = true
    add_child(camera)

func _build_interface() -> void:
    var layer := CanvasLayer.new()
    layer.name = "ShowroomUI"
    add_child(layer)
    var ui := Control.new()
    ui.name = "Root"
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_PASS
    layer.add_child(ui)

    var top_panel := _panel(ui, Vector2(26, 22), Vector2(1228, 88), Color(0.035, 0.075, 0.09, 0.93), Color("#4a7881"), 16)
    var kicker := _label(top_panel, Vector2(24, 12), Vector2(850, 17), 10, Color("#79e0bc"))
    kicker.text = "KOTA SIAGA  /  CHARACTER LAB"
    var title := _label(top_panel, Vector2(22, 34), Vector2(790, 42), 25, Color("#f2f7f5"))
    title.text = "Preview Karakter 3D"
    var back := _button(top_panel, Vector2(1010, 19), Vector2(190, 48), "← KEMBALI KE GAME", 11)
    back.pressed.connect(_return_to_game)

    var info_panel := _panel(ui, Vector2(28, 136), Vector2(350, 340), Color(0.035, 0.075, 0.09, 0.91), Color("#3f626e"), 16)
    var info_kicker := _label(info_panel, Vector2(22, 20), Vector2(300, 18), 10, Color("#70d9b6"))
    info_kicker.text = "MODEL TERPILIH"
    info_title = _label(info_panel, Vector2(22, 50), Vector2(305, 62), 22, Color("#f1f6f4"))
    info_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info_role = _label(info_panel, Vector2(22, 124), Vector2(305, 28), 11, Color("#f2cf77"))
    info_description = _label(info_panel, Vector2(22, 163), Vector2(305, 110), 13, Color("#d2e0e1"))
    info_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info_description.clip_text = false
    var tech := _label(info_panel, Vector2(22, 278), Vector2(306, 44), 10, Color("#87a2aa"))
    tech.text = "STATIC MESH • GLB • BELUM RIGGED / ANIMATED"
    tech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    var footer := _panel(ui, Vector2(28, 620), Vector2(1224, 76), Color(0.035, 0.075, 0.09, 0.93), Color("#3d626c"), 14)
    category_player_button = _button(footer, Vector2(16, 14), Vector2(142, 46), "PLAYER ROLES", 11)
    category_player_button.pressed.connect(func(): _set_category("PLAYER"))
    category_npc_button = _button(footer, Vector2(168, 14), Vector2(112, 46), "NPC WARGA", 11)
    category_npc_button.pressed.connect(func(): _set_category("NPC"))
    var previous := _button(footer, Vector2(410, 14), Vector2(54, 46), "←", 18)
    previous.pressed.connect(func(): _step_model(-1))
    var next := _button(footer, Vector2(474, 14), Vector2(54, 46), "→", 18)
    next.pressed.connect(func(): _step_model(1))
    counter_label = _label(footer, Vector2(548, 28), Vector2(145, 18), 11, Color("#d8e8e4"))
    var controls := _label(footer, Vector2(715, 19), Vector2(490, 38), 10, Color("#8ea9b1"))
    controls.text = "DRAG: PUTAR MODEL   •   SCROLL: ZOOM   •   ← / →: GANTI   •   ESC: KEMBALI"
    controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _set_category(category: String) -> void:
    current_category = category
    visible_characters.clear()
    for character in all_characters:
        if str(character["category"]) == category:
            visible_characters.append(character)
    current_index = 0
    _show_model()
    if category_player_button:
        category_player_button.disabled = category == "PLAYER"
    if category_npc_button:
        category_npc_button.disabled = category == "NPC"

func _show_model() -> void:
    if visible_characters.is_empty():
        return
    if is_instance_valid(model_root):
        model_root.queue_free()
    var character: Dictionary = visible_characters[current_index]
    var resource := load(str(character["path"]))
    if not (resource is PackedScene):
        info_title.text = str(character["display_name"])
        info_role.text = "ASSET TIDAK DAPAT DIBUKA"
        info_description.text = "Periksa kembali file GLB dan log impor Godot."
        counter_label.text = "%02d / %02d" % [current_index + 1, visible_characters.size()]
        return
    model_root = (resource as PackedScene).instantiate() as Node3D
    if model_root == null:
        info_role.text = "ROOT MODEL BUKAN NODE3D"
        return
    model_root.name = "Preview_%s" % str(character["id"])
    model_root.scale = Vector3.ONE
    model_pivot.add_child(model_root)

    var bounds := _calculate_model_bounds(model_root, model_root)
    if bounds.size.y <= 0.001:
        bounds = AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 2.0, 1.0))
    var scale_factor := 2.7 / maxf(bounds.size.y, 0.01)
    model_root.scale = Vector3.ONE * scale_factor
    var scaled_position := bounds.position * scale_factor
    var scaled_size := bounds.size * scale_factor
    var scaled_center_x := scaled_position.x + scaled_size.x * 0.5
    var scaled_center_z := scaled_position.z + scaled_size.z * 0.5
    model_root.position = Vector3(-scaled_center_x, -scaled_position.y, -scaled_center_z)
    model_pivot.rotation.y = 0.0

    info_title.text = str(character["display_name"])
    info_role.text = "%s  •  %s" % [str(character["category"]), str(character["role"])]
    info_description.text = str(character["description"])
    counter_label.text = "%02d / %02d" % [current_index + 1, visible_characters.size()]

func _calculate_model_bounds(node: Node, root: Node3D) -> AABB:
    var combined := AABB()
    var has_bounds := false
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            var relative_transform: Transform3D = root.global_transform.affine_inverse() * mesh_instance.global_transform
            var part := (mesh_instance.get_aabb() * relative_transform)
            combined = part
            has_bounds = true
    for child in node.get_children():
        var child_bounds := _calculate_model_bounds(child, root)
        if child_bounds.size.length_squared() > 0.0:
            if has_bounds:
                combined = combined.merge(child_bounds)
            else:
                combined = child_bounds
                has_bounds = true
    return combined if has_bounds else AABB()

func _step_model(direction: int) -> void:
    if visible_characters.is_empty():
        return
    current_index = posmod(current_index + direction, visible_characters.size())
    _show_model()

func _return_to_game() -> void:
    get_tree().change_scene_to_file(MAIN_SCENE_PATH)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            _return_to_game()
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_LEFT:
            _step_model(-1)
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_RIGHT:
            _step_model(1)
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_R:
            model_pivot.rotation.y = 0.0
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            # Reserve the center viewport for model manipulation so UI clicks do not rotate it.
            dragging = event.pressed and event.position.x > 390.0 and event.position.y < 610.0
            if dragging:
                drag_origin = event.position
                start_yaw = model_pivot.rotation.y
        elif event.pressed and event.position.x > 390.0 and event.position.y < 610.0 and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            preview_zoom = maxf(3.8, preview_zoom - 0.35)
            _update_camera_distance()
        elif event.pressed and event.position.x > 390.0 and event.position.y < 610.0 and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            preview_zoom = minf(8.0, preview_zoom + 0.35)
            _update_camera_distance()
    elif event is InputEventMouseMotion and dragging:
        model_pivot.rotation.y = start_yaw + (event.position.x - drag_origin.x) * 0.008

func _update_camera_distance() -> void:
    camera.position.z = preview_zoom

func _panel(parent: Control, panel_position: Vector2, panel_size: Vector2, fill: Color, border: Color, radius: int) -> Panel:
    var panel := Panel.new()
    panel.position = panel_position
    panel.size = panel_size
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 2
    style.content_margin_right = 2
    style.content_margin_top = 2
    style.content_margin_bottom = 2
    panel.add_theme_stylebox_override("panel", style)
    parent.add_child(panel)
    return panel

func _label(parent: Control, label_position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.position = label_position
    label.size = label_size
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func _button(parent: Control, button_position: Vector2, button_size: Vector2, title: String, font_size: int) -> Button:
    var button := Button.new()
    button.position = button_position
    button.size = button_size
    button.text = title
    button.add_theme_font_size_override("font_size", font_size)
    button.add_theme_color_override("font_color", Color("#eff9f5"))
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#1a4a50")
    normal.border_color = Color("#5cbca7")
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(9)
    button.add_theme_stylebox_override("normal", normal)
    var hover := StyleBoxFlat.new()
    hover.bg_color = Color("#246b69")
    hover.border_color = Color("#96efd4")
    hover.set_border_width_all(2)
    hover.set_corner_radius_all(9)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    var disabled := StyleBoxFlat.new()
    disabled.bg_color = Color("#263e43")
    disabled.border_color = Color("#3e686a")
    disabled.set_border_width_all(1)
    disabled.set_corner_radius_all(9)
    button.add_theme_stylebox_override("disabled", disabled)
    button.mouse_entered.connect(AudioManager.play_ui_hover)
    button.pressed.connect(AudioManager.play_ui_confirm)
    parent.add_child(button)
    return button
