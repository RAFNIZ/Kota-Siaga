extends Node

const CITIZEN_SCENE := preload("res://scenes/actors/Citizen.tscn")
var world: Node3D
var player: CharacterBody3D
var ui: CanvasLayer
var active: bool = false
var mission_started: bool = false
var current_level: int = 1
var disaster_timer: float = 0.0
var disaster_duration: float = 14.0
var early_warning_used: bool = false
var citizens: Array[Node3D] = []
var facilities: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var side_event: Dictionary = {}
var medkit_carried: bool = false
var side_bonus_done: bool = false
var pending_citizen_index: int = -1

func setup(p_world: Node3D, p_player: CharacterBody3D, p_ui: CanvasLayer) -> void:
    world = p_world
    player = p_player
    ui = p_ui

func load_level(level: int, show_story: bool = false) -> void:
    current_level = clampi(level, 1, 3)
    active = false
    mission_started = false
    disaster_timer = 0.0
    disaster_duration = 14.0
    early_warning_used = false
    medkit_carried = false
    side_bonus_done = false
    pending_citizen_index = -1
    for citizen in citizens:
        if is_instance_valid(citizen): citizen.queue_free()
    citizens.clear()
    facilities.clear()
    hazards.clear()
    world.call("clear_dynamic")
    GameState.start_level(current_level)
    player.global_position = Vector3(8.0, 0.0, -11.5)
    player.set("stamina", 100.0)
    player.set("input_enabled", false)
    _create_facilities()
    _create_hazards()
    _create_side_event()
    _create_citizens()
    _sync_world()
    if show_story: ui.call("show_briefing", current_level)

func begin_mission() -> void:
    AudioManager.set_game_mode(true)
    mission_started = true
    active = true
    player.set("input_enabled", true)
    var scene_root := get_tree().current_scene
    if scene_root != null and scene_root.has_method("set_menu_mode"):
        scene_root.call("set_menu_mode", false)
    ui.call("close_overlay")
    GameState.set_message("Koordinator masuk kawasan. Dekati objek dan tekan E untuk berinteraksi.")

func _create_facilities() -> void:
    facilities = [
        {"id":"drain", "name":("Main Drainage" if KotaLocale.language_code == "en" else "Drainase Utama"), "pos":Vector3(-42, 0, -12.25), "model":"Prop_Drain", "build_cost":170, "upgrade_cost":130, "repair_cost":120, "level":0, "damaged":false, "inspected":false, "repaired":false},
        {"id":"resapan", "name":("Rain Garden" if KotaLocale.language_code == "en" else "Area Resapan"), "pos":Vector3(-42, 0, 42), "model":"Prop_Planter_Single", "build_cost":190, "upgrade_cost":150, "repair_cost":140, "level":0, "damaged":false, "inspected":false, "repaired":false},
        {"id":"ramp", "name":("Accessible Ramp" if KotaLocale.language_code == "en" else "Ramp Akses"), "pos":Vector3(12.0, 0, -42), "model":"Sidewalk_Corner_Flat_3m", "build_cost":170, "upgrade_cost":130, "repair_cost":150, "level":0, "damaged":false, "inspected":false, "repaired":false},
        {"id":"signage", "name":("Evacuation Sign" if KotaLocale.language_code == "en" else "Rambu Evakuasi"), "pos":Vector3(54.0, 0, 12.25), "model":"", "build_cost":120, "upgrade_cost":95, "repair_cost":90, "level":0, "damaged":false, "inspected":false, "repaired":false}
    ]
    GameState.facilities_ready = 0
    for f in facilities:
        var not_ready_text := "NOT READY" if KotaLocale.language_code == "en" else "BELUM SIAP"
        world.call("create_facility_marker", str(f["id"]), str(f["name"]), f["pos"], str(f["model"]), not_ready_text, Color("#f0c46a"))

func _create_hazards() -> void:
    if current_level == 1:
        hazards = [
            {"id":"drain_clog", "name":("Blocked drain" if KotaLocale.language_code == "en" else "Saluran tersumbat"), "pos":Vector3(-48, 0.02, -12.25), "kind":"clog", "cost":55, "done":false},
            {"id":"water_crossing", "name":("Junction standing water" if KotaLocale.language_code == "en" else "Genangan persimpangan"), "pos":Vector3(21, 0.02, 48), "kind":"water", "cost":70, "done":false}
        ]
    elif current_level == 2:
        hazards = [
            {"id":"flood_crossing", "name":("Flooded main road" if KotaLocale.language_code == "en" else "Genangan di jalan utama"), "pos":Vector3(48, 0.02, -21), "kind":"flood", "cost":85, "done":false},
            {"id":"emergency_pump", "name":("Emergency pump needs activation" if KotaLocale.language_code == "en" else "Pompa darurat perlu diaktifkan"), "pos":Vector3(-48, 0.02, 21), "kind":"water", "cost":95, "done":false}
        ]
    else:
        hazards = [
            {"id":"road_debris", "name":("Debris blocking the road" if KotaLocale.language_code == "en" else "Puing menutup jalan"), "pos":Vector3(6, 0.02, 21), "kind":"debris", "cost":65, "done":false},
            {"id":"fallen_tree", "name":("Fallen branches and tree" if KotaLocale.language_code == "en" else "Ranting dan pohon tumbang"), "pos":Vector3(-21, 0.02, -48), "kind":"tree", "cost":75, "done":false}
        ]
    for h in hazards:
        world.call("create_hazard_marker", str(h["id"]), str(h["name"]), h["pos"], str(h["kind"]))
        world.call("update_hazard_marker", str(h["id"]), true)

func _create_side_event() -> void:
    if current_level == 1:
        side_event = {"id":"sensor", "name":("Field Info Desk" if KotaLocale.language_code == "en" else "Meja Informasi Lapangan"), "pos":Vector3(52.5, 0, -42.0), "kind":"sensor", "done":false, "label":("CHECK FIELD DESK" if KotaLocale.language_code == "en" else "CEK MEJA INFORMASI")}
    elif current_level == 2:
        side_event = {"id":"medkit", "name":("First Aid Kit" if KotaLocale.language_code == "en" else "Kotak P3K"), "pos":Vector3(12.0, 0, -51.0), "kind":"medkit", "done":false, "label":("FIRST AID KIT" if KotaLocale.language_code == "en" else "KOTAK P3K")}
    else:
        side_event = {"id":"siren", "name":("Siren Relay" if KotaLocale.language_code == "en" else "Repeater Sirene"), "pos":Vector3(12.0, 0, 42.0), "kind":"siren", "done":false, "label":("SIREN RELAY" if KotaLocale.language_code == "en" else "REPEATER SIRENE")}
    world.call("create_side_marker", str(side_event["id"]), str(side_event["label"]), side_event["pos"], str(side_event["kind"]))

