extends Node3D

const ASSET_ROOT := "res://assets/DowntownCity/"
var dynamic_root: Node3D
var building_bounds: Array[Dictionary] = []
var facility_visuals: Dictionary = {}
var hazard_visuals: Dictionary = {}
var side_visuals: Dictionary = {}
var citizen_root: Node3D
var weather_root: Node3D
var rain_particles: GPUParticles3D
var flood_sheet: MeshInstance3D
var tornado_root: Node3D
var map_built := false
var traffic_root: Node3D
var traffic_vehicles: Array[Dictionary] = []
var traffic_signal_visuals: Array[Dictionary] = []
var traffic_phase: int = 0
var traffic_phase_elapsed: float = 0.0
@export_range(4, 24, 1) var traffic_vehicle_target_count: int = 12
@export var traffic_front_detection_length: float = 9.0
@export var traffic_stop_buffer: float = 5.8
var traffic_rng: RandomNumberGenerator = RandomNumberGenerator.new()

const TRAFFIC_PHASE_X_GREEN: int = 0
const TRAFFIC_PHASE_X_YELLOW: int = 1
const TRAFFIC_PHASE_ALL_RED_AFTER_X: int = 2
const TRAFFIC_PHASE_Z_GREEN: int = 3
const TRAFFIC_PHASE_Z_YELLOW: int = 4
const TRAFFIC_PHASE_ALL_RED_AFTER_Z: int = 5
const TRAFFIC_PHASE_DURATIONS := [10.0, 2.8, 0.8, 10.0, 2.8, 0.8]
const TRAFFIC_ROUTE_SAMPLE_SPACING: float = 0.35
# Vehicle steering is derived from the path curvature in world metres.
# The body follows the current path tangent; front wheels anticipate curvature.
const TRAFFIC_BODY_TANGENT_SAMPLE_DISTANCE: float = 0.55
const TRAFFIC_WHEELBASE_FALLBACK: float = 2.65
const TRAFFIC_MAX_STEER_ANGLE: float = 0.52
var current_weather_level: int = 0
var weather_active: bool = false
var flood_sheet_secondary: MeshInstance3D
var flood_ripples: Array[Dictionary] = []
var wind_particles: GPUParticles3D
var disaster_manager: Node
var world_clock_minutes: float = 14.0 * 60.0
var clock_rate: float = 2.5
var sun_light: DirectionalLight3D
var world_environment: Environment
var sky_shader_material: ShaderMaterial
var sky_cloud_root: Node3D
var sky_cloud_groups: Array[Dictionary] = []
var sky_cloud_material: StandardMaterial3D
var clock_label: Label3D

func _ready() -> void:
    if not KotaLocale.language_changed.is_connected(_on_language_changed):
        KotaLocale.language_changed.connect(_on_language_changed)
    _make_lighting()
    _make_sky_cloud_assets()
    _make_ground()
    _build_metropolitan()
    _make_city_lighting()
    _make_traffic()
    _make_traffic_signals()
    _make_ambient_citizens()
    call_deferred("_hide_unwanted_floating_labels")
    dynamic_root = Node3D.new()
    dynamic_root.name = "MissionObjects"
    add_child(dynamic_root)
    citizen_root = Node3D.new()
    citizen_root.name = "Citizens"
    dynamic_root.add_child(citizen_root)
    weather_root = Node3D.new()
    weather_root.name = "WeatherEffects"
    add_child(weather_root)
    _make_weather_effects()

func _make_lighting() -> void:
    var world_env := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    sky.radiance_size = Sky.RADIANCE_SIZE_256
    sky.process_mode = Sky.PROCESS_MODE_REALTIME
    sky_shader_material = ShaderMaterial.new()
    sky_shader_material.shader = load("res://assets/sky/ArunikaDynamicSky.gdshader") as Shader
    sky.sky_material = sky_shader_material
    env.sky = sky
    # Use a stable colour ambient fill instead of relying only on sky radiance. This
    # keeps the shaded side of NPCs/buildings readable at sunrise and in storm weather.
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#b4c2cc")
    env.ambient_light_energy = 1.28
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 1.24
    env.fog_enabled = true
    env.fog_light_color = Color("#9eabb6")
    env.fog_density = 0.00042
    world_env.environment = env
    world_environment = env
    add_child(world_env)

    var sun := DirectionalLight3D.new()
    sun_light = sun
    sun.name = "ArunikaSun"
    sun.rotation_degrees = Vector3(-42, -32, 0)
    sun.light_color = Color("#fff1d9")
    sun.light_energy = 1.15
    sun.light_angular_distance = 0.42
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 68.0
    sun.shadow_bias = 0.028
    sun.shadow_normal_bias = 0.72
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
    add_child(sun)

func _make_sky_cloud_assets() -> void:
    # Low-poly voxel cloud banks provide chunky silhouettes close to the Minecraft look;
    # the sky shader continues to supply soft distant cloud coverage and the sun/moon sky.
    sky_cloud_root = Node3D.new()
    sky_cloud_root.name = "Arunika3DVoxelCloudBanks"
    add_child(sky_cloud_root)
    sky_cloud_material = StandardMaterial3D.new()
    sky_cloud_material.albedo_color = Color("#eef5fb")
    sky_cloud_material.roughness = 1.0
    sky_cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

    var banks: Array[Vector3] = [
        Vector3(-51.0, 34.0, -61.0), Vector3(-12.0, 38.0, -73.0),
        Vector3(40.0, 35.0, -59.0), Vector3(75.0, 32.0, -25.0),
        Vector3(65.0, 37.0, 32.0), Vector3(18.0, 34.0, 70.0),
        Vector3(-39.0, 36.0, 60.0), Vector3(-75.0, 33.0, 22.0)
    ]
    for i in range(banks.size()):
        var bank := Node3D.new()
        bank.name = "VoxelCloudBank_%02d" % (i + 1)
        bank.position = banks[i]
        bank.set_meta("base_position", banks[i])
        bank.set_meta("phase", float(i) * 0.83)
        sky_cloud_root.add_child(bank)
        sky_cloud_groups.append({"node": bank, "base": banks[i], "phase": float(i) * 0.83})

        var rng := RandomNumberGenerator.new()
        rng.seed = 4201 + i * 173
        var chunk_index := 0
        # Main horizontal body, built from overlapping box volumes rather than spheres.
        var base_count := rng.randi_range(5, 7)
        for base_index in range(base_count):
            var chunk := MeshInstance3D.new()
            chunk.name = "CloudVoxel_%02d" % chunk_index
            chunk_index += 1
            var box := BoxMesh.new()
            box.size = Vector3(rng.randf_range(3.4, 7.2), rng.randf_range(1.0, 1.65), rng.randf_range(2.8, 5.4))
            chunk.mesh = box
            chunk.position = Vector3(rng.randf_range(-7.5, 7.5), rng.randf_range(-0.22, 0.35), rng.randf_range(-2.0, 2.0))
            chunk.material_override = sky_cloud_material
            chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            bank.add_child(chunk)
        # Raised, smaller blocks create a stepped top silhouette, like voxel cloud masses.
        var top_count := rng.randi_range(3, 4)
        for top_index in range(top_count):
            var chunk := MeshInstance3D.new()
            chunk.name = "CloudVoxelTop_%02d" % chunk_index
            chunk_index += 1
            var box := BoxMesh.new()
            box.size = Vector3(rng.randf_range(2.4, 4.8), rng.randf_range(1.0, 1.8), rng.randf_range(2.2, 4.0))
            chunk.mesh = box
            chunk.position = Vector3(rng.randf_range(-5.8, 5.8), rng.randf_range(0.8, 1.7), rng.randf_range(-1.8, 1.8))
            chunk.material_override = sky_cloud_material
            chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            bank.add_child(chunk)

func _make_ground() -> void:
    var ground := MeshInstance3D.new()
    ground.name = "CityGround"
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(170, 170)
    ground.mesh = mesh
    ground.position = Vector3(0, -0.08, 0)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#87968e")
    mat.roughness = 0.98
    var concrete_texture := load(ASSET_ROOT + "T_Concrete_BaseColor.png") as Texture2D
    if concrete_texture:
        mat.albedo_texture = concrete_texture
        mat.uv1_scale = Vector3(16, 16, 1)
    ground.material_override = mat
    ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(ground)

    var ground_body := StaticBody3D.new()
    ground_body.name = "GroundCollider"
    ground_body.position.y = -0.18
    var ground_shape := CollisionShape3D.new()
    var floor_shape := BoxShape3D.new()
    floor_shape.size = Vector3(170, 0.2, 170)
    ground_shape.shape = floor_shape
    ground_body.add_child(ground_shape)
    add_child(ground_body)

