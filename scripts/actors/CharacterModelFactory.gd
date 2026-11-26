extends RefCounted

## Loads a GLB character, normalizes its height, and aligns the feet to y=0.
## Skinned assets use imported Skeleton3D + clips; legacy unskinned assets keep the pivot-rig fallback.
static func attach_model(parent: Node3D, resource_path: String, target_height: float = 1.72, facing_yaw: float = PI) -> Node3D:
    if not ResourceLoader.exists(resource_path):
        push_warning("Character asset missing: %s" % resource_path)
        return null
    var resource := load(resource_path)
    if not (resource is PackedScene):
        push_warning("Character asset is not an imported PackedScene: %s" % resource_path)
        return null
    var model := (resource as PackedScene).instantiate() as Node3D
    if model == null:
        push_warning("Character asset root must be Node3D: %s" % resource_path)
        return null
    model.name = "CharacterModel"
    parent.add_child(model)
    _polish_pbr_surfaces(model, resource_path)
    var bounds := _calculate_bounds(model, model)
    if bounds.size.y <= 0.001:
        model.queue_free()
        push_warning("Character asset has invalid mesh bounds: %s" % resource_path)
        return null
    var safe_height := maxf(target_height, 0.5)
    var scale_factor := safe_height / maxf(bounds.size.y, 0.001)
    var center := bounds.position + bounds.size * 0.5
    model.scale = Vector3.ONE * scale_factor
    model.position = Vector3(-center.x * scale_factor, -bounds.position.y * scale_factor, -center.z * scale_factor)
    var imported_skeleton := _find_descendant_by_type(model, "Skeleton3D") as Skeleton3D
    if imported_skeleton != null and _build_skeletal_animation_tree(model):
        model.set_meta("locomotion_profile", "seated" if resource_path.to_lower().contains("wheelchair") else "biped")
        model.set_meta("has_skeletal_animation_tree", true)
    else:
        _build_locomotion_rig(model, resource_path)
        _build_animation_tree(model)
    _build_role_accessories(model, resource_path, scale_factor, safe_height)
    model.rotation.y = facing_yaw
    return model


## Finds the first descendant matching a native Godot node type.
## Node.find_child() only accepts (pattern, recursive, owned); type filtering
## belongs to Node.find_children(pattern, type, recursive, owned).
static func _find_descendant_by_type(root: Node, type_name: String) -> Node:
    var matches: Array[Node] = root.find_children("*", type_name, true, false)
    if matches.is_empty():
        return null
    return matches[0]


static func _polish_pbr_surfaces(node: Node, resource_path: String = "") -> void:
    # Role-specific albedo overrides are deliberately explicit. The earlier version
    # changed roughness subtly but preserved the source colour, so in-game changes
    # were almost invisible. This pass gives each responder an unmistakable palette.
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            for surface_index in range(mesh_instance.mesh.get_surface_count()):
                var source_material := mesh_instance.get_active_material(surface_index)
                if source_material is StandardMaterial3D:
                    var material := (source_material as StandardMaterial3D).duplicate() as StandardMaterial3D
                    var part_name := mesh_instance.name.to_lower()
                    var finish_name := (part_name + " " + material.resource_name).to_lower()
                    material.albedo_color = _role_palette_color(resource_path, part_name, material.albedo_color)
                    var roughness := 0.76
                    var metallic := 0.02
                    if "visor" in finish_name or "lens" in finish_name or "glass" in finish_name:
                        roughness = 0.16
                        metallic = 0.22
                    elif "stripe" in finish_name or "reflect" in finish_name:
                        roughness = 0.26
                        metallic = 0.20
                    elif "badge" in finish_name or "buckle" in finish_name or "nameplate" in finish_name or "metal" in finish_name or "antenna" in finish_name:
                        roughness = 0.28
                        metallic = 0.58
                    elif "helmet" in finish_name or "hard_hat" in finish_name or "police_cap" in finish_name or "medical_cap" in finish_name:
                        roughness = 0.32
                        metallic = 0.06
                        material.clearcoat_enabled = true
                        material.clearcoat = 0.36
                        material.clearcoat_roughness = 0.18
                    elif "radio" in finish_name or "clipboard" in finish_name or "utility_belt" in finish_name or "bag" in finish_name:
                        roughness = 0.55
                        metallic = 0.08
                    elif "head" in finish_name or "neck" in finish_name or "hand" in finish_name or "ear_" in finish_name or "nose" in finish_name or "mouth" in finish_name or "eye" in finish_name or "brow" in finish_name:
                        roughness = 0.68
                        metallic = 0.0
                    elif "boot" in finish_name or "glove" in finish_name or "sole" in finish_name:
                        roughness = 0.84
                        metallic = 0.0
                    elif "hair" in finish_name:
                        roughness = 0.88
                        metallic = 0.0
                    material.roughness = roughness
                    material.metallic = metallic
                    material.metallic_specular = 0.42
                    material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
                    mesh_instance.set_surface_override_material(surface_index, material)
    for child in node.get_children():
        _polish_pbr_surfaces(child, resource_path)