func _create_citizens() -> void:
    if current_level == 1:
        GameState.citizens_total = 0
        return
    var data: Array[Dictionary]
    if current_level == 2:
        data = [
            {"type":"Warga", "name":"Pak Bima", "pos":Vector3(-31.5,0,-10.5), "speed":4.0, "dialogue":"Air naik cepat. Tolong bantu saya menuju jalur yang tidak tergenang."},
            {"type":"Anak", "name":"Naya", "pos":Vector3(31.5,0,-52.5), "speed":3.7, "dialogue":"Aku terpisah dari rombongan. Bisa tunjukkan jalan ke Titik Aman?"},
            {"type":"Lansia", "name":"Bu Rukmini", "pos":Vector3(-52.5,0,31.5), "speed":2.7, "dialogue":"Saya tidak bisa berjalan cepat. Tolong arahkan saya melalui jalan yang aman."},
            {"type":"Pengguna kursi roda", "name":"Dimas", "pos":Vector3(10.5,0,52.5), "speed":3.0, "dialogue":"Saya membutuhkan jalur landai dan bebas hambatan. Ramp akses akan membantu saya."}
        ]
    else:
        data = [
            {"type":"Warga", "name":"Pak Bima", "pos":Vector3(-31.5,0,-10.5), "speed":4.0, "dialogue":"Puing menutup persimpangan. Bantu saya mencapai titik perlindungan."},
            {"type":"Anak", "name":"Naya", "pos":Vector3(31.5,0,-52.5), "speed":3.7, "dialogue":"Anginnya kencang sekali. Aku takut—tolong temani aku."},
            {"type":"Lansia", "name":"Bu Rukmini", "pos":Vector3(-52.5,0,31.5), "speed":2.7, "dialogue":"Jangan lewatkan saya di belakang. Saya butuh jalur yang bebas puing."},
            {"type":"Pengguna kursi roda", "name":"Dimas", "pos":Vector3(10.5,0,52.5), "speed":3.0, "dialogue":"Pastikan rute saya cukup lebar dan tidak tertutup pohon tumbang."}
        ]
    for item in data:
        var citizen := CITIZEN_SCENE.instantiate() as Node3D
        var line := str(item["dialogue"])
        if KotaLocale.language_code == "en":
            line = _citizen_dialogue_english(str(item["name"]), current_level)
        citizen.call("configure", str(item["type"]), str(item["name"]), line, float(item["speed"]))
        citizen.position = item["pos"]
        citizen.set_meta("citizen_type", item["type"])
        citizen.set_meta("display_name", item["name"])
        citizen.reached_safe.connect(_on_citizen_reached_safe)
        world.call("add_citizen", citizen)
        citizens.append(citizen)
    GameState.citizens_total = citizens.size()

func _citizen_dialogue_english(person_name: String, stage_number: int) -> String:
    if stage_number == 2:
        match person_name:
            "Pak Bima": return "The water is rising fast. Please help me reach a route that is not flooded."
            "Naya": return "I got separated from my school group. Can you show me the way to the Safe Point?"
            "Bu Rukmini": return "I cannot walk quickly. Please guide me along a safe route."
            "Dimas": return "I need a step-free, accessible route. The access ramp would really help."
    match person_name:
        "Pak Bima": return "Debris has blocked the junction. Help me reach a safe shelter."
        "Naya": return "The wind is so strong. I'm scared—please stay with me."
        "Bu Rukmini": return "Please don't leave me behind. I need a route without debris."
        "Dimas": return "Please make sure the route is wide enough and clear of fallen trees."
    return "Please help me reach the Safe Point."

func _process(delta: float) -> void:
    if not mission_started or not active: return
    if GameState.stage == GameState.DISASTER:
        disaster_timer += delta
        ui.call("set_disaster_countdown", maxf(0.0, disaster_duration - disaster_timer))
        if disaster_timer >= disaster_duration:
            _apply_disaster()
            GameState.set_stage(GameState.HANDLING, _post_disaster_message())
            for citizen in citizens: citizen.call("set_alert")
    _sync_world()
    ui.call("refresh")

func _post_disaster_message() -> String:
    if KotaLocale.language_code == "en":
        if current_level == 1: return "The rain is easing. Two hotspots remain; clear them before inspection."
        if current_level == 2: return "Floodwater has cut off the main road. Clear hazards, then guide every resident to the Safe Point."
        return "The wind is easing, but debris still blocks the route. Clear the path before evacuation."
    if current_level == 1: return "Hujan mulai mereda. Ada dua titik masalah; tangani keduanya sebelum inspeksi."
    if current_level == 2: return "Air mengganggu jalan utama. Bersihkan hambatan, lalu temui semua warga untuk menuntun mereka ke Titik Aman."
    return "Angin mereda, tetapi puing masih menutup rute. Bersihkan hambatan sebelum evakuasi."

func _apply_disaster() -> void:
    disaster_timer = disaster_duration
    # Weather was visible during the countdown. Stop the overlay after the impact,
    # reveal hazard markers, and let the player work on the consequences.
    world.call("set_weather", current_level, false)
    GameState.damaged_count = 0
    for h in hazards:
        world.call("update_hazard_marker", str(h["id"]), bool(h["done"]))
    for i in range(facilities.size()):
        var f: Dictionary = facilities[i]
        var lv := int(f["level"])
        var damaged := false
        if lv > 0:
            if current_level == 1: damaged = str(f["id"]) in ["drain", "resapan"] and lv < 2
            elif current_level == 2: damaged = lv < 2
            else: damaged = lv == 1 or (str(f["id"]) in ["ramp", "signage"] and lv == 2)
        f["damaged"] = damaged
        f["inspected"] = false
        f["repaired"] = false
        facilities[i] = f
        if damaged: GameState.damaged_count += 1
        _update_facility(f)
    GameState.changed.emit()

func interact() -> void:
    if not mission_started or not active: return
    match GameState.stage:
        GameState.PREPARATION: _interact_preparation()
        GameState.DISASTER: _interact_disaster()
        GameState.HANDLING: _interact_handling()
        GameState.INSPECTION: _interact_inspection()
        GameState.REPAIR: _interact_repair()
        GameState.EVALUATION: pass

