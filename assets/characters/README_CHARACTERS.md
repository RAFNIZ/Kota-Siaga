# Karakter 3D Kota Siaga

Paket ini menambahkan empat model role Player dan lima model NPC dalam format `.glb`, beserta scene preview 3D yang dapat dibuka dari menu utama.

## Isi

- `player/`: pemadam, paramedis, evakuasi/logistik, polisi.
- `npc/`: warga dewasa, lansia, anak, pengguna kursi roda, korban cedera.
- `manifest.json`: katalog dan spesifikasi sumber paket.
- `KotaSiaga_CharacterPreview.png`: referensi visual.

## Batas teknis yang wajib diketahui

Manifest paket sumber menyatakan seluruh model adalah **static mesh**, belum memiliki skeleton/rig, dan belum memiliki animasi. Karena itu model bisa dipreview dan dipakai sebagai objek 3D, tetapi belum siap untuk animasi tulang atau animasi jalan yang natural. Model role Player juga dipakai untuk karakter gameplay. Kontrol dan collision tetap pada CharacterBody3D, dengan sway/bounce sederhana saat bergerak. Karena GLB role Player belum rigged/animated, animasi jalan tangan-kaki yang alami belum tersedia.

Koordinat sumber: glTF Y-up, satuan meter, model menghadap +Z. Lihat pula `manifest.json`.
