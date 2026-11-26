extends CharacterBody3D
class_name CityTrafficVehicle

## Kinematic traffic vehicle for Godot 4.7.
## NavigationAgent3D supplies a route corridor; pure-pursuit steering follows that
## corridor while the body advances with move_and_slide(). The wheels are visual
## children of independent steering and rolling pivots.

const ROUTE_SAMPLE_SPACING: float = 0.35
const NAV_GOAL_AHEAD_METERS: float = 16.0
const NAV_GOAL_REFRESH_METERS: float = 8.0
const MIN_LOOKAHEAD_METERS: float = 4.5
const MAX_LOOKAHEAD_METERS: float = 7.5
const MAX_STEER_ANGLE: float = 0.48
const STEER_RESPONSE: float = 2.8
const VEHICLE_ACCELERATION: float = 2.8
const VEHICLE_BRAKING: float = 7.5
const STOP_PLANNING_DECELERATION: float = 6.0

var navigation_agent: NavigationAgent3D
var route_points: Array[Vector3] = []
var route_key: StringName = &""
var route_progress: float = 0.0
var cruise_speed: float = 3.5
var current_speed: float = 0.0
var wheelbase: float = 2.65
var route_sample_spacing: float = ROUTE_SAMPLE_SPACING
var steering_nodes: Array[Node3D] = []
var wheel_spin_nodes: Array[Node3D] = []
var front_obstacle_ray: RayCast3D
var engine_audio: AudioStreamPlayer3D

var _current_steering_angle: float = 0.0
var _last_navigation_goal_progress: float = -1.0
var _navigation_retry_timer: float = 0.0
var _flood_intensity: float = 0.0


func _ready() -> void:
	add_to_group("traffic_vehicle")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	floor_snap_length = 0.0
	floor_stop_on_slope = true
	max_slides = 4
	
	navigation_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	front_obstacle_ray = get_node_or_null("FrontObstacleRay") as RayCast3D
	_collect_wheel_nodes()
	_build_engine_audio()


func _build_engine_audio() -> void:
	if engine_audio != null and is_instance_valid(engine_audio):
		return
	engine_audio = AudioStreamPlayer3D.new()
	engine_audio.name = "VehicleEngineAudio"
	engine_audio.stream = preload("res://assets/audio/vehicle_engine_loop.wav")
	var engine_stream := engine_audio.stream as AudioStreamWAV
	if engine_stream != null:
		engine_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		engine_stream.loop_begin = 0
		engine_stream.loop_end = int(engine_stream.mix_rate * engine_stream.get_length())
	engine_audio.volume_db = -60.0
	engine_audio.pitch_scale = 0.78
	engine_audio.unit_size = 8.0
	engine_audio.max_distance = 42.0
	engine_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(engine_audio)
	engine_audio.play()


func _update_engine_audio() -> void:
	if engine_audio == null or not is_instance_valid(engine_audio):
		return
	if not AudioManager.gameplay_audio_enabled:
		engine_audio.volume_db = -60.0
		return
	var speed_ratio := clampf(current_speed / maxf(cruise_speed, 0.1), 0.0, 1.2)
	engine_audio.volume_db = lerpf(-24.0, -12.5, clampf(speed_ratio, 0.0, 1.0)) + AudioManager.get_sfx_db()
	engine_audio.pitch_scale = lerpf(0.78, 1.32, clampf(speed_ratio, 0.0, 1.0))


func configure_traffic_route(
	path: Array[Vector3],
	start_index: int,
	new_route_key: String,
	new_cruise_speed: float,
	navigation_layer_mask: int
) -> void:
	route_points = path
	route_progress = float(start_index)
	route_key = StringName(new_route_key)
	cruise_speed = maxf(new_cruise_speed, 0.1)
	current_speed = 0.0
	wheelbase = maxf(float(get_meta("traffic_wheelbase", 2.65)), 1.8)
	
	if navigation_agent == null:
		navigation_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if navigation_agent != null:
		navigation_agent.navigation_layers = navigation_layer_mask
		navigation_agent.path_desired_distance = 1.2
		navigation_agent.target_desired_distance = 1.6
		navigation_agent.avoidance_enabled = false
		_set_navigation_goal(true)

	_collect_wheel_nodes()