func _interact_preparation() -> void:
    var fi := _nearest_facility(player.global_position, 3.6, false)
    var event_dist := player.global_position.distance_to(side_event["pos"]) if not bool(side_event.get("done", false)) else 999.0
    if event_dist <= 3.6 and event_dist < (fi.get("distance", 999.0) if not fi.is_empty() else 999.0):
        _complete_side_event()
        return
    if fi.is_empty():
        GameState.set_message("Dekati penanda fasilitas: drainase, area resapan, ramp akses, atau rambu evakuasi.")
        return
    var idx: int = fi["index"]
    var f: Dictionary = facilities[idx]
    var lv := int(f["level"])
    if lv == 0:
        if not GameState.spend(int(f["build_cost"])): return
        f["level"] = 1
        GameState.facilities_ready += 1
        GameState.add_score(8)
        GameState.change_trust(4 if str(f["id"]) == "ramp" else 2)
        GameState.set_message("%s dibangun. Ketahanan kawasan meningkat." % str(f["name"]))
    elif lv == 1:
        if not GameState.spend(int(f["upgrade_cost"])): return
        f["level"] = 2
        GameState.facilities_upgraded += 1
        GameState.add_score(5)
        GameState.change_trust(2)
        GameState.set_message("%s ditingkatkan. Fasilitas kini lebih tangguh menghadapi ancaman." % str(f["name"]))
    else:
        GameState.set_message("%s sudah di level maksimum. Simpan dana untuk respons darurat." % str(f["name"]))
        return
    facilities[idx] = f
    _update_facility(f)
    _sync_world()

func _interact_disaster() -> void:
    var fi := _nearest_facility(player.global_position, 3.8, false)
    if fi.is_empty() or str(facilities[int(fi["index"])]["id"]) != "signage":
        GameState.set_message("Bencana berlangsung. Jika rambu evakuasi sudah dibangun, datangi dan tekan E untuk mengirim peringatan dini.")
        return
    var sign_f: Dictionary = facilities[int(fi["index"])]
    if int(sign_f["level"]) < 1:
        GameState.set_message("Rambu belum dibangun sebelum bencana—peringatan dini belum tersedia.")
        return
    if early_warning_used:
        GameState.set_message("Peringatan dini sudah terkirim. Tetap waspada dan bersiap menangani dampak.")
        return
    early_warning_used = true
    disaster_duration += 4.0
    GameState.add_score(12)
    GameState.change_trust(8)
    for citizen in citizens: citizen.call("set_alert")
    GameState.set_message("PERINGATAN DINI TERKIRIM! Respons diperpanjang 4 detik agar warga sempat bersiap. Skor +12, kepercayaan +8.")

func _interact_handling() -> void:
    var hi := _nearest_hazard(player.global_position, 3.9)
    if not hi.is_empty():
        _clear_hazard(int(hi["index"]))
        return
    if not _hazards_cleared():
        GameState.set_message("Masih ada hambatan. Ikuti penanda jingga dan bersihkan dahulu sebelum evakuasi.")
        return
    if not bool(side_event.get("done", false)):
        var ev_dist: float = player.global_position.distance_to(side_event["pos"])
        if ev_dist <= 3.9:
            _complete_side_event()
            return
    var ci := _nearest_citizen(player.global_position, 3.7)
    if ci < 0:
        GameState.set_message("Dekati warga yang membutuhkan bantuan, lalu tekan E untuk berbicara dan memilih tindakan.")
        return
    var citizen: Node3D = citizens[ci]
    if str(citizen.get("state")) == "safe":
        GameState.set_message("%s sudah berada di Titik Aman." % str(citizen.get("display_name")))
        return
    if str(citizen.get("state")) == "evacuating":
        GameState.set_message("%s sedang mengikuti jalur evakuasi. Pastikan jalan tetap terbuka." % str(citizen.get("display_name")))
        return
    pending_citizen_index = ci
    player.set("input_enabled", false)
    ui.call("show_citizen_choice", ci, str(citizen.get("display_name")), str(citizen.get("dialogue_line")), bool(citizen.get("reassured")))

func resolve_citizen_choice(index: int, choice: String) -> void:
    if index < 0 or index >= citizens.size(): return
    var citizen: Node3D = citizens[index]
    ui.call("close_overlay")
    player.set("input_enabled", true)
    if choice == "reassure":
        if not bool(citizen.get("reassured")):
            citizen.set("reassured", true)
            GameState.change_trust(5)
            GameState.add_score(3)
            GameState.set_message("Kamu meluangkan waktu mendengarkan %s. Warga lebih tenang—kepercayaan +5." % str(citizen.get("display_name")))
        else:
            GameState.set_message("%s sudah lebih tenang. Saatnya membantu evakuasi." % str(citizen.get("display_name")))
        return
    if choice == "evacuate":
        if current_level == 2 and medkit_carried and str(citizen.get("citizen_type")) == "Lansia":
            medkit_carried = false
            GameState.change_trust(10)
            GameState.add_score(15)
            _complete_side_bonus()
            GameState.set_message("SIDE OBJECTIVE SELESAI — Bu Rukmini menerima P3K. Skor +23, kepercayaan +13.")
        else:
            GameState.set_message("Kamu menuntun %s mengikuti rute yang sesuai menuju Titik Aman." % str(citizen.get("display_name")))
        var route := _route_for_citizen(citizen)
        citizen.call("begin_evacuation", route)
        if str(citizen.get("citizen_type")) == "Pengguna kursi roda" and _facility_level("ramp") == 0:
            GameState.change_trust(-3)
            GameState.add_score(-3)
            GameState.set_message("Dimas memakai rute alternatif yang lebih panjang karena ramp akses belum dibangun. Rute tetap dapat dilalui, tetapi kepercayaan sedikit turun.")

