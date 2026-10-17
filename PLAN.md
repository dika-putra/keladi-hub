# Claude Profile Switcher: Plan

Tray/menu bar app (macOS + Windows) untuk launch Claude Desktop dengan akun berbeda. Satu profile = satu data directory terpisah.

## Cara link akun Claude ke Claude Desktop

Tidak ada link di level app kita. Switcher tidak menyentuh credential sama sekali.

1. Profile baru = folder kosong, misal `.../Claude-<id>`.
2. Launch Claude Desktop dengan `--user-data-dir=<folder itu>`.
3. Karena folder kosong, Claude Desktop tampil layar login. User login sendiri dengan akun yang diinginkan (browser flow biasa).
4. Sesi login (Cookies, Local Storage, dll) tersimpan di folder itu. Launch berikutnya langsung masuk.

Jadi "akun" cuma efek samping dari folder mana yang dipakai. Yang kita simpan hanya: id, nama, path folder.

[FACT] Claude Desktop di Mac ini adalah Electron (ada `Electron Framework.framework`) dan data dir `~/Library/Application Support/Claude` berisi `Cookies`, `Local Storage`, `Session Storage`, dll.
[ASSUMPTION] Flag `--user-data-dir` dihormati oleh Claude Desktop. Belum dites. Ini Phase 0.

## Fitur

- Tray icon (menu bar Mac, system tray Windows). Tidak ada window utama, tidak ada Dock icon.
- Klik tray: popup berisi list profile.
- Klik profile: launch Claude Desktop dengan profile itu.
- Tombol "+": tambah profile, isi nama.
- Mode manage: rename dan hapus profile.
- Profile "Default" otomatis ada, menunjuk ke data dir asli Claude (launch tanpa flag), jadi akun yang sudah login tidak perlu dimigrasi.

## Data model

`profiles.json` di app config dir (`app_config_dir` dari Tauri):

```json
[{ "id": "a1b2c3", "name": "Kerja" }, { "id": "d4e5f6", "name": "Pribadi" }]
```

- Folder data = `<base>/Claude-<id>`. Pakai id, bukan nama, supaya rename hanya ubah label dan tidak perlu pindah folder.
- Default tidak disimpan di file; hardcoded, tidak bisa dihapus atau rename.

## Launch

- macOS: `open -n -a Claude --args --user-data-dir=<folder>`
- Windows: jalankan `Claude.exe --user-data-dir=<folder>`. Lokasi exe harus ditemukan (lihat Risiko).
- Beberapa profile bisa jalan bersamaan (terbukti di Phase 0).
- `open -n` untuk profile yang sudah jalan membuat proses Claude baru yang tetap hidup dengan data dir yang sama (terbukti di Phase 0). Dua proses di satu data dir berisiko merusak data. App harus cek dulu apakah profile sudah jalan (cari proses dengan `--user-data-dir=<folder>`) dan hanya mem-fokuskan window-nya, bukan launch lagi. Cara fokus per pid (misal AppleScript via System Events) belum dites.

## Hapus profile

Dua langkah, dengan konfirmasi:
1. Hapus dari list (selalu).
2. Opsi "hapus juga data login/chat di folder" (permanen, default off, konfirmasi eksplisit).

## Stack

Tauri 2 (Rust core + web UI). Alasan: tray + popup window bawaan, satu codebase untuk Mac dan Windows, binary kecil, UI pakai React/TS (cocok dengan arah frontend kamu).
Alternatif ditolak: Electron (berat untuk app sekecil ini), Swift + C# dua codebase (dua kali kerja).

Struktur minimal:
- `src-tauri/`: tray, window popup, commands `list/add/rename/delete/launch`, baca-tulis `profiles.json`.
- `src/`: satu komponen React: list + form tambah + mode manage.

## Phase

0. Spike manual (30 menit, sebelum nulis app). Hasil Mac, 2026-10-17:
   - Terbukti: flag `--user-data-dir` jalan; folder baru mulai kosong dan menampilkan login; akun kedua bisa login terpisah (dikonfirmasi user).
   - Terbukti: `claude_desktop_config.json` per folder, jadi config MCP per profile dan profile baru mulai tanpa MCP server.
   - Terbukti: relaunch profile yang sedang jalan membuat proses ganda (lihat bagian Launch).
   - Terbukti (dikonfirmasi user): akun asli tetap login saat profile kedua login; profile kedua tetap login setelah ditutup dan dibuka lagi dengan perintah yang sama, dan prompt berjalan normal.
   - Belum dites: Windows.
   Daftar tes semula:
   - Jalankan perintah `open -n` dengan folder baru. Login akun kedua. Cek akun pertama tetap login.
   - Jalankan dua profile bersamaan. Cek klik ulang profile yang sudah jalan.
   - Cek apakah `claude_desktop_config.json` (MCP) ikut pindah ke folder baru atau tetap global.
   - Ulangi di Windows, termasuk cara menemukan exe.
   - Kalau flag tidak jalan, plan ini gugur. Berhenti di sini.
1. Scaffold Tauri 2, tray icon, popup muncul di bawah icon, hide saat kehilangan fokus.
2. Data layer: `profiles.json`, command add/rename/delete.
3. Launch per OS. Test di Mac dulu, lalu Windows.
4. UI: list, form tambah, mode manage, konfirmasi hapus.
5. Packaging: `.dmg` (signing + notarization kalau mau dibagikan) dan installer Windows.

Tidak termasuk (tambah kalau butuh): wrapper `.app` per profile dengan Dock icon sendiri, indikator profile aktif, auto-start saat login, import history.

## Risiko dan hal yang belum diverifikasi

- Flag `--user-data-dir` di Claude Desktop: unverified.
- Windows: Claude Desktop mungkin dipasang sebagai MSIX/Store app. Path exe tidak stabil dan launch dengan argumen bisa dibatasi. Unverified, cek di Phase 0.
- Semua instance memakai Dock icon / taskbar icon yang sama, jadi sulit membedakan window mana akun mana. Nama window atau avatar di Claude Desktop jadi satu-satunya petunjuk.
- Keychain/credential store: Electron `safeStorage` biasanya pakai satu key bersama di Keychain, token terenkripsi tetap di data dir. Kemungkinan aman, unverified.
- Update Claude Desktop bisa mengubah nama app, path, atau perilaku flag.
- Terms of Service Anthropic soal beberapa akun: belum dicek. Baca dulu kalau akan dibagikan ke orang lain.
- Hapus data dir adalah aksi permanen. Pastikan path divalidasi (hanya folder `Claude-<id>` di bawah base) supaya tidak bisa menghapus folder lain.