func _build_metropolitan() -> void:
    # Compact 3x3-block city: four intersections per axis, with two 12m
    # road segments filling every 24m gap between the 18m junction modules.
    var intersection := preload("res://assets/DowntownCity/Street_4WayIntersection.gltf")
    var road := preload("res://assets/DowntownCity/Street_4Lane.gltf")
    var junctions: Array[float] = [-63.0, -21.0, 21.0, 63.0]
    var gap_centers: Array[float] = [-42.0, 0.0, 42.0]
    var road_segments: Array[float] = [-48.0, -36.0, -6.0, 6.0, 36.0, 48.0]

    # Roads first; all segments touch the intersection apron without gaps.
    for x in junctions:
        for z in junctions:
            _add_instance(intersection, Vector3(x, 0.12, z), 0.0, Vector3.ONE, "Intersection")
    for road_z in junctions:
        for segment_x in road_segments:
            _add_instance(road, Vector3(segment_x, 0.12, road_z), PI * 0.5, Vector3.ONE, "EastWestRoad")
    for road_x in junctions:
        for segment_z in road_segments:
            _add_instance(road, Vector3(road_x, 0.12, segment_z), 0.0, Vector3.ONE, "NorthSouthRoad")

    # Sidewalks repeat in clean 3m modules along both sides of every street.
    var sidewalk := preload("res://assets/DowntownCity/Sidewalk_Straight_3m.gltf")
    var sidewalk_stripe := preload("res://assets/DowntownCity/Sidewalk_Straight_3m_Stripe.gltf")
    var sidewalk_corner := preload("res://assets/DowntownCity/Sidewalk_Corner_Round_3m.gltf")
    for road_z in junctions:
        for center_x in gap_centers:
            for i in range(8):
                var tile_x: float = center_x + (float(i) - 3.5) * 3.0
                var tile_scene: PackedScene = sidewalk_stripe if i == 2 or i == 5 else sidewalk
                for side in [-1.0, 1.0]:
                    _add_instance(tile_scene, Vector3(tile_x, 0.10, road_z + side * 10.5), 0.0, Vector3.ONE, "SidewalkHorizontal")
    for road_x in junctions:
        for center_z in gap_centers:
            for i in range(8):
                var tile_z: float = center_z + (float(i) - 3.5) * 3.0
                var tile_scene: PackedScene = sidewalk_stripe if i == 2 or i == 5 else sidewalk
                for side in [-1.0, 1.0]:
                    _add_instance(tile_scene, Vector3(road_x + side * 10.5, 0.10, tile_z), PI * 0.5, Vector3.ONE, "SidewalkVertical")
    for x in junctions:
        for z in junctions:
            for corner in [
                {"offset":Vector2(-10.5, -10.5), "yaw":0.0},
                {"offset":Vector2(10.5, -10.5), "yaw":PI * 0.5},
                {"offset":Vector2(10.5, 10.5), "yaw":PI},
                {"offset":Vector2(-10.5, 10.5), "yaw":PI * 1.5}
            ]:
                var offset: Vector2 = corner["offset"]
                _add_instance(sidewalk_corner, Vector3(x + offset.x, 0.10, z + offset.y), float(corner["yaw"]), Vector3.ONE, "SidewalkCorner")

    # Seven buildings leave two useful open public-space blocks instead of filling the whole map.
    _add_city_building("Building_Large_2", Vector3(-42, 0, -42), 0.68, 0.0, Vector2(20.0, 16.0), 28.0)
    _add_city_building("Building_Medium_2_001", Vector3(0, 0, -42), 0.78, PI, Vector2(14.0, 12.0), 25.0)
    _add_city_building("Building_Small_1", Vector3(42, 0, -42), 0.82, PI * 0.5, Vector2(12.4, 14.5), 17.0)
    _add_city_building("Building_Medium_2_001", Vector3(-42, 0, 0), 0.78, 0.0, Vector2(14.0, 12.0), 25.0)
    _add_city_building("Building_Small_1", Vector3(0, 0, 0), 0.82, PI * 0.5, Vector2(12.4, 14.5), 17.0)
    _add_city_building("Building_Large_2", Vector3(42, 0, 0), 0.68, PI, Vector2(20.0, 16.0), 28.0)
    _add_city_building("Building_Medium_2_001", Vector3(0, 0, 42), 0.78, PI, Vector2(14.0, 12.0), 25.0)

    _add_rooftop_ac_units(Vector3(-42, 0, -42), 19.04, 0.0, 2)
    _add_rooftop_ac_units(Vector3(0, 0, -42), 19.5, PI, 1)
    _add_rooftop_ac_units(Vector3(42, 0, -42), 13.94, PI * 0.5, 1)
    _add_rooftop_ac_units(Vector3(-42, 0, 0), 19.5, 0.0, 1)
    _add_rooftop_ac_units(Vector3(0, 0, 0), 13.94, PI * 0.5, 1)
    _add_rooftop_ac_units(Vector3(42, 0, 0), 19.04, PI, 2)
    _add_rooftop_ac_units(Vector3(0, 0, 42), 19.5, PI, 1)

    # A rain-garden/resapan block and a separate evacuation plaza are deliberately
    # far apart so the mitigation facilities do not crowd each other.
    _create_lot_surface(Vector3(-42, 0, 42), Vector2(20.0, 20.0), Color("#647d62"), true)
    _create_lot_surface(Vector3(42, 0, 42), Vector2(20.0, 20.0), Color("#879c8a"), true)

    # Road markings are oriented along the road direction: the source decals run along local Z.
    var crosswalk := preload("res://assets/DowntownCity/Decal_Crosswalk_Wide.gltf")
    var double_yellow := preload("res://assets/DowntownCity/Decal_DoubleYellow_Straight.gltf")
    var arrow_mark := preload("res://assets/DowntownCity/Decal_ArrowStraight.gltf")
    for x in junctions:
        for z in junctions:
            # Crosswalk centers are locked 9 m from the intersection; all four approaches use the same coordinates.
            # Imported stripe mesh bottoms sit 7 mm above the road top at y=-0.03, avoiding coplanar z-fighting.
            # Across east-west roads: rotate the long stripe array to lie across X.
            _add_instance(crosswalk, Vector3(x, 0.125, z - 9.0), PI * 0.5, Vector3.ONE, "CrosswalkNorth")
            _add_instance(crosswalk, Vector3(x, 0.125, z + 9.0), PI * 0.5, Vector3.ONE, "CrosswalkSouth")
            # Across north-south roads: default local-Z orientation is correct.
            _add_instance(crosswalk, Vector3(x - 9.0, 0.125, z), 0.0, Vector3.ONE, "CrosswalkWest")
            _add_instance(crosswalk, Vector3(x + 9.0, 0.125, z), 0.0, Vector3.ONE, "CrosswalkEast")
    # Each road segment receives one central double-yellow decal. The imported asphalt top is
    # world y=-0.03 (road origin 0.12 plus mesh local y=-0.15); this decal sits at local y=-0.11.
    # Place its origin at y=0.083 so the paint is 3 mm above the asphalt rather than floating or z-fighting.
    for road_z in junctions:
        for segment_x in road_segments:
            _add_instance(double_yellow, Vector3(segment_x, 0.083, road_z), PI * 0.5, Vector3.ONE, "DoubleYellowEW")
    for road_x in junctions:
        for segment_z in road_segments:
            _add_instance(double_yellow, Vector3(road_x, 0.083, segment_z), 0.0, Vector3.ONE, "DoubleYellowNS")
    # Painted STOP text removed by request; signal logic still controls vehicles.
    for mark in [
        {"pos":Vector3(-6, 0.124, -21), "yaw":PI * 0.5},
        {"pos":Vector3(6, 0.124, -21), "yaw":PI * 0.5},
        {"pos":Vector3(21, 0.124, -6), "yaw":0.0},
        {"pos":Vector3(21, 0.124, 6), "yaw":0.0}
    ]:
        _add_instance(arrow_mark, mark["pos"], float(mark["yaw"]), Vector3.ONE, "LaneArrow")

    # City furniture is placed at block edges/plazas, never in the middle of lane markings.
    var drain_scene := preload("res://assets/DowntownCity/Prop_Drain.gltf")
    var planter_scene := preload("res://assets/DowntownCity/Prop_Planter_Single.gltf")
    var plaza_planter_scene := preload("res://assets/DowntownCity/Sidewalk_Planter.gltf")
    # Drain grates sit beside the curb, never on the middle of a driving lane or the walking line.
    for point in [Vector3(-51,0.02,-12.25), Vector3(51,0.02,12.25), Vector3(-12.25,0.02,48), Vector3(12.25,0.02,-48)]:
        _add_instance(drain_scene, point, 0.0, Vector3.ONE * 0.88, "StreetDrain")
    # Decorative grey manhole-cover props are omitted from the road surface.
    # Zebra crossings and lane markings already provide clear road reading; keep drains
    # at the curb where they support the flood-mitigation theme without cluttering lanes.
    # Removed decorative bollards from sidewalk edges: they were visually intrusive and
    # could read as blocking props from the player camera. Keep accessible paths clear.
    # Former sprite dressing is replaced with procedural 3D objects below.
    # Place these props in the parks and at road corners, leaving the pedestrian center line clear.
    _add_modern_sprite("Greenery/street_greenery_tree_street_round_01.png", Vector3(-49.5, 0.02, 49.5), 0.0220, "ModernRainGardenTreeA")
    _add_modern_sprite("Greenery/street_greenery_tree_street_tall_01.png", Vector3(-34.5, 0.02, 49.0), 0.0200, "ModernRainGardenTreeB")
    _add_modern_sprite("Greenery/street_greenery_bush_pair_01.png", Vector3(-49.5, 0.02, 34.5), 0.0155, "ModernRainGardenShrubs")
    _add_modern_sprite("StreetFurniture/street_street_furniture_bench_park_01.png", Vector3(-34.0, 0.02, 34.0), 0.0098, "ModernRainGardenBench")

    _add_modern_sprite("Greenery/street_greenery_tree_street_round_01.png", Vector3(34.5, 0.02, 49.5), 0.0215, "ModernSafePlazaTreeA")
    _add_modern_sprite("Greenery/street_greenery_tree_street_tall_01.png", Vector3(49.5, 0.02, 49.0), 0.0190, "ModernSafePlazaTreeB")
    _add_modern_sprite("StreetFurniture/street_street_furniture_bench_park_01.png", Vector3(34.0, 0.02, 34.0), 0.0098, "ModernSafePlazaBenchA")
    _add_modern_sprite("StreetFurniture/street_street_furniture_bench_bus_stop_01.png", Vector3(40.0, 0.02, 34.5), 0.0090, "ModernSafePlazaBenchB")
    # Small city amenities are kept at plaza edges so the central route to Titik Aman stays open.
    _add_modern_sprite("StreetFurniture/street_street_furniture_bus_stop_shelter_01.png", Vector3(49.8, 0.02, 35.0), 0.0096, "ModernPlazaBusShelter")
    _add_modern_sprite("Utilities/street_utilities_trash_bin_street_green_01.png", Vector3(-44.5, 0.02, 34.0), 0.0085, "ModernRainGardenWasteBin")
    _add_modern_sprite("Utilities/street_utilities_trash_bin_street_green_01.png", Vector3(51.0, 0.02, 46.5), 0.0085, "ModernSafePlazaWasteBin")
    _add_modern_sprite("PlazaParkStructures/street_plaza_park_structures_fountain_drinking_park_01.png", Vector3(-42.0, 0.02, 47.0), 0.0078, "ModernRainGardenDrinkingFountain")
    _add_modern_sprite("StreetFurniture/street_street_furniture_sign_post_blank_01.png", Vector3(-50.0, 0.02, 35.5), 0.0090, "ModernRainGardenWayfinding")
    _add_modern_sprite("StreetFurniture/street_street_furniture_hydrant_fire_01.png", Vector3(-53.0, 0.02, 38.5), 0.0092, "ModernRainGardenHydrant")
    _add_modern_sprite("StreetFurniture/street_street_furniture_phone_booth_01.png", Vector3(50.5, 0.02, 42.0), 0.0092, "ModernSafePlazaPublicPhone")
    _add_modern_sprite("Utilities/street_utilities_recycling_bins_row_01.png", Vector3(45.0, 0.02, 37.0), 0.0076, "ModernSafePlazaRecycling")

    # Two street lamps and four signal cutouts decorate intersection corners (not the walk-through center).
    _add_modern_sprite("StreetFurniture/street_street_furniture_streetlight_double_01.png", Vector3(-52.5, 0.12, -53.8), 0.0150, "ModernStreetLampNW")
    _add_modern_sprite("StreetFurniture/street_street_furniture_streetlight_single_01.png", Vector3(52.5, 0.12, -53.8), 0.0150, "ModernStreetLampNE")
    _add_modern_sprite("StreetFurniture/street_street_furniture_streetlight_single_01.png", Vector3(-10.5, 0.12, -31.8), 0.0150, "ModernStreetLampCentralWest")
    _add_modern_sprite("StreetFurniture/street_street_furniture_streetlight_single_01.png", Vector3(31.8, 0.12, 10.5), 0.0150, "ModernStreetLampCentralEast")
    _add_modern_sprite("StreetFurniture/street_street_furniture_streetlight_single_01.png", Vector3(-31.8, 0.12, 31.5), 0.0150, "ModernStreetLampParkWest")
    _add_modern_sprite("StreetFurniture/street_street_furniture_streetlight_single_01.png", Vector3(52.5, 0.12, 52.5), 0.0150, "ModernStreetLampParkEast")
    # Traffic signals are built as working 3D systems at every intersection below.

    _create_safe_zone(Vector3(42, 0.06, 42))
    map_built = true

func _make_city_lighting() -> void:
    # Dense procedural streetlights for a readable, lived-in city at night.
    # Each lamp is a real 3D post with a warm emissive head and an OmniLight3D.
    var lamp_positions: Array[Vector3] = []
    var along: Array[float] = [-70.0, -49.0, -28.0, -7.0, 14.0, 35.0, 56.0, 72.0]
    var road_lines: Array[float] = [-63.0, -21.0, 21.0, 63.0]
    for road_z in road_lines:
        for x in along:
            lamp_positions.append(Vector3(x, 0.0, road_z + 9.0))
            lamp_positions.append(Vector3(x, 0.0, road_z - 9.0))
    for road_x in road_lines:
        for z in [-49.0, -7.0, 35.0]:
            lamp_positions.append(Vector3(road_x + 9.0, 0.0, z))
            lamp_positions.append(Vector3(road_x - 9.0, 0.0, z))

    var lamp_index := 0
    for lamp_pos in lamp_positions:
        var lamp_root := Node3D.new()
        lamp_root.name = "CityLamp_%02d" % lamp_index
        lamp_root.position = lamp_pos
        add_child(lamp_root)
        _make_box(lamp_root, Vector3(0.0, 2.25, 0.0), Vector3(0.13, 4.5, 0.13), Color("#263943"))
        _make_box(lamp_root, Vector3(0.42, 4.38, 0.0), Vector3(0.92, 0.11, 0.14), Color("#263943"))
        var bulb := _make_box(lamp_root, Vector3(0.80, 4.31, 0.0), Vector3(0.32, 0.10, 0.24), Color("#ffe3a0"))
        var bulb_mat := StandardMaterial3D.new()
        bulb_mat.albedo_color = Color("#ffe3a0")
        bulb_mat.emission_enabled = true
        bulb_mat.emission = Color("#ffd58a")
        bulb_mat.emission_energy_multiplier = 1.6
        bulb.material_override = bulb_mat
        var light := OmniLight3D.new()
        light.name = "StreetLightGlow"
        light.position = Vector3(0.78, 4.20, 0.0)
        light.light_color = Color("#ffd9a0")
        light.light_energy = 0.0
        light.omni_range = 23.0
        light.omni_attenuation = 0.92
        light.shadow_enabled = false
        lamp_root.add_child(light)
        lamp_root.set_meta("night_light", light)
        lamp_index += 1

