extends Node3D

const CHARACTER_MODEL_FACTORY := preload("res://scripts/actors/CharacterModelFactory.gd")

signal reached_safe(citizen: Node3D)

var citizen_type: String = "Warga"
var display_name: String = "Warga"
var dialogue_line: String = "Tolong bantu saya menuju tempat aman."
var walk_speed: float = 3.5
var state: String = "waiting"
var reassured: bool = false
var route: Array[Vector3] = []
var route_index: int = 0
var anim_time: float = 0.0
var gait_phase: float = 0.0
var gait_blend: float = 0.0
var run_blend: float = 0.0
var _last_footstep_index: int = -1
var visual_root: Node3D
var character_model: Node3D
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var stuck_timer: float = 0.0
var last_evac_position: Vector3 = Vector3.ZERO
var weather_level: int = 0
var weather_active: bool = false
var wind_direction := Vector3.ZERO

func configure(p_type: String, p_name: String, p_dialogue: String, p_speed: float) -> void:
    citizen_type = p_type
    display_name = p_name
    dialogue_line = p_dialogue
    walk_speed = p_speed


func set_weather_impact(level: int, active: bool, wind_dir: Vector3) -> void:
    weather_level = clampi(level, 0, 3)
    weather_active = active
    wind_direction = Vector3(wind_dir.x, 0.0, wind_dir.z).normalized()
    if weather_active and weather_level == 3 and state == "waiting":
        state = "alert"

func begin_evacuation(points: Array[Vector3]) -> void:
    if state in ["evacuating", "safe"]: return
    route = points.duplicate()
    route_index = 0
    state = "evacuating"

func set_alert() -> void:
    if state == "waiting": state = "alert"

func _ready() -> void:
    add_to_group("evacuation_npc")
    last_evac_position = global_position
    _build_visual()

func _process(delta: float) -> void:
    anim_time += delta
    var locomotion_speed: float = 0.0
    if state == "evacuating" and route_index < route.size():
        var target: Vector3 = route[route_index]
        var speed := walk_speed
        if citizen_type == "Lansia": speed *= 0.78
        elif citizen_type == "Anak": speed *= 0.90
        elif citizen_type == "Pengguna kursi roda": speed *= 0.87
        if weather_level == 2:
            speed *= 0.84
        elif weather_level == 3 and weather_active:
            speed *= 0.72
        var flat_target := Vector3(target.x, 0.0, target.z)
        var current := Vector3(global_position.x, 0.0, global_position.z)
        var offset := flat_target - current
        if offset.length() > 0.18:
            var move_direction := offset.normalized()
            if weather_level == 3 and weather_active:
                # Strong gusts slightly deflect evacuees without erasing their navigation goal.
                move_direction = (move_direction - wind_direction * 0.12).normalized()
                global_position += wind_direction * 0.12 * delta
            locomotion_speed = speed
            global_position.x += move_direction.x * speed * delta
            global_position.z += move_direction.z * speed * delta
            if visual_root: visual_root.rotation.y = atan2(-move_direction.x, -move_direction.z)
        else:
            route_index += 1
            if route_index >= route.size():
                state = "safe"
                reached_safe.emit(self)
    if state == "evacuating":
        if global_position.distance_to(last_evac_position) < 0.008 and route_index < route.size():
            stuck_timer += delta
            if stuck_timer >= 2.2:
                # Routes are precomputed around large props. If a point is blocked by a collider,
                # advance to the next route node instead of freezing the quest forever.
                route_index = mini(route_index + 1, route.size())
                stuck_timer = 0.0
                if route_index >= route.size():
                    state = "safe"
                    reached_safe.emit(self)
        else:
            stuck_timer = 0.0
        last_evac_position = global_position

    if visual_root:
        var moving := state == "evacuating" and locomotion_speed > 0.1
        var alarmed := state == "alert"
        var target_gait := clampf(locomotion_speed / maxf(walk_speed, 0.1), 0.0, 1.0) if moving else 0.0
        # Faster evacuees transition from walk to a restrained jog; older/child speeds remain individual.
        var target_run := clampf((locomotion_speed - 2.45) / 1.45, 0.0, 1.0) if moving else 0.0
        gait_blend = move_toward(gait_blend, target_gait, (5.5 if moving else 3.6) * delta)
        run_blend = move_toward(run_blend, target_run, 4.5 * delta)
        gait_phase += delta * lerpf(8.6, 11.2, run_blend) * gait_blend
        if moving:
            var step_index := floori(gait_phase / PI)
            if step_index != _last_footstep_index:
                _last_footstep_index = step_index
                AudioManager.play_footstep_at(global_position, run_blend > 0.5, true)
        else:
            _last_footstep_index = -1
        var idle_breath := sin(anim_time * (4.8 if alarmed else 1.8)) * (0.008 if alarmed else 0.003)
        visual_root.position.y = absf(sin(gait_phase * 2.0)) * (0.014 + 0.008 * run_blend) * gait_blend + idle_breath * (1.0 - gait_blend)
        if is_instance_valid(character_model):
            CHARACTER_MODEL_FACTORY.apply_locomotion(character_model, gait_blend, run_blend, gait_phase, false)
        _process_status()

func _build_visual() -> void:
    visual_root = Node3D.new()
    visual_root.name = "CitizenVisual"
    add_child(visual_root)

    var model_path := "res://assets/characters/rigged/npc_civilian.glb"
    var target_height := 1.72
    match citizen_type:
        "Anak":
            model_path = "res://assets/characters/rigged/npc_child.glb"
            target_height = 1.72
        "Lansia":
            model_path = "res://assets/characters/rigged/npc_elder.glb"
            target_height = 1.72
        "Pengguna kursi roda":
            model_path = "res://assets/characters/rigged/npc_wheelchair.glb"
            target_height = 1.72
        "Korban", "Korban cedera", "Korban Cedera":
            model_path = "res://assets/characters/rigged/npc_injured.glb"
            target_height = 1.72

    character_model = CHARACTER_MODEL_FACTORY.attach_model(visual_root, model_path, target_height, PI)

    var tag := Label3D.new()
    tag.name = "CitizenName"
    tag.text = display_name
    tag.position.y = target_height + 0.13
    tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    tag.pixel_size = 0.0032
    tag.font_size = 22
    tag.outline_size = 4
    tag.modulate = Color("#f3f8f7")
    tag.no_depth_test = true
    visual_root.add_child(tag)

    var status := Label3D.new()
    status.name = "CitizenStatus"
    status.position.y = target_height + 0.35
    status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    status.pixel_size = 0.003
    status.font_size = 16
    status.outline_size = 4
    status.modulate = Color("#ffd991")
    status.no_depth_test = true
    status.text = "MEMBUTUHKAN BANTUAN"
    visual_root.add_child(status)

func _process_status() -> void:
    var status := visual_root.get_node_or_null("CitizenStatus") as Label3D
    if status:
        match state:
            "waiting": status.text = KotaLocale.t("quest_waiting")
            "alert": status.text = KotaLocale.t("quest_alert")
            "evacuating": status.text = KotaLocale.t("quest_moving")
            "safe": status.text = KotaLocale.t("quest_safe")
        status.modulate = Color("#72e1b8") if state == "safe" else Color("#ffd991")
