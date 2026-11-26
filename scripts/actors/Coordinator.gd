extends CharacterBody3D

const CHARACTER_MODEL_FACTORY := preload("res://scripts/actors/CharacterModelFactory.gd")
const PLAYER_GRAVITY: float = 18.5
const FALL_GRAVITY_MULTIPLIER: float = 1.24
const JUMP_RELEASE_GRAVITY_MULTIPLIER: float = 1.28
const MAX_FALL_SPEED: float = 22.0
const JUMP_VELOCITY: float = 6.4
const GROUND_ACCELERATION: float = 24.0
const AIR_CONTROL_ACCELERATION: float = 7.5

@export var walk_speed: float = 4.2
@export var sprint_speed: float = 6.4
var game_controller: Node
var input_enabled: bool = false
var stamina: float = 100.0
var running: bool = false
var move_direction := Vector2.ZERO
var anim_time: float = 0.0
var _gait_phase: float = 0.0
var _gait_blend: float = 0.0
var _run_blend: float = 0.0
var _last_footstep_index: int = -1
var vehicle_contact_cooldown: float = 0.0
var visual_root: Node3D
var body_pivot: Node3D
var character_model: Node3D
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var e_was_down: bool = false
var jump_was_down: bool = false
var grounded_last_frame: bool = true
var jump_time: float = 0.0
var uniform_parts: Array[MeshInstance3D] = []
var selected_skin: String = "logistics"

func _ready() -> void:
    if not KotaLocale.language_changed.is_connected(_on_language_changed):
        KotaLocale.language_changed.connect(_on_language_changed)
    collision_layer = 1
    collision_mask = 3
    floor_snap_length = 0.35
    var col := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.36
    capsule.height = 1.8
    col.shape = capsule
    col.position.y = 0.9
    add_child(col)
    _build_visual()

func _physics_process(delta: float) -> void:
    anim_time += delta
    if not input_enabled:
        velocity.x = move_toward(velocity.x, 0.0, GROUND_ACCELERATION * delta)
        velocity.z = move_toward(velocity.z, 0.0, GROUND_ACCELERATION * delta)
        _apply_player_gravity(delta, false)
        move_and_slide()
        _update_ground_contact()
        _animate(delta)
        return
    var direction := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.y += 1.0
    direction = direction.normalized()
    running = Input.is_key_pressed(KEY_SHIFT) and direction.length_squared() > 0.0
    var speed := sprint_speed if running else walk_speed
    stamina = 100.0
    var jump_down := Input.is_key_pressed(KEY_SPACE)
    if jump_down and not jump_was_down and is_on_floor():
        velocity.y = JUMP_VELOCITY
        jump_time = 0.0
        AudioManager.play_jump_at(global_position + Vector3(0.0, 0.08, 0.0))
    jump_was_down = jump_down
    _apply_player_gravity(delta, jump_down)
    var world_direction := Vector3(direction.x, 0.0, direction.y)
    var scene_root := get_tree().current_scene
    if scene_root != null and scene_root.has_method("get_camera_yaw"):
        world_direction = world_direction.rotated(Vector3.UP, float(scene_root.call("get_camera_yaw")))
    world_direction = world_direction.normalized()
    var horizontal_acceleration := GROUND_ACCELERATION if is_on_floor() else AIR_CONTROL_ACCELERATION
    velocity.x = move_toward(velocity.x, world_direction.x * speed, horizontal_acceleration * delta)
    velocity.z = move_toward(velocity.z, world_direction.z * speed, horizontal_acceleration * delta)
    if world_direction.length_squared() > 0.01:
        visual_root.rotation.y = atan2(-world_direction.x, -world_direction.z)
    move_and_slide()
    _update_ground_contact()
    vehicle_contact_cooldown = maxf(0.0, vehicle_contact_cooldown - delta)
    _respond_to_vehicle_contact(delta)
    global_position.x = clampf(global_position.x, -76.0, 76.0)
    global_position.z = clampf(global_position.z, -76.0, 76.0)
    _animate(delta)


func _apply_player_gravity(delta: float, jump_held: bool = false) -> void:
    if is_on_floor():
        if velocity.y < 0.0:
            velocity.y = 0.0
        return

    var gravity_scale := 1.0
    if velocity.y < 0.0:
        gravity_scale = FALL_GRAVITY_MULTIPLIER
    elif not jump_held:
        # Releasing Space early shortens the jump instead of leaving a floaty apex.
        gravity_scale = JUMP_RELEASE_GRAVITY_MULTIPLIER
    velocity.y = maxf(velocity.y - PLAYER_GRAVITY * gravity_scale * delta, -MAX_FALL_SPEED)


func _update_ground_contact() -> void:
    var grounded_now := is_on_floor()
    if grounded_now and not grounded_last_frame:
        # Kill residual downward velocity on landing; animation tree exits Jump immediately
        # and cross-fades back to the locomotion blend space.
        velocity.y = 0.0
        jump_time = 0.0
        AudioManager.play_land_at(global_position, running)
    grounded_last_frame = grounded_now


