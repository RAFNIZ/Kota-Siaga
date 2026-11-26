extends Node

## Project-wide audio controller.
## Dedicated BGM players are intentionally separate from ambience and weather loops,
## so the menu and gameplay always have a melodic backing track under their sound beds.

const MENU_BGM := preload("res://assets/audio/bgm_menu.wav")
const GAMEPLAY_BGM := preload("res://assets/audio/bgm_gameplay.wav")
const MENU_AMBIENCE := preload("res://assets/audio/menu_ambient.wav")
const CITY_AMBIENCE := preload("res://assets/audio/city_ambience.wav")
const UI_HOVER := preload("res://assets/audio/ui_hover.wav")
const UI_CONFIRM := preload("res://assets/audio/ui_confirm.wav")
const UI_BACK := preload("res://assets/audio/ui_back.wav")
const FOOTSTEP_WALK := preload("res://assets/audio/footstep.wav")
const FOOTSTEP_RUN := preload("res://assets/audio/footstep_run.wav")
const PLAYER_JUMP := preload("res://assets/audio/player_jump.wav")
const PLAYER_LAND := preload("res://assets/audio/player_land.wav")
const INTERACT := preload("res://assets/audio/interact.wav")
const DISASTER_ALERT := preload("res://assets/audio/disaster_alert.wav")
const SIREN_RELAY := preload("res://assets/audio/siren_relay.wav")
const RAIN_LOOP := preload("res://assets/audio/rain_loop.wav")
const WIND_LOOP := preload("res://assets/audio/wind_loop.wav")
const FLOOD_LOOP := preload("res://assets/audio/flood_loop.wav")
const TORNADO_LOOP := preload("res://assets/audio/tornado_loop.wav")

const SFX_POOL_SIZE := 12
const MAX_WORLD_FOOTSTEPS := 6
const MENU_BGM_GAIN := 0.78
const GAMEPLAY_BGM_GAIN := 0.72
const MENU_AMBIENCE_GAIN := 0.12
const CITY_AMBIENCE_GAIN := 0.20

var master_volume: float = 0.82
var music_volume: float = 0.72
var sfx_volume: float = 0.78
var gameplay_audio_enabled: bool = false

var bgm_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var weather_primary_player: AudioStreamPlayer
var weather_secondary_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var world_footstep_players: Array[AudioStreamPlayer3D] = []

var _sfx_cursor: int = 0
var _desired_bgm_stream: AudioStream
var _desired_ambience_stream: AudioStream
var _desired_bgm_gain: float = 0.0
var _desired_ambience_gain: float = 0.0
var _weather_primary_gain_scale: float = 0.0
var _weather_secondary_gain_scale: float = 0.0
var _weather_primary_stream: AudioStream
var _weather_secondary_stream: AudioStream
var _loop_tweens: Dictionary = {}
var _master_bus_index: int = 0
var _volume_config := ConfigFile.new()
var _watchdog_elapsed: float = 0.0
var _last_hover_ms: int = -1000
var _last_disaster_alert_key: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_master_bus_index = AudioServer.get_bus_index("Master")
	_load_volume_settings()

	for stream in [MENU_BGM, GAMEPLAY_BGM, MENU_AMBIENCE, CITY_AMBIENCE, RAIN_LOOP, WIND_LOOP, FLOOD_LOOP, TORNADO_LOOP, preload("res://assets/audio/vehicle_engine_loop.wav")]:
		_make_loop(stream)

	bgm_player = _create_2d_player("BackgroundMusic", -60.0)
	ambience_player = _create_2d_player("WorldAmbience", -60.0)
	weather_primary_player = _create_2d_player("WeatherPrimary", -60.0)
	weather_secondary_player = _create_2d_player("WeatherSecondary", -60.0)

	for index in range(SFX_POOL_SIZE):
		sfx_players.append(_create_2d_player("SFX_%02d" % index, -60.0))

	_apply_master_volume()
	# Start menu music immediately from the autoload. Main.gd may call this again;
	# set_game_mode is idempotent and will not restart an already-playing track.
	set_game_mode(false)


func _process(delta: float) -> void:
	# Recover from an unexpected AudioStreamPlayer stop (for example after an import
	# refresh) instead of leaving the game silent until the next scene transition.
	_watchdog_elapsed += delta
	if _watchdog_elapsed >= 0.75:
		_watchdog_elapsed = 0.0
		if music_volume > 0.0001 and _desired_bgm_stream != null:
			if bgm_player != null and not bgm_player.playing:
				_start_loop(bgm_player, _desired_bgm_stream, _desired_bgm_gain, 0.65)
		if music_volume > 0.0001 and _desired_ambience_stream != null:
			if ambience_player != null and not ambience_player.playing:
				_start_loop(ambience_player, _desired_ambience_stream, _desired_ambience_gain, 0.7)


func _create_2d_player(player_name: String, initial_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.volume_db = initial_db
	add_child(player)
	return player


func _make_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.mix_rate * wav.get_length())