func _build_rounded_traffic_loop(min_x: float, max_x: float, min_z: float, max_z: float, corner_radius: float, clockwise: bool) -> Array[Vector3]:
    var route: Array[Vector3] = []
    var r := clampf(corner_radius, 2.6, minf((max_x - min_x) * 0.25, (max_z - min_z) * 0.25))
    var road_y := 0.01
    if clockwise:
        var top_left := Vector3(min_x + r, road_y, min_z)
        var top_right := Vector3(max_x - r, road_y, min_z)
        route.append(top_left)
        _append_route_line(route, top_left, top_right, 1.1)
        _append_route_arc(route, Vector2(max_x - r, min_z + r), r, -PI * 0.5, 0.0, 28)
        var right_top := Vector3(max_x, road_y, min_z + r)
        var right_bottom := Vector3(max_x, road_y, max_z - r)
        _append_route_line(route, right_top, right_bottom, 1.1)
        _append_route_arc(route, Vector2(max_x - r, max_z - r), r, 0.0, PI * 0.5, 28)
        var bottom_right := Vector3(max_x - r, road_y, max_z)
        var bottom_left := Vector3(min_x + r, road_y, max_z)
        _append_route_line(route, bottom_right, bottom_left, 1.1)
        _append_route_arc(route, Vector2(min_x + r, max_z - r), r, PI * 0.5, PI, 28)
        var left_bottom := Vector3(min_x, road_y, max_z - r)
        var left_top := Vector3(min_x, road_y, min_z + r)
        _append_route_line(route, left_bottom, left_top, 1.1)
        _append_route_arc(route, Vector2(min_x + r, min_z + r), r, PI, PI * 1.5, 28)
    else:
        var top_right := Vector3(max_x - r, road_y, min_z)
        var top_left := Vector3(min_x + r, road_y, min_z)
        route.append(top_right)
        _append_route_line(route, top_right, top_left, 1.1)
        _append_route_arc(route, Vector2(min_x + r, min_z + r), r, -PI * 0.5, -PI, 28)
        var left_top := Vector3(min_x, road_y, min_z + r)
        var left_bottom := Vector3(min_x, road_y, max_z - r)
        _append_route_line(route, left_top, left_bottom, 1.1)
        _append_route_arc(route, Vector2(min_x + r, max_z - r), r, PI, PI * 0.5, 28)
        var bottom_left := Vector3(min_x + r, road_y, max_z)
        var bottom_right := Vector3(max_x - r, road_y, max_z)
        _append_route_line(route, bottom_left, bottom_right, 1.1)
        _append_route_arc(route, Vector2(max_x - r, max_z - r), r, PI * 0.5, 0.0, 28)
        var right_bottom := Vector3(max_x, road_y, max_z - r)
        var right_top := Vector3(max_x, road_y, min_z + r)
        _append_route_line(route, right_bottom, right_top, 1.1)
        _append_route_arc(route, Vector2(max_x - r, min_z + r), r, 0.0, -PI * 0.5, 28)
    if route.size() > 1 and route[route.size() - 1].distance_to(route[0]) < 0.15:
        route.pop_back()
    return _resample_closed_route(route, TRAFFIC_ROUTE_SAMPLE_SPACING)

func _append_route_line(route: Array[Vector3], from: Vector3, to: Vector3, spacing: float) -> void:
    var distance := from.distance_to(to)
    var steps := maxi(1, int(ceil(distance / maxf(spacing, 1.0))))
    for i in range(1, steps + 1):
        route.append(from.lerp(to, float(i) / float(steps)))

func _append_route_arc(route: Array[Vector3], center: Vector2, radius: float, start_angle: float, end_angle: float, steps: int) -> void:
    for i in range(1, steps + 1):
        var angle := lerpf(start_angle, end_angle, float(i) / float(steps))
        route.append(Vector3(center.x + cos(angle) * radius, 0.01, center.y + sin(angle) * radius))

func _resample_closed_route(source_route: Array[Vector3], spacing: float) -> Array[Vector3]:
    var result: Array[Vector3] = []
    if source_route.size() < 3:
        return source_route.duplicate()
    var lengths: Array[float] = []
    var total_length := 0.0
    for i in range(source_route.size()):
        var segment_length := source_route[i].distance_to(source_route[(i + 1) % source_route.size()])
        lengths.append(segment_length)
        total_length += segment_length
    if total_length <= 0.001:
        return source_route.duplicate()
    var count := maxi(3, int(ceil(total_length / maxf(spacing, 0.2))))
    var segment_index := 0
    var segment_start := 0.0
    var segment_end := lengths[0]
    for sample_index in range(count):
        var target_distance := total_length * float(sample_index) / float(count)
        while target_distance >= segment_end and segment_index < lengths.size() - 1:
            segment_start = segment_end
            segment_index += 1
            segment_end += lengths[segment_index]
        var segment_length := maxf(lengths[segment_index], 0.0001)
        var t := clampf((target_distance - segment_start) / segment_length, 0.0, 1.0)
        result.append(source_route[segment_index].lerp(source_route[(segment_index + 1) % source_route.size()], t))
    return result

func _reverse_traffic_route(source_route: Array[Vector3]) -> Array[Vector3]:
    var reversed_route: Array[Vector3] = []
    for i in range(source_route.size() - 1, -1, -1):
        reversed_route.append(source_route[i])
    return reversed_route

func _make_traffic() -> void:
    traffic_root = Node3D.new()
    traffic_root.name = "MovingCityTraffic"
    add_child(traffic_root)
    traffic_vehicles.clear()
    traffic_rng.randomize()

    # Road-aligned closed lane loops. Each lane is authored separately so opposing
    # traffic never shares the same centerline or steering path.
    # Opposing lane loops use 3 m centerline spacing (one 3 m lane each).
    # Paired arcs share corner centres so the inner and outer turn radii stay parallel.
    var route_catalog: Dictionary = {
        # Each carriageway centreline is 1.5 m from its road centre.
        # Paired curves share the same corner centres and keep 3 m lane-to-lane spacing.
        # This fits the 6 m asphalt width: one 3 m lane per direction.
        "outer_cw": _build_rounded_traffic_loop(-61.5, 61.5, -61.5, 61.5, 7.5, true),
        "outer_ccw": _build_rounded_traffic_loop(-64.5, 64.5, -64.5, 64.5, 10.5, false),
        "inner_cw": _build_rounded_traffic_loop(-19.5, 19.5, -19.5, 19.5, 7.5, true),
        "inner_ccw": _build_rounded_traffic_loop(-22.5, 22.5, -22.5, 22.5, 10.5, false)
    }
    var routes: Array[Dictionary] = [
        {"route_key":"outer_cw", "ring":0, "speed":3.8, "color":Color("#c92f36"), "kind":"supercar"},
        {"route_key":"outer_ccw", "ring":0, "speed":3.6, "color":Color("#111a20"), "kind":"luxury"},
        {"route_key":"inner_cw", "ring":1, "speed":3.5, "color":Color("#3c70a5"), "kind":"tuner"},
        {"route_key":"inner_ccw", "ring":1, "speed":3.4, "color":Color("#eff0e9"), "kind":"sedan"}
    ]

    # Build one navigation corridor per directed lane loop. Each route owns a
    # navigation-layer bit so agents cannot accidentally switch into an opposing lane.
    var navigation_layers_by_route: Dictionary = {
        "outer_cw": 1,
        "outer_ccw": 2,
        "inner_cw": 4,
        "inner_ccw": 8
    }
    for route_data in routes:
        var navigation_route_key: String = str(route_data["route_key"])
        var navigation_path: Array[Vector3] = route_catalog[navigation_route_key]
        var navigation_layer_mask: int = int(navigation_layers_by_route[navigation_route_key])
        _create_traffic_navigation_region(navigation_route_key, navigation_path, navigation_layer_mask)
        route_data["navigation_layer"] = navigation_layer_mask

    # Spawner: distribute a randomized fleet over the four valid road loops.
    # Cars on a loop are separated along its arc length, with bounded random jitter.
    var target_count: int = maxi(routes.size(), traffic_vehicle_target_count)
    var route_counts: Array[int] = []
    for route_index in range(routes.size()):
        route_counts.append(0)
    for car_index in range(target_count):
        route_counts[car_index % routes.size()] += 1

    var serial_number: int = 1
    for route_index in range(routes.size()):
        var route_data: Dictionary = routes[route_index]
        var route_key: String = str(route_data["route_key"])
        var path: Array[Vector3] = route_catalog[route_key]
        if path.size() < 16:
            push_warning("Traffic route is too short; skipping route %s." % route_key)
            continue

        var lane_car_count: int = route_counts[route_index]
        var spacing_points: int = maxi(1, int(path.size() / lane_car_count))
        var random_offset: int = traffic_rng.randi_range(0, path.size() - 1)
        var jitter_limit: int = mini(10, maxi(0, int(spacing_points * 0.025)))
        var used_start_indices: Array[int] = []

        for lane_car_index in range(lane_car_count):
            var jitter: int = traffic_rng.randi_range(-jitter_limit, jitter_limit)
            var proposed_index: int = posmod(random_offset + lane_car_index * spacing_points + jitter, path.size())
            var start_index: int = _find_safe_traffic_spawn_index(path, proposed_index, used_start_indices)
            used_start_indices.append(start_index)
            _spawn_traffic_vehicle(route_data, path, start_index, serial_number)
            serial_number += 1


func _find_safe_traffic_spawn_index(path: Array[Vector3], proposed_index: int, used_indices: Array[int]) -> int:
    # Do not initialize cars on top of an intersection or on its stop-line
    # approach. The first few seconds therefore cannot begin as a traffic jam.
    for offset in range(path.size()):
        var candidate: int = posmod(proposed_index + offset, path.size())
        var point: Vector3 = path[candidate]
        if _distance_to_nearest_junction(point) < 15.0:
            continue
        var separated := true
        for used_index in used_indices:
            var gap: int = mini(posmod(candidate - used_index, path.size()), posmod(used_index - candidate, path.size()))
            if float(gap) * TRAFFIC_ROUTE_SAMPLE_SPACING < 24.0:
                separated = false
                break
        if separated:
            return candidate
    return proposed_index


func _distance_to_nearest_junction(point: Vector3) -> float:
    var nearest_distance: float = INF
    var junction_coordinates: Array[float] = [-63.0, -21.0, 21.0, 63.0]
    for x in junction_coordinates:
        for z in junction_coordinates:
            nearest_distance = minf(nearest_distance, Vector2(point.x - x, point.z - z).length())
    return nearest_distance


func _spawn_traffic_vehicle(route_data: Dictionary, path: Array[Vector3], start_index: int, serial_number: int) -> void:
    var route_key: String = str(route_data["route_key"])
    var vehicle_speed: float = float(route_data["speed"]) * traffic_rng.randf_range(0.96, 1.04)
    var car := _create_traffic_vehicle(route_data["color"], str(route_data["kind"]), "Car%02d" % serial_number) as CharacterBody3D
    if car == null:
        return

    car.position = path[start_index]
    var initial_direction: Vector3 = _traffic_tangent_at(
        path, float(start_index), TRAFFIC_BODY_TANGENT_SAMPLE_DISTANCE
    )
    if initial_direction.length_squared() > 0.0001:
        car.rotation = Vector3(0.0, _traffic_yaw_from_tangent(initial_direction), 0.0)
    traffic_root.add_child(car)

    # Configure only after entering the tree so the agent can use the active World3D map.
    car.call(
        "configure_traffic_route",
        path,
        start_index,
        route_key,
        vehicle_speed,
        int(route_data.get("navigation_layer", 1))
    )

    traffic_vehicles.append({
        "node": car,
        "path": path,
        "waypoint_index": start_index,
        "path_progress": float(start_index),
        "ring_id": int(route_data["ring"]),
        "route_key": route_key,
        "speed": vehicle_speed,
        "current_speed": 0.0,
        "obstacle_ray": car.get_node_or_null("FrontObstacleRay") as RayCast3D
    })


func _create_traffic_navigation_region(route_key: String, path: Array[Vector3], layer_mask: int) -> void:
    if path.size() < 3:
        return

    # Construct a walkable ribbon around each lane centreline using shared vertices.
    # Shared cross-sections keep neighbouring polygons connected around smooth curves.
    var navigation_vertices := PackedVector3Array()
    var lane_half_width: float = 1.18
    for point_index in range(path.size()):
        var before: Vector3 = path[posmod(point_index - 1, path.size())]
        var after: Vector3 = path[(point_index + 1) % path.size()]
        var tangent: Vector3 = after - before
        tangent.y = 0.0
        if tangent.length_squared() < 0.0001:
            tangent = Vector3.FORWARD
        tangent = tangent.normalized()
        var lateral: Vector3 = Vector3(tangent.z, 0.0, -tangent.x).normalized()
        navigation_vertices.append(path[point_index] - lateral * lane_half_width)
        navigation_vertices.append(path[point_index] + lateral * lane_half_width)

    var navigation_mesh := NavigationMesh.new()
    navigation_mesh.agent_radius = 0.0
    navigation_mesh.agent_height = 1.5
    navigation_mesh.vertices = navigation_vertices
    for segment_index in range(path.size()):
        var first_left: int = segment_index * 2
        var next_left: int = ((segment_index + 1) % path.size()) * 2
        # Vertex winding faces upward (+Y); each lane loop remains a closed ribbon.
        navigation_mesh.add_polygon(PackedInt32Array([
            first_left,
            next_left,
            next_left + 1,
            first_left + 1
        ]))

    var region := NavigationRegion3D.new()
    region.name = "TrafficLaneNavigation_%s" % route_key
    region.navigation_layers = layer_mask
    region.navigation_mesh = navigation_mesh
    region.use_edge_connections = false
    traffic_root.add_child(region)

