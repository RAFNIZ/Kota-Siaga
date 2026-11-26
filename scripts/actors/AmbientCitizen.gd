extends CharacterBody3D

const CHARACTER_MODEL_FACTORY := preload("res://scripts/actors/CharacterModelFactory.gd")

@export var shirt_color: Color = Color("#4c7f9c")
@export var skin_color: Color = Color("#c99573")
@export var patrol_offsets: Array[Vector3] = [Vector3(2, 0, 0), Vector3(2, 0, 2), Vector3(0, 0, 2), Vector3.ZERO]
@export var walk_speed: float = 1.6
@export var idle_min: float = 0.8
@export var idle_max: float = 2.6

var _origin := Vector3.ZERO
var _target_index := 0
var _idle_timer := 0.0
var _stuck_timer := 0.0
var _animation_clock := 0.0
var _gait_phase := 0.0
var _gait_blend := 0.0
var _run_blend := 0.0
var _last_footstep_index: int = -1
var _last_position := Vector3.ZERO
var _visual_root: Node3D
var character_asset_id: String = "civilian"
var character_model: Node3D
var _rng := RandomNumberGenerator.new()
var _weather_level: int = 0
var _weather_active: bool = false
var _wind_direction := Vector3.ZERO


func configure_ambient(p_shirt: Color, p_skin: Color, p_route: Array[Vector3], p_speed: float, p_idle_min: float, p_idle_max: float, p_character_asset_id: String = "civilian") -> void:
    shirt_color = p_shirt
    skin_color = p_skin
    patrol_offsets = p_route.duplicate()
    walk_speed = p_speed
    idle_min = p_idle_min
    idle_max = p_idle_max
    character_asset_id = p_character_asset_id


func set_weather_impact(level: int, active: bool, wind_dir: Vector3) -> void:
    _weather_level = clampi(level, 0, 3)
    _weather_active = active
    _wind_direction = Vector3(wind_dir.x, 0.0, wind_dir.z).normalized()

func _ready() -> void:
    add_to_group("ambient_npc")
    collision_layer = 1
    collision_mask = 1
    floor_snap_length = 0.25
    _origin = global_position
    _last_position = global_position
    _rng.randomize()
    _idle_timer = _rng.randf_range(idle_min, idle_max)
    var collision := CollisionShape3D.new()
    collision.name = "NPCBodyCollider"
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.34
    capsule.height = 1.8
    collision.shape = capsule
    collision.position.y = 0.9
    add_child(collision)
    _build_character()

func _physics_process(delta: float) -> void:
    _animation_clock += delta
    if patrol_offsets.is_empty():
        velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
        _apply_gravity(delta)
        move_and_slide()
        _animate(false, delta)
        return

    if _idle_timer > 0.0:
        _idle_timer -= delta
        velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
        _apply_gravity(delta)
        move_and_slide()
        _animate(false, delta)
        return

    var target := _origin + patrol_offsets[_target_index]
    var direction := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
    if direction.length() < 0.42:
        _target_index = (_target_index + 1) % patrol_offsets.size()
        _idle_timer = _rng.randf_range(idle_min, idle_max)
        _stuck_timer = 0.0
        direction = Vector3.ZERO
    else:
        direction = direction.normalized()
        if _visual_root:
            _visual_root.rotation.y = atan2(-direction.x, -direction.z)
    var weather_speed_scale := 1.0
    if _weather_level == 2:
        weather_speed_scale = 0.84
    elif _weather_level == 3 and _weather_active:
        weather_speed_scale = 0.72
    var wind_push := _wind_direction * 0.42 if _weather_level == 3 and _weather_active else Vector3.ZERO
    velocity.x = direction.x * walk_speed * weather_speed_scale + wind_push.x
    velocity.z = direction.z * walk_speed * weather_speed_scale + wind_push.z
    _apply_gravity(delta)
    move_and_slide()
    var moved_distance := Vector2(global_position.x - _last_position.x, global_position.z - _last_position.z).length()
    if moved_distance < 0.008 and direction.length_squared() > 0.01:
        _stuck_timer += delta
        if _stuck_timer > 1.6:
            _target_index = (_target_index + 1) % patrol_offsets.size()
            _stuck_timer = 0.0
    else:
        _stuck_timer = 0.0
    _last_position = global_position
    _animate(direction.length_squared() > 0.01 and _idle_timer <= 0.0, delta)

func _apply_gravity(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * delta
    else:
        velocity.y = maxf(velocity.y, 0.0)

func _build_character() -> void:
    _visual_root = Node3D.new()
    _visual_root.name = "AmbientNPCVisual"
    add_child(_visual_root)

    var model_paths := {
        "civilian": "res://assets/characters/rigged/npc_civilian.glb",
        "elder": "res://assets/characters/rigged/npc_elder.glb",
        "child": "res://assets/characters/rigged/npc_child.glb",
        "wheelchair": "res://assets/characters/rigged/npc_wheelchair.glb",
        "injured": "res://assets/characters/rigged/npc_injured.glb"
    }
    var target_height := 1.72
    if character_asset_id == "elder":
        target_height = 1.72
    elif character_asset_id == "child":
        target_height = 1.72
    elif character_asset_id == "wheelchair":
        target_height = 1.72
    character_model = CHARACTER_MODEL_FACTORY.attach_model(
        _visual_root,
        str(model_paths.get(character_asset_id, model_paths["civilian"])),
        target_height,
        PI
    )

    var name_tag := Label3D.new()
    name_tag.name = "AmbientName"
    name_tag.text = "WARGA"
    name_tag.position.y = target_height + 0.10
    name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    name_tag.pixel_size = 0.003
    name_tag.font_size = 18
    name_tag.outline_size = 4
    name_tag.modulate = Color("#e6f2ef")
    name_tag.no_depth_test = true
    name_tag.visible = false
    _visual_root.add_child(name_tag)

func _animate(moving: bool, delta: float) -> void:
    if not is_instance_valid(_visual_root):
        return
    var target_blend := 1.0 if moving else 0.0
    # The current ambient routes are walk-paced; higher-speed routes blend naturally into the run pose.
    var target_run := clampf((walk_speed - 2.45) / 1.45, 0.0, 1.0) if moving else 0.0
    _gait_blend = move_toward(_gait_blend, target_blend, (5.5 if moving else 3.8) * delta)
    _run_blend = move_toward(_run_blend, target_run, 4.5 * delta)
    _gait_phase += delta * lerpf(8.0, 10.8, _run_blend) * _gait_blend
    if moving:
        var step_index := floori(_gait_phase / PI)
        if step_index != _last_footstep_index:
            _last_footstep_index = step_index
            AudioManager.play_footstep_at(global_position, _run_blend > 0.5, true)
    else:
        _last_footstep_index = -1
    _visual_root.position.y = absf(sin(_gait_phase * 2.0)) * (0.014 + 0.008 * _run_blend) * _gait_blend + sin(_animation_clock * 1.6) * 0.004 * (1.0 - _gait_blend)
    if is_instance_valid(character_model):
        CHARACTER_MODEL_FACTORY.apply_locomotion(character_model, _gait_blend, _run_blend, _gait_phase, false)
