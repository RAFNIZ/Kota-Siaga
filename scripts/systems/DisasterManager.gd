extends Node

## Owns city-wide disaster visuals and environmental gameplay impact.
## All effects are constrained to the authored 154 m Arunika city footprint.

const CITY_HALF_EXTENT: float = 77.0
const FLOOD_SURFACE_Y: float = 0.46
const FLOOD_SPEED_MULTIPLIER: float = 0.58

var world_root: Node3D
var fx_root: Node3D
var environment: Environment
var active_level: int = 0
var disaster_active: bool = false
var daylight: float = 0.8
var elapsed: float = 0.0
var flood_intensity: float = 0.0
var target_flood_intensity: float = 0.0
var wind_strength: float = 0.0
var target_wind_strength: float = 0.0
var base_fog_density: float = 0.00028
var base_fog_light_color: Color = Color("#9eabb6")
var rain_particles: GPUParticles3D
var screen_rain_particles: GPUParticles3D
var water_plane: MeshInstance3D
var water_material: ShaderMaterial
var tornado_root: Node3D
var city_wind_particles: GPUParticles3D
var puddle_ripples: Array[Dictionary] = []
var wind_props: Array[Dictionary] = []
var camera_rig: Node
var current_water_y: float = -0.035
var wind_direction: Vector3 = Vector3(-0.72, 0.0, -0.69).normalized()
var _impact_refresh_timer: float = 0.0

func configure(p_world_root: Node3D, p_environment: Environment, p_fx_root: Node3D) -> void:
    world_root = p_world_root
    environment = p_environment
    fx_root = p_fx_root
    if environment != null:
        base_fog_density = environment.fog_density
        base_fog_light_color = environment.fog_light_color
    _build_citywide_rain()
    _build_camera_rain()
    _build_flood_surface()
    _build_tornado_and_wind()
    _capture_wind_props()
    _apply_actor_impact_state()

func set_daylight(value: float, _weather_active: bool, _level: int) -> void:
    daylight = clampf(value, 0.0, 1.0)
    # CityWorld updates the day/night fog colour each frame. Mirror that baseline here
    # so the storm tint layers over the current time of day instead of fighting it.
    base_fog_light_color = Color("#314459").lerp(Color("#9aaab4"), daylight)

func set_disaster(level: int, active: bool) -> void:
    active_level = clampi(level, 0, 3)
    disaster_active = active and active_level > 0
    # Floodwater remains through the response/repair stage of a flood chapter,
    # but drains away when the chapter resets to weather level 0.
    target_flood_intensity = 1.0 if active_level == 2 else 0.0
    target_wind_strength = _target_wind_strength()

    if is_instance_valid(rain_particles):
        if active_level == 1:
            rain_particles.amount = 2300
        elif active_level == 2:
            rain_particles.amount = 3600
        rain_particles.emitting = disaster_active and active_level in [1, 2]
    if is_instance_valid(screen_rain_particles):
        if active_level == 1:
            screen_rain_particles.amount = 240
        elif active_level == 2:
            screen_rain_particles.amount = 360
        screen_rain_particles.emitting = disaster_active and active_level in [1, 2]
    if is_instance_valid(water_plane):
        water_plane.visible = target_flood_intensity > 0.0 or flood_intensity > 0.05
    if is_instance_valid(tornado_root):
        tornado_root.visible = disaster_active and active_level == 3
    if is_instance_valid(city_wind_particles):
        city_wind_particles.emitting = disaster_active and active_level == 3

    _apply_actor_impact_state()

func _target_wind_strength() -> float:
    if not disaster_active:
        return 0.0
    match active_level:
        1: return 0.22
        2: return 0.35
        3: return 1.0
    return 0.0