func _make_ambient_citizens() -> void:
    var ambient_root := Node3D.new()
    ambient_root.name = "AmbientPedestrians"
    add_child(ambient_root)
    # Keep pedestrians on the sidewalk ribbons, not inside the road or building plots.
    var spots: Array[Vector3] = [
        Vector3(-42.0, 0.0, -52.5), Vector3(-36.0, 0.0, -10.5),
        Vector3(0.0, 0.0, 31.5), Vector3(42.0, 0.0, 52.5),
        Vector3(-52.5, 0.0, 42.0), Vector3(-31.5, 0.0, 42.0),
        Vector3(10.5, 0.0, -42.0), Vector3(52.5, 0.0, -42.0),
        Vector3(52.5, 0.0, 31.5), Vector3(-10.5, 0.0, 42.0),
        Vector3(31.5, 0.0, -52.5), Vector3(-52.5, 0.0, -36.0)
    ]
    var outfit_colors: Array[Color] = [
        Color("#bd7957"), Color("#4c7f9c"), Color("#a9b7a1"), Color("#d5b35d"),
        Color("#6c6b9e"), Color("#e0e2de"), Color("#4d826e"), Color("#b86a6b"),
        Color("#6b9aa7"), Color("#b79b84"), Color("#849a62"), Color("#ba7e9b")
    ]
    var route_x: Array[Vector3] = [Vector3(2.2, 0, 0), Vector3(-2.2, 0, 0), Vector3.ZERO]
    var route_z: Array[Vector3] = [Vector3(0, 0, 2.2), Vector3(0, 0, -2.2), Vector3.ZERO]
    var npc_script := preload("res://scripts/actors/AmbientCitizen.gd")
    var ambient_character_ids: Array[String] = ["civilian", "elder", "child", "civilian", "wheelchair", "civilian", "injured", "elder", "civilian", "child", "civilian", "wheelchair"]
    for i in range(spots.size()):
        var person := CharacterBody3D.new()
        person.set_script(npc_script)
        person.name = "AmbientCitizen%02d" % (i + 1)
        person.position = spots[i]
        var route: Array[Vector3] = route_x if i % 2 == 0 else route_z
        person.call("configure_ambient", outfit_colors[i], Color("#c99573") if i % 3 != 1 else Color("#8e604b"), route, 1.25 + float(i % 4) * 0.16, 0.8 + float(i % 3) * 0.25, 2.0 + float(i % 4) * 0.30, ambient_character_ids[i])
        ambient_root.add_child(person)


func _make_traffic_signals() -> void:
    traffic_signal_visuals.clear()
    var junctions: Array[float] = [-63.0, -21.0, 21.0, 63.0]
    for x in junctions:
        for z in junctions:
            # Four signals sit on the curb; two govern east-west traffic and two north-south traffic.
            # Each head faces the approaching traffic lane (its bulbs face local -Z).
            _create_traffic_signal(Vector3(x - 10.2, 0.0, z - 10.2), "z", 0.0)
            _create_traffic_signal(Vector3(x + 10.2, 0.0, z + 10.2), "z", PI)
            _create_traffic_signal(Vector3(x - 10.2, 0.0, z + 10.2), "x", PI * 0.5)
            _create_traffic_signal(Vector3(x + 10.2, 0.0, z - 10.2), "x", -PI * 0.5)
    _update_traffic_signal_visuals()