static func _role_palette_color(resource_path: String, part_name: String, fallback: Color) -> Color:
    var path := resource_path.to_lower()
    var part := part_name.to_lower()

    if "player_firefighter" in path:
        if "stripe" in part or "reflect" in part:
            return Color("#F4E7B2") if "lower" not in part else Color("#D7E0DF")
        if "helmet_shell" in part or "helmet_brim" in part:
            return Color("#D62828")
        if "helmet_badge" in part:
            return Color("#F6C84A")
        if "visor" in part:
            return Color("#182B35")
        if "air_cylinder" in part or "radio_body" in part or "radio_antenna" in part:
            return Color("#202D34")
        if "hose_pouch" in part:
            return Color("#E87525")
        if _contains_any_token(part, ["left_boot", "right_boot", "trouser", "knee", "pelvis"]):
            return Color("#29343A")
        if _contains_any_token(part, ["torso", "shoulder", "upper_arm", "forearm", "vest_front", "fire_collar"]):
            return Color("#B51F24")

    elif "player_paramedic" in path:
        if "medical_cross" in part or "bag_cross" in part or "medical_cap_cross" in part:
            return Color("#E43D4D")
        if "medical_bag" in part:
            return Color("#C91F35")
        if "medical_cap" in part and "cross" not in part:
            return Color("#F0F2EE")
        if "left_hand" in part or "right_hand" in part:
            return Color("#2D78C9")
        if "belt_buckle" in part:
            return Color("#D5E1DF")
        if "left_boot" in part or "right_boot" in part:
            return Color("#101C25")
        if "pelvis" in part or "trouser" in part or "knee" in part:
            return Color("#122B3D")
        if "coat_collar" in part:
            return Color("#D8E2E4")
        if _contains_any_token(part, ["torso", "shoulder", "upper_arm", "forearm", "medical_coat"]):
            return Color("#163D59")

    elif "player_logistics" in path:
        if "vest_front" in part:
            return Color("#FF8A12")
        if "stripe" in part or "reflect" in part:
            return Color("#EAF2CE")
        if "hard_hat" in part:
            return Color("#F2BD27")
        if "clipboard_paper" in part:
            return Color("#F0E8D2")
        if "clipboard" in part:
            return Color("#855B34")
        if "belt_buckle" in part:
            return Color("#D8C58D")
        if "left_boot" in part or "right_boot" in part:
            return Color("#18211F")
        if "pelvis" in part or "trouser" in part or "knee" in part:
            return Color("#303A32")
        if _contains_any_token(part, ["torso", "shoulder", "upper_arm", "forearm"]):
            return Color("#455447")

    elif "player_police" in path:
        if "police_badge" in part or "cap_badge" in part or "belt_buckle" in part:
            return Color("#D7B568")
        if "nameplate" in part:
            return Color("#DCE5E5")
        if "police_vest" in part:
            return Color("#101B26")
        if "police_cap" in part:
            return Color("#132A43")
        if "police_belt" in part or "police_radio" in part or "radio_body" in part:
            return Color("#202B32")
        if "left_boot" in part or "right_boot" in part:
            return Color("#0D151C")
        if "pelvis" in part or "trouser" in part or "knee" in part:
            return Color("#14243A")
        if _contains_any_token(part, ["torso", "shoulder", "upper_arm", "forearm"]):
            return Color("#1A3049")

    elif "npc_injured" in path:
        if "torso" in part or "upper_arm" in part or "forearm" in part:
            return Color("#8D4B42")
        if "trouser" in part or "pelvis" in part:
            return Color("#303B43")
    elif "npc_elder" in path:
        if "torso" in part or "upper_arm" in part or "forearm" in part:
            return Color("#55706A")
        if "trouser" in part or "pelvis" in part:
            return Color("#41454A")
    elif "npc_child" in path:
        if "torso" in part or "upper_arm" in part or "forearm" in part:
            return Color("#287F89")
        if "trouser" in part or "pelvis" in part:
            return Color("#35516B")
    elif "npc_civilian" in path:
        if "torso" in part or "upper_arm" in part or "forearm" in part:
            return Color("#356F72")
    elif "npc_wheelchair" in path:
        if "torso" in part or "upper_arm" in part or "forearm" in part:
            return Color("#1F5E7A")

    return fallback