func _build_citywide_rain() -> void:
    rain_particles = GPUParticles3D.new()
    rain_particles.name = "CitywideRainParticles"
    rain_particles.amount = 3200
    rain_particles.lifetime = 1.05
    rain_particles.preprocess = 0.65
    rain_particles.explosiveness = 0.0
    rain_particles.local_coords = false
    rain_particles.emitting = false
    # Include the full falling path down to the street in local emitter bounds;
    # a too-high visibility AABB can cull rain before it reaches ground level.
    rain_particles.visibility_aabb = AABB(Vector3(-82.0, -21.0, -82.0), Vector3(164.0, 45.0, 164.0))

    var rain_mesh := QuadMesh.new()
    rain_mesh.size = Vector2(0.035, 0.72)
    var rain_mat := StandardMaterial3D.new()
    rain_mat.albedo_color = Color(0.69, 0.82, 0.93, 0.54)
    rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    rain_mat.no_depth_test = false
    rain_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    rain_mesh.material = rain_mat
    rain_particles.draw_pass_1 = rain_mesh

    var rain_process := ParticleProcessMaterial.new()
    rain_process.direction = Vector3(-0.16, -1.0, -0.10)
    rain_process.spread = 7.0
    rain_process.gravity = Vector3(0.0, -4.0, 0.0)
    rain_process.initial_velocity_min = 17.0
    rain_process.initial_velocity_max = 24.0
    rain_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    rain_process.emission_box_extents = Vector3(CITY_HALF_EXTENT, 9.0, CITY_HALF_EXTENT)
    rain_particles.process_material = rain_process
    rain_particles.position = Vector3(0.0, 18.0, 0.0)
    fx_root.add_child(rain_particles)

func _build_camera_rain() -> void:
    # This light camera-space layer adds readable foreground streaks; the larger
    # world-space emitter above keeps the storm visible across the entire city.
    screen_rain_particles = GPUParticles3D.new()
    screen_rain_particles.name = "ForegroundRainStreaks"
    screen_rain_particles.amount = 360
    screen_rain_particles.lifetime = 0.42
    screen_rain_particles.explosiveness = 0.0
    screen_rain_particles.local_coords = true
    screen_rain_particles.emitting = false
    screen_rain_particles.visibility_aabb = AABB(Vector3(-9.0, -6.0, -5.0), Vector3(18.0, 12.0, 5.0))

    var streak_mesh := QuadMesh.new()
    streak_mesh.size = Vector2(0.018, 0.48)
    var streak_material := StandardMaterial3D.new()
    streak_material.albedo_color = Color(0.76, 0.87, 0.96, 0.32)
    streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    streak_mesh.material = streak_material
    screen_rain_particles.draw_pass_1 = streak_mesh
    var streak_process := ParticleProcessMaterial.new()
    streak_process.direction = Vector3(-0.04, -1.0, 0.0)
    streak_process.spread = 4.0
    streak_process.gravity = Vector3(0.0, -2.0, 0.0)
    streak_process.initial_velocity_min = 10.0
    streak_process.initial_velocity_max = 15.0
    streak_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    streak_process.emission_box_extents = Vector3(8.0, 4.2, 0.05)
    screen_rain_particles.process_material = streak_process
    screen_rain_particles.position = Vector3(0.0, 0.0, -3.6)

func _attach_screen_rain_if_camera_ready() -> void:
    if not is_instance_valid(screen_rain_particles) or screen_rain_particles.is_inside_tree():
        return
    if camera_rig == null or not is_instance_valid(camera_rig):
        camera_rig = get_tree().get_first_node_in_group("camera_rig")
    if not is_instance_valid(camera_rig):
        return
    var camera := camera_rig.get_node_or_null("Camera3D") as Camera3D
    if camera != null:
        camera.add_child(screen_rain_particles)

func _build_flood_surface() -> void:
    water_plane = MeshInstance3D.new()
    water_plane.name = "CitywideFloodSurface"
    var plane := PlaneMesh.new()
    plane.size = Vector2(154.0, 154.0)
    plane.subdivide_width = 64
    plane.subdivide_depth = 64
    water_plane.mesh = plane
    water_plane.position = Vector3(0.0, current_water_y, 0.0)
    water_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    water_plane.visible = false
    water_material = ShaderMaterial.new()
    water_material.shader = load("res://assets/shaders/CityFloodWater.gdshader") as Shader
    water_plane.material_override = water_material
    fx_root.add_child(water_plane)

    for item in [Vector3(-49.0, 0.0, -21.0), Vector3(21.0, 0.0, 49.0), Vector3(49.0, 0.0, -21.0), Vector3(-21.0, 0.0, 49.0), Vector3(-49.0, 0.0, 21.0), Vector3(21.0, 0.0, -49.0)]:
        var ripple := MeshInstance3D.new()
        ripple.name = "FloodPuddleRipple"
        var mesh := TorusMesh.new()
        mesh.inner_radius = 0.38
        mesh.outer_radius = 0.48
        mesh.rings = 8
        mesh.ring_segments = 16
        ripple.mesh = mesh
        ripple.position = Vector3(item.x, current_water_y + 0.018, item.z)
        # TorusMesh defaults to the XY plane; rotate flat so it sits on the water surface.
        ripple.rotation.x = deg_to_rad(90.0)
        ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.63, 0.82, 0.91, 0.30)
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        ripple.material_override = material
        ripple.visible = false
        fx_root.add_child(ripple)
        puddle_ripples.append({"node": ripple, "phase": float(puddle_ripples.size()) * 0.91})