func _disable_shadows_recursive(node: Node) -> void:
    if node is GeometryInstance3D:
        (node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for child in node.get_children():
        _disable_shadows_recursive(child)

func _create_traffic_signal(pos: Vector3, axis_name: String, yaw: float) -> void:
    var prop := Node3D.new()
    prop.name = "TrafficSignal_%s_%02d" % [axis_name, traffic_signal_visuals.size() + 1]
    prop.position = pos
    prop.rotation.y = yaw
    add_child(prop)
    # Intentionally omit the old mounting shoe: it intersected the road/sidewalk mesh and
    # produced a visible flicker. The pole begins slightly above the surface; no replacement
    # base prop is added until the ground contact is confirmed stable in-editor.
    var signal_pole := _make_box(prop, Vector3(0, 1.52, 0), Vector3(0.12, 3.0, 0.12), Color("#333f43"))
    signal_pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var signal_head := _make_box(prop, Vector3(0, 3.0, -0.12), Vector3(0.42, 0.90, 0.28), Color("#1c282d"))
    signal_head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var red_mat := _signal_material(Color("#ed4545"), false)
    var yellow_mat := _signal_material(Color("#ffc94e"), false)
    var green_mat := _signal_material(Color("#4bdd8e"), false)
    for entry in [
        {"node_y":3.28, "mat":red_mat},
        {"node_y":3.00, "mat":yellow_mat},
        {"node_y":2.72, "mat":green_mat}
    ]:
        var bulb := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.09
        sphere.height = 0.18
        bulb.mesh = sphere
        bulb.position = Vector3(0, float(entry["node_y"]), -0.29)
        bulb.material_override = entry["mat"]
        prop.add_child(bulb)
    traffic_signal_visuals.append({"axis":axis_name, "red":red_mat, "yellow":yellow_mat, "green":green_mat})
    _add_prop_collider(prop, Vector3(0, 1.50, 0), Vector3(0.12, 2.96, 0.12))
    _disable_shadows_recursive(prop)

func _signal_material(color: Color, active: bool) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color if active else color.darkened(0.82)
    mat.roughness = 0.35
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = 0.95 if active else 0.025
    return mat

func _update_traffic_signal_visuals() -> void:
    for signal_data in traffic_signal_visuals:
        var axis_name := str(signal_data["axis"])
        var green_active := (axis_name == "x" and traffic_phase == TRAFFIC_PHASE_X_GREEN) or (axis_name == "z" and traffic_phase == TRAFFIC_PHASE_Z_GREEN)
        var yellow_active := (axis_name == "x" and traffic_phase == TRAFFIC_PHASE_X_YELLOW) or (axis_name == "z" and traffic_phase == TRAFFIC_PHASE_Z_YELLOW)
        var red_active := not green_active and not yellow_active
        _set_signal_lamp(signal_data["red"] as StandardMaterial3D, red_active, Color("#ed4545"))
        _set_signal_lamp(signal_data["yellow"] as StandardMaterial3D, yellow_active, Color("#ffc94e"))
        _set_signal_lamp(signal_data["green"] as StandardMaterial3D, green_active, Color("#4bdd8e"))

func _set_signal_lamp(mat: StandardMaterial3D, active: bool, color: Color) -> void:
    mat.albedo_color = color if active else color.darkened(0.82)
    mat.emission = color
    mat.emission_energy_multiplier = 1.0 if active else 0.025

func _next_intersection_coordinate(coordinate: float, direction: float) -> float:
    var points: Array[float] = [-63.0, -21.0, 21.0, 63.0]
    var candidate := 999.0 if direction > 0.0 else -999.0
    for point in points:
        if direction > 0.0 and point > coordinate + 0.05:
            candidate = minf(candidate, point)
        elif direction < 0.0 and point < coordinate - 0.05:
            candidate = maxf(candidate, point)
    return candidate

func _nearest_intersection_coordinate(coordinate: float) -> float:
    var points: Array[float] = [-63.0, -21.0, 21.0, 63.0]
    var nearest: float = points[0]
    var nearest_distance: float = absf(coordinate - nearest)
    for point in points:
        var candidate_distance: float = absf(coordinate - point)
        if candidate_distance < nearest_distance:
            nearest = point
            nearest_distance = candidate_distance
    return nearest


func _traffic_path_position(path: Array[Vector3], progress: float) -> Vector3:
    if path.is_empty():
        return Vector3.ZERO
    var wrapped_progress: float = fposmod(progress, float(path.size()))
    var index: int = floori(wrapped_progress)
    var fraction: float = wrapped_progress - float(index)
    return path[index].lerp(path[(index + 1) % path.size()], fraction)


func _traffic_tangent_at(path: Array[Vector3], progress: float, sample_distance: float = TRAFFIC_BODY_TANGENT_SAMPLE_DISTANCE) -> Vector3:
    if path.size() < 3:
        return Vector3.ZERO
    # Route samples are evenly resampled, so distances can be mapped back to
    # continuous path-progress units without snapping to individual waypoints.
    var sample_steps: float = maxf(sample_distance / TRAFFIC_ROUTE_SAMPLE_SPACING, 1.0)
    var point_before: Vector3 = _traffic_path_position(path, progress - sample_steps)
    var point_after: Vector3 = _traffic_path_position(path, progress + sample_steps)
    var tangent: Vector3 = point_after - point_before
    tangent.y = 0.0
    if tangent.length_squared() < 0.0001:
        return Vector3.ZERO
    return tangent.normalized()


func _traffic_yaw_from_tangent(tangent: Vector3) -> float:
    return atan2(-tangent.x, -tangent.z)


func _traffic_data_tangent(traffic_data: Dictionary) -> Vector3:
    var path: Array[Vector3] = traffic_data.get("path", [])
    if path.size() < 3:
        var fallback_vehicle := traffic_data.get("node") as Node3D
        if is_instance_valid(fallback_vehicle):
            var fallback := -fallback_vehicle.global_transform.basis.z
            fallback.y = 0.0
            return fallback.normalized()
        return Vector3.ZERO
    return _traffic_tangent_at(
        path,
        float(traffic_data.get("path_progress", 0.0)),
        TRAFFIC_BODY_TANGENT_SAMPLE_DISTANCE
    )


func _intersection_has_conflicting_vehicle(junction_center: Vector3, axis_name: String, current_vehicle: Node3D) -> bool:
    # Compare route tangents, not body yaw. Cars on parallel offset turning
    # lanes must not block one another simply because their bodies are diagonal.
    var current_direction := -current_vehicle.global_transform.basis.z
    current_direction.y = 0.0
    if current_direction.length_squared() < 0.0001:
        current_direction = Vector3.RIGHT if axis_name == "x" else Vector3.BACK
    current_direction = current_direction.normalized()

    for other_data in traffic_vehicles:
        var other_vehicle := other_data.get("node") as Node3D
        if not is_instance_valid(other_vehicle) or other_vehicle == current_vehicle:
            continue
        var offset: Vector3 = other_vehicle.position - junction_center
        if absf(offset.x) > 6.5 or absf(offset.z) > 6.5:
            continue

        var other_direction := _traffic_data_tangent(other_data)
        if other_direction.length_squared() < 0.0001:
            continue
        # Parallel/co-flow and opposing parallel lanes are handled by lane
        # following; only sufficiently crosswise trajectories occupy conflict.
        var alignment: float = absf(current_direction.dot(other_direction))
        if alignment < 0.62:
            return true
    return false


func _get_ray_obstacle_speed_limit(traffic_data: Dictionary) -> float:
    var ray := traffic_data.get("obstacle_ray") as RayCast3D
    if not is_instance_valid(ray) or not ray.is_enabled():
        return INF
    ray.force_raycast_update()
    if not ray.is_colliding():
        return INF

    var hit_object: Object = ray.get_collider()
    # Only a registered traffic vehicle should affect traffic following. The ray's
    # mask is limited to layer 2; this additional check prevents unknown bodies from
    # becoming permanent invisible brakes.
    if not (hit_object is CharacterBody3D):
        return INF

    var lead_data: Dictionary = {}
    for other_data in traffic_vehicles:
        if other_data.get("node") == hit_object:
            lead_data = other_data
            break
    if lead_data.is_empty():
        return INF

    # A car passing across the front ray or using a parallel lane must not stop
    # this vehicle. The route-progress queue handles cars on the same lane.
    if str(lead_data.get("route_key", "")) != str(traffic_data.get("route_key", "")):
        return INF

    var current_vehicle := traffic_data.get("node") as Node3D
    if not is_instance_valid(current_vehicle):
        return INF
    var current_forward := -current_vehicle.global_transform.basis.z
    current_forward.y = 0.0
    current_forward = current_forward.normalized()
    var lead_forward := _traffic_data_tangent(lead_data)
    if lead_forward.length_squared() < 0.0001 or current_forward.dot(lead_forward) < 0.65:
        return INF

    var hit_distance: float = ray.global_position.distance_to(ray.get_collision_point())
    var lead_vehicle := lead_data.get("node") as CharacterBody3D
    if not is_instance_valid(lead_vehicle):
        return INF
    var lead_speed: float = float(lead_vehicle.get("current_speed"))
    # This distance is bumper-to-bumper, not centre-to-centre. Keep it smaller
    # than the arc-gap buffer used by the queue controller.
    var safe_bumper_gap: float = 2.8
    return maxf(0.0, lead_speed + (hit_distance - safe_bumper_gap) * 0.85)


func _move_traffic(delta: float) -> void:
    if delta <= 0.0:
        return

    traffic_phase_elapsed += delta
    # X green -> X yellow -> all-red clearance -> Z green -> Z yellow -> all-red clearance.
    while traffic_phase_elapsed >= TRAFFIC_PHASE_DURATIONS[traffic_phase]:
        traffic_phase_elapsed -= TRAFFIC_PHASE_DURATIONS[traffic_phase]
        traffic_phase = (traffic_phase + 1) % TRAFFIC_PHASE_DURATIONS.size()
        _update_traffic_signal_visuals()

    for traffic_data in traffic_vehicles:
        var vehicle := traffic_data.get("node") as CharacterBody3D
        if not is_instance_valid(vehicle):
            continue
        var path: Array[Vector3] = traffic_data.get("path", [])
        if path.size() < 3:
            continue

        var path_progress: float = fposmod(
            float(traffic_data.get("path_progress", 0.0)),
            float(path.size())
        )
        var current_point: Vector3 = _traffic_path_position(path, path_progress)
        var lane_direction: Vector3 = _traffic_tangent_at(path, path_progress, 0.70)
        if lane_direction.length_squared() < 0.0001:
            lane_direction = _traffic_data_tangent(traffic_data)
        if lane_direction.length_squared() < 0.0001:
            continue
        lane_direction = lane_direction.normalized()

        # Use route curvature for speed planning only. Steering and body yaw are
        # computed together by TrafficVehicle.gd, preventing the old split-control bug.
        var curvature_sample_distance: float = 2.4
        var curvature_start: Vector3 = _traffic_tangent_at(
            path,
            path_progress + 0.35 / TRAFFIC_ROUTE_SAMPLE_SPACING,
            0.55
        )
        var curvature_end: Vector3 = _traffic_tangent_at(
            path,
            path_progress + curvature_sample_distance / TRAFFIC_ROUTE_SAMPLE_SPACING,
            0.55
        )
        var route_curvature: float = 0.0
        if curvature_start.length_squared() > 0.0001 and curvature_end.length_squared() > 0.0001:
            var heading_start: float = _traffic_yaw_from_tangent(curvature_start)
            var heading_end: float = _traffic_yaw_from_tangent(curvature_end)
            route_curvature = wrapf(heading_end - heading_start, -PI, PI) / maxf(
                curvature_sample_distance - 0.35, 0.1
            )

        var current_speed: float = float(vehicle.get("current_speed"))
        var cruise_speed: float = float(traffic_data.get("speed", 3.4))
        var curve_factor: float = clampf(absf(route_curvature) * 7.5, 0.0, 1.0)
        var target_speed: float = cruise_speed * lerpf(1.0, 0.72, curve_factor)

        # Lane-local queue: only a vehicle ahead on the same directed loop controls
        # this speed limit. Crossing or parallel traffic never creates a false queue.
        for other_data in traffic_vehicles:
            if other_data == traffic_data:
                continue
            if str(other_data.get("route_key", "")) != str(traffic_data.get("route_key", "")):
                continue
            var other_vehicle := other_data.get("node") as CharacterBody3D
            if not is_instance_valid(other_vehicle):
                continue
            var other_progress: float = float(other_data.get("path_progress", 0.0))
            var progress_gap: float = fposmod(other_progress - path_progress, float(path.size()))
            var arc_gap: float = progress_gap * TRAFFIC_ROUTE_SAMPLE_SPACING
            if arc_gap > 0.05 and arc_gap < 22.0:
                var lead_speed: float = float(other_vehicle.get("current_speed"))
                var safe_gap: float = maxf(traffic_stop_buffer, 5.5)
                var safe_follow_speed: float = maxf(
                    0.0,
                    lead_speed + (arc_gap - safe_gap) * 0.8
                )
                target_speed = minf(target_speed, safe_follow_speed)

        target_speed = minf(target_speed, _get_ray_obstacle_speed_limit(traffic_data))

        # Stop lines are placed before each turning arc. Signal phase stays global,
        # while each vehicle computes its own braking speed from the local stop distance.
        var axis_name: String = "x" if absf(lane_direction.x) >= absf(lane_direction.z) else "z"
        var axis_component: float = lane_direction.x if axis_name == "x" else lane_direction.z
        var straight_segment: bool = absf(axis_component) > 0.995
        # Crosswalk decals are centred about 9 m from the junction centre.
        # Place a virtual stop line 12 m out so the vehicle stops before the zebra stripes,
        # not on top of them. Braking includes a speed-dependent anticipation buffer.
        var stop_line_offset: float = 12.0
        var green: bool = false
        var yellow: bool = false
        var yellow_can_clear: bool = false
        var distance_to_stop_line: float = INF
        var distance_to_junction: float = INF
        var red_stop_active: bool = false

        if straight_segment:
            var coordinate: float = current_point.x if axis_name == "x" else current_point.z
            var next_junction: float = _next_intersection_coordinate(coordinate, signf(axis_component))
            distance_to_junction = (next_junction - coordinate) * signf(axis_component)
            if absf(next_junction) < 900.0 and distance_to_junction >= 0.0 and distance_to_junction <= 36.0:
                distance_to_stop_line = distance_to_junction - stop_line_offset
                green = (axis_name == "x" and traffic_phase == TRAFFIC_PHASE_X_GREEN) or (axis_name == "z" and traffic_phase == TRAFFIC_PHASE_Z_GREEN)
                yellow = (axis_name == "x" and traffic_phase == TRAFFIC_PHASE_X_YELLOW) or (axis_name == "z" and traffic_phase == TRAFFIC_PHASE_Z_YELLOW)
                yellow_can_clear = yellow and distance_to_stop_line <= maxf(4.0, cruise_speed * 1.25) and distance_to_stop_line > 0.15
                var cross_road_coordinate: float = current_point.z if axis_name == "x" else current_point.x
                var crossing_coordinate: float = _nearest_intersection_coordinate(cross_road_coordinate)
                var junction_center: Vector3 = Vector3(next_junction, 0.0, crossing_coordinate) if axis_name == "x" else Vector3(crossing_coordinate, 0.0, next_junction)
                if _intersection_has_conflicting_vehicle(junction_center, axis_name, vehicle):
                    green = false
                    yellow_can_clear = false
                # While approaching, red/all-red/conflict phases remain stop-active right
                # up to the junction. The hold margin absorbs route-sample quantization and
                # the one physics tick of acceleration/braking integration.
                red_stop_active = not green and not yellow_can_clear and distance_to_junction >= 0.0
                if red_stop_active:
                    # Vehicle computes its own conservative braking envelope using its current speed.
                    target_speed = float(vehicle.call("limit_speed_for_stop_line", target_speed, distance_to_stop_line, 1.25))

        # CharacterBody3D now owns physical displacement; the agent provides a
        # route-corridor lookahead and the controller integrates steering + yaw + motion.
        var travelled_distance: float = float(vehicle.call("drive_step", delta, target_speed))
        var new_progress: float = fposmod(
            path_progress + travelled_distance / TRAFFIC_ROUTE_SAMPLE_SPACING,
            float(path.size())
        )
        vehicle.call("set_route_progress", new_progress)
        traffic_data["path_progress"] = new_progress
        traffic_data["waypoint_index"] = floori(new_progress) % path.size()
        traffic_data["current_speed"] = float(vehicle.get("current_speed"))

func _create_traffic_vehicle(body_color: Color, kind: String, node_name: String) -> CharacterBody3D:
    var car := CharacterBody3D.new()
    car.set_script(preload("res://scripts/world/TrafficVehicle.gd"))
    car.name = node_name
    car.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
    car.collision_layer = 2
    car.collision_mask = 2

    var navigation_agent := NavigationAgent3D.new()
    navigation_agent.name = "NavigationAgent3D"
    navigation_agent.path_desired_distance = 1.2
    navigation_agent.target_desired_distance = 1.6
    navigation_agent.avoidance_enabled = false
    car.add_child(navigation_agent)
    var is_van := kind in ["van", "ambulance", "suv"]
    var width := 1.92 if is_van else (1.98 if kind == "luxury" else 1.84)
    var length := 5.0 if kind in ["van", "ambulance", "suv", "luxury"] else 4.55
    car.set_meta("traffic_wheelbase", length * 0.62)
    var body_height := 0.54 if is_van else 0.48
    var hit_shape := CollisionShape3D.new()
    hit_shape.name = "VehicleCollision"
    var hit_box := BoxShape3D.new()
    hit_box.size = Vector3(width * 0.92, 1.18, length * 0.86)
    hit_shape.shape = hit_box
    hit_shape.position = Vector3(0.0, 0.61, 0.0)
    car.add_child(hit_shape)

    # Modern semi-3D vehicle bodies are imported from modular GLBs. Steering and wheel
    # spin remain separate runtime pivots, so swapping visuals cannot break traffic AI.
    var vehicle_asset_path := "res://assets/KotaSiagaModularRoads/vehicles/VehicleModern_Sedan.glb"
    if kind == "luxury":
        vehicle_asset_path = "res://assets/KotaSiagaModularRoads/vehicles/VehicleModern_Luxury.glb"
    elif kind in ["supercar", "tuner", "hypercar"]:
        vehicle_asset_path = "res://assets/KotaSiagaModularRoads/vehicles/VehicleModern_Sports.glb"
    elif kind in ["suv", "van"]:
        vehicle_asset_path = "res://assets/KotaSiagaModularRoads/vehicles/VehicleModern_SUV.glb"
    elif kind == "ambulance":
        vehicle_asset_path = "res://assets/KotaSiagaModularRoads/vehicles/VehicleModern_Ambulance.glb"

    var vehicle_scene := load(vehicle_asset_path) as PackedScene
    var vehicle_model: Node3D
    if vehicle_scene != null:
        vehicle_model = vehicle_scene.instantiate() as Node3D
    if vehicle_model != null:
        vehicle_model.name = "VehicleModernBody"
        car.add_child(vehicle_model)
        for baked_wheel_part in vehicle_model.find_children("*", "MeshInstance3D", true, false):
            var baked_name := baked_wheel_part.name
            if baked_name.begins_with("StaticWheel") or baked_name.begins_with("WheelSpoke_"):
                (baked_wheel_part as MeshInstance3D).visible = false
        for mesh_name in ["BodyPaint", "Hood", "Trunk", "CabinPaint"]:
            var paint_mesh := vehicle_model.find_child(mesh_name, true, false) as MeshInstance3D
            if paint_mesh != null:
                var paint_color := body_color
                if mesh_name == "Hood":
                    paint_color = body_color.lightened(0.055)
                elif mesh_name == "Trunk":
                    paint_color = body_color.darkened(0.05)
                _apply_vehicle_paint(paint_mesh, paint_color)
        for glass_name in ["WindowGlass", "FrontWindshield", "RearWindow"]:
            var glass_mesh := vehicle_model.find_child(glass_name, true, false) as MeshInstance3D
            if glass_mesh != null:
                _apply_vehicle_glass(glass_mesh, Color("#31505d"), 0.18)
        for lamp_entry in [
            {"name":"Headlamp_-1", "color":Color("#ffe6b0"), "energy":0.34},
            {"name":"Headlamp_1", "color":Color("#ffe6b0"), "energy":0.34},
            {"name":"TailLamp_-1", "color":Color("#d9383c"), "energy":0.22},
            {"name":"TailLamp_1", "color":Color("#d9383c"), "energy":0.22}
        ]:
            var lamp_mesh := vehicle_model.find_child(str(lamp_entry["name"]), true, false) as MeshInstance3D
            if lamp_mesh != null:
                _apply_vehicle_emission(lamp_mesh, lamp_entry["color"], float(lamp_entry["energy"]))
    else:
        # Import-safe fallback during a first editor scan.
        var fallback_shell := _make_box(car, Vector3(0, 0.46, 0), Vector3(width, body_height, length), body_color)
        _apply_vehicle_paint(fallback_shell, body_color)

    # Axle centres are placed so 0.26m radius tyres meet the road surface at y=-0.03.
    for side in [-1.0, 1.0]:
        for z_sign in [-1.0, 1.0]:
            var wheel_mount := Node3D.new()
            wheel_mount.name = "WheelMount_%s_%s" % [str(int(side)), "Front" if z_sign < 0.0 else "Rear"]
            wheel_mount.position = Vector3(side * width * 0.505, 0.245, z_sign * length * 0.31)
            if z_sign < 0.0:
                wheel_mount.add_to_group("traffic_front_steering")
            car.add_child(wheel_mount)

            var spin_pivot := Node3D.new()
            spin_pivot.name = "WheelSpinPivot"
            spin_pivot.add_to_group("traffic_wheel_spin")
            wheel_mount.add_child(spin_pivot)

            var tire := MeshInstance3D.new()
            tire.name = "Tire"
            var tire_mesh := CylinderMesh.new()
            tire_mesh.top_radius = 0.285
            tire_mesh.bottom_radius = 0.285
            tire_mesh.height = 0.18
            tire_mesh.radial_segments = 24
            tire.mesh = tire_mesh
            tire.rotation.z = PI * 0.5
            var tire_material := StandardMaterial3D.new()
            tire_material.albedo_color = Color("#242b2e")
            tire_material.metallic = 0.0
            tire_material.roughness = 0.9
            tire.material_override = tire_material
            spin_pivot.add_child(tire)

            var hub := MeshInstance3D.new()
            hub.name = "WheelHub"
            var hub_mesh := CylinderMesh.new()
            hub_mesh.top_radius = 0.105
            hub_mesh.bottom_radius = 0.105
            hub_mesh.height = 0.19
            hub_mesh.radial_segments = 16
            hub.mesh = hub_mesh
            hub.rotation.z = PI * 0.5
            hub.add_to_group("traffic_wheel_hub")
            var hub_material := StandardMaterial3D.new()
            hub_material.albedo_color = Color("#b2bdc0")
            hub_material.metallic = 0.72
            hub_material.roughness = 0.30
            hub.material_override = hub_material
            spin_pivot.add_child(hub)

            # Five clean, metallic spokes are parented to the spin pivot so they rotate with the tire.
            for spoke_index in range(5):
                var spoke := MeshInstance3D.new()
                spoke.name = "RimSpoke_%02d" % spoke_index
                var spoke_mesh := BoxMesh.new()
                spoke_mesh.size = Vector3(0.028, 0.16, 0.045)
                spoke.mesh = spoke_mesh
                spoke.position = Vector3(side * 0.106, 0.0, 0.0)
                spoke.rotation.x = TAU * float(spoke_index) / 5.0
                var spoke_material := StandardMaterial3D.new()
                spoke_material.albedo_color = Color("#c8d1d3")
                spoke_material.metallic = 0.82
                spoke_material.roughness = 0.24
                spoke.material_override = spoke_material
                spin_pivot.add_child(spoke)

    # Keep the cabin clean; no blocky procedural driver mesh is placed over the imported glass.

    # Vehicle-only front sensor. The route has authored lane geometry, so this ray
    # is only a last same-lane spacing aid and must not hit static roadside props.
    var front_ray := RayCast3D.new()
    front_ray.name = "FrontObstacleRay"
    front_ray.position = Vector3(0.0, 0.64, -length * 0.44)
    front_ray.target_position = Vector3(0.0, 0.0, -traffic_front_detection_length)
    front_ray.collision_mask = 2
    front_ray.collide_with_bodies = true
    front_ray.collide_with_areas = false
    front_ray.exclude_parent = true
    front_ray.enabled = true
    car.add_child(front_ray)
    return car

func _apply_vehicle_paint(mesh_node: MeshInstance3D, color: Color) -> void:
    if not is_instance_valid(mesh_node):
        return
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.48
    material.roughness = 0.27
    material.clearcoat_enabled = true
    material.clearcoat = 0.72
    material.clearcoat_roughness = 0.16
    material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    mesh_node.material_override = material


func _apply_vehicle_glass(mesh_node: MeshInstance3D, color: Color, surface_roughness: float) -> void:
    if not is_instance_valid(mesh_node):
        return
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.12
    material.roughness = clampf(surface_roughness, 0.08, 0.4)
    material.clearcoat_enabled = true
    material.clearcoat = 0.45
    material.clearcoat_roughness = 0.12
    material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    mesh_node.material_override = material


func _apply_vehicle_emission(mesh_node: MeshInstance3D, emission_color: Color, energy: float) -> void:
    if not is_instance_valid(mesh_node):
        return
    var material := StandardMaterial3D.new()
    material.albedo_color = emission_color
    material.roughness = 0.24
    material.emission_enabled = true
    material.emission = emission_color
    material.emission_energy_multiplier = energy
    mesh_node.material_override = material


func _add_modern_sprite(_relative_path: String, ground_position: Vector3, _pixel_size: float, node_name: String) -> void:
    # Former ModernCity 2D dressing is replaced by lightweight procedural 3D props.
    var prop := Node3D.new()
    prop.name = node_name.replace("Modern", "City")
    prop.position = ground_position
    add_child(prop)
    var lower := node_name.to_lower()
    if lower.contains("streetlamp") or lower.contains("streetlight"):
        _make_box(prop, Vector3(0, 2.25, 0), Vector3(0.12, 4.5, 0.12), Color("#34444b"))
        _make_box(prop, Vector3(0.48, 4.25, 0), Vector3(1.0, 0.10, 0.10), Color("#34444b"))
        _make_box(prop, Vector3(0.83, 4.14, 0), Vector3(0.34, 0.12, 0.28), Color("#e7e0c8"))
        var light := OmniLight3D.new()
        light.position = Vector3(0.83, 4.0, 0)
        light.light_color = Color("#ffdca0")
        light.light_energy = 0.0
        light.omni_range = 23.0
        light.omni_attenuation = 0.92
        light.shadow_enabled = false
        prop.add_child(light)
        prop.set_meta("night_light", light)
        _add_prop_collider(prop, Vector3(0, 2.2, 0), Vector3(0.20, 4.4, 0.20))
    elif lower.contains("trafficlight"):
        _make_box(prop, Vector3(0, 1.65, 0), Vector3(0.12, 3.3, 0.12), Color("#3a454b"))
        _make_box(prop, Vector3(0, 3.18, 0), Vector3(0.42, 0.92, 0.28), Color("#222b30"))
        for y in [3.45, 3.18, 2.91]:
            var lamp := MeshInstance3D.new()
            var sphere := SphereMesh.new()
            sphere.radius = 0.085
            sphere.height = 0.17
            lamp.mesh = sphere
            lamp.position = Vector3(0, y, -0.15)
            var mat := StandardMaterial3D.new()
            mat.albedo_color = Color("#d84942") if y > 3.3 else (Color("#e5bd51") if y > 3.0 else Color("#4fc28b"))
            mat.emission_enabled = true
            mat.emission = mat.albedo_color
            mat.emission_energy_multiplier = 0.35
            lamp.material_override = mat
            prop.add_child(lamp)
        _add_prop_collider(prop, Vector3(0, 1.6, 0), Vector3(0.18, 3.2, 0.18))
    elif lower.contains("tree") or lower.contains("greenery") or lower.contains("shrub"):
        prop.add_to_group("wind_affected")
        prop.set_meta("wind_phase", ground_position.x * 0.17 + ground_position.z * 0.13)
        _make_box(prop, Vector3(0, 1.0, 0), Vector3(0.28, 2.0, 0.28), Color("#665044"))
        for item in [Vector3(0, 2.2, 0), Vector3(-0.42, 1.9, 0.1), Vector3(0.38, 2.0, -0.1)]:
            var crown := MeshInstance3D.new()
            var mesh := SphereMesh.new()
            mesh.radius = 0.8 if item.y > 2.0 else 0.62
            mesh.height = mesh.radius * 2.0
            crown.mesh = mesh
            crown.position = item
            var material := StandardMaterial3D.new()
            material.albedo_color = Color("#3f785b") if item.y > 2.0 else Color("#568b65")
            material.roughness = 0.88
            crown.material_override = material
            prop.add_child(crown)
        _add_prop_collider(prop, Vector3(0, 1.0, 0), Vector3(0.35, 2.0, 0.35))
    elif lower.contains("bench"):
        # Human-scale park bench: seat width ~1.9 m and seat height ~0.48 m.
        _make_box(prop, Vector3(0, 0.49, 0), Vector3(1.92, 0.14, 0.52), Color("#7a5940"))
        _make_box(prop, Vector3(0, 0.80, 0.22), Vector3(1.92, 0.48, 0.13), Color("#77563d"))
        for x in [-0.70, 0.70]: _make_box(prop, Vector3(x, 0.23, 0), Vector3(0.14, 0.48, 0.14), Color("#3e4c50"))
        _add_prop_collider(prop, Vector3(0, 0.46, 0), Vector3(1.96, 0.92, 0.60))
    elif lower.contains("busstop"):
        _make_box(prop, Vector3(0, 1.35, 0), Vector3(2.3, 0.12, 1.0), Color("#4b6269"))
        for x in [-1.0, 1.0]: _make_box(prop, Vector3(x, 0.85, 0), Vector3(0.08, 1.7, 0.08), Color("#44565c"))
        _make_box(prop, Vector3(0, 0.75, -0.42), Vector3(2.0, 0.65, 0.06), Color("#6b9ca5"))
        _add_prop_collider(prop, Vector3(0, 0.85, 0), Vector3(2.3, 1.7, 0.95))
    elif lower.contains("hydrant"):
        _make_box(prop, Vector3(0, 0.36, 0), Vector3(0.35, 0.65, 0.35), Color("#c94d43"))
        _make_box(prop, Vector3(0, 0.68, 0), Vector3(0.48, 0.12, 0.48), Color("#d85a4c"))
        _add_prop_collider(prop, Vector3(0, 0.36, 0), Vector3(0.45, 0.72, 0.45))
    elif lower.contains("sign") or lower.contains("wayfinding"):
        _make_box(prop, Vector3(0, 1.05, 0), Vector3(0.09, 2.1, 0.09), Color("#49575c"))
        _make_box(prop, Vector3(0, 1.75, -0.02), Vector3(0.8, 0.42, 0.08), Color("#207c63"))
        # Keep the wayfinding board clean; the objective label already appears in the HUD.
        _add_prop_collider(prop, Vector3(0, 1.0, 0), Vector3(0.18, 2.0, 0.18))
    elif lower.contains("fountain"):
        var basin := CylinderMesh.new(); basin.top_radius = 0.72; basin.bottom_radius = 0.78; basin.height = 0.38
        var basin_node := MeshInstance3D.new(); basin_node.mesh = basin; basin_node.position.y = 0.2
        var basin_mat := StandardMaterial3D.new(); basin_mat.albedo_color = Color("#91a8ac"); basin_mat.metallic = 0.28; basin_mat.roughness = 0.25; basin_node.material_override = basin_mat; prop.add_child(basin_node)
        _add_prop_collider(prop, Vector3(0, 0.2, 0), Vector3(1.5, 0.4, 1.5))
    else:
        _make_box(prop, Vector3(0, 0.5, 0), Vector3(0.65, 1.0, 0.65), Color("#526b70"))
        _add_prop_collider(prop, Vector3(0, 0.5, 0), Vector3(0.68, 1.0, 0.68))

func _add_prop_collider(parent: Node3D, local_position: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    body.name = "CollisionBody"
    body.position = local_position
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    body.add_child(shape)
    parent.add_child(body)

func _add_rooftop_ac_units(building_center: Vector3, roof_y: float, yaw: float, count: int) -> void:
    var ac_scene := preload("res://assets/DowntownCity/Prop_ACUnit.gltf")
    var offsets: Array[Vector2] = [Vector2(-2.7, -1.7), Vector2(2.5, 1.6)]
    for i in range(mini(count, offsets.size())):
        var offset: Vector2 = offsets[i]
        var local_offset := Vector3(offset.x, 0, offset.y).rotated(Vector3.UP, yaw)
        var position := building_center + local_offset + Vector3(0, roof_y + 0.045, 0)
        _add_instance(ac_scene, position, yaw, Vector3.ONE * 0.82, "RooftopHVAC")

func _create_lot_surface(center: Vector3, dimensions: Vector2, tint: Color, plaza: bool = false) -> void:
    var lot := MeshInstance3D.new()
    lot.name = "PlazaSurface" if plaza else "BuildingPlotSurface"
    var lot_mesh := BoxMesh.new()
    lot_mesh.size = Vector3(dimensions.x, 0.09, dimensions.y)
    lot.mesh = lot_mesh
    lot.position = Vector3(center.x, -0.075, center.z)
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.roughness = 0.94
    var texture_path := ASSET_ROOT + ("T_Dirt_BaseColor.png" if plaza else "T_Concrete_BaseColor.png")
    var texture := load(texture_path) as Texture2D
    if texture:
        material.albedo_texture = texture
        material.uv1_scale = Vector3(maxf(2.0, dimensions.x / 4.0), maxf(2.0, dimensions.y / 4.0), 1.0)
    lot.material_override = material
    lot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(lot)

    # Subtle raised perimeter makes each lot read as a designed city block.
    if not plaza:
        var edge_material := StandardMaterial3D.new()
        edge_material.albedo_color = Color("#69777b")
        edge_material.roughness = 0.95
        var edge_y := -0.005
        var edge_h := 0.08
        for edge in [
            {"p":Vector3(center.x, edge_y, center.z - dimensions.y * 0.5), "s":Vector3(dimensions.x, edge_h, 0.10)},
            {"p":Vector3(center.x, edge_y, center.z + dimensions.y * 0.5), "s":Vector3(dimensions.x, edge_h, 0.10)},
            {"p":Vector3(center.x - dimensions.x * 0.5, edge_y, center.z), "s":Vector3(0.10, edge_h, dimensions.y)},
            {"p":Vector3(center.x + dimensions.x * 0.5, edge_y, center.z), "s":Vector3(0.10, edge_h, dimensions.y)}
        ]:
            var edge_node := MeshInstance3D.new()
            var edge_mesh := BoxMesh.new()
            edge_mesh.size = edge["s"]
            edge_node.mesh = edge_mesh
            edge_node.position = edge["p"]
            edge_node.material_override = edge_material
            add_child(edge_node)

func _add_instance(scene: PackedScene, pos: Vector3, yaw: float, scale_value: Vector3, node_name: String) -> Node3D:
    var instance := scene.instantiate() as Node3D
    instance.name = "%s_%d_%d_%d" % [node_name, int(pos.x), int(pos.y), int(pos.z)]
    instance.position = pos
    instance.rotation.y = yaw
    instance.scale = scale_value
    if node_name.begins_with("DoubleYellow"):
        # Imported road-marking scenes can have a plain Node3D root. Shadow settings
        # belong to GeometryInstance3D descendants, not to every Node3D root.
        _set_cast_shadow_recursive(instance, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
    if node_name == "EastWestRoad" or node_name == "NorthSouthRoad":
        # Street_4Lane is only 6m wide at its asphalt surface, but the junction apron is 18m.
        # A matching textured underlay closes that gap so traffic stays on visible asphalt.
        _add_asphalt_carriageway_underlay(instance)
    if node_name == "Intersection" or node_name == "EastWestRoad" or node_name == "NorthSouthRoad":
        _neutralize_intersection_trim(instance)
    add_child(instance)
    return instance


func _set_cast_shadow_recursive(root: Node, shadow_setting: int) -> void:
    if root is GeometryInstance3D:
        (root as GeometryInstance3D).cast_shadow = shadow_setting
    for child in root.get_children():
        _set_cast_shadow_recursive(child, shadow_setting)


func _add_asphalt_carriageway_underlay(road_root: Node3D) -> void:
    var underlay := MeshInstance3D.new()
    underlay.name = "WideAsphaltUnderlay"
    var asphalt := BoxMesh.new()
    asphalt.size = Vector3(17.7, 0.02, 12.0)
    underlay.mesh = asphalt
    # The imported road plane top is at local y=-0.15, world y=-0.03 after placement.
    # Keep this underlay 5mm below it to avoid z-fighting while filling the full carriageway.
    underlay.position = Vector3(0.0, -0.165, 0.0)
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = load(ASSET_ROOT + "T_Concrete_Asphalt_BaseColor.png") as Texture2D
    mat.albedo_color = Color.WHITE
    mat.roughness = 0.96
    mat.uv1_scale = Vector3(4.4, 3.0, 1.0)
    underlay.material_override = mat
    underlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    road_root.add_child(underlay)

    # Dashed lane separators make the wider carriageway readable as four lanes.
    # Local X is lateral and local Z follows the road; the parent rotates with the road.
    var marking_material := StandardMaterial3D.new()
    marking_material.albedo_color = Color("#e6e7df")
    marking_material.roughness = 0.9
    for lateral in [-3.0, 3.0]:
        for along in [-3.0, 3.0]:
            var dash := MeshInstance3D.new()
            dash.name = "WhiteLaneDash"
            var dash_mesh := BoxMesh.new()
            dash_mesh.size = Vector3(0.13, 0.004, 2.3)
            dash.mesh = dash_mesh
            dash.position = Vector3(lateral, -0.151, along)
            dash.material_override = marking_material
            dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            road_root.add_child(dash)

func _neutralize_intersection_trim(root: Node) -> void:
    if root is MeshInstance3D:
        var mesh_instance := root as MeshInstance3D
        if mesh_instance.mesh != null:
            for surface_index in range(mesh_instance.mesh.get_surface_count()):
                var source_material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
                var material_name := ""
                if source_material != null:
                    material_name = str(source_material.resource_name)
                if surface_index == 0:
                    # The supplied asphalt surface has red vertex-color values on some corners.
                    # Keep the original asphalt material/texture but stop vertex color tinting.
                    var asphalt_neutral: StandardMaterial3D
                    if source_material != null:
                        asphalt_neutral = source_material.duplicate() as StandardMaterial3D
                    else:
                        asphalt_neutral = StandardMaterial3D.new()
                        asphalt_neutral.albedo_texture = load(ASSET_ROOT + "T_Concrete_Asphalt_BaseColor.png") as Texture2D
                    asphalt_neutral.albedo_color = Color.WHITE
                    asphalt_neutral.vertex_color_use_as_albedo = false
                    mesh_instance.set_surface_override_material(surface_index, asphalt_neutral)
                elif surface_index == 1:
                    # IMPORTANT: surface 1 is MI_StreetDecals in the supplied city asset.
                    # It contains the baked road paint/crossing geometry. Replacing it with
                    # an asphalt material avoids a large grey rectangular block on the road surface.
                    # Preserve the original material exactly; only neutralize asphalt and trim.
                    pass
                elif surface_index == 2 or material_name.to_lower().contains("trim"):
                    # Trim surface extends beyond the 6m street tile and sits on top of the
                    # junction zebra stripes. Do not render this imported raised geometry;
                    # the separate sidewalk/corner modules already define the pedestrian edge.
                    var hidden_trim := StandardMaterial3D.new()
                    hidden_trim.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
                    hidden_trim.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                    hidden_trim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                    mesh_instance.set_surface_override_material(surface_index, hidden_trim)
    for child in root.get_children():
        _neutralize_intersection_trim(child)

func _add_city_building(asset_name: String, visual_center: Vector3, scale_value: float, yaw: float, footprint: Vector2, building_height: float) -> void:
    var lot_size := Vector2(footprint.x * scale_value + 3.6, footprint.y * scale_value + 3.6)
    var lot_color := Color("#808b89") if asset_name == "Building_Large_2" else (Color("#87928f") if asset_name == "Building_Medium_2_001" else Color("#8e9690"))
    _create_lot_surface(visual_center, lot_size, lot_color, false)
    var scene := load(ASSET_ROOT + asset_name + ".gltf") as PackedScene
    if scene == null:
        push_warning("Building asset tidak ditemukan: " + asset_name)
        return
    var local_center := Vector3.ZERO
    match asset_name:
        "Building_Large_2": local_center = Vector3(1.0, 0, -8.0)
        "Building_Medium_2_001": local_center = Vector3(0.0, 0, -5.96)
        "Building_Small_1": local_center = Vector3(-1.0, 0, -6.0)
    var root_pos := visual_center - local_center.rotated(Vector3.UP, yaw) * scale_value
    var building := scene.instantiate() as Node3D
    building.name = "%s_%d_%d" % [asset_name, int(visual_center.x), int(visual_center.z)]
    building.position = root_pos
    building.rotation.y = yaw
    building.scale = Vector3.ONE * scale_value
    add_child(building)
    # Collision uses a simple footprint proxy so the coordinator can walk around, not through, buildings.
    var body := StaticBody3D.new()
    body.name = "Collision_" + building.name
    body.position = Vector3(visual_center.x, building_height * scale_value * 0.5, visual_center.z)
    body.rotation.y = yaw
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(footprint.x * scale_value * 0.92, building_height * scale_value, footprint.y * scale_value * 0.92)
    shape_node.shape = shape
    body.add_child(shape_node)
    add_child(body)

func _create_safe_zone(center: Vector3) -> void:
    var zone := MeshInstance3D.new()
    zone.name = "EvacuationSafeZone"
    var mesh := BoxMesh.new()
    mesh.size = Vector3(9.0, 0.12, 8.0)
    zone.mesh = mesh
    zone.position = center
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.08, 0.24, 0.18, 0.26)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.emission_enabled = true
    mat.emission = Color("#137a55")
    mat.emission_energy_multiplier = 0.06
    zone.material_override = mat
    add_child(zone)
    var frame_mat := StandardMaterial3D.new()
    frame_mat.albedo_color = Color("#61ddb0")
    frame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    for border_data in [
        {"pos":Vector3(0, 0.14, -4.08), "size":Vector3(9.3, 0.08, 0.10)},
        {"pos":Vector3(0, 0.14, 4.08), "size":Vector3(9.3, 0.08, 0.10)},
        {"pos":Vector3(-4.58, 0.14, 0), "size":Vector3(0.10, 0.08, 8.3)},
        {"pos":Vector3(4.58, 0.14, 0), "size":Vector3(0.10, 0.08, 8.3)}
    ]:
        var frame := MeshInstance3D.new()
        var frame_mesh := BoxMesh.new()
        frame_mesh.size = border_data["size"]
        frame.mesh = frame_mesh
        frame.position = center + border_data["pos"]
        frame.material_override = frame_mat
        add_child(frame)
    var corner_mat := StandardMaterial3D.new()
    corner_mat.albedo_color = Color("#dcfff0")
    corner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    for corner_pos in [Vector3(-4.1, 0.13, -3.55), Vector3(4.1, 0.13, -3.55), Vector3(-4.1, 0.13, 3.55), Vector3(4.1, 0.13, 3.55)]:
        var corner_mark := MeshInstance3D.new()
        var corner_mesh := BoxMesh.new()
        corner_mesh.size = Vector3(0.42, 0.045, 0.42)
        corner_mark.mesh = corner_mesh
        corner_mark.position = center + corner_pos
        corner_mark.material_override = corner_mat
        add_child(corner_mark)
    # The safe area is identified through the HUD/map; avoid large floating text in the world.

func _hide_unwanted_floating_labels() -> void:
    for node in find_children("*", "Label3D", true, false):
        if node is Label3D:
            var label := node as Label3D
            var label_text := label.text.strip_edges().to_upper()
            if label_text in ["TITIK AMAN", "SAFE POINT", "KOORDINATOR", "COORDINATOR"]:
                label.visible = false

func _on_language_changed(_language_code: String) -> void:
    for node in find_children("*", "Label3D", true, false):
        if node.has_meta("locale_key"):
            node.text = KotaLocale.t(str(node.get_meta("locale_key")))

func create_facility_marker(id: String, label_text: String, pos: Vector3, model_name: String, status_text: String, tint: Color) -> void:
    if facility_visuals.has(id):
        var old: Node3D = facility_visuals[id]
        old.queue_free()
    var node := Node3D.new()
    node.name = "Facility_" + id
    node.position = pos
    dynamic_root.add_child(node)
    var ring := MeshInstance3D.new()
    var ring_mesh := CylinderMesh.new()
    ring_mesh.top_radius = 0.56
    ring_mesh.bottom_radius = 0.56
    ring_mesh.height = 0.035
    ring.mesh = ring_mesh
    ring.position.y = 0.035
    var ring_mat := StandardMaterial3D.new()
    ring_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.07)
    ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ring_mat.roughness = 0.8
    ring.material_override = ring_mat
    node.add_child(ring)
    if id == "resapan":
        var garden := MeshInstance3D.new()
        garden.name = "PermeableRainGarden"
        var garden_mesh := BoxMesh.new()
        garden_mesh.size = Vector3(5.8, 0.06, 5.2)
        garden.mesh = garden_mesh
        garden.position = Vector3(0, -0.015, 0)
        var garden_mat := StandardMaterial3D.new()
        garden_mat.albedo_texture = load(ASSET_ROOT + "T_Dirt_BaseColor.png") as Texture2D
        garden_mat.albedo_color = Color("#9eb18d")
        garden_mat.roughness = 0.98
        garden_mat.uv1_scale = Vector3(2.5, 2.5, 1.0)
        garden.material_override = garden_mat
        node.add_child(garden)
    if model_name != "":
        var scene := load(ASSET_ROOT + model_name + ".gltf") as PackedScene
        if scene:
            var instance := scene.instantiate() as Node3D
            instance.scale = Vector3.ONE * (0.85 if model_name == "Prop_Planter_Single" else 0.78)
            node.add_child(instance)
    if id == "signage":
        var pole := _make_box(node, Vector3(0, 1.0, 0), Vector3(0.10, 1.9, 0.10), Color("#47545d"))
        var board := _make_box(node, Vector3(0, 1.85, 0), Vector3(0.92, 0.6, 0.12), Color("#f0c85a"))
        _label_3d(node, "EVAKUASI", Vector3(0, 1.82, 0.09), Color("#253238"), 22)
    _label_3d(node, label_text, Vector3(0, 2.55, 0), Color("#f5faf7"), 28)
    _label_3d(node, status_text, Vector3(0, 2.08, 0), tint, 20)
    facility_visuals[id] = node

func update_facility_marker(id: String, status_text: String, tint: Color) -> void:
    if not facility_visuals.has(id): return
    var node: Node3D = facility_visuals[id]
    # The second Label3D is the status. It is found by its creation order after the main name and possible sign label.
    var labels: Array[Label3D] = []
    _collect_labels(node, labels)
    if labels.size() >= 2:
        labels[labels.size() - 1].text = status_text
        labels[labels.size() - 1].modulate = tint

func create_hazard_marker(id: String, label_text: String, pos: Vector3, kind: String) -> void:
    if hazard_visuals.has(id):
        var previous: Node3D = hazard_visuals[id]
        previous.queue_free()
    var node := Node3D.new()
    node.name = "Hazard_" + id
    node.position = pos
    dynamic_root.add_child(node)
    var disc := MeshInstance3D.new()
    var dm := TorusMesh.new()
    dm.inner_radius = 0.58
    dm.outer_radius = 0.68
    dm.rings = 32
    dm.ring_segments = 8
    disc.mesh = dm
    disc.position.y = 0.07
    var dm_mat := StandardMaterial3D.new()
    dm_mat.albedo_color = Color("#d99b55")
    dm_mat.roughness = 0.68
    dm_mat.metallic = 0.0
    dm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    disc.material_override = dm_mat
    node.add_child(disc)
    if kind in ["water", "flood"]:
        var puddle := MeshInstance3D.new()
        var puddle_mesh := PlaneMesh.new()
        puddle_mesh.size = Vector2(2.2, 1.35)
        puddle.mesh = puddle_mesh
        puddle.position.y = 0.06
        var blue := StandardMaterial3D.new()
        blue.albedo_color = Color(0.14, 0.46, 0.75, 0.68)
        blue.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        blue.metallic = 0.18
        blue.roughness = 0.18
        blue.emission_enabled = true
        blue.emission = Color("#164e78")
        blue.emission_energy_multiplier = 0.22
        puddle.material_override = blue
        node.add_child(puddle)
    elif kind in ["debris", "tree"]:
        var debris := _make_box(node, Vector3(0, 0.35, 0), Vector3(1.7, 0.7, 1.2), Color("#765d4f"))
        debris.rotation.y = 0.28
        var plank := _make_box(node, Vector3(0.1, 0.75, 0.1), Vector3(1.6, 0.15, 0.2), Color("#aa835e"))
        plank.rotation.z = 0.35
    else:
        var drain := load(ASSET_ROOT + "Prop_Drain.gltf") as PackedScene
        if drain:
            var d := drain.instantiate() as Node3D
            d.position.y = 0.08
            d.scale = Vector3.ONE * 1.8
            node.add_child(d)
    _label_3d(node, label_text, Vector3(0, 1.9, 0), Color("#ffe1c8"), 22)
    hazard_visuals[id] = node

func update_hazard_marker(id: String, is_done: bool) -> void:
    if not hazard_visuals.has(id): return
    var node: Node3D = hazard_visuals[id]
    node.visible = not is_done

func create_side_marker(id: String, label_text: String, pos: Vector3, kind: String) -> void:
    if side_visuals.has(id):
        var previous: Node3D = side_visuals[id]
        previous.queue_free()
    var node := Node3D.new()
    node.name = "SideObjective_" + id
    node.position = pos
    dynamic_root.add_child(node)
    var color := Color("#59b9e8")
    if kind == "medkit": color = Color("#ef8f77")
    elif kind == "siren": color = Color("#f1cc68")
    var beacon := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.48, 0.58, 0.48)
    beacon.mesh = mesh
    beacon.position.y = 0.34
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color.darkened(0.2)
    mat.emission_energy_multiplier = 0.32
    beacon.material_override = mat
    node.add_child(beacon)
    _label_3d(node, label_text, Vector3(0, 1.25, 0), Color("#f3faf7"), 18)
    side_visuals[id] = node

