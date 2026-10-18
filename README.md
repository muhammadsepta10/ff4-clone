# Ladang Riuh

Game farm manajemen waktu, offline, untuk Android (Godot 4.7). Mekanik setara Farm Frenzy 4 dengan identitas orisinal. Lihat [PRD](docs/prd/0001-game-farm-offline-android.md), [CONTEXT.md](CONTEXT.md), dan [ADR](docs/adr/).

## Struktur

- `core/` — `GameCore` headless (simulasi deterministik, kampanye, bot, balancer). Satu-satunya seam.
- `content/` — data JSON dan skemanya (`content/schema`). Level di `content/levels/`.
- `ui/` — scene Godot: menu, peta, briefing, permainan, hasil, achievement, pengaturan, kredit, benchmark.
- `i18n/` — teks Indonesia dan Inggris.
- `tests/` — tes headless lewat `GameCore`.
- `tools/` — typecheck, balancer tropi, helper screenshot.

## Perintah

```sh
tools/typecheck.sh                                        # parse/type-check semua skrip
tests/run.sh [filter]                                     # tes (mis. tests/run.sh test_campaign)
godot --headless --path . -s tools/balance.gd             # bot main semua level, tulis batas tropi
godot --headless --path . -s tools/balance.gd -- --check  # verifikasi saja (CI)
godot --path .                                            # jalankan game
godot --path . -- --benchmark                             # scene benchmark (FPS, waktu muat)
```

CI (`.github/workflows/ci.yml`) menjalankan typecheck, tes, bot, lalu export APK debug sebagai artefak.