func _route_for_citizen(citizen: Node3D) -> Array[Vector3]:
    var kind := str(citizen.get("citizen_type"))
    if kind == "Pengguna kursi roda" and _facility_level("ramp") == 0:
        # Longer step-free route around the west/north sidewalks when the curb ramp is unavailable.
        return [Vector3(10.5,0,52.5), Vector3(-10.5,0,52.5), Vector3(-10.5,0,31.5), Vector3(-10.5,0,10.5), Vector3(10.5,0,10.5), Vector3(31.5,0,10.5), Vector3(31.5,0,31.5), Vector3(42,0,42)]
    if kind == "Lansia":
        return [Vector3(-52.5,0,10.5), Vector3(-31.5,0,10.5), Vector3(-10.5,0,10.5), Vector3(10.5,0,10.5), Vector3(31.5,0,10.5), Vector3(31.5,0,31.5), Vector3(42,0,42)]
    if kind == "Anak":
        return [Vector3(31.5,0,-31.5), Vector3(31.5,0,-10.5), Vector3(31.5,0,10.5), Vector3(31.5,0,31.5), Vector3(42,0,42)]
    if kind == "Pengguna kursi roda":
        return [Vector3(10.5,0,31.5), Vector3(31.5,0,31.5), Vector3(42,0,42)]
    return [Vector3(-10.5,0,-10.5), Vector3(10.5,0,-10.5), Vector3(31.5,0,-10.5), Vector3(31.5,0,10.5), Vector3(31.5,0,31.5), Vector3(42,0,42)]

func _interact_inspection() -> void:
    var fi := _nearest_facility(player.global_position, 3.7, true)
    if fi.is_empty():
        GameState.set_message("Dekati fasilitas yang ditandai RUSAK untuk memeriksa kondisinya.")
        return
    var idx: int = fi["index"]
    var f: Dictionary = facilities[idx]
    if bool(f["inspected"]):
        GameState.set_message("Temuan %s sudah tercatat." % str(f["name"]))
        return
    f["inspected"] = true
    facilities[idx] = f
    GameState.inspected_count += 1
    GameState.add_score(6)
    GameState.set_message("Pemeriksaan %s selesai. Temuan masuk ke laporan kawasan." % str(f["name"]))
    _update_facility(f)

func _interact_repair() -> void:
    var fi := _nearest_facility(player.global_position, 3.7, true)
    if fi.is_empty():
        GameState.set_message("Dekati fasilitas rusak yang sudah diperiksa untuk melakukan perbaikan.")
        return
    var idx: int = fi["index"]
    var f: Dictionary = facilities[idx]
    if not bool(f["inspected"]):
        GameState.set_message("Periksa fasilitas ini terlebih dahulu.")
        return
    if bool(f["repaired"]):
        GameState.set_message("Fasilitas ini sudah pulih.")
        return
    var cost := int(f["repair_cost"])
    if not GameState.spend(cost): return
    f["repaired"] = true
    facilities[idx] = f
    GameState.repaired_count += 1
    GameState.add_score(12)
    GameState.change_trust(2)
    GameState.set_message(("%s repaired for %s." % [str(f["name"]), KotaLocale.format_money(cost)]) if KotaLocale.language_code == "en" else ("%s berhasil diperbaiki dengan biaya %s." % [str(f["name"]), KotaLocale.format_money(cost)]))
    _update_facility(f)

func _clear_hazard(index: int) -> void:
    var h: Dictionary = hazards[index]
    if bool(h["done"]): return
    var cost := int(h["cost"])
    if GameState.spend(cost):
        GameState.add_score(10)
        GameState.change_trust(2)
        GameState.set_message("%s berhasil ditangani." % str(h["name"]))
    else:
        GameState.add_score(-5)
        GameState.change_trust(-3)
        GameState.set_message("Anggaran darurat habis. Warga bergotong royong membuka akses, tetapi skor dan kepercayaan berkurang.")
    h["done"] = true
    hazards[index] = h
    world.call("update_hazard_marker", str(h["id"]), true)
    _sync_world()

func _complete_side_event() -> void:
    var kind := str(side_event.get("kind", ""))
    match kind:
        "sensor":
            GameState.add_score(10)
            GameState.change_trust(5)
            if KotaLocale.language_code == "en":
                GameState.set_message("SIDE OBJECTIVE CLEAR — field reports can now reach the response team faster. Bonus score and trust earned.")
            else:
                GameState.set_message("SIDE OBJECTIVE SELESAI — meja informasi mempercepat laporan warga ke tim respons. Bonus skor dan kepercayaan didapat.")
            side_event["done"] = true
            _complete_side_bonus()
        "medkit":
            if medkit_carried:
                GameState.set_message("The first-aid kit is already carried. Deliver it to Mrs. Rukmini." if KotaLocale.language_code == "en" else "Kotak P3K sudah dibawa. Serahkan kepada Bu Rukmini saat berbicara dengannya.")
            else:
                medkit_carried = true
                GameState.add_score(5)
                GameState.set_message("First-aid kit secured. Deliver it to Mrs. Rukmini for the story bonus." if KotaLocale.language_code == "en" else "Kotak P3K diamankan. Bawa ke Bu Rukmini untuk bonus cerita.")
                side_event["done"] = true
        "siren":
            GameState.add_score(12)
            GameState.change_trust(8)
            var relay_position: Vector3 = side_event.get("pos", player.global_position)
            AudioManager.play_siren_relay_at(relay_position + Vector3(0.0, 1.2, 0.0))
            GameState.set_message("SIDE OBJECTIVE CLEAR — the siren relay is back online. Residents can receive warnings sooner." if KotaLocale.language_code == "en" else "SIDE OBJECTIVE SELESAI — repeater sirene aktif lagi agar peringatan lebih cepat diterima warga.")
            side_event["done"] = true
            _complete_side_bonus()
    world.call("update_side_marker", str(side_event.get("id", "")), bool(side_event.get("done", false)))

func _complete_side_bonus() -> void:
    if side_bonus_done:
        return
    side_bonus_done = true
    GameState.side_events_completed += 1
    GameState.add_score(8)
    GameState.change_trust(3)

func _on_citizen_reached_safe(citizen: Node3D) -> void:
    GameState.citizens_safe += 1
    GameState.add_score(18)
    GameState.change_trust(5)
    GameState.set_message("%s tiba di Titik Aman. Warga selamat %d/%d; kepercayaan +5." % [str(citizen.get("display_name")), GameState.citizens_safe, GameState.citizens_total])
    _sync_world()

