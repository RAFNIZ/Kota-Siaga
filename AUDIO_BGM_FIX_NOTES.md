# Audio BGM Fix — Kota Siaga (Godot 4.7.2)

## Why the previous build sounded like there was no background music
The previous AudioManager used `menu_ambient.wav` and `city_ambience.wav` as its only continuous tracks. Those are ambience beds, not a dedicated melodic soundtrack. The new build adds two actual original instrumental BGM loops and gives them their own player, separate from environmental ambience and disaster loops.

## BGM files
- `assets/audio/bgm_menu.wav` — 56.47 seconds, stereo, 22,050 Hz, 16-bit. Original cinematic-electronic menu theme.
- `assets/audio/bgm_gameplay.wav` — 45.71 seconds, stereo, 22,050 Hz, 16-bit. Original low-intensity rhythmic gameplay theme.

## Playback routes
- `Main.gd` calls `AudioManager.set_game_mode(false)` on startup; the AudioManager autoload also starts the menu track as a fallback.
- `UIRoot.show_main_menu()` selects the menu BGM.
- `GameController.begin_mission()` and `Main.set_menu_mode(false)` select the gameplay BGM.
- Settings, character roster, briefing, pause, and other overlays do not switch BGM, so the current track continues under those panels.
- BGM and ambience use separate AudioStreamPlayers and crossfade over 1.35–1.7 seconds.
- A playback watchdog checks every 0.75 seconds and restarts the desired BGM if the stream stops unexpectedly while Music volume is above zero.

## Click and UI sounds
- All buttons created by `UIRoot._button()` play hover and confirm audio. This includes the main menu, settings, character roster, pause, briefing, stage selection, HUD action, and evaluation buttons.
- Character showroom's own Button factory also plays hover and confirm cues.
- Language OptionButton plays an open cue and a confirm cue when the selection changes.
- Master/Music/SFX sliders play hover feedback and a soft cue at drag start.
- Stage transition cues fire only when `GameState.stage` actually changes.

## Existing gameplay sound preserved
Footsteps, jump, landing, interaction, vehicle engine, siren relay, disaster alert, rain, flood, wind, and tornado sounds remain in the project. Vehicle engine pitch/volume now uses a slightly more audible speed range. The SFX slider still controls the one-shots, weather beds, and vehicle audio; the Music slider controls BGM and regular ambience.

## Settings
Master/Music/SFX sliders persist in `user://kota_siaga_audio.cfg`. Existing saved settings are respected, including a deliberately muted value of zero. For audible music, set Music above zero; for UI clicks and gameplay effects, set SFX above zero.

## Validation
The two BGM files have nonzero signal levels and valid stereo PCM WAV metadata. Source checks confirm the AudioManager autoload, menu/gameplay mode calls, UI button hooks, settings control hooks, stage transition cue, and resource paths. ZIP integrity is checked after packaging.

Godot 4.7.2 runtime playback could not be executed in this editing environment. The user should verify actual speakers/headphones, mixer level, and mix balance on the target machine.