static func _build_role_accessories(model: Node3D, resource_path: String, scale_factor: float, display_height: float = 1.72) -> void:
    if model.get_node_or_null("RoleVisualEnhancements") != null:
        return
    var path := resource_path.to_lower()
    var is_player_role := "player_firefighter" in path or "player_paramedic" in path or "player_logistics" in path or "player_police" in path
    var is_injured := "npc_injured" in path
    var is_civilian := "npc_civilian" in path or "npc_elder" in path or "npc_child" in path or "npc_wheelchair" in path
    if not is_player_role and not is_injured and not is_civilian:
        return

    var details := Node3D.new()
    details.name = "RoleVisualEnhancements"
    var display_scale := maxf(display_height / 1.72, 0.1)
    details.scale = Vector3.ONE * (display_scale / maxf(scale_factor, 0.001))
    model.add_child(details)

    if "player_firefighter" in path:
        _add_detail_box(details, "FireReflectiveBandChestUpper", Vector3(0.0, 1.125, 0.145), Vector3(0.28, 0.022, 0.012), Color("#F1E8C7"), 0.28, 0.16)
        _add_detail_box(details, "FireReflectiveBandChestLower", Vector3(0.0, 1.065, 0.145), Vector3(0.28, 0.022, 0.012), Color("#DCE5E4"), 0.28, 0.18)
        _add_detail_box(details, "FireChestRadioPlate", Vector3(-0.135, 1.285, 0.158), Vector3(0.085, 0.12, 0.032), Color("#17242B"), 0.48, 0.08)
        _add_detail_box(details, "FireChestPocket", Vector3(0.125, 1.265, 0.158), Vector3(0.105, 0.085, 0.028), Color("#8D1E22"), 0.76, 0.0)
        _add_detail_box(details, "FireBeltPouchL", Vector3(-0.145, 0.865, 0.147), Vector3(0.075, 0.09, 0.045), Color("#202A2F"), 0.72, 0.04)
        _add_detail_box(details, "FireBeltPouchR", Vector3(0.145, 0.865, 0.147), Vector3(0.075, 0.09, 0.045), Color("#202A2F"), 0.72, 0.04)
        for x in [-0.12, 0.12]:
            for y in [0.30, 0.36]:
                _add_detail_box(details, "FireTrouserReflective_%s_%s" % [str(x), str(y)], Vector3(x, y, 0.10), Vector3(0.135, 0.018, 0.012), Color("#E5E7D8"), 0.30, 0.15)

    elif "player_paramedic" in path:
        _add_detail_box(details, "MedicChestPatch", Vector3(-0.135, 1.295, 0.15), Vector3(0.085, 0.105, 0.018), Color("#EAF0ED"), 0.62, 0.0)
        _add_detail_box(details, "MedicCrossVertical", Vector3(-0.135, 1.295, 0.164), Vector3(0.019, 0.072, 0.008), Color("#D6253D"), 0.4, 0.0)
        _add_detail_box(details, "MedicCrossHorizontal", Vector3(-0.135, 1.295, 0.165), Vector3(0.058, 0.019, 0.009), Color("#D6253D"), 0.4, 0.0)
        _add_detail_box(details, "MedicChestPocket", Vector3(0.125, 1.275, 0.158), Vector3(0.105, 0.085, 0.025), Color("#214B63"), 0.74, 0.0)
        _add_detail_box(details, "MedicBeltPouch", Vector3(0.18, 0.86, 0.143), Vector3(0.11, 0.13, 0.065), Color("#BD2236"), 0.62, 0.02)
        _add_detail_box(details, "MedicPouchCrossV", Vector3(0.18, 0.86, 0.18), Vector3(0.015, 0.075, 0.006), Color("#F0F1E9"), 0.35, 0.0)
        _add_detail_box(details, "MedicPouchCrossH", Vector3(0.18, 0.86, 0.181), Vector3(0.055, 0.015, 0.006), Color("#F0F1E9"), 0.35, 0.0)

    elif "player_logistics" in path:
        _add_detail_box(details, "LogisticsReflectiveBandUpper", Vector3(0.0, 1.19, 0.145), Vector3(0.28, 0.026, 0.012), Color("#E6EEE0"), 0.28, 0.12)
        _add_detail_box(details, "LogisticsReflectiveBandLower", Vector3(0.0, 1.105, 0.145), Vector3(0.28, 0.026, 0.012), Color("#E6EEE0"), 0.28, 0.12)
        _add_detail_box(details, "LogisticsPocketL", Vector3(-0.115, 1.275, 0.157), Vector3(0.11, 0.085, 0.03), Color("#C46B16"), 0.68, 0.0)
        _add_detail_box(details, "LogisticsPocketR", Vector3(0.115, 1.275, 0.157), Vector3(0.11, 0.085, 0.03), Color("#C46B16"), 0.68, 0.0)
        _add_detail_box(details, "LogisticsPatch", Vector3(-0.23, 1.37, 0.102), Vector3(0.07, 0.075, 0.024), Color("#E5EAE1"), 0.48, 0.0)

    elif "player_police" in path:
        _add_detail_box(details, "PoliceNamePlate", Vector3(0.025, 1.315, 0.15), Vector3(0.19, 0.035, 0.014), Color("#D8E1E3"), 0.30, 0.42)
        var police_label := Label3D.new()
        police_label.name = "PoliceChestText"
        police_label.text = "POLISI"
        police_label.font_size = 24
        police_label.pixel_size = 0.0012
        police_label.modulate = Color("#132A43")
        police_label.position = Vector3(0.025, 1.312, 0.16)
        details.add_child(police_label)
        _add_detail_box(details, "PoliceChestBadge", Vector3(-0.135, 1.305, 0.158), Vector3(0.052, 0.065, 0.016), Color("#D5B05D"), 0.28, 0.55)
        _add_detail_box(details, "PoliceVestPouchL", Vector3(-0.115, 1.14, 0.158), Vector3(0.088, 0.09, 0.04), Color("#202B35"), 0.62, 0.12)
        _add_detail_box(details, "PoliceVestPouchC", Vector3(0.0, 1.14, 0.158), Vector3(0.088, 0.09, 0.04), Color("#202B35"), 0.62, 0.12)
        _add_detail_box(details, "PoliceVestPouchR", Vector3(0.115, 1.14, 0.158), Vector3(0.088, 0.09, 0.04), Color("#202B35"), 0.62, 0.12)
        _add_detail_box(details, "PoliceShoulderPatch", Vector3(-0.245, 1.36, 0.102), Vector3(0.065, 0.072, 0.024), Color("#E4E9E4"), 0.46, 0.1)

    elif is_injured:
        _add_detail_box(details, "InjuredMedicalBand", Vector3(0.245, 1.29, 0.10), Vector3(0.055, 0.07, 0.025), Color("#F0E7D6"), 0.6, 0.0)
        _add_detail_box(details, "InjuredBandCrossV", Vector3(0.245, 1.29, 0.115), Vector3(0.012, 0.043, 0.006), Color("#C92F3F"), 0.4, 0.0)
        _add_detail_box(details, "InjuredBandCrossH", Vector3(0.245, 1.29, 0.116), Vector3(0.035, 0.012, 0.006), Color("#C92F3F"), 0.4, 0.0)

    elif is_civilian:
        if "npc_wheelchair" in path:
            _add_detail_box(details, "WheelchairSafetyTab", Vector3(0.0, 0.60, -0.28), Vector3(0.14, 0.07, 0.018), Color("#E7B832"), 0.55, 0.05)
        elif "npc_child" in path:
            _add_detail_box(details, "ChildBackpack", Vector3(0.0, 0.94, -0.145), Vector3(0.19, 0.22, 0.085), Color("#C64A3B"), 0.78, 0.0)
            _add_detail_box(details, "ChildBackpackFlap", Vector3(0.0, 1.035, -0.194), Vector3(0.15, 0.065, 0.018), Color("#E5B04C"), 0.68, 0.0)
        elif "npc_civilian" in path:
            _add_detail_box(details, "CivilianDaypack", Vector3(0.0, 1.00, -0.14), Vector3(0.19, 0.24, 0.08), Color("#2B4950"), 0.84, 0.0)
            _add_detail_box(details, "CivilianDaypackFlap", Vector3(0.0, 1.095, -0.187), Vector3(0.14, 0.06, 0.016), Color("#5E8B7F"), 0.8, 0.0)