func advance_stage() -> void:
    if not mission_started: return
    var previous_stage := GameState.stage
    match GameState.stage:
        GameState.PREPARATION:
            if GameState.facilities_ready == 0:
                GameState.set_message("Bangun setidaknya satu fasilitas sebelum memulai bencana.")
                return
            disaster_timer = 0.0
            early_warning_used = false
            world.call("set_weather", current_level, true)
            GameState.set_stage(GameState.DISASTER, "%s datang. Waktu respons dimulai—peringatan dini tersedia jika rambu telah dibangun." % GameState.disaster_name())
        GameState.DISASTER:
            GameState.set_message("Ancaman masih aktif. Waktu respons belum selesai; manfaatkan kesempatan untuk mengirim peringatan dini.")
        GameState.HANDLING:
            if not _hazards_cleared():
                GameState.set_message("Masih ada hambatan yang belum ditangani. Buka seluruh penanda darurat terlebih dahulu.")
                return
            if current_level > 1 and GameState.citizens_safe < GameState.citizens_total:
                GameState.set_message("Belum semua warga tiba di Titik Aman. Bantu warga yang masih menunggu atau sedang berjalan.")
                return
            GameState.set_stage(GameState.INSPECTION, "Penanganan selesai. Periksa fasilitas terdampak dan catat masalah yang ditemukan.")
        GameState.INSPECTION:
            if not _inspection_complete():
                GameState.set_message("Masih ada fasilitas rusak yang belum diperiksa.")
                return
            GameState.set_stage(GameState.REPAIR, "Pemeriksaan selesai. Perbaiki fasilitas prioritas menggunakan sisa anggaran.")
        GameState.REPAIR:
            GameState.add_score(GameState.facilities_ready * 3 + GameState.facilities_upgraded * 3 + GameState.repaired_count * 4 + GameState.citizens_safe * 3 + int(GameState.trust / 10))
            GameState.total_score += GameState.score
            GameState.complete_current_chapter()
            GameState.set_stage(GameState.EVALUATION, "Laporan kesiapsiagaan kawasan selesai. Tinjau hasil keputusanmu.")
        GameState.EVALUATION:
            if current_level < 3:
                load_level(current_level + 1, true)
            else:
                GameState.campaign_complete = true
                GameState.unlocked_level = 3
                GameState.save_progress()
                if GameState.side_events_completed >= 3:
                    GameState.add_score(20)
                    GameState.change_trust(5)
                    GameState.set_message("ENDING SPESIAL — KOORDINATOR TELADAN! Semua objective sampingan selesai. Arunika lebih siap menghadapi bencana.")
                else:
                    GameState.set_message("Kampanye selesai. Arunika belajar dari hujan, banjir, dan puting beliung—masih ada cerita sampingan yang bisa diselesaikan saat bermain ulang.")
                ui.call("show_finale")
    if GameState.stage != previous_stage:
        AudioManager.play_stage_transition()
    _sync_world()
    ui.call("refresh")

func get_minimap_objective_position() -> Vector3:
    var reference_position := player.global_position if is_instance_valid(player) else Vector3.ZERO
    var selected_position := reference_position
    var selected_distance := INF
    var has_target := false

    # First priority: unresolved hazards during disaster response.
    for hazard in hazards:
        if bool(hazard.get("done", false)):
            continue
        var hazard_position: Vector3 = hazard.get("pos", Vector3.ZERO)
        var hazard_distance := reference_position.distance_to(hazard_position)
        if hazard_distance < selected_distance:
            selected_distance = hazard_distance
            selected_position = hazard_position
            has_target = true

    # Then citizens who still need assistance, using their actual runtime positions.
    if GameState.stage == GameState.HANDLING or GameState.stage == GameState.DISASTER:
        for citizen in citizens:
            if not is_instance_valid(citizen):
                continue
            if str(citizen.get("state")) in ["safe", "evacuating"]:
                continue
            var citizen_position: Vector3 = citizen.global_position
            var citizen_distance := reference_position.distance_to(citizen_position)
            if citizen_distance < selected_distance:
                selected_distance = citizen_distance
                selected_position = citizen_position
                has_target = true

    # During inspection/repair, guide the player to the nearest unresolved damaged facility.
    if GameState.stage == GameState.INSPECTION or GameState.stage == GameState.REPAIR:
        for facility in facilities:
            if not bool(facility.get("damaged", false)) or bool(facility.get("repaired", false)):
                continue
            if GameState.stage == GameState.REPAIR and not bool(facility.get("inspected", false)):
                continue
            var facility_position: Vector3 = facility.get("pos", Vector3.ZERO)
            var facility_distance := reference_position.distance_to(facility_position)
            if facility_distance < selected_distance:
                selected_distance = facility_distance
                selected_position = facility_position
                has_target = true

    # Before an emergency, point to the nearest facility that still needs setting up.
    if GameState.stage == GameState.PREPARATION:
        selected_distance = INF
        has_target = false
        for facility in facilities:
            if int(facility.get("level", 0)) > 0:
                continue
            var prep_facility_position: Vector3 = facility.get("pos", Vector3.ZERO)
            var prep_facility_distance := reference_position.distance_to(prep_facility_position)
            if prep_facility_distance < selected_distance:
                selected_distance = prep_facility_distance
                selected_position = prep_facility_position
                has_target = true

    # If primary tasks are complete, point to the side objective when it remains available.
    if not has_target and not side_event.is_empty() and not bool(side_event.get("done", false)):
        selected_position = side_event.get("pos", reference_position)
        has_target = true
    return selected_position

func can_advance() -> bool:
    if not mission_started: return false
    match GameState.stage:
        GameState.PREPARATION: return GameState.facilities_ready > 0
        GameState.DISASTER: return false
        GameState.HANDLING: return _hazards_cleared() and (current_level == 1 or GameState.citizens_safe >= GameState.citizens_total)
        GameState.INSPECTION: return _inspection_complete()
        GameState.REPAIR: return true
        GameState.EVALUATION: return true
    return false

func action_label() -> String:
    if KotaLocale.language_code == "en":
        if not mission_started: return "DEPLOY TO DISTRICT  →"
        match GameState.stage:
            GameState.PREPARATION: return "START %s  →" % GameState.disaster_name()
            GameState.DISASTER: return "HAZARD IN PROGRESS…"
            GameState.HANDLING: return "MOVE TO INSPECTION  →" if can_advance() else "CLEAR ACTIVE OBJECTIVES"
            GameState.INSPECTION: return "NEXT STAGE  →" if can_advance() else "INSPECT DAMAGED ASSETS"
            GameState.REPAIR: return "WRAP UP & DEBRIEF  →"
            GameState.EVALUATION: return "BACK TO MENU" if GameState.campaign_complete else "NEXT STAGE  →"
        return "CONTINUE"
    if not mission_started: return "MULAI MISI  →"
    match GameState.stage:
        GameState.PREPARATION: return "MULAI %s  →" % GameState.disaster_name()
        GameState.DISASTER: return "BENCANA BERLANGSUNG…"
        GameState.HANDLING: return "LANJUT KE PEMERIKSAAN  →" if can_advance() else "SELESAIKAN PENANGANAN"
        GameState.INSPECTION: return "STAGE BERIKUTNYA  →" if can_advance() else "PERIKSA FASILITAS RUSAK"
        GameState.REPAIR: return "SELESAI & EVALUASI  →"
        GameState.EVALUATION: return "KEMBALI KE MENU" if GameState.campaign_complete else "STAGE BERIKUTNYA  →"
    return "LANJUTKAN"

