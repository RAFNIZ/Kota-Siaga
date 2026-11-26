extends Node

signal changed
signal message_changed(text: String)

const PREPARATION := 0
const DISASTER := 1
const HANDLING := 2
const INSPECTION := 3
const REPAIR := 4
const EVALUATION := 5

var level: int = 1
var stage: int = PREPARATION
var budget: int = 1000
var score: int = 0
var total_score: int = 0
var trust: int = 60
var facilities_ready: int = 0
var facilities_upgraded: int = 0
var damaged_count: int = 0
var inspected_count: int = 0
var repaired_count: int = 0
var citizens_safe: int = 0
var citizens_total: int = 0
var message: String = ""
var campaign_complete: bool = false
var side_events_completed: int = 0
var unlocked_level: int = 1
var chapter_stars: Array[int] = [0, 0, 0, 0]
var player_skin: String = "logistics"
const SAVE_PATH := "user://kota_siaga_progress.cfg"

func _ready() -> void:
    load_progress()

func load_progress() -> void:
    var config := ConfigFile.new()
    if config.load(SAVE_PATH) != OK:
        return
    unlocked_level = clampi(int(config.get_value("campaign", "unlocked_level", 1)), 1, 3)
    total_score = maxi(0, int(config.get_value("campaign", "total_score", 0)))
    trust = clampi(int(config.get_value("campaign", "trust", 60)), 0, 100)
    var saved_skin := str(config.get_value("settings", "player_skin", "logistics"))
    player_skin = saved_skin if saved_skin in ["logistics", "paramedic", "firefighter", "police"] else "logistics"
    var saved_stars: Variant = config.get_value("campaign", "chapter_stars", [0, 0, 0, 0])
    chapter_stars = [0, 0, 0, 0]
    if saved_stars is Array:
        for i in range(mini(3, saved_stars.size())):
            chapter_stars[i + 1] = clampi(int(saved_stars[i]), 0, 3)

func save_progress() -> void:
    var config := ConfigFile.new()
    config.set_value("campaign", "unlocked_level", unlocked_level)
    config.set_value("campaign", "total_score", total_score)
    config.set_value("campaign", "trust", trust)
    config.set_value("campaign", "chapter_stars", [chapter_stars[1], chapter_stars[2], chapter_stars[3]])
    config.set_value("settings", "player_skin", player_skin)
    var err := config.save(SAVE_PATH)
    if err != OK:
        push_warning("Progress Kota Siaga gagal disimpan: %s" % error_string(err))

func stars_for_current_chapter() -> int:
    var stars := 1
    if score >= 55 and trust >= 60:
        stars = 2
    if score >= 90 and trust >= 75 and (citizens_total == 0 or citizens_safe >= citizens_total):
        stars = 3
    return stars

func complete_current_chapter() -> void:
    var stars := stars_for_current_chapter()
    chapter_stars[level] = maxi(chapter_stars[level], stars)
    unlocked_level = maxi(unlocked_level, mini(3, level + 1))
    save_progress()

func reset_campaign() -> void:
    load_progress()
    campaign_complete = false
    side_events_completed = 0
    start_level(unlocked_level)

func start_level(p_level: int) -> void:
    level = clampi(p_level, 1, 3)
    stage = PREPARATION
    budget = [0, 1650, 1850, 1950][level]
    score = 0
    facilities_ready = 0
    facilities_upgraded = 0
    damaged_count = 0
    inspected_count = 0
    repaired_count = 0
    citizens_safe = 0
    citizens_total = 0
    set_message("Kawasan Arunika menunggu koordinator. Tentukan prioritas sebelum ancaman datang.")
    changed.emit()

func disaster_name() -> String:
    match level:
        1: return "EXTREME RAIN" if KotaLocale.language_code == "en" else "HUJAN EKSTREM"
        2: return "URBAN FLOOD" if KotaLocale.language_code == "en" else "BANJIR PERKOTAAN"
        3: return "TORNADO" if KotaLocale.language_code == "en" else "ANGIN PUTING BELIUNG"
    return "DISASTER" if KotaLocale.language_code == "en" else "BENCANA"