func _respond_to_vehicle_contact(delta: float) -> void:
    # Moving traffic is represented by AnimatableBody3D collision bodies in CityWorld.
    # On contact, keep the player out of the vehicle and give a small readable shove.
    for i in range(get_slide_collision_count()):
        var hit := get_slide_collision(i)
        var collider := hit.get_collider()
        if collider is Node and str((collider as Node).name).begins_with("Car"):
            var normal := hit.get_normal()
            var horizontal := Vector3(normal.x, 0.0, normal.z).normalized()
            if horizontal.length_squared() > 0.01:
                velocity.x += horizontal.x * 2.8
                velocity.z += horizontal.z * 2.8
                global_position += horizontal * minf(0.12, delta * 2.0)
                if vehicle_contact_cooldown <= 0.0:
                    GameState.set_message("Kendaraan melintas dekat. Jaga jarak dan gunakan jalur aman.")
                    vehicle_contact_cooldown = 1.6

func _on_language_changed(_language_code: String) -> void:
    if not is_instance_valid(visual_root):
        return
    var tag := visual_root.get_node_or_null("Label3D") as Label3D
    if tag != null and tag.has_meta("locale_key"):
        tag.text = KotaLocale.t(str(tag.get_meta("locale_key")))

func _unhandled_input(event: InputEvent) -> void:
    if not input_enabled or game_controller == null: return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
        AudioManager.play_interaction_at(global_position + Vector3(0.0, 0.8, 0.0))
        game_controller.call("interact")
        get_viewport().set_input_as_handled()

func _build_visual() -> void:
    visual_root = Node3D.new()
    visual_root.name = "CoordinatorVisual"
    add_child(visual_root)
    body_pivot = Node3D.new()
    body_pivot.name = "BodyPivot"
    visual_root.add_child(body_pivot)

    # The translucent foot disc was removed because it intersected tiled sidewalks and flickered.

    set_skin(GameState.player_skin)

func set_skin(skin_id: String) -> void:
    if skin_id not in ["logistics", "paramedic", "firefighter", "police"]:
        skin_id = "logistics"
    selected_skin = skin_id
    GameState.player_skin = skin_id
    uniform_parts.clear()
    if is_instance_valid(character_model):
        character_model.free()
    character_model = null
    if body_pivot == null:
        return

    var model_paths := {
        "logistics": "res://assets/characters/rigged/player_logistics.glb",
        "paramedic": "res://assets/characters/rigged/player_paramedic.glb",
        "firefighter": "res://assets/characters/rigged/player_firefighter.glb",
        "police": "res://assets/characters/rigged/player_police.glb"
    }
    character_model = CHARACTER_MODEL_FACTORY.attach_model(body_pivot, str(model_paths[skin_id]), 1.72, PI)
    if is_instance_valid(character_model):
        character_model.name = "PlayerRoleModel"

func _calculate_character_bounds(node: Node, model_root: Node3D) -> AABB:
    var combined := AABB()
    var has_bounds := false
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            var relative_transform: Transform3D = model_root.global_transform.affine_inverse() * mesh_instance.global_transform
            combined = mesh_instance.get_aabb() * relative_transform
            has_bounds = true
    for child in node.get_children():
        var child_bounds := _calculate_character_bounds(child, model_root)
        if child_bounds.size.length_squared() > 0.0:
            if has_bounds:
                combined = combined.merge(child_bounds)
            else:
                combined = child_bounds
                has_bounds = true
    return combined if has_bounds else AABB()

func _animate(delta: float) -> void:
    var horizontal_speed := Vector2(velocity.x, velocity.z).length()
    var moving := horizontal_speed > 0.35
    var airborne := not is_on_floor()
    var target_gait := clampf(horizontal_speed / maxf(walk_speed, 0.1), 0.0, 1.0) if moving else 0.0
    var target_run := 1.0 if running and moving else 0.0
    _gait_blend = move_toward(_gait_blend, target_gait, (6.5 if target_gait > _gait_blend else 4.0) * delta)
    _run_blend = move_toward(_run_blend, target_run, 5.0 * delta)
    _gait_phase += delta * lerpf(0.0, 10.2, _gait_blend) * lerpf(1.0, 1.30, _run_blend)
    if body_pivot:
        if airborne:
            body_pivot.position.y = 0.055
        elif moving:
            body_pivot.position.y = absf(sin(_gait_phase * 2.0)) * (0.018 + 0.010 * _run_blend)
        else:
            body_pivot.position.y = sin(anim_time * 1.8) * 0.004
    if moving and not airborne:
        var footstep_index := floori(_gait_phase / PI)
        if footstep_index != _last_footstep_index:
            _last_footstep_index = footstep_index
            AudioManager.play_footstep_at(global_position, running, false)
    else:
        _last_footstep_index = -1
    if is_instance_valid(character_model):
        CHARACTER_MODEL_FACTORY.apply_locomotion(character_model, _gait_blend, _run_blend, _gait_phase, airborne)

func _add_capsule(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
    var node := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = size.x
    mesh.height = size.y * 2.0
    node.mesh = mesh
    node.position = pos
    node.scale = Vector3(1.0, 1.0, size.z / maxf(size.x, 0.01))
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.72
    node.material_override = mat
    parent.add_child(node)

func _add_sphere(parent: Node3D, pos: Vector3, radius: float, color: Color) -> void:
    var node := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    node.mesh = mesh
    node.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.75
    node.material_override = mat
    parent.add_child(node)

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.62
    node.material_override = mat
    parent.add_child(node)
    return node