func update_side_marker(id: String, is_done: bool) -> void:
    if not side_visuals.has(id): return
    var node: Node3D = side_visuals[id]
    node.visible = not is_done

func clear_dynamic() -> void:
    if is_instance_valid(dynamic_root):
        dynamic_root.queue_free()
    dynamic_root = Node3D.new()
    dynamic_root.name = "MissionObjects"
    add_child(dynamic_root)
    citizen_root = Node3D.new()
    citizen_root.name = "Citizens"
    dynamic_root.add_child(citizen_root)
    facility_visuals.clear()
    hazard_visuals.clear()
    side_visuals.clear()
    # Weather state is always reset before the new chapter is prepared.
    set_weather(0, false)

func add_citizen(citizen: Node3D) -> void:
    citizen_root.add_child(citizen)

func set_weather(level: int, active: bool) -> void:
    current_weather_level = clampi(level, 0, 3)
    weather_active = active and current_weather_level > 0
    if current_weather_level == 0:
        weather_active = false
    AudioManager.set_disaster_audio(current_weather_level, weather_active)
    if is_instance_valid(disaster_manager):
        disaster_manager.call("set_disaster", current_weather_level, weather_active)

func _make_weather_effects() -> void:
    var manager_script := load("res://scripts/systems/DisasterManager.gd") as Script
    if manager_script == null:
        push_error("DisasterManager.gd could not be loaded; city weather effects are disabled.")
        return
    disaster_manager = Node.new()
    disaster_manager.name = "DisasterManager"
    disaster_manager.set_script(manager_script)
    weather_root.add_child(disaster_manager)
    disaster_manager.call("configure", self, world_environment, weather_root)