func stage_name() -> String:
    match stage:
        PREPARATION: return KotaLocale.t("prep")
        DISASTER: return KotaLocale.t("disaster")
        HANDLING: return KotaLocale.t("response")
        INSPECTION: return KotaLocale.t("inspection")
        REPAIR: return KotaLocale.t("repair")
        EVALUATION: return KotaLocale.t("debrief")
    return "-"

func level_title() -> String:
    if KotaLocale.language_code == "en":
        match level:
            1: return "STAGE 01 — CITY UNDER RAIN"
            2: return "STAGE 02 — WHEN WATER BLOCKS THE ROAD"
            3: return "STAGE 03 — WHEN THE WIND HITS"
        return "CITY ALERT"
    match level:
        1: return "STAGE 01 — KOTA DI BAWAH HUJAN"
        2: return "STAGE 02 — AIR MENUTUP JALAN"
        3: return "STAGE 03 — KETIKA ANGIN MEROBOHKAN KOTA"
    return "KOTA SIAGA"

func story_text() -> String:
    if KotaLocale.language_code == "en":
        match level:
            1:
                return "Arunika has just been announced as a new business district. Offices and apartment towers line the main corridor, but residents report that the old drainage network was never upgraded for the new construction. The weather service has issued an extreme-rain warning—and the district response team has only a short window to prepare.\n\nYou are the district readiness coordinator. Your budget is limited, so prioritize drainage, a rain garden, accessible ramps, and evacuation signs. When the storm hits, send an early warning if signs are ready. After the rain, clear blocked drains, inspect damage, and repair the facilities that matter most.\n\nSIDE OBJECTIVE — FIELD DESK: inspect the information desk near the junction so resident reports can reach the response team faster."
            2:
                return "Runoff from the upper district has raised the waterline and cut off the main road. Four residents are separated from a safe route. Bima is searching for an exit, Naya has lost her school group, Mrs. Rukmini cannot move quickly, and Dimas needs a wide accessible route for his wheelchair.\n\nThe district now depends on your calls: clear blocked access, meet each resident, listen to their needs, and guide them to the Safe Point. A ramp shortens Dimas's route; without one, he can still reach safety by taking a longer detour.\n\nSIDE OBJECTIVE — FIRST AID KIT: pick up the kit near the field desk and deliver it to Mrs. Rukmini."
            3:
                return "Arunika is still repairing the flood damage when storm clouds build again. A tornado tears through the eastern district, dropping branches and debris across the roads. The siren repeater on the main corridor is offline, so the next alert could arrive too late.\n\nReopen the debris-blocked route, help residents reach shelter, inspect damaged facilities, and spend the remaining budget carefully. You are not only responding to a single disaster—you are rebuilding trust that the city can recover together.\n\nSIDE OBJECTIVE — RESTORE THE SIREN: reactivate the repeater after clearing the access route."
        return ""
    match level:
        1:
            return "Arunika baru diumumkan sebagai kawasan bisnis baru. Gedung perkantoran dan apartemen tumbuh di sepanjang koridor utama, tetapi laporan warga menyebut drainase lama tidak pernah disesuaikan dengan pembangunan baru. Pusat cuaca mengeluarkan peringatan hujan ekstrem—tim respons kawasan hanya punya waktu singkat untuk bersiap.\n\nSebagai Koordinator Kesiapsiagaan Kawasan, kamu menerima anggaran terbatas. Prioritaskan drainase, area resapan, ramp akses, atau rambu evakuasi. Saat hujan datang, kirim peringatan dini jika rambu sudah siap. Setelah hujan mereda, tangani saluran tersumbat, periksa kerusakan, dan perbaiki fasilitas yang paling berdampak.\n\nMISI SAMPINGAN — MEJA INFORMASI: periksa meja informasi dekat persimpangan agar laporan warga bisa diteruskan lebih cepat."
        2:
            return "Aliran air dari kawasan hulu menaikkan permukaan air hingga menutup jalan utama. Empat warga terpisah dari jalur aman. Pak Bima mencari akses keluar, Naya terpisah dari rombongan sekolah, Bu Rukmini berjalan lambat, sedangkan Dimas membutuhkan jalur lebar yang bisa dilalui kursi rodanya.\n\nKawasan bergantung pada keputusanmu: buka akses yang terendam, temui setiap warga, dengarkan kebutuhannya, lalu tuntun mereka ke Titik Aman. Ramp akses mempersingkat rute Dimas; tanpa ramp, jalur alternatif tetap tersedia tetapi lebih panjang.\n\nMISI SAMPINGAN — P3K: ambil kotak P3K dekat pos lapangan dan serahkan kepada Bu Rukmini."
        3:
            return "Arunika belum selesai memperbaiki dampak banjir ketika awan badai kembali berkumpul. Angin puting beliung menerjang sisi timur distrik, merobohkan ranting dan menutup sebagian jalur. Repeater sirene di koridor utama mati—peringatan berikutnya bisa terlambat diterima warga.\n\nBuka akses yang tertutup puing sebelum menolong warga. Setelah evakuasi, periksa fasilitas terdampak dan gunakan sisa dana secara cermat. Kamu tidak sekadar menangani satu bencana; kamu sedang membangun kepercayaan bahwa kota bisa pulih bersama-sama.\n\nMISI SAMPINGAN — AKTIFKAN KEMBALI SIRENE: aktifkan kembali repeater setelah akses utama dibuka."
    return ""

