extends Node

signal language_changed(language_code: String)

const SETTINGS_PATH := "user://kota_siaga_settings.cfg"
var language_code: String = "id"

const TEXTS := {
    "menu_kicker": {"id":"SIMULASI KESIAPSIAGAAN BENCANA  •  SEMI-3D", "en":"DISASTER READINESS SIMULATION  •  SEMI-3D"},
    "title": {"id":"KOTA SIAGA", "en":"CITY ALERT"},
    "subtitle": {"id":"Satu Kota, Banyak Kehidupan", "en":"One City, Many Lives"},
    "menu_desc": {"id":"Arunika tumbuh menjadi kota metropolitan. Tiga bencana menguji infrastruktur, anggaran, dan keselamatan warga.", "en":"Arunika is growing into a metropolitan city. Three disasters will test its infrastructure, budget, and public safety."},
    "mission_title": {"id":"OPERASI LAPANGAN", "en":"FIELD OPERATIONS"},
    "campaign_progress": {"id":"", "en":""},
    "stage_locked_hint": {"id":"Selesaikan stage sebelumnya untuk membuka stage ini.", "en":"Complete the previous stage to unlock this one."},
    "ambient_activity": {"id":"Aktivitas warga", "en":"Resident activity"},
    "field_start": {"id":"Koordinator online. Cek objective, tentukan prioritas, lalu bergerak.", "en":"Coordinator online. Check the objective, set priorities, and move out."},
    "field_follow": {"id":"Ikuti marker objective dan interaksi dengan tombol E saat sudah dekat.", "en":"Follow the objective marker and interact with E when in range."},
    "stage_complete": {"id":"Stage clear. Cek laporan dan lanjut ke stage berikutnya.", "en":"Stage clear. Review the report and continue to the next stage."},
    "mission_steps": {"id":"Siapkan kawasan  •  Kirim peringatan  •  Evakuasi\nInspeksi kerusakan  •  Perbaikan fasilitas", "en":"Prepare the district  •  Send alerts  •  Evacuate\nInspect damage  •  Repair critical facilities"},
    "story": {"id":"CERITA", "en":"STORY"},
    "continue": {"id":"LANJUTKAN STAGE %02d  →", "en":"CONTINUE STAGE %02d  →"},
    "start": {"id":"MULAI KAMPANYE  →", "en":"START CAMPAIGN  →"},
    "settings": {"id":"PENGATURAN", "en":"SETTINGS"},
    "menu_tag": {"id":"", "en":""},
    "mission_current": {"id":"MISI SAAT INI", "en":"CURRENT OBJECTIVE"},
    "district_status": {"id":"STATUS KAWASAN", "en":"DISTRICT STATUS"},
    "navigation": {"id":"ARAH TUJUAN", "en":"OBJECTIVE TRACKER"},
    "comms": {"id":"PESAN SISTEM", "en":"SYSTEM MESSAGE"},
    "system_message": {"id":"PESAN SISTEM", "en":"SYSTEM MESSAGE"},
    "report": {"id":"LAPORAN OPERASI", "en":"OPS REPORT"},
    "story_heading": {"id":"CERITA  /  PILIH STAGE", "en":"STORY  /  SELECT STAGE"},
    "story_sub": {"id":"Pilih stage yang sudah terbuka. Progres tersimpan otomatis setelah stage selesai.", "en":"Choose an unlocked stage. Progress is saved when a stage is completed."},
    "stage_1": {"id":"STAGE 01  ·  HUJAN EKSTREM", "en":"STAGE 01  ·  EXTREME RAIN"},
    "stage_2": {"id":"STAGE 02  ·  BANJIR PERKOTAAN", "en":"STAGE 02  ·  URBAN FLOOD"},
    "stage_3": {"id":"STAGE 03  ·  ANGIN PUTING BELIUNG", "en":"STAGE 03  ·  TORNADO"},
    "stage_desc_1": {"id":"Siapkan fasilitas dan respons terhadap hujan ekstrem.", "en":"Prepare infrastructure and respond to extreme rain."},
    "stage_desc_2": {"id":"Buka akses yang terendam dan evakuasi warga.", "en":"Reopen flooded routes and evacuate residents."},
    "stage_desc_3": {"id":"Bersihkan puing, selamatkan warga, dan perbaiki kawasan.", "en":"Clear debris, rescue residents, and repair the district."},
    "play_stage": {"id":"MAINKAN STAGE", "en":"PLAY STAGE"},
    "locked": {"id":"TERKUNCI", "en":"LOCKED"},
    "back_menu": {"id":"KEMBALI KE MENU", "en":"BACK TO MENU"},
    "settings_heading": {"id":"PENGATURAN", "en":"SETTINGS"},
    "language": {"id":"BAHASA", "en":"LANGUAGE"},
    "rules_title": {"id":"RULES / CARA BERMAIN", "en":"RULES / HOW TO PLAY"},
    "rules_body": {"id":"TUJUAN\nSelesaikan objektif setiap stage dan jaga keselamatan warga.\n\nKONTROL\nWASD / panah — bergerak  ·  Shift — sprint\nSpace — lompat  ·  E — interaksi  ·  Tab — lepas/tangkap kursor\nEsc — jeda  ·  Mouse — putar kamera\n\nPROGRES\nStage yang terbuka bisa dipilih kembali. Progres tersimpan otomatis setelah stage selesai.", "en":"OBJECTIVE\nComplete each stage objective and keep residents safe.\n\nCONTROLS\nWASD / arrows — move  ·  Shift — sprint\nSpace — jump  ·  E — interact  ·  Tab — release/capture cursor\nEsc — pause  ·  Mouse — orbit camera\n\nPROGRESS\nUnlocked stages can be replayed. Progress is saved after each completed stage."},
    "close": {"id":"KEMBALI", "en":"BACK"},
    "prep": {"id":"PERSIAPAN", "en":"PREP"},
    "disaster": {"id":"BENCANA AKTIF", "en":"DISASTER"},
    "response": {"id":"RESPONS", "en":"RESPONSE"},
    "inspection": {"id":"INSPEKSI", "en":"INSPECTION"},
    "repair": {"id":"PERBAIKAN", "en":"REPAIR"},
    "debrief": {"id":"EVALUASI", "en":"DEBRIEF"},
    "funds": {"id":"ANGGARAN", "en":"FUNDS"},
        "points": {"id":"SKOR", "en":"POINTS"},
    "access": {"id":"AKSES", "en":"ACCESS"},
    "assets": {"id":"FASILITAS", "en":"ASSETS"},
    "damaged": {"id":"RUSAK", "en":"DAMAGED"},
    "repaired": {"id":"DIPERBAIKI", "en":"REPAIRED"},
    "civilians_safe": {"id":"WARGA AMAN", "en":"CIVILIANS SAFE"},
    "active_area": {"id":"KAWASAN AKTIF", "en":"AREA ACTIVE"},
    "stage_prefix": {"id":"STAGE", "en":"STAGE"},
    "trust": {"id":"KEPERCAYAAN", "en":"TRUST"},
    "upgrade": {"id":"UPGRADE", "en":"UPGRADES"},
    "inspected": {"id":"DIPERIKSA", "en":"INSPECTED"},
    "time_morning": {"id":"PAGI", "en":"MORNING"},
    "time_day": {"id":"SIANG", "en":"DAYTIME"},
    "time_evening": {"id":"SORE", "en":"EVENING"},
    "time_night": {"id":"MALAM", "en":"NIGHT"},
    "weather_clear": {"id":"CERAH", "en":"CLEAR"},
    "weather_rain": {"id":"HUJAN EKSTREM", "en":"HEAVY RAIN"},
    "weather_flood": {"id":"BANJIR AKTIF", "en":"FLOOD ACTIVE"},
    "weather_wind": {"id":"PUTING BELIUNG", "en":"TORNADO WARNING"},
    "evaluation_title": {"id":"LAPORAN KESIAPSIAGAAN", "en":"READINESS REPORT"},
    "pause_title": {"id":"JEDA PERMAINAN", "en":"PAUSED"},
    "resume": {"id":"LANJUTKAN", "en":"RESUME"},
    "restart_stage": {"id":"ULANGI STAGE", "en":"RESTART STAGE"},
    "main_menu": {"id":"KEMBALI KE MENU", "en":"MAIN MENU"},
    "safe_point": {"id":"TITIK AMAN", "en":"SAFE POINT"},
    "next_stage": {"id":"STAGE BERIKUTNYA  →", "en":"NEXT STAGE  →"},
    "loading": {"id":"MEMUAT KAWASAN…", "en":"LOADING DISTRICT…"},
    "quest_waiting": {"id":"MENUNGGU BANTUAN", "en":"AWAITING ASSISTANCE"},
    "quest_alert": {"id":"BUTUH BANTUAN", "en":"NEEDS HELP"},
    "quest_moving": {"id":"MENUJU TITIK AMAN", "en":"MOVING TO SAFE POINT"},
    "quest_safe": {"id":"AMAN  ✓", "en":"SAFE  ✓"},
    "msg_start": {"id":"Koordinator online. Cek objective, tentukan prioritas, lalu bergerak.", "en":"Coordinator online. Check the objective, set priorities, and move out."},
    "msg_vehicle": {"id":"Kendaraan melintas dekat. Jaga jarak dan gunakan jalur aman.", "en":"Traffic is passing nearby. Keep clear of the lane and use the sidewalk."},
    "msg_funds": {"id":"Dana tidak mencukupi. Pilih tindakan lain atau gunakan gotong royong untuk membuka akses darurat.", "en":"Insufficient funds. Choose another action or use community effort to reopen the emergency route."},
    "msg_build_first": {"id":"Bangun setidaknya satu fasilitas sebelum memulai bencana.", "en":"Build at least one facility before triggering the disaster phase."},
    "msg_disaster_wait": {"id":"Ancaman masih aktif. Waktu respons belum selesai; manfaatkan kesempatan untuk mengirim peringatan dini.", "en":"The hazard is still active. Wait for the response timer and send an early warning if available."},
    "msg_warning": {"id":"PERINGATAN DINI TERKIRIM! Respons diperpanjang 4 detik agar warga sempat bersiap. Skor +12, kepercayaan +8.", "en":"EARLY WARNING SENT! Response time increased by 4 seconds. Score +12, trust +8."},
    "msg_inspection": {"id":"Pemeriksaan selesai. Perbaiki fasilitas prioritas dengan dana yang tersisa.", "en":"Inspection complete. Repair priority facilities with the remaining funds."},
    "msg_prep_needed": {"id":"Bangun setidaknya satu fasilitas sebelum memulai bencana.", "en":"Build at least one facility before starting the hazard phase."},
    "msg_hazards_pending": {"id":"Masih ada hambatan yang belum ditangani. Cek marker darurat yang tersisa.", "en":"Some hazards are still active. Check the remaining emergency markers."},
    "msg_citizens_pending": {"id":"Belum semua warga sampai di Titik Aman. Temui mereka dan bantu evakuasi.", "en":"Not all residents have reached the Safe Point. Find them and assist with evacuation."},
    "msg_inspection_pending": {"id":"Masih ada fasilitas rusak yang belum diperiksa.", "en":"Some damaged facilities still need inspection."},
    "msg_stage_clear": {"id":"Stage clear. Cek laporan operasi sebelum lanjut.", "en":"Stage clear. Review the operation report before continuing."},
    "msg_district_ready": {"id":"Kawasan Arunika siap. Cek objective dan tentukan prioritas.", "en":"Arunika is ready. Check the objectives and set priorities."},
    "msg_facility_hint": {"id":"Dekati marker fasilitas untuk membangun, upgrade, atau memperbaikinya.", "en":"Approach a facility marker to build, upgrade, or repair it."},
    "player_tag": {"id":"KOORDINATOR", "en":"COORDINATOR"},
    "skin_loadout": {"id":"SKIN PLAYER", "en":"PLAYER SKIN"},
    "skin_logistics": {"id":"LOGISTIK", "en":"LOGISTICS"},
    "skin_medic": {"id":"MEDIS", "en":"MEDIC"},
    "skin_fire": {"id":"PEMADAM", "en":"FIRE"},
    "skin_police": {"id":"POLISI", "en":"POLICE"},
    "msg_facility_built": {"id":"Fasilitas terpasang. Ketahanan kawasan meningkat.", "en":"Facility deployed. District resilience improved."},
    "msg_facility_upgraded": {"id":"Upgrade selesai. Fasilitas lebih siap menghadapi dampak bencana.", "en":"Upgrade complete. The facility is better prepared for disaster impact."},
    "msg_facility_max": {"id":"Fasilitas sudah mencapai tingkat maksimum. Simpan dana untuk respons darurat.", "en":"Facility is at maximum upgrade. Keep funds for emergency response."},
    "msg_hazard_done": {"id":"Ancaman berhasil ditangani. Objective lapangan diperbarui.", "en":"Hazard cleared. Field objective updated."},
    "msg_evacuation_hint": {"id":"Temui warga yang butuh bantuan, lalu pilih tindakan yang sesuai.", "en":"Find residents who need help and choose the appropriate response."},
    "msg_citizen_safe": {"id":"Warga sudah mencapai Titik Aman.", "en":"Resident reached the Safe Point."},
    "msg_citizen_moving": {"id":"Warga sedang mengikuti rute evakuasi. Pastikan akses tetap terbuka.", "en":"Resident is following the evacuation route. Keep access clear."},
    "msg_reassure": {"id":"Kamu mendengarkan warga. Trust meningkat dan warga lebih tenang.", "en":"You listened to the resident. Trust increased and they are calmer."},
    "msg_reassured_before": {"id":"Warga sudah lebih tenang. Lanjutkan proses evakuasi.", "en":"The resident is calmer now. Continue the evacuation."},
    "msg_medkit_bonus": {"id":"Side objective selesai: P3K diterima warga. Skor dan kepercayaan bertambah.", "en":"Side objective cleared: first-aid supplies delivered. Score and trust increased."},
    "msg_accessible_detour": {"id":"Rute alternatif digunakan karena ramp akses belum tersedia. Waktu tempuh bertambah.", "en":"An alternate route is in use because the access ramp is unavailable. Travel time increased."},
    "msg_inspection_target": {"id":"Datangi fasilitas berstatus rusak untuk memulai inspeksi.", "en":"Approach a damaged facility to start inspection."},
    "msg_inspection_recorded": {"id":"Data kerusakan tercatat. Lanjutkan inspeksi fasilitas lain.", "en":"Damage report recorded. Inspect the next facility."},
    "msg_inspection_complete": {"id":"Inspeksi selesai. Pilih fasilitas prioritas untuk diperbaiki.", "en":"Inspection complete. Choose a priority facility to repair."},
    "msg_repair_target": {"id":"Dekati fasilitas rusak yang sudah diinspeksi untuk memperbaikinya.", "en":"Approach an inspected damaged facility to repair it."},
    "msg_inspect_first": {"id":"Inspeksi fasilitas ini terlebih dahulu sebelum perbaikan.", "en":"Inspect this facility before attempting repairs."},
    "msg_already_repaired": {"id":"Fasilitas ini sudah diperbaiki.", "en":"This facility has already been repaired."},
    "msg_repaired_cost": {"id":"Perbaikan selesai. Kondisi fasilitas dan status kawasan diperbarui.", "en":"Repair complete. Facility condition and district status updated."},
    "msg_route_blocked": {"id":"Anggaran darurat habis. Warga membantu membuka akses, tetapi skor dan kepercayaan turun.", "en":"Emergency funds depleted. Residents cleared access, but score and trust decreased."},
    "msg_stage1_side": {"id":"Side objective selesai. Laporan lapangan kini lebih cepat diteruskan ke tim respons.", "en":"Side objective cleared. Field reports now reach the response team faster."},
    "msg_medkit_carried": {"id":"P3K sudah diamankan. Serahkan kepada Bu Rukmini untuk bonus cerita.", "en":"First-aid kit secured. Deliver it to Mrs. Rukmini for the story bonus."},
    "msg_siren_restored": {"id":"Side objective selesai. Repeater sirene aktif dan peringatan bisa diterima lebih cepat.", "en":"Side objective cleared. The siren relay is online, so alerts can arrive sooner."},
    "msg_citizen_arrived": {"id":"Warga mencapai Titik Aman. Jumlah warga selamat dan trust diperbarui.", "en":"Resident reached the Safe Point. Safe-resident count and trust updated."},
    "msg_special_ending": {"id":"SPECIAL ENDING — KOORDINATOR TELADAN! Semua side objective selesai. Arunika lebih siap menghadapi bencana.", "en":"SPECIAL ENDING — OUTSTANDING COORDINATOR! All side objectives cleared. Arunika is better prepared for disaster."},
    "msg_campaign_complete": {"id":"Kampanye selesai. Arunika belajar dari tiga bencana. Side objective lain bisa dikerjakan saat replay.", "en":"Campaign complete. Arunika learned from three disasters. Replay to finish any remaining side objectives."},
    "msg_debrief": {"id":"Laporan operasi siap. Tinjau hasil sebelum lanjut ke stage berikutnya.", "en":"Operations report ready. Review the results before moving to the next stage."},
    "msg_hazard_started": {"id":"Bencana dimulai. Timer respons berjalan; kirim peringatan dini jika rambu siap.", "en":"Hazard phase started. Response timer is running; send an early warning if signage is ready."},
    "msg_warning_unavailable": {"id":"Peringatan dini belum tersedia karena rambu evakuasi belum dibangun.", "en":"Early warning is unavailable because evacuation signage has not been built."},
    "msg_inspection_prompt": {"id":"Datangi fasilitas yang ditandai rusak untuk memulai inspeksi.", "en":"Approach a damaged facility to start inspection."}
}

