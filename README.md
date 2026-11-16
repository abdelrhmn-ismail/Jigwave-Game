# 🧩 Jigwave

An original jigsaw puzzle game made with **Godot 4.7** (GDScript), portrait, for Android.
Free pictures (CC0 / public domain) are cut into real jigsaw pieces; drag them from the
tray onto the board. Right spot → snap. Wrong spot → back to the tray (counts a mistake,
no game over). Finish to earn stars and coins; spend coins on hints.

See **[PLAN.md](PLAN.md)** for the full plan and progress.

## ▶️ Run
- Open the folder in Godot 4.7 and press ▶️ (mouse works as touch).
- Developer shortcuts: `godot --path . -- --screen=puzzle --level=12`
  (`home`, `gallery`, `puzzle`, `puzzle-half`, `complete`; add `--lang=ar`, `--shot=file.png`).

## 🧪 Tests
```
godot --headless --path . -s tests/test_runner.gd     # rules: cutting, state, levels, coins, catalog
godot --headless --path . res://tests/smoke_test.tscn # plays puzzles through the touch code
```

## 🖼️ Pictures
```
python3 -I tools/fetch_pictures.py --per-query 2 --download-dir /tmp/pics        # fetch more (CC0/PD only)
python3 -I tools/fetch_pictures.py --remove nature_004,food_002                  # drop + never fetch again
```
Every new picture must be checked by eye (no logos, no faces of real people).
Credits: `assets/puzzles/CREDITS.md`.

## 🎨 Art and 🎵 sound (all original, generated)
```
python3 -I tools/make_art.py     # logo, app icons, store icon, feature graphic
python3 -I tools/make_audio.py   # sound effects + 4 relaxing music tracks
```

## 📦 Release build
```
GODOT=/path/to/godot tools/export_release.sh   # build/jigwave-release.aab + .apk
```
The signing key and its password are in `keys/` (never committed — back it up in 3 places).
Raise `version/code` in both Android presets before every Google Play upload.

## 🗂️ Where things are
| What | File |
|---|---|
| Piece shapes (tabs/blanks) | `logic/jigsaw_cut.gd` |
| Puzzle rules, mistakes, save | `logic/puzzle_state.gd` |
| Level → picture + piece count | `logic/levels.gd` |
| Coins, stars, hint prices | `logic/economy.gd` |
| Texts (EN, AR) | `logic/strings.gd` |
| Colors and UI helpers | `ui/ui_kit.gd` |
| Play screen | `scenes/puzzle_screen.gd` |

## 📜 Credits
- Pictures: see `assets/puzzles/CREDITS.md` (all CC0 / public domain)
- Logo, icons, sounds and music: made for this game by `tools/make_art.py` and `tools/make_audio.py`
- Fonts: [Fredoka](https://fonts.google.com/specimen/Fredoka) and [Tajawal](https://fonts.google.com/specimen/Tajawal) — SIL Open Font License 1.1
