# Keladi Hub

App menu bar macOS untuk mengelola dan berpindah antar profile akun Claude Desktop (menu bar manager for Claude Desktop account profiles). Tiap profile memakai folder data sendiri, jadi login satu akun tidak mengeluarkan akun lain. Semua akun bisa jalan bersamaan.

Status: macOS saja (Swift native). Versi Windows akan dibuat di repo terpisah. Rencana dan hasil riset ada di [PLAN.md](PLAN.md).

![Daftar profile](assets/screenshots/popup.png) ![Mode Manage](assets/screenshots/manage.png)

Screenshot memakai data contoh (dibuat dengan `KeladiHub --screenshot <folder>`), bukan akun sungguhan.

## Instalasi

Unduh `Keladi-Hub-<versi>-macOS.zip` dari halaman Releases, buka zip-nya, lalu pindahkan `Keladi Hub.app` ke folder Applications. Butuh macOS 14 atau lebih baru (Apple Silicon dan Intel).

App ini **belum ditandatangani Developer ID dan belum di-notarize oleh Apple**, jadi macOS akan memblokirnya saat pertama dibuka. Untuk membukanya: coba buka app, lalu di System Settings > Privacy & Security tekan **Open Anyway**. Kalau tidak mau memercayai binary ini, bangun dari kode sumber (lihat Build di bawah). Checksum SHA-256 tiap rilis ada di halaman Releases.

## Fitur

- Icon di menu bar, tanpa Dock icon dan tanpa window utama. Klik icon, muncul popup berisi daftar profile.
- Klik satu baris profile untuk membuka Claude dengan akun itu. Popup menutup sendiri.
- Profile yang sedang jalan punya titik hijau dan label **Show**. Klik untuk memfokuskan window yang sudah ada, tidak membuka proses kedua.
- **+ Add profile**: beri nama, lalu klik **Login** dan masuk dengan akun yang diinginkan. Cukup sekali, login tersimpan.
- **Manage**: ganti nama profile (ikon pensil), jadikan default (ikon bintang), atau hapus (ikon tempat sampah).
- Profile default adalah akun yang terbuka kalau Claude dibuka dari Spotlight atau Dock. Namanya bisa diganti, dan statusnya bisa dipindah ke profile lain.
- Hapus profile menghapus semua data lokalnya, tapi histori sesi Code disimpan dulu ke folder backup, satu backup per akun Claude (digabung, bukan diganti).
- **Restore** (ikon panah melingkar di mode Manage) mengembalikan histori sesi Code dari backup ke profile mana pun.

## Kelebihan

- Tidak menyentuh kredensial. App tidak membaca password atau token. Ia hanya memilih folder data mana yang dipakai Claude Desktop.
- Tidak perlu login ulang saat berpindah akun. Tiap profile menyimpan sesinya sendiri.
- Akun yang sudah login di Claude Desktop tidak perlu dimigrasi. Profile default memakai folder aslinya.
- Ringan. Native Swift/SwiftUI, tanpa dependensi pihak ketiga, tanpa Electron.
- Penghapusan dijaga: hanya folder `Claude-<id>` yang boleh dihapus, ditolak selama Claude profile itu masih jalan, dan dibatalkan kalau backup gagal.
- Tukar default memakai rename folder dengan rollback, bukan penyalinan.

## Cara kerja

Claude Desktop adalah app Electron. App ini menjalankannya dengan `--user-data-dir=<folder>`, jadi tiap profile punya folder data sendiri:

| Profile | Folder data |
|---|---|
| Default | `~/Library/Application Support/Claude` |
| Lainnya | `~/Library/Application Support/Claude-<id>` |

Folder dinamai dengan id acak, bukan nama, jadi ganti nama tidak memindahkan data.

Daftar profile disimpan di `~/Library/Application Support/ClaudeProfileSwitcher/profiles.json`. Backup histori Code ada di `~/Library/Application Support/ClaudeProfileSwitcher/Backups/<id akun>/` (folder `Library` tersembunyi di Finder; buka lewat Go > Go to Folder).

## Build

Butuh Xcode (command line tools cukup) dan macOS 14 atau lebih baru.

```bash
./build.sh
open "build/Keladi Hub.app"
```

`build.sh` membangun lewat SwiftPM, membuat `build/Keladi Hub.app` (menu bar saja, `LSUIElement`), dan menandatangani dengan ad-hoc signature. Untuk dibagikan ke orang lain perlu signing dan notarization sendiri.

## Keterbatasan

- Hanya macOS. Windows belum dibuat dan belum dites (lokasi Claude.exe dan kemungkinan paket MSIX belum dicek).
- Config MCP per profile. Profile baru mulai tanpa MCP server.
- Semua instance Claude memakai Dock icon yang sama, jadi window antar akun dibedakan dari akun di dalam Claude.
- Window Claude yang sedang diminimize tidak dikembalikan oleh **Show**. Buka lewat Dock. Pemulihan lewat Accessibility API pernah dicoba, tapi build-nya dihapus macOS sebagai malware (alasan persisnya tidak diketahui), jadi dibuang.
- Status login tidak dideteksi. Label **Login** berarti folder profile belum pernah dibuat, bukan bahwa login sudah berhasil.
- Menghapus profile menghapus daftar sesi Code dan file di scratch workspace-nya. Transkrip di `~/.claude/projects` dipakai bersama semua profile dan tidak ikut terhapus. Restore dari backup terbukti untuk daftar sesi, belum untuk scratch workspace.
- Tukar default memindahkan folder yang berisi login. Sesi Code yang memakai scratch workspace menyimpan path absolut ke folder lama, jadi sesi itu mungkin tidak bisa dibuka setelah tukar.
- Belum dicek apakah memakai beberapa akun sesuai Terms of Service Anthropic. Baca dulu sebelum dipakai atau dibagikan.

## Struktur

- `Sources/KeladiHub/Store.swift`: model, `profiles.json`, deteksi proses, launch dan fokus, hapus, backup, restore, tukar default.
- `Sources/KeladiHub/ContentView.swift`: isi popup.
- `Sources/KeladiHub/App.swift`: icon menu bar dan panel popup yang dipasang sendiri di bawah icon.
- `assets/`: ikon app dan ikon menu bar, plus `make-icons.swift` yang menggambarnya (desain `captain`, `hub`, `pinwheel`, `leaf`).
- `build.sh`: build dan bungkus jadi `.app`.

## Catatan nama

Nama folder data `ClaudeProfileSwitcher` di `~/Library/Application Support` dipertahankan dari nama app sebelumnya supaya profile dan backup yang sudah ada tetap terbaca.

## Lisensi

MIT, lihat [LICENSE](LICENSE).

## Disclaimer

Keladi Hub bukan produk resmi Anthropic dan tidak berafiliasi, didukung, atau disponsori oleh Anthropic. "Claude" adalah merek dagang Anthropic. App ini hanya membuka Claude Desktop yang sudah terpasang dengan folder data yang berbeda.
