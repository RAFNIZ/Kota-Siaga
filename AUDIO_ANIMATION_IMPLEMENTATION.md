# Kota Siaga — BGM, Audio Feedback & Animation Integration

Target engine: Godot 4.7.2

## Dedicated background music added

- `assets/audio/bgm_menu.wav` — original 56.47-second stereo cinematic-electronic menu theme.
- `assets/audio/bgm_gameplay.wav` — original 45.71-second stereo ambient-pulse gameplay theme.
- Existing `menu_ambient.wav` and `city_ambience.wav` remain as quiet environmental beds; they are no longer used as the primary music track.

## Runtime routing

| System | Integration | Behaviour |
|---|---|---|
| Autoload startup | `AudioManager._ready()` | Starts menu BGM immediately and fades in |
| Main menu | `Main.gd` + `UIRoot.show_main_menu()` | Selects menu BGM and menu ambience; repeated calls do not restart the playing track |
| Mission begin | `GameController.begin_mission()` / `Main.set_menu_mode(false)` | Crossfades to gameplay BGM and city ambience |
| Pause/settings/character | `UIRoot` modal layers | Current menu/gameplay BGM continues; AudioManager runs while paused |
| UI buttons | `UIRoot._button()` | Hover and click/confirm cues for all helper-created buttons |
| Character showroom | `CharacterShowroom._button()` | Hover and click/confirm cues |
| Settings dropdown | `UIRoot._show_settings()` | Open cue on dropdown press; confirm cue after language selection |
| Settings sliders | `UIRoot._add_audio_slider()` | Hover and drag-start interaction cues |
| Stage flow | `GameController.advance_stage()` | Transition cue only when GameState.stage actually changes |
| Toast / objective | `UIRoot` | Notification cue |
| Player | `Coordinator.gd` | Walk/run steps keyed to gait phase, jump, landing, E interaction |
| Ambient residents | `AmbientCitizen.gd` | Quiet spatial footsteps when nearby |
| Evacuation NPCs | `Citizen.gd` | Footsteps follow evacuation locomotion phase |
| Traffic | `TrafficVehicle.gd` | Per-vehicle 3D engine loop; pitch and gain react to speed |
| Weather | `CityWorld.set_weather()` | Rain, flood, wind, and tornado ambience crossfade independently of BGM |
| Siren objective | `GameController` | Spatial siren relay tone when the district repeater is restored |

## AudioManager design

`AudioManager.gd` is an autoload in `project.godot`. It owns separate `AudioStreamPlayer` instances for:

1. BGM (menu/gameplay)
2. Ambience (menu/city)
3. Primary weather loop
4. Secondary weather loop
5. A pooled set of UI one-shots

The BGM stream is selected by `set_game_mode(bool)`. `PROCESS_MODE_ALWAYS` keeps music and UI cues alive during pause. A 0.75-second watchdog checks that the requested BGM is still playing and restarts it if playback stopped unexpectedly while music volume is nonzero. Crossfades cancel an earlier tween before applying the next route.

## Settings

Master, Music, and SFX sliders remain in the Settings panel and save to `user://kota_siaga_audio.cfg`. Music changes update both BGM and ambience player levels live. SFX changes update UI/spatial one-shots and current weather-loop levels live. User-muted values of zero are preserved.

## Animation feedback

Existing rigged player/NPC animation setup remains intact. The audio integration does not replace imported animation clips; it synchronizes footstep cues with the gait-phase accumulator already used by the walk/run blend. Jump and landing cues use the player's jump edge and grounded transition. UI overlay fades remain unchanged.

## Audio files and validation

- 19 original WAV files total.
- BGM files are stereo PCM 16-bit at 22,050 Hz; menu BGM 56.47 seconds, gameplay BGM 45.71 seconds.
- Existing effects/ambiences are 22,050 Hz, 16-bit WAV files.
- Source checks include audio method call resolution, resource paths, WAV metadata/signal levels, balanced delimiters, and archive integrity.
- Godot 4.7.2 is not installed in this environment; parser/runtime playback and mix balance are not claimed as tested here.
