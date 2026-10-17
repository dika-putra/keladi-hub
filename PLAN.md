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

Satu aksi: "Remove and delete all local data", dengan penjelasan di panel konfirmasi (tanpa dialog sistem, karena dialog menutup popup menu bar). Opsi "keep data" dibuang karena folder yatim tidak bisa dipasang lagi ke profile baru (id baru berarti folder baru).
- Ditolak selama Claude profile itu masih jalan (panel menampilkan peringatan).
- Hanya menghapus folder `Claude-<id>` tepat di bawah `~/Library/Application Support`. Profile default tidak bisa dihapus.
- Isi yang terhapus: login (Cookies, Local Storage), config MCP, cache, daftar sesi Code, scratch workspace.
- Tidak terhapus: chat di claude.ai (di akun Anthropic), transkrip Code di `~/.claude/projects` (dipakai bersama semua profile), repo di disk.

### Backup histori Code sebelum hapus

Sebelum folder dihapus, app menyalin ke folder tersembunyi:
`~/Library/Application Support/ClaudeProfileSwitcher/Backups/<nama>-<id>-<yyyyMMdd-HHmmss>/`
Isi backup: `claude-code-sessions/`, `scratch-workspaces/`, `git-worktrees.json` (yang ada saja). Kalau penyalinan gagal, profile dan datanya tidak dihapus.
Folder `Library` tersembunyi di Finder: buka lewat Go > Go to Folder, atau `open ~/Library/Application\ Support/ClaudeProfileSwitcher/Backups`.

Restore manual (terbukti 2026-10-17 untuk `claude-code-sessions` dan `git-worktrees.json`: sesi Code lama muncul lagi di profile baru; `scratch-workspaces` belum diuji): tambah profile baru, buka sekali lalu tutup supaya foldernya terbentuk, salin isi backup ke `~/Library/Application Support/Claude-<id baru>/`, buka lagi.
Risiko yang tersisa untuk sesi di scratch workspace: file sesi menyimpan `cwd` absolut yang menunjuk ke folder profile lama (contoh `.../Claude/scratch-workspaces/...`) dan id akun, jadi sesi di scratch workspace mungkin tidak bisa dibuka. Transkrip asli tetap bisa dibuka lewat `claude --resume` karena ada di `~/.claude/projects`.
Backup tidak dibersihkan otomatis. Hapus manual kalau tidak dibutuhkan.

## Set as default

Default = akun yang terbuka kalau Claude dibuka dari Spotlight atau Dock = isi folder `Claude`. Memindahkannya berarti menukar folder: `Claude` -> `Claude-swap-tmp`, `Claude-<id>` -> `Claude`, `Claude-swap-tmp` -> `Claude-<id>`, lalu menukar nama kedua profile supaya nama tetap mengikuti akunnya. Rollback kalau satu langkah gagal. Ditolak kalau ada Claude yang jalan, atau profile target belum pernah dibuka (foldernya belum ada).
Belum diuji. Risiko: sesi Code di scratch workspace menyimpan path absolut ke folder lama.

## Catatan 2026-10-17: build dihapus macOS

Percobaan memulihkan window yang diminimize lewat Accessibility API (`AXUIElement`), dengan tanda tangan Apple Development, berakhir dengan `.app` dihapus macOS karena terdeteksi malware. Nama deteksi dan penyebab pasti tidak diketahui (log sistem tidak mencatat alasannya). Kode Accessibility dan log `/tmp` dibuang, tanda tangan kembali ad-hoc. Pemulihan window yang diminimize belum ada. Kalau dicoba lagi, minta izin sekali dan jangan pakai build yang sama dengan yang dihapus.

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