func _process(delta: float) -> void:
    world_clock_minutes = fposmod(world_clock_minutes + delta * clock_rate, 1440.0)
    var hour := world_clock_minutes / 60.0
    var daylight := clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)
    # Street lights fade in at dusk as daylight falls, not at an arbitrary 19:00 switch.
    var dusk_lights := 1.0 - smoothstep(0.16, 0.48, daylight)
    var dawn_dusk_strength := maxf(1.0 - absf(hour - 6.2) / 2.0, 1.0 - absf(hour - 18.1) / 2.6)
    if is_instance_valid(sky_shader_material):
        sky_shader_material.set_shader_parameter("daylight", daylight)
        sky_shader_material.set_shader_parameter("dusk_strength", clampf(dawn_dusk_strength, 0.0, 1.0))
        sky_shader_material.set_shader_parameter("weather_amount", 0.76 if weather_active else 0.12)
    if is_instance_valid(sky_cloud_root):
        var cloud_clock := Time.get_ticks_msec() * 0.001
        for cloud_data in sky_cloud_groups:
            var cloud_node := cloud_data["node"] as Node3D
            if not is_instance_valid(cloud_node):
                continue
            var cloud_base: Vector3 = cloud_data["base"]
            var cloud_phase := float(cloud_data["phase"])
            cloud_node.position = Vector3(wrapf(cloud_base.x + cloud_clock * 0.22 + cloud_phase * 2.0, -88.0, 88.0), cloud_base.y + sin(cloud_clock * 0.13 + cloud_phase) * 0.32, cloud_base.z)
        var cloud_day_color := Color("#f0f5fa").lerp(Color("#8b99a7"), 0.72 if weather_active else 0.0)
        cloud_day_color = cloud_day_color.lerp(Color("#43566b"), 1.0 - daylight)
        if is_instance_valid(sky_cloud_material):
            sky_cloud_material.albedo_color = cloud_day_color
    if is_instance_valid(sun_light):
        sun_light.light_energy = lerpf(0.16, 1.24, daylight)
        var sun_fraction := clampf((hour - 5.5) / 13.5, 0.0, 1.0)
        sun_light.rotation_degrees.x = lerpf(18.0, -72.0, sun_fraction)
        var dawn_dusk := hour < 8.0 or hour >= 16.0
        sun_light.light_color = Color("#e98f67").lerp(Color("#fff5e4"), daylight) if dawn_dusk else Color("#fff5e4")
    if world_environment != null:
        world_environment.background_color = Color("#17263a").lerp(Color("#6b8593"), daylight)
        world_environment.ambient_light_color = Color("#9aadc0").lerp(Color("#c6d4dc"), daylight)
        world_environment.ambient_light_energy = lerpf(1.08, 1.42, daylight)
        world_environment.ambient_light_sky_contribution = 0.62
        world_environment.fog_light_color = Color("#314459").lerp(Color("#9aaab4"), daylight)
        if weather_active:
            world_environment.ambient_light_energy = maxf(1.02, world_environment.ambient_light_energy * 0.88)
            world_environment.background_color = world_environment.background_color.lerp(Color("#526371"), 0.30)
    var storm_light_factor := 1.0
    if weather_active:
        match current_weather_level:
            1: storm_light_factor = 0.92
            2: storm_light_factor = 0.80
            3:
                # High winds cause a restrained district-wide power flicker, not full blackouts.
                var flicker := 0.92 + 0.08 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0045))
                storm_light_factor = 0.60 * flicker
    for child in get_children():
        if child is Node3D and child.has_meta("night_light"):
            var lamp := child.get_meta("night_light") as OmniLight3D
            if is_instance_valid(lamp): lamp.light_energy = 5.2 * dusk_lights * storm_light_factor
    if is_instance_valid(disaster_manager):
        disaster_manager.call("set_daylight", daylight, weather_active, current_weather_level)

