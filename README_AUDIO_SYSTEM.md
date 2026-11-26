# Kota Siaga — Full Background Music & Audio Feedback

Target: Godot 4.7.2. All soundtrack and sound-effect WAV files are original procedural audio generated for this project.

## Continuous background music (new dedicated tracks)

| Game state | Track | Playback | Mix |
|---|---|---|---|
| Main menu, stage select, briefing, character, settings | `bgm_menu.wav` | Dedicated looping BGM player | Music slider, menu ambience mixed quietly underneath |
| Active gameplay and pause | `bgm_gameplay.wav` | Dedicated looping BGM player | Music slider, city ambience mixed quietly underneath |
| Menu / gameplay switch | Both tracks | 1.35-second crossfade | No hard cut; old transition tween is cancelled before a new one |

The previous package only had `menu_ambient.wav` and `city_ambience.wav`, which are environmental sound beds rather than actual musical backing tracks. The dedicated BGM tracks are now separate, longer, melodic instrumental loops.

## UI sounds

- Button hover: `ui_hover.wav` on every button created by `UIRoot._button()` and the custom `CharacterShowroom` button builder.
- Button click/confirm: `ui_confirm.wav` on every helper-created menu, settings, character, pause, mission, and gameplay action button.
- Language dropdown: a distinct open cue when the OptionButton is pressed, plus confirm on selection.
- Audio sliders: hover cue when entered and a soft interaction cue when dragging starts.
- Back/ESC: `ui_back.wav` on existing overlay-back paths.
- Objective/system notifications and stage transitions: short notification/transition cues.

## Gameplay sound

| Event | Asset / route | Trigger |
|---|---|---|
| City ambience | `city_ambience.wav` | Gameplay mode; low-level environmental bed under the gameplay BGM |
| Footsteps | `footstep.wav`, `footstep_run.wav` | Player/NPC gait phase crosses alternating step threshold |
| Jump / landing | `player_jump.wav`, `player_land.wav` | Player jump start and grounded transition |
| Interaction | `interact.wav` | Player presses E to interact |
| Vehicle engine | `vehicle_engine_loop.wav` | Positional AudioStreamPlayer3D attached to each traffic vehicle; pitch and gain follow speed |
| Extreme rain | `rain_loop.wav` | Disaster level 1 |
| Flood | `rain_loop.wav` + `flood_loop.wav` | Disaster level 2 |
| Tornado / severe wind | `wind_loop.wav` + `tornado_loop.wav` | Disaster level 3 |
| Disaster warning | `disaster_alert.wav` | Disaster start |
| Siren relay restored | `siren_relay.wav` | Side objective: reactivate the district siren relay |

## Audio settings

The `AudioManager` autoload exposes Master, Music, and SFX sliders. Values persist to `user://kota_siaga_audio.cfg`. Master controls the Godot Master bus; Music controls dedicated BGM and quieter ambience beds; SFX controls UI feedback, spatial one-shots, weather loops, and vehicle engines. Default levels are audible on first launch; a saved user value of zero remains respected as an intentional mute.

## Reliability

- The AudioManager autoload runs in `PROCESS_MODE_ALWAYS`, so BGM and UI feedback continue during pause overlays.
- A watchdog checks BGM playback and restarts the desired track if an AudioStreamPlayer stops unexpectedly while the Music slider is above zero.
- Separate players are used for BGM, ambience, primary weather, secondary weather, and pooled UI SFX. Weather effects cannot replace or stop the main soundtrack.
- Loop crossfades cancel previous transitions on the same player, preventing overlapping tweens during rapid menu/gameplay changes.
- NPC footsteps are quieter, limited to residents near the player, and capped to avoid crowd-noise buildup.

## Validation boundary

WAV durations, channels, sample rates, non-silent signal levels, script call sites, resource references, and ZIP integrity are checked statically. Godot 4.7.2 is not installed in the editing environment, so runtime playback, loop joins, and final mix balance still need confirmation in the Godot editor/game on the target machine.
