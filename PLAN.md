# Claude Profile Switcher: Plan

Menu bar app macOS (native Swift) untuk launch Claude Desktop dengan akun berbeda. Satu profile = satu data directory terpisah.

## Cara link akun Claude ke Claude Desktop

Tidak ada link di level app kita. Switcher tidak menyentuh credential sama sekali.

1. Profile baru = folder kosong, misal `.../Claude-<id>`.
2. Launch Claude Desktop dengan `--user-data-dir=<folder itu>`.
3. Karena folder kosong, Claude Desktop tampil layar login. User login sendiri dengan akun yang diinginkan (browser flow biasa).
4. Sesi login (Cookies, Local Storage, dll) tersimpan di folder itu. Launch berikutnya langsung masuk.

Jadi "akun" cuma efek samping dari folder mana yang dipakai. Yang kita simpan hanya: id, nama, path folder.

[FACT] Claude Desktop di Mac ini adalah Electron (ada `Electron Framework.framework`) dan data dir `~/Library/Application Support/Claude` berisi `Cookies`, `Local Storage`, `Session Storage`, dll.
[FACT] Flag `--user-data-dir` dihormati oleh Claude Desktop di macOS (dites di Phase 0).

## Fitur

- Tray icon (menu bar Mac; Windows di repo terpisah nanti). Tidak ada window utama, tidak ada Dock icon.
- Klik tray: popup berisi list profile.
- Klik profile: launch Claude Desktop dengan profile itu.
- Tombol "+": tambah profile, isi nama.
- Mode manage: rename dan hapus profile.
- Profile "Default" otomatis ada, menunjuk ke data dir asli Claude (launch tanpa flag), jadi akun yang sudah login tidak perlu dimigrasi.

## Data model

`profiles.json` di app config dir (`~/Library/Application Support/ClaudeProfileSwitcher/profiles.json`):

```json
[{ "id": "a1b2c3", "name": "Kerja" }, { "id": "d4e5f6", "name": "Pribadi" }]
```

- Folder data = `<base>/Claude-<id>`. Pakai id, bukan nama, supaya rename hanya ubah label dan tidak perlu pindah folder.
- Default tidak disimpan di file; hardcoded, tidak bisa dihapus atau rename.

## Launch

- macOS: `open -n -a Claude --args --user-data-dir=<folder>`
- Windows: jalankan `Claude.exe --user-data-dir=<folder>`. Lokasi exe harus ditemukan (lihat Risiko).
- Beberapa profile bisa jalan bersamaan (terbukti di Phase 0).
- `open -n` untuk profile yang sudah jalan membuat proses Claude baru yang tetap hidup dengan data dir yang sama (terbukti di Phase 0). Dua proses di satu data dir berisiko merusak data. App harus cek dulu apakah profile sudah jalan (cari proses dengan `--user-data-dir=<folder>`) dan hanya mem-fokuskan window-nya, bukan launch lagi. Fokus per pid lewat NSRunningApplication belum dites manual.

## Hapus profile

Dua langkah, dengan konfirmasi:
1. Hapus dari list (selalu).
2. Opsi "hapus juga data login/chat di folder" (permanen, default off, konfirmasi eksplisit).

## Stack

Native Swift, SwiftUI `MenuBarExtra` (style window), SwiftPM tanpa Xcode project. `build.sh` membangun `build/Claude Profiles.app` dengan `LSUIElement` (tanpa Dock icon) dan ad-hoc codesign.
Keputusan 2026-10-17: fokus macOS dulu karena urgent. Windows dibuat di repo terpisah nanti. Tauri dan Flutter dipertimbangkan, tidak dipakai. Scaffold Tauri dibuang (tidak pernah di-commit).

Struktur:
- `Sources/ClaudeProfiles/Store.swift`: model profile, `profiles.json`, deteksi proses jalan (`ps`), launch/fokus, hapus aman.
- `Sources/ClaudeProfiles/ContentView.swift`: popup: list, tambah, mode manage (rename, hapus dengan konfirmasi).
- `Sources/ClaudeProfiles/App.swift`: `MenuBarExtra`.

## Status

- Phase 0 (spike macOS): selesai, lihat hasil di bawah. Windows belum dites.
- Phase 1-4 versi macOS: kode pertama sudah ada dan ter-build. Launch/fokus, tambah, rename, hapus sudah ditulis. Belum diuji manual oleh user: klik tray, popup, launch profile, fokus profile yang jalan, rename, hapus.
- Belum: icon custom, auto-start saat login, signing + notarization untuk dibagikan.

Hasil Phase 0 macOS, 2026-10-17:
- Terbukti: flag `--user-data-dir` jalan; folder baru mulai kosong dan menampilkan login; akun kedua login terpisah; akun asli tetap login; sesi bertahan setelah ditutup dan dibuka lagi; chat berjalan normal.
- Terbukti: `claude_desktop_config.json` per folder, jadi config MCP per profile dan profile baru mulai tanpa MCP server.
- Terbukti: relaunch profile yang sedang jalan membuat proses ganda, jadi app cek dulu dan hanya fokus (`NSRunningApplication.activate`, belum diuji).
- Belum dites: Windows (lokasi exe, MSIX), keluar-masuk popup saat banyak profile.

Tidak termasuk (tambah kalau butuh): wrapper `.app` per profile dengan Dock icon sendiri, indikator profile aktif, auto-start saat login, import history.

## Risiko dan hal yang belum diverifikasi

- Flag `--user-data-dir` di Claude Desktop: unverified.
- Windows: Claude Desktop mungkin dipasang sebagai MSIX/Store app. Path exe tidak stabil dan launch dengan argumen bisa dibatasi. Unverified, cek di Phase 0.
- Semua instance memakai Dock icon / taskbar icon yang sama, jadi sulit membedakan window mana akun mana. Nama window atau avatar di Claude Desktop jadi satu-satunya petunjuk.
- Keychain/credential store: Electron `safeStorage` biasanya pakai satu key bersama di Keychain, token terenkripsi tetap di data dir. Kemungkinan aman, unverified.
- Update Claude Desktop bisa mengubah nama app, path, atau perilaku flag.
- Terms of Service Anthropic soal beberapa akun: belum dicek. Baca dulu kalau akan dibagikan ke orang lain.
- Hapus data dir adalah aksi permanen. Pastikan path divalidasi (hanya folder `Claude-<id>` di bawah base) supaya tidak bisa menghapus folder lain.