func set_route_progress(value: float) -> void:
	if route_points.is_empty():
		route_progress = 0.0
		return
	route_progress = fposmod(value, float(route_points.size()))
	_set_navigation_goal(false)


func set_flood_intensity(value: float) -> void:
	_flood_intensity = clampf(value, 0.0, 1.0)


## Called by CityWorld once per physics frame, after signal and queue limits
## have been calculated. Returns horizontal distance actually travelled.
## Called by CityWorld when a red/all-red/conflicting phase requires a stop.
## Returns a conservative target speed that leaves a fixed hold margin before the stop line.
func limit_speed_for_stop_line(requested_speed: float, distance_to_stop_line: float, hold_margin: float = 1.25) -> float:
	var anticipation: float = maxf(current_speed, 0.0) * 0.22
	var available_braking_distance: float = distance_to_stop_line - hold_margin - anticipation
	if available_braking_distance <= 0.0:
		return 0.0
	var braking_speed: float = sqrt(maxf(0.0, 2.0 * STOP_PLANNING_DECELERATION * available_braking_distance))
	return minf(maxf(requested_speed, 0.0), braking_speed)


func drive_step(delta: float, requested_speed: float) -> float:
	if delta <= 0.0 or route_points.size() < 3:
		return 0.0

	# Flooding affects the whole traffic network. Stop-line constraints are computed
	# by CityWorld first; this multiplier only reduces the remaining travel speed.
	var flood_multiplier := lerpf(1.0, 0.58, _flood_intensity)
	requested_speed = maxf(requested_speed, 0.0) * flood_multiplier
	_set_navigation_goal(false)
	var steering_target: Vector3 = _get_navigation_lookahead_target(delta)
	var local_target: Vector3 = to_local(steering_target)
	local_target.y = 0.0
	var lookahead_distance: float = Vector2(local_target.x, local_target.z).length()

	# If navigation data is still synchronizing, or the agent has not produced a
	# usable path yet, use the authored lane as a deterministic short-term fallback.
	if lookahead_distance < 1.0 or local_target.z > 0.25:
		steering_target = _route_point_world(
			route_progress + MIN_LOOKAHEAD_METERS / route_sample_spacing
		)
		local_target = to_local(steering_target)
		local_target.y = 0.0
		lookahead_distance = Vector2(local_target.x, local_target.z).length()

	lookahead_distance = clampf(lookahead_distance, MIN_LOOKAHEAD_METERS, MAX_LOOKAHEAD_METERS)
	var alpha: float = atan2(-local_target.x, -local_target.z)
	var desired_steering: float = atan(
		(2.0 * wheelbase * sin(alpha)) / maxf(lookahead_distance, 0.5)
	)
	desired_steering = clampf(desired_steering, -MAX_STEER_ANGLE, MAX_STEER_ANGLE)
	_current_steering_angle = move_toward(
		_current_steering_angle,
		desired_steering,
		STEER_RESPONSE * delta
	)

	# Use the same steering command for both front wheels and chassis curvature.
	# The body can only yaw while moving; a stopped car cannot spin in place.
	var safe_wheelbase: float = maxf(wheelbase, 1.8)
	current_speed = move_toward(
		current_speed,
		maxf(requested_speed, 0.0),
		(VEHICLE_ACCELERATION if requested_speed > current_speed else VEHICLE_BRAKING) * delta
	)
	var yaw_rate: float = (current_speed / safe_wheelbase) * tan(_current_steering_angle)
	rotation = Vector3(0.0, wrapf(rotation.y + yaw_rate * delta, -PI, PI), 0.0)

	for steering_node in steering_nodes:
		if is_instance_valid(steering_node):
			steering_node.rotation.y = _current_steering_angle

	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	velocity = Vector3(forward.x * current_speed, 0.0, forward.z * current_speed)
	move_and_slide()

	# Respect a physical collision with another car instead of maintaining a hidden
	# cruise speed while pinned against it. The manager will safely accelerate again.
	if get_slide_collision_count() > 0:
		var post_move_forward: Vector3 = -global_transform.basis.z
		post_move_forward.y = 0.0
		post_move_forward = post_move_forward.normalized()
		var projected_speed: float = Vector3(velocity.x, 0.0, velocity.z).dot(post_move_forward)
		current_speed = clampf(projected_speed, 0.0, current_speed)

	var travelled: Vector3 = get_position_delta()
	travelled.y = 0.0
	var travelled_distance: float = travelled.length()
	_update_engine_audio()
	if travelled_distance > 0.0005:
		var roll_angle: float = travelled_distance / 0.26
		for spin_node in wheel_spin_nodes:
			if is_instance_valid(spin_node):
				spin_node.rotation.x = wrapf(spin_node.rotation.x + roll_angle, -PI, PI)

	return travelled_distance


