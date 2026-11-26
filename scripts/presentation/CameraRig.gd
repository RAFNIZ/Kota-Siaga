extends Node3D

## Orthographic orbit camera rig for the angled semi-3D gameplay view.

@export var camera_size: float = 20.5
@export var camera_distance: float = 7.0
@export_range(3.0, 45.0, 1.0) var initial_pitch_degrees: float = 7.0
@export_range(2.0, 45.0, 1.0) var minimum_pitch_degrees: float = 3.0
@export_range(8.0, 55.0, 1.0) var maximum_pitch_degrees: float = 42.0
@export var mouse_sensitivity: float = 0.0025

var target: Node3D
var menu_mode: bool = true
var camera_yaw: float = 0.0
var camera_pitch: float = deg_to_rad(7.0)
var camera: Camera3D
var disaster_shake_strength: float = 0.0
var disaster_shake_clock: float = 0.0

func _ready() -> void:
    add_to_group("camera_rig")
    camera = get_node_or_null("Camera3D") as Camera3D
    if camera == null:
        camera = Camera3D.new()
        camera.name = "Camera3D"
        add_child(camera)
    camera.projection = Camera3D.PROJECTION_PERSPECTIVE
    camera.fov = 72.0
    camera.near = 0.1
    camera.far = 240.0
    camera.current = true
    camera.position = Vector3(0.0, 2.4, 7.0)
    camera.look_at(Vector3(0.0, 1.5, 0.0), Vector3.UP)
    camera_pitch = deg_to_rad(initial_pitch_degrees)

func set_target(value: Node3D) -> void:
    target = value

func set_menu_mode(value: bool) -> void:
    menu_mode = value
    if is_instance_valid(camera):
        camera.fov = 54.0 if value else 72.0

func get_yaw() -> float:
    return camera_yaw

func set_disaster_shake(value: float) -> void:
    disaster_shake_strength = clampf(value, 0.0, 0.08)

func set_mouse_capture(captured: bool) -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
    if not is_instance_valid(camera):
        return
    if menu_mode or not is_instance_valid(target):
        # Cinematic oblique overview: close enough to read the city, low enough to avoid a flat minimap view.
        var menu_target := Vector3(0.0, 4.0, 0.0)
        var menu_camera := Vector3(-78.0, 38.0, 100.0)
        camera.fov = 52.0
        camera.position = menu_camera
        camera.look_at(menu_target, Vector3.UP)
        return

    var look_target: Vector3 = target.global_position + Vector3(0.0, 1.42, 0.0)
    var horizontal_distance := cos(camera_pitch) * camera_distance
    var vertical_distance := sin(camera_pitch) * camera_distance
    var orbit_offset := Vector3(0.0, vertical_distance, horizontal_distance).rotated(Vector3.UP, camera_yaw)
    var desired_position: Vector3 = look_target + orbit_offset
    disaster_shake_clock += delta
    var shake_offset := Vector3(
        sin(disaster_shake_clock * 23.0) * disaster_shake_strength,
        cos(disaster_shake_clock * 17.0) * disaster_shake_strength * 0.45,
        sin(disaster_shake_clock * 19.0) * disaster_shake_strength * 0.55
    )
    camera.global_position = camera.global_position.lerp(desired_position + shake_offset, minf(delta * 6.0, 1.0))
    camera.look_at(look_target, Vector3.UP)

func _input(event: InputEvent) -> void:
    if menu_mode:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        camera_yaw = wrapf(camera_yaw - event.relative.x * mouse_sensitivity, -TAU, TAU)
        camera_pitch = clampf(
            camera_pitch + event.relative.y * mouse_sensitivity,
            deg_to_rad(minimum_pitch_degrees),
            deg_to_rad(maximum_pitch_degrees)
        )
        get_viewport().set_input_as_handled()
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_TAB:
            set_mouse_capture(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_BRACKETLEFT:
            mouse_sensitivity = clampf(mouse_sensitivity - 0.0003, 0.0008, 0.006)
            GameState.set_message("Sensitivitas POV: %.4f. Gunakan [ dan ] untuk menyesuaikan." % mouse_sensitivity)
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_BRACKETRIGHT:
            mouse_sensitivity = clampf(mouse_sensitivity + 0.0003, 0.0008, 0.006)
            GameState.set_message("Sensitivitas POV: %.4f. Gunakan [ dan ] untuk menyesuaikan." % mouse_sensitivity)
            get_viewport().set_input_as_handled()