func _build_tornado_and_wind() -> void:
    tornado_root = Node3D.new()
    tornado_root.name = "CitywideTornadoVisual"
    tornado_root.position = Vector3(-60.0, 0.0, 56.0)
    tornado_root.visible = false
    for index in range(12):
        var ring := MeshInstance3D.new()
        ring.name = "TornadoVortexRing_%02d" % index
        var ring_mesh := TorusMesh.new()
        ring_mesh.inner_radius = 0.24 + float(index) * 0.15
        ring_mesh.outer_radius = 0.40 + float(index) * 0.15
        ring.mesh = ring_mesh
        ring.position.y = 0.75 + float(index) * 0.82
        ring.rotation.x = deg_to_rad(90.0)
        ring.rotation.y = float(index) * 0.31
        var ring_mat := StandardMaterial3D.new()
        ring_mat.albedo_color = Color(0.57, 0.66, 0.73, 0.27)
        ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
        ring_mat.roughness = 0.88
        ring.material_override = ring_mat
        ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        tornado_root.add_child(ring)
    fx_root.add_child(tornado_root)

    city_wind_particles = GPUParticles3D.new()
    city_wind_particles.name = "CitywideWindDebris"
    city_wind_particles.amount = 380
    city_wind_particles.lifetime = 1.45
    city_wind_particles.explosiveness = 0.0
    city_wind_particles.local_coords = false
    city_wind_particles.emitting = false
    city_wind_particles.visibility_aabb = AABB(Vector3(-82.0, -4.0, -82.0), Vector3(164.0, 22.0, 164.0))
    var debris_mesh := BoxMesh.new()
    debris_mesh.size = Vector3(0.075, 0.035, 0.09)
    var debris_material := StandardMaterial3D.new()
    debris_material.albedo_color = Color("#9c907f")
    debris_material.roughness = 0.96
    debris_mesh.material = debris_material
    city_wind_particles.draw_pass_1 = debris_mesh
    var wind_process := ParticleProcessMaterial.new()
    wind_process.direction = wind_direction
    wind_process.spread = 32.0
    wind_process.gravity = Vector3(0.0, -1.2, 0.0)
    wind_process.initial_velocity_min = 8.5
    wind_process.initial_velocity_max = 17.0
    wind_process.angular_velocity_min = -8.0
    wind_process.angular_velocity_max = 8.0
    wind_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    wind_process.emission_box_extents = Vector3(CITY_HALF_EXTENT, 5.0, CITY_HALF_EXTENT)
    city_wind_particles.process_material = wind_process
    city_wind_particles.position = Vector3(0.0, 4.5, 0.0)
    fx_root.add_child(city_wind_particles)

func _capture_wind_props() -> void:
    wind_props.clear()
    if world_root == null or not is_instance_valid(world_root):
        return
    for node in world_root.get_tree().get_nodes_in_group("wind_affected"):
        if node is Node3D and is_instance_valid(node):
            var prop := node as Node3D
            wind_props.append({
                "node": prop,
                "base_rotation": prop.rotation,
                "phase": float(prop.get_meta("wind_phase", prop.global_position.x * 0.11 + prop.global_position.z * 0.07))
            })

func _apply_actor_impact_state() -> void:
    if world_root == null or not is_instance_valid(world_root):
        return
    for group_name in ["traffic_vehicle", "ambient_npc", "evacuation_npc"]:
        for node in world_root.get_tree().get_nodes_in_group(group_name):
            if not is_instance_valid(node):
                continue
            if group_name == "traffic_vehicle" and node.has_method("set_flood_intensity"):
                node.call("set_flood_intensity", flood_intensity)
            elif group_name != "traffic_vehicle" and node.has_method("set_weather_impact"):
                node.call("set_weather_impact", active_level, disaster_active, wind_direction)