func _physics_process(delta: float) -> void:
    _move_traffic(delta)

func get_clock_text() -> String:
    var total_minutes := int(world_clock_minutes)
    var hour := int(total_minutes / 60) % 24
    var minute := total_minutes % 60
    return "%02d:%02d" % [hour, minute]

func get_period_text() -> String:
    return KotaLocale.time_period(int(world_clock_minutes / 60.0))

func get_weather_text() -> String:
    if weather_active:
        if current_weather_level == 1: return KotaLocale.t("weather_rain")
        if current_weather_level == 2: return KotaLocale.t("weather_flood")
        if current_weather_level == 3: return KotaLocale.t("weather_wind")
    elif current_weather_level == 2:
        return KotaLocale.t("weather_flood")
    return KotaLocale.t("weather_clear")

func _make_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    mesh_node.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.7
    mesh_node.material_override = mat
    parent.add_child(mesh_node)
    return mesh_node

func _label_3d(parent: Node3D, text_value: String, pos: Vector3, color: Color, font_size: int) -> Label3D:
    var label := Label3D.new()
    label.text = text_value
    var normalized_label := text_value.strip_edges().to_upper()
    if normalized_label in ["TITIK AMAN", "SAFE POINT", "KOORDINATOR", "COORDINATOR"]:
        label.visible = false
    label.position = pos
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.pixel_size = 0.018
    label.font_size = font_size
    label.outline_size = 4
    label.modulate = color
    label.no_depth_test = true
    label.shaded = false
    parent.add_child(label)
    return label

func _collect_labels(node: Node, out: Array[Label3D]) -> void:
    if node is Label3D: out.append(node as Label3D)
    for child in node.get_children(): _collect_labels(child, out)