func interaction_hint() -> String:
    if KotaLocale.language_code == "en":
        if not mission_started: return "Review the briefing and deploy to the district."
        if GameState.stage == GameState.DISASTER:
            if early_warning_used: return "EARLY WARNING SENT  •  Stay alert."
            for entry in facilities:
                if str(entry["id"]) == "signage" and int(entry["level"]) > 0:
                    if player.global_position.distance_to(entry["pos"]) < 4.0: return "E  •  SEND EARLY WARNING"
                    return "Head to the evacuation sign to send an early warning."
            return "Early warning is unavailable until an evacuation sign is built."
        if GameState.stage == GameState.PREPARATION:
            var nearest := _nearest_facility(player.global_position, 4.2, false)
            if not nearest.is_empty():
                var item: Dictionary = facilities[int(nearest["index"])]
                var name_en := _facility_name_english(str(item["id"]))
                if int(item["level"]) == 0: return "E  •  BUILD %s  (%s)" % [name_en.to_upper(), KotaLocale.format_money(int(item["build_cost"]))]
                if int(item["level"]) == 1: return "E  •  UPGRADE %s  (%s)" % [name_en.to_upper(), KotaLocale.format_money(int(item["upgrade_cost"]))]
                return "%s  •  MAX LEVEL" % name_en.to_upper()
            if not bool(side_event.get("done", false)) and player.global_position.distance_to(side_event["pos"]) < 4.2: return "E  •  " + str(side_event["label"])
        if GameState.stage == GameState.HANDLING:
            var near_hazard := _nearest_hazard(player.global_position, 4.2)
            if not near_hazard.is_empty(): return "E  •  RESPOND TO " + _hazard_name_english(str(hazards[int(near_hazard["index"])]["id"])).to_upper()
            var near_citizen := _nearest_citizen(player.global_position, 4.2)
            if near_citizen >= 0:
                var person: Node3D = citizens[near_citizen]
                var person_state := str(person.get("state"))
                if person_state == "safe": return "%s  •  SAFE" % str(person.get("display_name")).to_upper()
                if person_state == "evacuating": return "%s  •  MOVING TO SAFETY" % str(person.get("display_name")).to_upper()
                return "E  •  TALK TO " + str(person.get("display_name")).to_upper()
        if GameState.stage == GameState.INSPECTION:
            var nearest_damaged := _nearest_facility(player.global_position, 4.2, true)
            if not nearest_damaged.is_empty(): return "E  •  INSPECT DAMAGED ASSET"
        if GameState.stage == GameState.REPAIR:
            var repair_target := _nearest_facility(player.global_position, 4.2, true)
            if not repair_target.is_empty(): return "E  •  REPAIR FACILITY (%s)" % KotaLocale.format_money(int(facilities[int(repair_target["index"])]["repair_cost"]))
        return "Follow the objective marker."
    if not mission_started: return "Baca briefing dan masuk ke kawasan."
    if GameState.stage == GameState.DISASTER:
        if early_warning_used: return "PERINGATAN DINI TERKIRIM  •  tetap waspada."
        var sign_idx := -1
        for i in range(facilities.size()):
            if str(facilities[i]["id"]) == "signage": sign_idx = i
        if sign_idx >= 0 and int(facilities[sign_idx]["level"]) > 0:
            if player.global_position.distance_to(facilities[sign_idx]["pos"]) < 4.0: return "E  •  KIRIM PERINGATAN DINI KE WARGA"
            return "Datangi rambu evakuasi untuk mengirim peringatan dini."
        return "Peringatan dini tidak tersedia karena rambu belum dibangun."
    if GameState.stage == GameState.PREPARATION:
        var f := _nearest_facility(player.global_position, 4.2, false)
        if not f.is_empty():
            var data: Dictionary = facilities[int(f["index"])]
            if int(data["level"]) == 0: return "E  •  BANGUN %s  (%s)" % [str(data["name"]).to_upper(), KotaLocale.format_money(int(data["build_cost"]))]
            if int(data["level"]) == 1: return "E  •  TINGKATKAN %s  (%s)" % [str(data["name"]).to_upper(), KotaLocale.format_money(int(data["upgrade_cost"]))]
            return "%s  •  SUDAH MAKSIMUM" % str(data["name"]).to_upper()
        if not bool(side_event.get("done", false)) and player.global_position.distance_to(side_event["pos"]) < 4.2: return "E  •  " + str(side_event["label"]).to_upper()
    if GameState.stage == GameState.HANDLING:
        var h := _nearest_hazard(player.global_position, 4.2)
        if not h.is_empty(): return "E  •  TANGANI " + str(hazards[int(h["index"])]["name"]).to_upper()
        var ci := _nearest_citizen(player.global_position, 4.2)
        if ci >= 0:
            var citizen: Node3D = citizens[ci]
            if str(citizen.get("state")) == "safe": return str(citizen.get("display_name")).to_upper() + "  •  SUDAH AMAN"
            if str(citizen.get("state")) == "evacuating": return str(citizen.get("display_name")).to_upper() + "  •  MENUJU TITIK AMAN"
            return "E  •  BICARA DENGAN " + str(citizen.get("display_name")).to_upper()
        if not bool(side_event.get("done", false)) and player.global_position.distance_to(side_event["pos"]) < 4.2: return "E  •  " + str(side_event["label"]).to_upper()
    if GameState.stage == GameState.INSPECTION:
        var f2 := _nearest_facility(player.global_position, 4.2, true)
        if not f2.is_empty(): return "E  •  PERIKSA " + str(facilities[int(f2["index"])]["name"]).to_upper()
    if GameState.stage == GameState.REPAIR:
        var f3 := _nearest_facility(player.global_position, 4.2, true)
        if not f3.is_empty(): return "E  •  PERBAIKI FASILITAS (%s)" % KotaLocale.format_money(int(facilities[int(f3["index"])]["repair_cost"]))
    return "Ikuti marker objective terdekat." if KotaLocale.language_code == "id" else "Follow the nearest objective marker."