const MESSAGE_PREFIXES := {
    "PERINGATAN DINI TERKIRIM!": "msg_warning",
    "Koordinator masuk kawasan.": "msg_start",
    "Kendaraan melintas dekat.": "msg_vehicle",
    "Kawasan Arunika menunggu": "msg_district_ready",
    "Kawasan Arunika siap.": "msg_district_ready",
    "Pemeriksaan selesai. Pulihkan": "msg_inspection",
    "Pemeriksaan selesai.": "msg_inspection",
    "Bangun setidaknya satu fasilitas": "msg_prep_needed",
    "Masih ada hambatan yang belum ditangani.": "msg_hazards_pending",
    "Masih ada hambatan.": "msg_hazards_pending",
    "Belum semua warga tiba di Titik Aman.": "msg_citizens_pending",
    "Belum semua warga sampai di Titik Aman.": "msg_citizens_pending",
    "Masih ada fasilitas rusak": "msg_inspection_pending",
    "Penanganan selesai.": "msg_stage_clear",
    "Dekati penanda fasilitas": "msg_facility_hint",
    "Dekati fasilitas yang ditandai RUSAK": "msg_inspection_target",
    "Dekati fasilitas rusak yang sudah diperiksa": "msg_repair_target",
    "Periksa fasilitas ini terlebih dahulu.": "msg_inspect_first",
    "Fasilitas ini sudah pulih.": "msg_already_repaired",
    "Pemeriksaan %s selesai.": "msg_inspection_complete",
    "Temuan %s sudah tercatat.": "msg_inspection_recorded",
    "SIDE OBJECTIVE CLEAR — the siren relay": "msg_siren_restored",
    "SIDE OBJECTIVE CLEAR — field reports": "msg_stage1_side",
    "SIDE OBJECTIVE SELESAI — repeater sirene": "msg_siren_restored",
    "SIDE OBJECTIVE SELESAI — meja informasi": "msg_stage1_side",
    "MISI SAMPINGAN SELESAI — Bu Rukmini": "msg_medkit_bonus",
    "ENDING SPESIAL": "msg_special_ending",
    "Kampanye selesai.": "msg_campaign_complete",
    "Dana tidak mencukupi.": "msg_funds",
    "Anggaran darurat habis.": "msg_route_blocked",
    "Ancaman masih aktif.": "msg_disaster_wait",
    "Masih ada hambatan. Ikuti": "msg_hazards_pending",
    "Bencana berlangsung.": "msg_disaster_wait",
    "Rambu belum dibangun": "msg_warning_unavailable",
    "Peringatan dini sudah terkirim.": "msg_warning",
    "Laporan kesiapsiagaan kawasan selesai.": "msg_debrief",
    "Dekati warga yang membutuhkan bantuan": "msg_evacuation_hint"
}