func set_game_mode(in_game: bool) -> void:
	gameplay_audio_enabled = in_game
	_desired_bgm_stream = GAMEPLAY_BGM if in_game else MENU_BGM
	_desired_ambience_stream = CITY_AMBIENCE if in_game else MENU_AMBIENCE
	_desired_bgm_gain = music_volume * (GAMEPLAY_BGM_GAIN if in_game else MENU_BGM_GAIN)
	_desired_ambience_gain = music_volume * (CITY_AMBIENCE_GAIN if in_game else MENU_AMBIENCE_GAIN)

	_transition_loop(bgm_player, _desired_bgm_stream, _desired_bgm_gain, 1.35)
	_transition_loop(ambience_player, _desired_ambience_stream, _desired_ambience_gain, 1.7)

	if not in_game:
		set_disaster_audio(0, false)


func set_disaster_audio(level: int, active: bool) -> void:
	if weather_primary_player == null or weather_secondary_player == null:
		return

	if not gameplay_audio_enabled or level <= 0:
		_weather_primary_gain_scale = 0.0
		_weather_secondary_gain_scale = 0.0
		_weather_primary_stream = null
		_weather_secondary_stream = null
		_transition_loop(weather_primary_player, null, 0.0, 1.0)
		_transition_loop(weather_secondary_player, null, 0.0, 1.0)
		_last_disaster_alert_key = ""
		return

	var primary: AudioStream = null
	var secondary: AudioStream = null
	var primary_scale := 0.0
	var secondary_scale := 0.0

	if not active:
		# Keep a quieter water bed after the flood's impact until the stage clears.
		if level == 2:
			secondary = FLOOD_LOOP
			secondary_scale = 0.13
	else:
		match level:
			1:
				primary = RAIN_LOOP
				primary_scale = 0.30
			2:
				primary = RAIN_LOOP
				secondary = FLOOD_LOOP
				primary_scale = 0.34
				secondary_scale = 0.34
			3:
				primary = WIND_LOOP
				secondary = TORNADO_LOOP
				primary_scale = 0.36
				secondary_scale = 0.36

	var alert_key := "%d_%s" % [level, str(active)]
	if active and alert_key != _last_disaster_alert_key:
		play_disaster_alert()
	_last_disaster_alert_key = alert_key

	_weather_primary_gain_scale = primary_scale
	_weather_secondary_gain_scale = secondary_scale
	_weather_primary_stream = primary
	_weather_secondary_stream = secondary
	_transition_loop(weather_primary_player, primary, sfx_volume * primary_scale, 1.25)
	_transition_loop(weather_secondary_player, secondary, sfx_volume * secondary_scale, 1.55)


