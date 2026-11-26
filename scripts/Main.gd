extends Node3D

const WORLD_SCENE := preload("res://scenes/world/CityWorld.tscn")
const PLAYER_SCENE := preload("res://scenes/actors/Coordinator.tscn")
const UI_SCENE := preload("res://scenes/ui/UIRoot.tscn")
const CAMERA_RIG_SCENE := preload("res://scenes/CameraRig.tscn")
const CONTROLLER_SCRIPT := preload("res://scripts/systems/GameController.gd")

var world_root: Node3D
var actor_root: Node3D
var system_root: Node
var presentation_root: Node3D
var city: Node3D
var player: CharacterBody3D
var camera_rig: Node3D
var controller: Node
var ui: CanvasLayer
var menu_mode: bool = true

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    AudioManager.set_game_mode(false)
    GameState.reset_campaign()
    _build_scene_roots()
    _create_world()
    _create_player()
    _create_presentation()
    _create_controller_and_ui()

func _build_scene_roots() -> void:
    world_root = Node3D.new()
    world_root.name = "WorldRoot"
    add_child(world_root)

    actor_root = Node3D.new()
    actor_root.name = "Actors"
    add_child(actor_root)

    system_root = Node.new()
    system_root.name = "Systems"
    add_child(system_root)

    presentation_root = Node3D.new()
    presentation_root.name = "Presentation"
    add_child(presentation_root)

func _create_world() -> void:
    city = WORLD_SCENE.instantiate() as Node3D
    city.name = "ArunikaMetropolitan"
    world_root.add_child(city)

func _create_player() -> void:
    player = PLAYER_SCENE.instantiate() as CharacterBody3D
    player.name = "Koordinator"
    player.add_to_group("player")
    player.position = Vector3(-3.5, 0.0, 10.5)
    player.set("input_enabled", false)
    actor_root.add_child(player)

func _create_presentation() -> void:
    camera_rig = CAMERA_RIG_SCENE.instantiate() as Node3D
    camera_rig.name = "CameraRig"
    presentation_root.add_child(camera_rig)
    camera_rig.call("set_target", player)
    camera_rig.call("set_menu_mode", true)

func _create_controller_and_ui() -> void:
    controller = Node.new()
    controller.name = "GameController"
    controller.set_script(CONTROLLER_SCRIPT)
    system_root.add_child(controller)
    player.set("game_controller", controller)

    ui = UI_SCENE.instantiate() as CanvasLayer
    ui.name = "UIRoot"
    add_child(ui)
    controller.call("setup", city, player, ui)
    ui.call("setup", controller)
    controller.call("load_level", 1, true)
    ui.call("show_main_menu")

func get_camera_yaw() -> float:
    if is_instance_valid(camera_rig):
        return float(camera_rig.call("get_yaw"))
    return 0.0

func set_mouse_capture(captured: bool) -> void:
    if is_instance_valid(camera_rig):
        camera_rig.call("set_mouse_capture", captured)
    else:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE

func begin_campaign() -> void:
    menu_mode = false
    var resume_level := clampi(GameState.unlocked_level, 1, 3)
    controller.call("load_level", resume_level, true)

func set_menu_mode(value: bool) -> void:
    menu_mode = value
    AudioManager.set_game_mode(not value)
    if is_instance_valid(player):
        player.set("input_enabled", not value)
    if is_instance_valid(camera_rig):
        camera_rig.call("set_menu_mode", value)
    set_mouse_capture(not value)

func return_to_menu() -> void:
    if NetworkSession.is_online_session():
        NetworkSession.leave_session()
    get_tree().reload_current_scene()