func objective() -> String:
    if KotaLocale.language_code == "en":
        match stage:
            PREPARATION: return "Scout the district. Build or upgrade drainage, rain gardens, access ramps, and evacuation signs. Spend on priorities, not on everything."
            DISASTER: return "Stay on task during the event. If evacuation signs are ready, interact with one to send an early warning before the timer ends."
            HANDLING:
                if level == 1: return "Clear the blocked drain and standing water. Finish both emergency markers before inspection."
                if level == 2: return "Open flooded access and guide all four residents to the Safe Point. Their needs and routes differ."
                return "Clear debris and fallen branches, then guide all residents to the Safe Point."
            INSPECTION: return "Approach each damaged facility and press E to log its condition. Healthy facilities do not need inspection."
            REPAIR: return "Repair facilities that have been inspected. The budget is limited, so choose the most critical ones."
            EVALUATION: return "Review stage score, resident safety, public trust, and remaining funds before moving on."
        return ""
    match stage:
        PREPARATION: return "Kelilingi area. Bangun atau tingkatkan drainase, resapan, ramp akses, dan rambu sesuai anggaran. Prioritaskan yang paling berdampak."
        DISASTER: return "Pantau kejadian. Jika rambu evakuasi sudah siap, dekati dan tekan E untuk mengirim peringatan dini sebelum timer habis."
        HANDLING:
            if level == 1: return "Tangani saluran tersumbat dan genangan. Selesaikan dua penanda darurat sebelum inspeksi."
            if level == 2: return "Buka akses banjir dan tuntun empat warga ke Titik Aman. Kebutuhan serta rute tiap warga berbeda."
            return "Bersihkan puing dan ranting yang menutup jalan, lalu bantu semua warga mencapai Titik Aman."
        INSPECTION: return "Dekati fasilitas berstatus RUSAK dan tekan E untuk mencatat kondisinya. Fasilitas sehat tidak perlu diperiksa."
        REPAIR: return "Perbaiki fasilitas yang sudah diperiksa. Anggaran terbatas, jadi pilih fasilitas paling penting."
        EVALUATION: return "Tinjau skor stage, keselamatan warga, kepercayaan komunitas, dan anggaran tersisa sebelum lanjut."
    return ""

func set_stage(p_stage: int, text: String = "") -> void:
    stage = p_stage
    if not text.is_empty(): set_message(text)
    changed.emit()

func spend(amount: int) -> bool:
    if budget < amount:
        set_message("Dana tidak mencukupi. Pilih tindakan lain atau gunakan gotong royong untuk membuka akses darurat.")
        return false
    budget -= amount
    changed.emit()
    return true

func add_score(amount: int) -> void:
    score = maxi(0, score + amount)
    changed.emit()

func change_trust(amount: int) -> void:
    trust = clampi(trust + amount, 0, 100)
    changed.emit()

func trust_status() -> String:
    if KotaLocale.language_code == "en":
        if trust >= 85: return "STRONG"
        if trust >= 65: return "STEADY"
        if trust >= 40: return "FRAGILE"
        return "LOW"
    if trust >= 85: return "TINGGI"
    if trust >= 65: return "STABIL"
    if trust >= 40: return "RAPUH"
    return "RENDAH"

func set_message(text: String) -> void:
    message = KotaLocale.translate_message(text)
    message_changed.emit(message)