func _set_navigation_goal(force: bool) -> void:
	if navigation_agent == null or route_points.size() < 3:
		return

	var progressed_distance: float = 0.0
	if _last_navigation_goal_progress >= 0.0:
		progressed_distance = fposmod(
			route_progress - _last_navigation_goal_progress,
			float(route_points.size())
		) * route_sample_spacing

	if force or _last_navigation_goal_progress < 0.0 or progressed_distance >= NAV_GOAL_REFRESH_METERS:
		var goal_local: Vector3 = _route_point_local(
			route_progress + NAV_GOAL_AHEAD_METERS / route_sample_spacing
		)
		var parent_node: Node3D = get_parent() as Node3D
		if is_instance_valid(parent_node):
			navigation_agent.target_position = parent_node.to_global(goal_local)
			_last_navigation_goal_progress = route_progress


func _get_navigation_lookahead_target(delta: float) -> Vector3:
	var route_fallback: Vector3 = _route_point_world(
		route_progress + MIN_LOOKAHEAD_METERS / route_sample_spacing
	)
	if navigation_agent == null:
		return route_fallback

	# Godot requires this call every physics frame to advance NavigationAgent state.
	var _next_navigation_position: Vector3 = navigation_agent.get_next_path_position()
	var nav_path: PackedVector3Array = navigation_agent.get_current_navigation_path()
	if nav_path.size() < 2:
		_navigation_retry_timer -= delta
		if _navigation_retry_timer <= 0.0:
			# Reissue a slightly advanced goal only while no nav path exists.
			# This covers the first-frame NavigationServer map synchronization case.
			navigation_agent.target_position = _route_point_world(
				route_progress + (NAV_GOAL_AHEAD_METERS + 0.4) / route_sample_spacing
			)
			_navigation_retry_timer = 1.0
		return route_fallback

	var current_index: int = clampi(
		navigation_agent.get_current_navigation_path_index(),
		1,
		nav_path.size() - 1
	)
	var previous_point: Vector3 = global_position
	var accumulated_distance: float = 0.0
	var lookahead_distance: float = clampf(
		MIN_LOOKAHEAD_METERS + current_speed * 0.35,
		MIN_LOOKAHEAD_METERS,
		MAX_LOOKAHEAD_METERS
	)
	for path_index in range(current_index, nav_path.size()):
		var candidate: Vector3 = nav_path[path_index]
		candidate.y = global_position.y
		accumulated_distance += previous_point.distance_to(candidate)
		previous_point = candidate
		if accumulated_distance >= lookahead_distance:
			return candidate

	var final_point: Vector3 = nav_path[nav_path.size() - 1]
	final_point.y = global_position.y
	if final_point.distance_to(global_position) > 1.0:
		return final_point
	return route_fallback


func _route_point_local(progress: float) -> Vector3:
	if route_points.is_empty():
		return Vector3.ZERO
	var wrapped: float = fposmod(progress, float(route_points.size()))
	var first_index: int = floori(wrapped)
	var fraction: float = wrapped - float(first_index)
	return route_points[first_index].lerp(route_points[(first_index + 1) % route_points.size()], fraction)


func _route_point_world(progress: float) -> Vector3:
	var local_point: Vector3 = _route_point_local(progress)
	var parent_node: Node3D = get_parent() as Node3D
	if is_instance_valid(parent_node):
		return parent_node.to_global(local_point)
	return local_point


func _collect_wheel_nodes() -> void:
	steering_nodes.clear()
	wheel_spin_nodes.clear()
	for node in find_children("*", "Node3D", true, false):
		if not node is Node3D:
			continue
		var wheel_node: Node3D = node as Node3D
		if wheel_node.is_in_group("traffic_front_steering"):
			steering_nodes.append(wheel_node)
		if wheel_node.is_in_group("traffic_wheel_spin"):
			wheel_spin_nodes.append(wheel_node)