static func _contains_any_token(value: String, tokens: Array) -> bool:
    for token in tokens:
        if str(token) in value:
            return true
    return false


static func _add_detail_box(parent: Node3D, detail_name: String, position: Vector3, size: Vector3, color: Color, roughness: float = 0.65, metallic: float = 0.0) -> MeshInstance3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    material.metallic_specular = 0.35 if metallic > 0.2 else 0.18
    material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    material.cull_mode = BaseMaterial3D.CULL_DISABLED

    var box := BoxMesh.new()
    box.size = size
    box.material = material

    var instance := MeshInstance3D.new()
    instance.name = detail_name
    instance.mesh = box
    instance.position = position
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    parent.add_child(instance)
    return instance

static func _calculate_bounds(node: Node, model_root: Node3D) -> AABB:
    var combined := AABB()
    var has_bounds := false
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            var relative_transform: Transform3D = model_root.global_transform.affine_inverse() * mesh_instance.global_transform
            combined = mesh_instance.get_aabb() * relative_transform
            has_bounds = true
    for child in node.get_children():
        var child_bounds := _calculate_bounds(child, model_root)
        if child_bounds.size.length_squared() > 0.0:
            if has_bounds:
                combined = combined.merge(child_bounds)
            else:
                combined = child_bounds
                has_bounds = true
    return combined if has_bounds else AABB()