func _transition_loop(player: AudioStreamPlayer, stream: AudioStream, gain: float, duration: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	var tween_key := player.get_instance_id()
	var previous_tween: Tween = _loop_tweens.get(tween_key) as Tween
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()

	var target_db := _gain_to_db(gain)
	if stream == null:
		if not player.playing:
			player.stream = null
			player.volume_db = -60.0
			return
		var stop_tween := create_tween()
		_loop_tweens[tween_key] = stop_tween
		stop_tween.tween_property(player, "volume_db", -60.0, maxf(duration, 0.08))
		stop_tween.tween_callback(func():
			if is_instance_valid(player):
				player.stop()
				player.stream = null
		)
		return

	if player.stream == stream and player.playing:
		var level_tween := create_tween()
		_loop_tweens[tween_key] = level_tween
		level_tween.tween_property(player, "volume_db", target_db, maxf(duration, 0.08))
		return

	if not player.playing:
		_start_loop(player, stream, gain, duration)
		return

	var switch_tween := create_tween()
	_loop_tweens[tween_key] = switch_tween
	switch_tween.tween_property(player, "volume_db", -54.0, minf(0.42, duration * 0.40))
	switch_tween.tween_callback(func():
		if not is_instance_valid(player):
			return
		player.stop()
		player.stream = stream
		player.volume_db = -54.0
		player.play()
	)
	switch_tween.tween_property(player, "volume_db", target_db, maxf(0.15, duration * 0.72))


func _start_loop(player: AudioStreamPlayer, stream: AudioStream, gain: float, fade_in: float) -> void:
	if player == null or not is_instance_valid(player) or stream == null:
		return
	player.stop()
	player.stream = stream
	player.volume_db = -54.0
	player.play()
	var tween_key := player.get_instance_id()
	var previous_tween: Tween = _loop_tweens.get(tween_key) as Tween
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	var tween := create_tween()
	_loop_tweens[tween_key] = tween
	tween.tween_property(player, "volume_db", _gain_to_db(gain), maxf(fade_in, 0.08))


func play_ui_hover() -> void:
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_hover_ms < 75:
		return
	_last_hover_ms = now_ms
	_play_sfx(UI_HOVER, -16.0, randf_range(0.96, 1.04))


func play_ui_open() -> void:
	_play_sfx(UI_CONFIRM, -8.5, 0.92)


func play_ui_confirm() -> void:
	_play_sfx(UI_CONFIRM, -7.0, randf_range(0.97, 1.03))


func play_ui_back() -> void:
	_play_sfx(UI_BACK, -8.5, 1.0)


func play_notification() -> void:
	_play_sfx(UI_CONFIRM, -18.0, 0.92)


func play_stage_transition() -> void:
	_play_sfx(UI_CONFIRM, -7.5, 0.84)


func play_disaster_alert() -> void:
	_play_sfx(DISASTER_ALERT, -8.0, 1.0)


func play_siren_relay_at(world_position: Vector3) -> void:
	_play_world_one_shot(SIREN_RELAY, world_position, -8.0, 1.0)


func play_interaction_at(world_position: Vector3) -> void:
	_play_world_one_shot(INTERACT, world_position, -11.0, 1.0)


func play_jump_at(world_position: Vector3) -> void:
	_play_world_one_shot(PLAYER_JUMP, world_position, -13.0, 1.0)


func play_land_at(world_position: Vector3, running: bool = false) -> void:
	_play_world_one_shot(PLAYER_LAND, world_position, -11.0 if running else -14.0, randf_range(0.96, 1.04))


func play_footstep_at(world_position: Vector3, running: bool = false, is_npc: bool = false) -> void:
	if not gameplay_audio_enabled:
		return
	var listener := get_tree().get_first_node_in_group("player") as Node3D
	if is_npc and is_instance_valid(listener) and listener.global_position.distance_to(world_position) > 17.0:
		return
	world_footstep_players = world_footstep_players.filter(func(item): return is_instance_valid(item))
	if world_footstep_players.size() >= MAX_WORLD_FOOTSTEPS:
		return
	var stream: AudioStream = FOOTSTEP_RUN if running else FOOTSTEP_WALK
	var volume_db := -21.0 if is_npc else (-11.0 if running else -14.0)
	_play_world_one_shot(stream, world_position, volume_db, randf_range(0.92, 1.08), true)


func _play_world_one_shot(
	stream: AudioStream,
	world_position: Vector3,
	volume_db: float,
	pitch: float,
	is_footstep: bool = false
) -> void:
	if not gameplay_audio_enabled:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.name = "OneShotWorldAudio"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.stream = stream
	player.volume_db = volume_db + _gain_to_db(sfx_volume)
	player.pitch_scale = pitch
	player.max_distance = 22.0 if is_footstep else 34.0
	player.unit_size = 7.0 if is_footstep else 9.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	scene.add_child(player)
	player.global_position = world_position
	if is_footstep:
		world_footstep_players.append(player)
	player.finished.connect(player.queue_free)
	player.play()


func _play_sfx(stream: AudioStream, base_db: float, pitch: float) -> void:
	if sfx_players.is_empty() or sfx_volume <= 0.0001:
		return
	var player: AudioStreamPlayer = sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % sfx_players.size()
	player.stop()
	player.stream = stream
	player.volume_db = base_db + _gain_to_db(sfx_volume)
	player.pitch_scale = pitch
	player.play()


func get_master_volume() -> float:
	return master_volume


func get_music_volume() -> float:
	return music_volume


func get_sfx_volume() -> float:
	return sfx_volume


func get_sfx_db() -> float:
	return _gain_to_db(sfx_volume)


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_master_volume()
	_save_volume_settings()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_desired_bgm_gain = music_volume * (GAMEPLAY_BGM_GAIN if gameplay_audio_enabled else MENU_BGM_GAIN)
	_desired_ambience_gain = music_volume * (CITY_AMBIENCE_GAIN if gameplay_audio_enabled else MENU_AMBIENCE_GAIN)
	if bgm_player != null:
		_transition_loop(bgm_player, _desired_bgm_stream, _desired_bgm_gain, 0.25)
	if ambience_player != null:
		_transition_loop(ambience_player, _desired_ambience_stream, _desired_ambience_gain, 0.25)
	_save_volume_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_save_volume_settings()
	if weather_primary_player != null:
		_transition_loop(weather_primary_player, _weather_primary_stream, sfx_volume * _weather_primary_gain_scale, 0.25)
	if weather_secondary_player != null:
		_transition_loop(weather_secondary_player, _weather_secondary_stream, sfx_volume * _weather_secondary_gain_scale, 0.25)


func _apply_master_volume() -> void:
	if _master_bus_index >= 0:
		AudioServer.set_bus_volume_db(_master_bus_index, _gain_to_db(master_volume))


func _gain_to_db(gain: float) -> float:
	if gain <= 0.0001:
		return -80.0
	return linear_to_db(gain)


func _load_volume_settings() -> void:
	if _volume_config.load("user://kota_siaga_audio.cfg") != OK:
		return
	master_volume = clampf(float(_volume_config.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(_volume_config.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(_volume_config.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)


func _save_volume_settings() -> void:
	_volume_config.set_value("audio", "master", master_volume)
	_volume_config.set_value("audio", "music", music_volume)
	_volume_config.set_value("audio", "sfx", sfx_volume)
	_volume_config.save("user://kota_siaga_audio.cfg")