func _facility_name_english(id: String) -> String:
    match id:
        "drain": return "Main Drainage"
        "resapan": return "Rain Garden"
        "ramp": return "Accessible Ramp"
        "signage": return "Evacuation Sign"
    return id.replace("_", " ").capitalize()

func _hazard_name_english(id: String) -> String:
    match id:
        "drain_clog": return "Blocked Drain"
        "water_crossing": return "Standing Water"
        "flood_crossing": return "Flooded Main Road"
        "emergency_pump": return "Emergency Pump"
        "road_debris": return "Road Debris"
        "fallen_tree": return "Fallen Tree"
    return id.replace("_", " ").capitalize()

func side_mission_status_text() -> String:
    if KotaLocale.language_code == "en":
        var en_title := str(side_event.get("label", "SIDE OBJECTIVE"))
        if side_bonus_done: return "%s  •  COMPLETE (%d/3 campaign)" % [en_title, GameState.side_events_completed]
        if current_level == 2 and medkit_carried: return "FIRST AID KIT CARRIED  •  deliver it to Mrs. Rukmini"
        if bool(side_event.get("done", false)): return "%s  •  FOLLOW-UP PENDING" % en_title
        return "%s  •  OPTIONAL" % en_title
    var title := str(side_event.get("label", "MISI SAMPINGAN"))
    if side_bonus_done:
        return "%s  •  SELESAI (%d/3 kampanye)" % [title, GameState.side_events_completed]
    if current_level == 2 and medkit_carried:
        return "P3K SUDAH DIBAWA  •  serahkan kepada Bu Rukmini"
    if bool(side_event.get("done", false)):
        return "%s  •  MENUNGGU TINDAKAN LANJUT" % title
    return "%s  •  OPSIONAL" % title

func navigation_hint_text() -> String:
    if KotaLocale.language_code == "en":
        if not mission_started: return "DEPLOY TO DISTRICT\nReview the briefing to begin."
        if GameState.stage == GameState.EVALUATION: return "REPORT READY\nReview the stage results."
        if GameState.stage == GameState.DISASTER:
            if early_warning_used: return "WARNING SENT\n%.0f sec remaining" % maxf(0.0, disaster_duration - disaster_timer)
            return "ACTIVE HAZARD\nWatch the timer and send an early warning if signage is ready."
        if GameState.stage == GameState.PREPARATION: return "PREP PHASE\nBuild or upgrade the nearest priority facility."
        if GameState.stage == GameState.HANDLING:
            if not _hazards_cleared(): return "RESPONSE\nFollow the hazard markers and clear the route."
            if GameState.citizens_safe < GameState.citizens_total: return "EVACUATION\nMeet residents and guide them to the Safe Point."
            return "RESPONSE CLEAR\nProceed to the inspection phase."
        if GameState.stage == GameState.INSPECTION: return "INSPECTION\nCheck every damaged facility."
        if GameState.stage == GameState.REPAIR: return "REPAIR PHASE\nRepair the facilities marked as damaged."
    if not mission_started:
        return "MASUK KE KAWASAN\nBaca briefing untuk memulai."
    if GameState.stage == GameState.EVALUATION:
        return "LAPORAN SIAP\nTinjau hasil skenario."

    var target_name := ""
    var target_position := Vector3.ZERO
    var best_distance := INF
    var current_position: Vector3 = player.global_position

    match GameState.stage:
        GameState.PREPARATION:
            for f in facilities:
                var level_value := int(f["level"])
                if level_value >= 2:
                    continue
                var action_cost := int(f["build_cost"]) if level_value == 0 else int(f["upgrade_cost"])
                if action_cost > GameState.budget:
                    continue
                var facility_position: Vector3 = f["pos"]
                var d: float = Vector2(current_position.x - facility_position.x, current_position.z - facility_position.z).length()
                if d < best_distance:
                    best_distance = d
                    target_name = str(f["name"]) + (" • TINGKATKAN" if level_value == 1 else " • BANGUN")
                    target_position = f["pos"]
            if not bool(side_event.get("done", false)):
                var side_pos: Vector3 = side_event["pos"]
                var side_distance := Vector2(current_position.x - side_pos.x, current_position.z - side_pos.z).length()
                if side_distance < best_distance:
                    best_distance = side_distance
                    target_name = "OPSIONAL • " + str(side_event.get("label", "MISI SAMPINGAN"))
                    target_position = side_pos
        GameState.DISASTER:
            if early_warning_used:
                return "PERINGATAN TERKIRIM\nSisa waktu %.0f dtk" % maxf(0.0, disaster_duration - disaster_timer)
            for f in facilities:
                if str(f["id"]) == "signage" and int(f["level"]) > 0:
                    target_name = "KIRIM PERINGATAN DINI"
                    target_position = f["pos"]
                    best_distance = Vector2(current_position.x - target_position.x, current_position.z - target_position.z).length()
                    break
            if target_name.is_empty():
                return "BENCANA BERLANGSUNG\nSiapkan diri untuk penanganan."
        GameState.HANDLING:
            for h in hazards:
                if bool(h["done"]):
                    continue
                var hazard_pos: Vector3 = h["pos"]
                var d := Vector2(current_position.x - hazard_pos.x, current_position.z - hazard_pos.z).length()
                if d < best_distance:
                    best_distance = d
                    target_name = str(h["name"])
                    target_position = hazard_pos
            if target_name.is_empty():
                if current_level == 2 and medkit_carried:
                    for citizen in citizens:
                        if str(citizen.get("citizen_type")) == "Lansia" and str(citizen.get("state")) != "safe":
                            target_name = "ANTAR P3K • " + str(citizen.get("display_name"))
                            target_position = citizen.global_position
                            best_distance = Vector2(current_position.x - target_position.x, current_position.z - target_position.z).length()
                            break
                else:
                    # Find the nearest mandatory citizen task first.
                    for citizen in citizens:
                        var citizen_state := str(citizen.get("state"))
                        if citizen_state in ["safe", "evacuating"]:
                            continue
                        var d := Vector2(current_position.x - citizen.global_position.x, current_position.z - citizen.global_position.z).length()
                        if d < best_distance:
                            best_distance = d
                            target_name = "BANTU • " + str(citizen.get("display_name"))
                            target_position = citizen.global_position
                    # An optional story marker can be the target when it is the closer nearby task.
                    if not bool(side_event.get("done", false)):
                        var optional_pos: Vector3 = side_event["pos"]
                        var optional_distance := Vector2(current_position.x - optional_pos.x, current_position.z - optional_pos.z).length()
                        if optional_distance < best_distance:
                            best_distance = optional_distance
                            target_name = "OPSIONAL • " + str(side_event.get("label", "MISI SAMPINGAN"))
                            target_position = optional_pos
                if target_name.is_empty():
                    if GameState.citizens_total > 0 and GameState.citizens_safe < GameState.citizens_total:
                        return "PANTAU EVAKUASI\nWarga masih menuju Titik Aman."
                    if not bool(side_event.get("done", false)):
                        target_name = "OPSIONAL • " + str(side_event.get("label", "MISI SAMPINGAN"))
                        target_position = side_event["pos"]
                        best_distance = Vector2(current_position.x - target_position.x, current_position.z - target_position.z).length()
                    else:
                        return "PENANGANAN TUNTAS\nSiapkan pemeriksaan fasilitas."
        GameState.INSPECTION:
            for f in facilities:
                if not bool(f["damaged"]) or bool(f["inspected"]):
                    continue
                var pos: Vector3 = f["pos"]
                var d := Vector2(current_position.x - pos.x, current_position.z - pos.z).length()
                if d < best_distance:
                    best_distance = d
                    target_name = "PERIKSA • " + str(f["name"])
                    target_position = pos
        GameState.REPAIR:
            for f in facilities:
                if not bool(f["damaged"]) or not bool(f["inspected"]) or bool(f["repaired"]):
                    continue
                var pos: Vector3 = f["pos"]
                var d := Vector2(current_position.x - pos.x, current_position.z - pos.z).length()
                if d < best_distance:
                    best_distance = d
                    target_name = "PULIHKAN • " + str(f["name"])
                    target_position = pos

    if target_name.is_empty():
        return "TIDAK ADA TARGET BARU\nPeriksa objektif tahap ini."

    var delta_x := target_position.x - current_position.x
    var delta_z := target_position.z - current_position.z
    var direction := ""
    if absf(delta_x) > absf(delta_z) * 1.7:
        direction = "TIMUR" if delta_x > 0.0 else "BARAT"
    elif absf(delta_z) > absf(delta_x) * 1.7:
        direction = "SELATAN" if delta_z > 0.0 else "UTARA"
    else:
        if delta_z < 0.0:
            direction = "TIMUR LAUT" if delta_x > 0.0 else "BARAT LAUT"
        else:
            direction = "TENGGARA" if delta_x > 0.0 else "BARAT DAYA"
    if best_distance <= 3.8:
        return "%s\nDI DEKATMU • TEKAN E" % target_name
    return "%s\nARAH %s • %dm" % [target_name, direction, roundi(best_distance)]