## Builds a runtime AnimationTree around the imported GLB clips and the real Skeleton3D.
## A copied runtime animation library allows us to explicitly set loop modes without editing source GLBs.
static func _build_skeletal_animation_tree(model: Node3D) -> bool:
    if model.get_node_or_null("LocomotionAnimationTree") != null:
        return true
    var animation_player := _find_descendant_by_type(model, "AnimationPlayer") as AnimationPlayer
    if animation_player == null:
        return false

    var runtime_library := AnimationLibrary.new()
    for clip_name in ["Idle", "Walk", "Run", "Jump"]:
        var source_animation := _find_imported_animation(animation_player, clip_name)
        if source_animation == null:
            push_warning("Rigged character is missing animation clip '%s': %s" % [clip_name, model.name])
            return false
        var clip := source_animation.duplicate(true) as Animation
        clip.resource_name = clip_name
        clip.loop_mode = Animation.LOOP_NONE if clip_name == "Jump" else Animation.LOOP_LINEAR
        var add_error := runtime_library.add_animation(clip_name, clip)
        if add_error != OK:
            push_warning("Failed to copy animation '%s' into runtime library." % clip_name)
            return false
    if animation_player.has_animation_library("KotaSiagaRuntime"):
        animation_player.remove_animation_library("KotaSiagaRuntime")
    animation_player.add_animation_library("KotaSiagaRuntime", runtime_library)

    var blend_space := AnimationNodeBlendSpace1D.new()
    blend_space.min_space = 0.0
    blend_space.max_space = 2.0
    blend_space.value_label = "Speed (m/s, normalized)"
    blend_space.sync_mode = AnimationNodeBlendSpace1D.SYNC_MODE_CYCLIC_MUTABLE
    for blend_point in [{"clip":"Idle", "position":0.0}, {"clip":"Walk", "position":1.0}, {"clip":"Run", "position":2.0}]:
        var animation_node := AnimationNodeAnimation.new()
        animation_node.animation = "KotaSiagaRuntime/" + str(blend_point["clip"])
        blend_space.add_blend_point(animation_node, float(blend_point["position"]))

    var state_machine := AnimationNodeStateMachine.new()
    state_machine.add_node("Locomotion", blend_space, Vector2(0.0, 0.0))
    var jump_node := AnimationNodeAnimation.new()
    jump_node.animation = "KotaSiagaRuntime/Jump"
    state_machine.add_node("Jump", jump_node, Vector2(260.0, 0.0))

    var start_transition := AnimationNodeStateMachineTransition.new()
    start_transition.xfade_time = 0.0
    state_machine.add_transition("Start", "Locomotion", start_transition)
    var jump_transition := AnimationNodeStateMachineTransition.new()
    jump_transition.xfade_time = 0.12
    state_machine.add_transition("Locomotion", "Jump", jump_transition)
    var land_transition := AnimationNodeStateMachineTransition.new()
    land_transition.xfade_time = 0.18
    state_machine.add_transition("Jump", "Locomotion", land_transition)

    var tree := AnimationTree.new()
    tree.name = "LocomotionAnimationTree"
    tree.tree_root = state_machine
    tree.active = false
    model.add_child(tree)
    tree.anim_player = tree.get_path_to(animation_player)
    tree.active = true
    var playback := tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
    if playback != null:
        playback.start("Locomotion")
    return true


static func _find_imported_animation(player: AnimationPlayer, wanted_name: String) -> Animation:
    for library_name in player.get_animation_library_list():
        var library := player.get_animation_library(library_name)
        if library != null and library.has_animation(wanted_name):
            return library.get_animation(wanted_name)
        if library != null:
            for animation_name in library.get_animation_list():
                if String(animation_name).to_lower().ends_with("/" + wanted_name.to_lower()) or String(animation_name).to_lower() == wanted_name.to_lower():
                    return library.get_animation(animation_name)
    return null


## Creates pivots around the independently modeled limbs exported in the current GLBs.
## These files do not contain Skeleton3D/animation clips; pivots give the split mesh parts
## a safe, deterministic runtime locomotion rig without pretending an imported skeleton exists.
static func _build_locomotion_rig(model: Node3D, resource_path: String) -> void:
    if model.find_child("MotionRig", false, false) != null:
        return
    var rig := Node3D.new()
    rig.name = "MotionRig"
    model.add_child(rig)
    var seated := resource_path.to_lower().contains("wheelchair")
    model.set_meta("locomotion_profile", "seated" if seated else "biped")

    if seated:
        _add_pivot_group(model, rig, "ArmL", Vector3(-0.22, 1.22, 0.0), ["left_upper_arm", "left_upper_arm_joint_a", "left_upper_arm_joint_b"])
        _add_pivot_group(model, rig, "ArmR", Vector3(0.22, 1.22, 0.0), ["right_upper_arm", "right_upper_arm_joint_a", "right_upper_arm_joint_b"])
        _add_pivot_group(model, rig, "ForearmL", Vector3(-0.29, 1.00, 0.04), ["left_forearm", "left_forearm_joint_a", "left_forearm_joint_b", "left_hand"])
        _add_pivot_group(model, rig, "ForearmR", Vector3(0.29, 1.00, 0.04), ["right_forearm", "right_forearm_joint_a", "right_forearm_joint_b", "right_hand"])
        _add_pivot_group(model, rig, "WheelL", Vector3(-0.29, 0.35, -0.05), ["left_wheel", "left_wheel_hub"])
        _add_pivot_group(model, rig, "WheelR", Vector3(0.29, 0.35, -0.05), ["right_wheel", "right_wheel_hub"])
        return

    _add_pivot_group(model, rig, "LegL", Vector3(-0.12, 0.88, 0.0), ["left_trouser_upper", "left_trouser_upper_joint_a"])
    _add_pivot_group(model, rig, "LegR", Vector3(0.12, 0.88, 0.0), ["right_trouser_upper", "right_trouser_upper_joint_a"])
    _add_pivot_group(model, rig, "ShinL", Vector3(-0.12, 0.48, 0.0), ["left_trouser_upper_joint_b", "left_knee", "left_trouser_lower", "left_trouser_lower_joint_a", "left_trouser_lower_joint_b", "left_boot"])
    _add_pivot_group(model, rig, "ShinR", Vector3(0.12, 0.48, 0.0), ["right_trouser_upper_joint_b", "right_knee", "right_trouser_lower", "right_trouser_lower_joint_a", "right_trouser_lower_joint_b", "right_boot"])
    _add_pivot_group(model, rig, "ArmL", Vector3(-0.22, 1.32, 0.0), ["left_upper_arm", "left_upper_arm_joint_a", "left_upper_arm_joint_b"])
    _add_pivot_group(model, rig, "ArmR", Vector3(0.22, 1.32, 0.0), ["right_upper_arm", "right_upper_arm_joint_a", "right_upper_arm_joint_b"])
    _add_pivot_group(model, rig, "ForearmL", Vector3(-0.29, 1.08, 0.04), ["left_forearm", "left_forearm_joint_a", "left_forearm_joint_b", "left_hand"])
    _add_pivot_group(model, rig, "ForearmR", Vector3(0.29, 1.08, 0.04), ["right_forearm", "right_forearm_joint_a", "right_forearm_joint_b", "right_hand"])


