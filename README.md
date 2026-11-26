# Kota Siaga — Arunika Metropolitan

**Kota Siaga** adalah game edukasi semi-3D bertema simulasi mitigasi bencana, kesiapsiagaan warga, dan pembangunan kota yang inklusif.

## Informasi Project

- **Game Engine:** Godot Engine 4.7.2
- **Platform target:** Windows dan macOS (MacBook)
- **Jenis project:** Source project Godot

Project ditujukan agar dapat dibuka dan dijalankan di laptop Windows maupun MacBook menggunakan Godot Engine 4.7.2.

## Menjalankan Game

1. Unduh atau clone repository ini ke komputer.
2. Instal Godot Engine 4.7.2 sesuai sistem operasi yang digunakan (Windows atau macOS).
3. Buka Godot Project Manager.
4. Pilih **Import** dan arahkan ke file `project.godot` pada folder project `Kota Siaga`.
5. Setelah project selesai diimpor, buka project tersebut.
6. Tekan **F5** atau tombol **Run Project** di editor untuk menjalankan game.

> **Catatan:** Repository ini berisi source project Godot. File aplikasi hasil export seperti `.exe` untuk Windows atau `.app` untuk macOS belum disertakan. Untuk membagikan game sebagai aplikasi mandiri, lakukan export untuk masing-masing platform melalui Godot Editor.

## Fitur Project

- Simulasi kota edukatif dengan tema mitigasi bencana.
- Skenario hujan ekstrem, banjir, dan angin puting beliung.
- Interaksi dengan karakter/NPC serta kegiatan inspeksi dan perbaikan lingkungan kota.
- Sistem kendaraan dan lalu lintas, termasuk jalur kendaraan dan lampu lalu lintas.
- Antarmuka permainan dan sistem audio.

## Struktur Folder

```text
Kota Siaga/
├── assets/       # Model, tekstur, audio, dan aset game
├── scenes/       # Scene Godot
├── scripts/      # Script dan sistem gameplay
├── project.godot # Konfigurasi utama project Godot
└── README.md
```

## Catatan Pengembangan

- Pertahankan folder `assets`, `scenes`, dan `scripts` beserta file `project.godot` dalam satu struktur folder.
- Saat pertama kali dibuka, Godot mungkin membutuhkan waktu untuk mengimpor aset.
- Folder cache lokal `.godot/` tidak perlu diunggah ke GitHub; folder tersebut sudah dikecualikan melalui `.gitignore`.
- File `.gd.uid` dan `.import` tetap disertakan sebagai bagian dari metadata project.
- Sebelum repository dibuat publik, pastikan seluruh aset pihak ketiga yang digunakan memang memiliki izin untuk didistribusikan.