func _nearest_facility(pos: Vector3, radius: float, damaged_only: bool) -> Dictionary:
    var best := -1
    var best_distance := radius
    for i in range(facilities.size()):
        var f: Dictionary = facilities[i]
        if damaged_only and (not bool(f["damaged"]) or bool(f["repaired"])): continue
        var d: float = pos.distance_to(f["pos"])
        if d < best_distance:
            best = i
            best_distance = d
    if best < 0: return {}
    return {"index":best, "distance":best_distance}

func _nearest_hazard(pos: Vector3, radius: float) -> Dictionary:
    var best := -1
    var best_distance := radius
    for i in range(hazards.size()):
        if bool(hazards[i]["done"]): continue
        var d: float = pos.distance_to(hazards[i]["pos"])
        if d < best_distance:
            best = i
            best_distance = d
    if best < 0: return {}
    return {"index":best, "distance":best_distance}

func _nearest_citizen(pos: Vector3, radius: float) -> int:
    var best := -1
    var best_distance := radius
    for i in range(citizens.size()):
        var c: Node3D = citizens[i]
        if str(c.get("state")) in ["safe", "evacuating"]: continue
        var d: float = pos.distance_to(c.global_position)
        if d < best_distance:
            best = i
            best_distance = d
    return best

func _facility_level(id: String) -> int:
    for f in facilities:
        if str(f["id"]) == id: return int(f["level"])
    return 0

func accessibility_score() -> int:
    # Accessibility is tied to built infrastructure and real evacuation outcomes,
    # not a generic player health/heart meter.
    var ramp_level := _facility_level("ramp")
    var value := 40
    if ramp_level >= 1: value += 30
    if ramp_level >= 2: value += 15
    if current_level >= 2 and GameState.citizens_total > 0:
        var wheelchair_safe := false
        for citizen in citizens:
            if str(citizen.get("citizen_type")) == "Pengguna kursi roda" and str(citizen.get("state")) == "safe":
                wheelchair_safe = true
                break
        if wheelchair_safe: value += 15
    return clampi(value, 0, 100)

func _hazards_cleared() -> bool:
    for h in hazards:
        if not bool(h["done"]): return false
    return true

func _inspection_complete() -> bool:
    for f in facilities:
        if bool(f["damaged"]) and not bool(f["inspected"]): return false
    return true

func _update_facility(f: Dictionary) -> void:
    var is_en := KotaLocale.language_code == "en"
    var status := "NOT READY" if is_en else "BELUM SIAP"
    var tint := Color("#edc46d")
    if int(f["level"]) > 0:
        status = ("READY · LV.%d" if is_en else "SIAP · LV.%d") % int(f["level"])
        tint = Color("#77dcaf")
    if bool(f["damaged"]) and not bool(f["repaired"]):
        status = "DAMAGED · INSPECT" if is_en else "RUSAK · PERIKSA"
        tint = Color("#ff9a67")
    if bool(f["inspected"]) and bool(f["damaged"]) and not bool(f["repaired"]):
        status = "FINDING LOGGED" if is_en else "TEMUAN TERCATAT"
        tint = Color("#f4cc73")
    if bool(f["repaired"]):
        status = "RESTORED" if is_en else "PULIH"
        tint = Color("#73e2bb")
    world.call("update_facility_marker", str(f["id"]), status, tint)

func _create_initial_markers() -> void:
    pass

func _sync_world() -> void:
    if is_instance_valid(world):
        for citizen in citizens:
            if citizen.has_method("_process_status"): citizen.call("_process_status")

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        active = false