func _process(delta: float) -> void:
    elapsed += delta
    _attach_screen_rain_if_camera_ready()

    var wind_target := _target_wind_strength()
    target_wind_strength = wind_target
    wind_strength = move_toward(wind_strength, target_wind_strength, delta * 0.72)
    flood_intensity = move_toward(flood_intensity, target_flood_intensity, delta * 0.48)
    if is_instance_valid(water_plane):
        water_plane.visible = target_flood_intensity > 0.0 or flood_intensity > 0.05
    var target_fog := base_fog_density
    if disaster_active:
        match active_level:
            1: target_fog = base_fog_density + 0.00072
            2: target_fog = base_fog_density + 0.00145
            3: target_fog = base_fog_density + 0.00255
    if environment != null:
        environment.fog_density = lerpf(environment.fog_density, target_fog, clampf(delta * 1.2, 0.0, 1.0))
        var fog_target_color := base_fog_light_color
        if disaster_active:
            if active_level == 1: fog_target_color = base_fog_light_color.lerp(Color("#798d9f"), 0.42)
            elif active_level == 2: fog_target_color = base_fog_light_color.lerp(Color("#647b8c"), 0.64)
            elif active_level == 3: fog_target_color = base_fog_light_color.lerp(Color("#536675"), 0.82)
        environment.fog_light_color = environment.fog_light_color.lerp(fog_target_color, clampf(delta * 0.85, 0.0, 1.0))

    var flood_target_y := lerpf(-0.035, FLOOD_SURFACE_Y, flood_intensity)
    current_water_y = lerpf(current_water_y, flood_target_y, clampf(delta * 0.62, 0.0, 1.0))
    if is_instance_valid(water_plane):
        water_plane.position.y = current_water_y
    for ripple_data in puddle_ripples:
        var ripple := ripple_data["node"] as MeshInstance3D
        if not is_instance_valid(ripple):
            continue
        ripple.visible = flood_intensity > 0.05 or target_flood_intensity > 0.0
        ripple.position.y = current_water_y + 0.018
        var phase := elapsed * 1.7 + float(ripple_data["phase"])
        var wave_scale := 0.72 + (sin(phase) + 1.0) * 0.32
        ripple.scale = Vector3(wave_scale, 1.0, wave_scale)
        var ripple_material := ripple.material_override as StandardMaterial3D
        if ripple_material != null:
            var tint := ripple_material.albedo_color
            tint.a = 0.14 + (sin(phase) + 1.0) * 0.08
            ripple_material.albedo_color = tint

    if is_instance_valid(tornado_root):
        if tornado_root.visible:
            var path_t := fposmod(elapsed / 17.0, 1.0)
            tornado_root.position = Vector3(-60.0, sin(elapsed * 2.2) * 0.12, 56.0).lerp(Vector3(60.0, 0.0, -56.0), path_t)
            tornado_root.rotate_y(delta * 2.6)
    if is_instance_valid(city_wind_particles):
        city_wind_particles.emitting = disaster_active and active_level == 3
        city_wind_particles.position.y = 4.2 + sin(elapsed * 2.1) * 0.35

    for data in wind_props:
        var prop := data["node"] as Node3D
        if not is_instance_valid(prop):
            continue
        var base_rotation: Vector3 = data["base_rotation"]
        var phase := float(data["phase"])
        var amplitude := wind_strength * 0.075
        prop.rotation = Vector3(
            base_rotation.x + sin(elapsed * 2.7 + phase) * amplitude,
            base_rotation.y,
            base_rotation.z + cos(elapsed * 2.1 + phase * 0.7) * amplitude * 0.75
        )

    _impact_refresh_timer -= delta
    if _impact_refresh_timer <= 0.0:
        _apply_actor_impact_state()
        _impact_refresh_timer = 0.5

    if camera_rig == null or not is_instance_valid(camera_rig):
        camera_rig = get_tree().get_first_node_in_group("camera_rig")
    if is_instance_valid(camera_rig) and camera_rig.has_method("set_disaster_shake"):
        var shake_amount := 0.0
        if disaster_active:
            if active_level == 1: shake_amount = 0.012
            elif active_level == 2: shake_amount = 0.018
            elif active_level == 3: shake_amount = 0.038
        camera_rig.call("set_disaster_shake", shake_amount)