static func _add_pivot_group(model: Node3D, rig: Node3D, pivot_name: String, pivot_position: Vector3, part_names: Array[String]) -> void:
    var pivot := Node3D.new()
    pivot.name = pivot_name
    # Pivot coordinates are authored in normalized target-height metres, while
    # the imported GLB root retains its original import scale. Compensate for
    # that root scale so elbows/knees remain at the correct visible joint height.
    var root_scale := maxf(absf(model.scale.y), 0.001)
    pivot.position = pivot_position / root_scale
    rig.add_child(pivot)
    for part_name in part_names:
        var part := model.find_child(part_name, true, false) as Node3D
        if part != null and part != pivot and part != rig:
            part.reparent(pivot, true)


## Creates actual AnimationPlayer clips and an AnimationTree for the mesh-part pivots.
## This is a procedural pose rig because the current GLBs are unskinned static meshes.
static func _build_animation_tree(model: Node3D) -> void:
    if model.get_node_or_null("LocomotionAnimationTree") != null:
        return
    var profile := str(model.get_meta("locomotion_profile", "biped"))
    var library := AnimationLibrary.new()
    library.add_animation("Idle", _make_pose_animation("Idle", 1.4, true, _pose_tracks(profile, "idle")))
    library.add_animation("Walk", _make_pose_animation("Walk", 0.72, true, _pose_tracks(profile, "walk")))
    library.add_animation("Run", _make_pose_animation("Run", 0.50, true, _pose_tracks(profile, "run")))
    library.add_animation("Jump", _make_pose_animation("Jump", 0.56, false, _pose_tracks(profile, "jump")))

    var animation_player := AnimationPlayer.new()
    animation_player.name = "AnimationPlayer"
    animation_player.root_node = NodePath("..")
    animation_player.add_animation_library("locomotion", library)
    model.add_child(animation_player)

    var blend_space := AnimationNodeBlendSpace1D.new()
    blend_space.min_space = 0.0
    blend_space.max_space = 1.0
    blend_space.value_label = "Locomotion Speed"
    blend_space.sync_mode = AnimationNodeBlendSpace1D.SYNC_MODE_CYCLIC_MUTABLE
    for blend_data in [["Idle", 0.0], ["Walk", 0.56], ["Run", 1.0]]:
        var animation_node := AnimationNodeAnimation.new()
        animation_node.animation = "locomotion/" + str(blend_data[0])
        blend_space.add_blend_point(animation_node, float(blend_data[1]))

    # Nest the BlendSpace in a BlendTree so stride cadence can react to real movement speed.
    var locomotion_graph := AnimationNodeBlendTree.new()
    locomotion_graph.add_node("StrideBlendSpace", blend_space, Vector2(-180.0, 0.0))
    var stride_time_scale := AnimationNodeTimeScale.new()
    locomotion_graph.add_node("StrideTimeScale", stride_time_scale, Vector2(40.0, 0.0))
    locomotion_graph.connect_node("StrideTimeScale", 0, "StrideBlendSpace")
    locomotion_graph.connect_node("output", 0, "StrideTimeScale")

    var state_machine := AnimationNodeStateMachine.new()
    state_machine.add_node("Locomotion", locomotion_graph, Vector2(0.0, 0.0))
    var jump_node := AnimationNodeAnimation.new()
    jump_node.animation = "locomotion/Jump"
    state_machine.add_node("Jump", jump_node, Vector2(220.0, 0.0))
    # Godot 4.7 state machines expose built-in Start/End states; use an explicit
    # Start -> Locomotion edge instead of the removed set_start_node() API.
    var start_to_locomotion := AnimationNodeStateMachineTransition.new()
    start_to_locomotion.xfade_time = 0.0
    state_machine.add_transition("Start", "Locomotion", start_to_locomotion)
    var to_jump := AnimationNodeStateMachineTransition.new()
    to_jump.xfade_time = 0.12
    state_machine.add_transition("Locomotion", "Jump", to_jump)
    var to_locomotion := AnimationNodeStateMachineTransition.new()
    to_locomotion.xfade_time = 0.16
    state_machine.add_transition("Jump", "Locomotion", to_locomotion)

    var animation_tree := AnimationTree.new()
    animation_tree.name = "LocomotionAnimationTree"
    animation_tree.anim_player = NodePath("../AnimationPlayer")
    animation_tree.tree_root = state_machine
    animation_tree.active = true
    model.add_child(animation_tree)
    model.set_meta("has_locomotion_animation_tree", true)


