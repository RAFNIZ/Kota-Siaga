extends RefCounted

## Single source of truth for character preview assets.
## GLB models in this catalogue are static meshes; they are not rigged or animated.

static func all_characters() -> Array[Dictionary]:
    return [
        {"id":"firefighter", "display_name":"Petugas Pemadam", "category":"PLAYER", "role":"Pemadam", "path":"res://assets/characters/rigged/player_firefighter.glb", "description":"Membantu pengamanan titik api, pemeriksaan area, dan dukungan evakuasi."},
        {"id":"paramedic", "display_name":"Paramedis", "category":"PLAYER", "role":"Medis", "path":"res://assets/characters/rigged/player_paramedic.glb", "description":"Menangani pertolongan pertama dan memprioritaskan warga yang terluka."},
        {"id":"logistics", "display_name":"Evakuasi dan Logistik", "category":"PLAYER", "role":"Logistik", "path":"res://assets/characters/rigged/player_logistics.glb", "description":"Mengatur titik kumpul, distribusi kebutuhan, dan jalur pengungsian."},
        {"id":"police", "display_name":"Petugas Polisi", "category":"PLAYER", "role":"Keamanan", "path":"res://assets/characters/rigged/player_police.glb", "description":"Mengamankan akses, mengarahkan lalu lintas, dan menjaga area berbahaya."},
        {"id":"civilian", "display_name":"Warga Dewasa", "category":"NPC", "role":"Warga", "path":"res://assets/characters/rigged/npc_civilian.glb", "description":"Warga yang dapat meminta informasi atau bantuan saat bencana."},
        {"id":"elder", "display_name":"Warga Lansia", "category":"NPC", "role":"Warga prioritas", "path":"res://assets/characters/rigged/npc_elder.glb", "description":"Membutuhkan waktu, komunikasi, dan jalur evakuasi yang lebih aman."},
        {"id":"child", "display_name":"Anak", "category":"NPC", "role":"Warga prioritas", "path":"res://assets/characters/rigged/npc_child.glb", "description":"Membutuhkan pendampingan untuk mencapai titik aman."},
        {"id":"wheelchair", "display_name":"Pengguna Kursi Roda", "category":"NPC", "role":"Warga prioritas", "path":"res://assets/characters/rigged/npc_wheelchair.glb", "description":"Membutuhkan rute yang cukup lebar, bebas hambatan, dan akses landai."},
        {"id":"injured", "display_name":"Korban Cedera", "category":"NPC", "role":"Korban", "path":"res://assets/characters/rigged/npc_injured.glb", "description":"Membutuhkan bantuan medis serta pengantaran ke titik penanganan."}
    ]