func _ready() -> void:
    var config := ConfigFile.new()
    if config.load(SETTINGS_PATH) == OK:
        var saved := str(config.get_value("settings", "language", "id"))
        language_code = "en" if saved == "en" else "id"

func t(key: String) -> String:
    if TEXTS.has(key):
        return str(TEXTS[key].get(language_code, TEXTS[key].get("id", key)))
    return key

func set_language(code: String) -> void:
    var next_code := "en" if code.to_lower().begins_with("en") else "id"
    if language_code == next_code:
        return
    language_code = next_code
    var config := ConfigFile.new()
    config.set_value("settings", "language", language_code)
    var error := config.save(SETTINGS_PATH)
    if error != OK:
        push_warning("Unable to save language setting: %s" % error_string(error))
    language_changed.emit(language_code)

func format_money(amount: int) -> String:
    var text_value := str(maxi(amount, 0))
    var separator := "." if language_code == "id" else ","
    var result := ""
    while text_value.length() > 3:
        result = separator + text_value.substr(text_value.length() - 3, 3) + result
        text_value = text_value.substr(0, text_value.length() - 3)
    result = text_value + result
    return "Rp " + result if language_code == "id" else "$" + result

func translate_message(text_value: String) -> String:
    if language_code != "en":
        return text_value
    for prefix in MESSAGE_PREFIXES.keys():
        if text_value.begins_with(str(prefix)):
            return t(str(MESSAGE_PREFIXES[prefix]))
    # Some field-callouts begin with a resident or facility name, so translate by action phrase.
    if text_value.contains(" dibangun. Ketahanan kawasan"):
        return t("msg_facility_built")
    if text_value.contains(" ditingkatkan. Fasilitas"):
        return t("msg_facility_upgraded")
    if text_value.contains(" sudah di tingkat maksimum"):
        return t("msg_facility_max")
    if text_value.contains(" sudah berada di Titik Aman") or text_value.contains(" tiba di Titik Aman"):
        return t("msg_citizen_safe")
    if text_value.contains(" sedang mengikuti jalur evakuasi"):
        return t("msg_citizen_moving")
    if text_value.contains("meluangkan waktu mendengarkan"):
        return t("msg_reassure")
    if text_value.contains("sudah lebih tenang"):
        return t("msg_reassured_before")
    if text_value.contains("mengikuti rute yang sesuai"):
        return t("msg_citizen_moving")
    if text_value.contains("rute alternatif yang lebih panjang"):
        return t("msg_accessible_detour")
    if text_value.contains("berhasil dipulihkan dengan biaya"):
        return t("msg_repaired_cost")
    if text_value.contains("berhasil ditangani"):
        return t("msg_hazard_done")
    if text_value.contains(" tiba di Titik Aman. Warga selamat"):
        return t("msg_citizen_arrived")
    if text_value.contains(" datang. Waktu respons dimulai"):
        return t("msg_hazard_started")
    if text_value.contains(" sudah tercatat."):
        return t("msg_inspection_recorded")
    if text_value.contains(" selesai. Temuan masuk ke laporan kawasan."):
        return t("msg_inspection_complete")
    if text_value.contains("PERINGATAN DINI") and text_value.contains("Belum"):
        return t("msg_warning_unavailable")
    if text_value.contains("tiba di Titik Aman") and text_value.contains("Warga selamat"):
        return t("msg_citizen_arrived")
    return text_value

func time_period(hour: int) -> String:
    if hour >= 5 and hour < 11: return t("time_morning")
    if hour >= 11 and hour < 16: return t("time_day")
    if hour >= 16 and hour < 19: return t("time_evening")
    return t("time_night")