static func _pose_tracks(profile: String, clip: String) -> Array[Dictionary]:
    var tracks: Array[Dictionary] = []
    if profile == "seated":
        var left_wheel := [0.0, PI * 0.5, PI, PI * 1.5, TAU]
        var right_wheel := [0.0, PI * 0.5, PI, PI * 1.5, TAU]
        var movement_scale := 0.0
        if clip == "walk": movement_scale = 0.78
        elif clip == "run": movement_scale = 1.0
        elif clip == "jump": movement_scale = 0.0
        tracks.append({"node": "WheelL", "values": left_wheel.map(func(v): return float(v) * movement_scale)})
        tracks.append({"node": "WheelR", "values": right_wheel.map(func(v): return float(v) * movement_scale)})
        if clip == "jump":
            tracks.append({"node": "ArmL", "values": [0.0, -0.16, -0.24, -0.10, 0.0]})
            tracks.append({"node": "ArmR", "values": [0.0, -0.16, -0.24, -0.10, 0.0]})
            tracks.append({"node": "ForearmL", "values": [0.0, 0.12, 0.18, 0.10, 0.0]})
            tracks.append({"node": "ForearmR", "values": [0.0, 0.12, 0.18, 0.10, 0.0]})
        else:
            var arm_amplitude := 0.05 if clip == "idle" else (0.14 if clip == "walk" else 0.19)
            tracks.append({"node": "ArmL", "values": [0.0, arm_amplitude, 0.0, -arm_amplitude, 0.0]})
            tracks.append({"node": "ArmR", "values": [0.0, arm_amplitude, 0.0, -arm_amplitude, 0.0]})
            tracks.append({"node": "ForearmL", "values": [0.09, 0.12, 0.09, 0.06, 0.09]})
            tracks.append({"node": "ForearmR", "values": [0.09, 0.12, 0.09, 0.06, 0.09]})
        return tracks

    match clip:
        "idle":
            tracks.append({"node": "ArmL", "values": [0.0, -0.018, 0.0, 0.018, 0.0]})
            tracks.append({"node": "ArmR", "values": [0.0, -0.018, 0.0, 0.018, 0.0]})
            tracks.append({"node": "ForearmL", "values": [0.08, 0.085, 0.08, 0.075, 0.08]})
            tracks.append({"node": "ForearmR", "values": [0.08, 0.085, 0.08, 0.075, 0.08]})
        "walk", "run":
            var leg_amplitude := 0.46 if clip == "walk" else 0.68
            var knee_amplitude := 0.30 if clip == "walk" else 0.46
            var arm_amplitude := 0.28 if clip == "walk" else 0.42
            tracks.append({"node": "LegL", "values": [0.0, leg_amplitude, 0.0, -leg_amplitude, 0.0]})
            tracks.append({"node": "LegR", "values": [0.0, -leg_amplitude, 0.0, leg_amplitude, 0.0]})
            tracks.append({"node": "ShinL", "values": [0.0, knee_amplitude, 0.0, 0.05, 0.0]})
            tracks.append({"node": "ShinR", "values": [0.0, 0.05, 0.0, knee_amplitude, 0.0]})
            tracks.append({"node": "ArmL", "values": [0.0, -arm_amplitude, 0.0, arm_amplitude, 0.0]})
            tracks.append({"node": "ArmR", "values": [0.0, arm_amplitude, 0.0, -arm_amplitude, 0.0]})
            var forearm_bend: float = 0.12 if clip == "walk" else 0.19
            tracks.append({"node": "ForearmL", "values": [0.06, forearm_bend, 0.08, 0.05, 0.06]})
            tracks.append({"node": "ForearmR", "values": [0.06, 0.05, 0.08, forearm_bend, 0.06]})
        "jump":
            tracks.append({"node": "LegL", "values": [0.0, -0.14, -0.22, -0.12, 0.0]})
            tracks.append({"node": "LegR", "values": [0.0, -0.14, -0.22, -0.12, 0.0]})
            tracks.append({"node": "ShinL", "values": [0.0, 0.10, 0.16, 0.05, 0.0]})
            tracks.append({"node": "ShinR", "values": [0.0, 0.10, 0.16, 0.05, 0.0]})
            tracks.append({"node": "ArmL", "values": [0.0, -0.30, -0.48, -0.26, 0.0]})
            tracks.append({"node": "ArmR", "values": [0.0, -0.30, -0.48, -0.26, 0.0]})
            tracks.append({"node": "ForearmL", "values": [0.06, 0.20, 0.28, 0.12, 0.06]})
            tracks.append({"node": "ForearmR", "values": [0.06, 0.20, 0.28, 0.12, 0.06]})
    return tracks


static func _make_pose_animation(animation_name: String, duration: float, looping: bool, tracks: Array[Dictionary]) -> Animation:
    var animation := Animation.new()
    animation.resource_name = animation_name
    animation.length = duration
    animation.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
    var sample_times := [0.0, duration * 0.25, duration * 0.50, duration * 0.75, duration]
    for track_data in tracks:
        var track_idx := animation.add_track(Animation.TYPE_VALUE)
        animation.track_set_path(track_idx, NodePath("MotionRig/" + str(track_data["node"]) + ":rotation"))
        animation.value_track_set_update_mode(track_idx, Animation.UPDATE_CONTINUOUS)
        var values: Array = track_data["values"]
        for key_idx in range(mini(values.size(), sample_times.size())):
            animation.track_insert_key(track_idx, float(sample_times[key_idx]), Vector3(float(values[key_idx]), 0.0, 0.0))
    return animation


## Drives AnimationTree blending when available; retains procedural fallback for malformed/import-incomplete models.
static func apply_locomotion(model: Node3D, gait_blend: float, run_blend: float, phase: float, airborne: bool = false) -> void:
    var animation_tree := model.get_node_or_null("LocomotionAnimationTree") as AnimationTree
    if animation_tree != null and animation_tree.active:
        var gait := clampf(gait_blend, 0.0, 1.0)
        var run := clampf(run_blend, 0.0, 1.0)
        if bool(model.get_meta("has_skeletal_animation_tree", false)):
            # Imported GLB uses true Skeleton3D clips: Idle @ 0, Walk @ 1, Run @ 2.
            animation_tree.set("parameters/Locomotion/blend_position", clampf(gait * (1.0 + run), 0.0, 2.0))
        else:
            # Legacy fallback animates separated mesh pivots through a nested BlendTree.
            animation_tree.set("parameters/Locomotion/StrideBlendSpace/blend_position", clampf(gait * (0.56 + 0.44 * run), 0.0, 1.0))
            animation_tree.set("parameters/Locomotion/StrideTimeScale/scale", clampf(0.82 + gait * 0.28 + run * 0.20, 0.82, 1.30))
        var playback := animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
        if playback != null:
            var current_state := String(playback.get_current_node())
            if current_state.is_empty() or current_state == "Start":
                playback.start("Locomotion")
                current_state = "Locomotion"
            if airborne and current_state != "Jump":
                playback.travel("Jump")
            elif not airborne and current_state == "Jump":
                playback.travel("Locomotion")
        return

    var rig := model.get_node_or_null("MotionRig") as Node3D
    if rig == null:
        return
    var gait := clampf(gait_blend, 0.0, 1.0)
    var run := clampf(run_blend, 0.0, 1.0)
    var swing_amplitude := lerpf(0.34, 0.58, run)
    var left_swing := sin(phase) * swing_amplitude * gait
    var right_swing := sin(phase + PI) * swing_amplitude * gait
    if airborne:
        left_swing = -0.12
        right_swing = -0.12
    if str(model.get_meta("locomotion_profile", "biped")) == "seated":
        _set_pivot_x(rig, "WheelL", phase * gait * 0.18)
        _set_pivot_x(rig, "WheelR", phase * gait * 0.18)
        _set_pivot_x(rig, "ArmL", -0.13 * gait + left_swing * 0.22)
        _set_pivot_x(rig, "ArmR", -0.13 * gait + right_swing * 0.22)
        _set_pivot_x(rig, "ForearmL", 0.12 * gait)
        _set_pivot_x(rig, "ForearmR", 0.12 * gait)
        return
    _set_pivot_x(rig, "LegL", left_swing)
    _set_pivot_x(rig, "LegR", right_swing)
    _set_pivot_x(rig, "ShinL", maxf(0.0, -sin(phase)) * 0.40 * gait)
    _set_pivot_x(rig, "ShinR", maxf(0.0, -sin(phase + PI)) * 0.40 * gait)
    _set_pivot_x(rig, "ArmL", -left_swing * 0.72 + sin(phase * 0.5) * 0.012)
    _set_pivot_x(rig, "ArmR", -right_swing * 0.72 - sin(phase * 0.5) * 0.012)
    _set_pivot_x(rig, "ForearmL", 0.10 * gait + maxf(0.0, -sin(phase)) * 0.08 * gait)
    _set_pivot_x(rig, "ForearmR", 0.10 * gait + maxf(0.0, -sin(phase + PI)) * 0.08 * gait)


static func _set_pivot_x(rig: Node3D, pivot_name: String, angle: float) -> void:
    var pivot := rig.get_node_or_null(pivot_name) as Node3D
    if pivot != null:
        pivot.rotation.x = angle
