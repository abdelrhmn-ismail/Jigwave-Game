# 🧩 Puzzlo — Full Plan (Godot 4 → Google Play)

> **Working title:** *Puzzlo* (check the name is free on Google Play before release).
> **Rules:** an original jigsaw game. No images, sounds, code, name, or look from any
> existing app. Every picture must be **CC0 or Public Domain** and is listed in
> `assets/puzzles/CREDITS.md`. No photos of identifiable people (especially children).

Same engine and approach as **Bloxo**: Godot 4.7, GDScript, portrait 1080×1920,
rules in `logic/` (no drawing, unit-tested), screens in `scenes/`, light drawing
that only redraws when something changes.

---

## ✅ Progress

- [x] Phase 0 — Project setup (Godot project, portrait, autoloads, git)
- [x] Phase 1 — Jigsaw cutter: classic tab/blank pieces from any picture + tests
- [x] Phase 2 — Puzzle screen: board, scrolling tray, drag, snap, wrong → back to tray
- [x] Phase 3 — Levels, stars, coins, hints (place a piece, peek) + save/resume
- [x] Phase 4 — Picture library tool (CC0 from Openverse) + first batch (31 pictures, checked by eye)
- [ ] Phase 5 — Home screen polish: level path / map (basic home + gallery with categories and free-play sizes already work)
- [ ] Phase 6 — Look and feel: own theme, logo, icons, sounds, music, juice
- [ ] Phase 7 — Languages (EN, AR first; then FR, DE, ES, IT like Bloxo)
- [ ] Phase 8 — Bigger library (300+ pictures), daily puzzle, gifts
- [ ] Phase 9 — Test on real phones (low-end), performance pass
- [ ] Phase 10 — Release build (AAB) + Google Play listing

---

## 🎮 How a puzzle plays

1. A picture is cut into **N×N jigsaw pieces** with real tabs and blanks.
2. The board shows the empty frame with a faint grid. Pieces wait in a
   **scrolling tray** under the board.
3. Drag a piece onto the board:
   - **Right spot** (close enough) → it **snaps** in with a click and a sparkle, and locks.
   - **Wrong spot** → it slides **back to the tray**. Counted as a *mistake*. **No game over.**
4. Last piece placed → the full picture shines, stars and coins are awarded.

### Why "wrong = back to tray, no restart" (recommended)
Jigsaw players come to relax. Restarting a 64-piece puzzle for one bad drop feels
unfair and makes people quit. The **challenge** comes from:

| Challenge | How |
|---|---|
| ⭐ Stars | 3★ with few mistakes, 2★ with some, 1★ otherwise (limits grow with piece count) |
| 📈 Piece count | levels grow from 9 pieces to 16, 25, 36, 49, 64 … |
| 🔄 Rotation (later, optional) | hard mode: pieces also come rotated; tap to turn |
| ❤️ Challenge mode (later, optional) | 3 hearts; out of hearts → retry, but pays double coins |

Mistake limits for stars: `3★ ≤ ceil(pieces × 0.10)`, `2★ ≤ ceil(pieces × 0.25)`.

---

## 🗺️ Levels (a very large number)

- The library is a list of pictures in a fixed, mixed order (nature, animals,
  space, art, cities, food, sports, toys…), so every level feels different.
- **Level L** uses picture `L` of that list; when the list runs out it starts
  again (by then with more pieces) — so levels never run out.
- Piece count by level:

| Levels | Grid | Pieces |
|---|---|---|
| 1–5 | 3×3 | 9 |
| 6–15 | 4×4 | 16 |
| 16–35 | 5×5 | 25 |
| 36–70 | 6×6 | 36 |
| 71–120 | 7×7 | 49 |
| 121–250 | 8×8 | 64 |
| 251–400 | 9×9 | 81 |
| 401+ | 10×10 | 100 |

- **Gallery / free play:** any picture you already reached can be played again
  in any size (9, 16, 36, 64, 100 pieces) for coins.

---

## 🪙 Coins

| Earn | Coins |
|---|---|
| Finish a level | 10 + 5 per star |
| Bigger puzzles | +1 per 4 pieces |
| Daily gift (later) | 25 |

| Spend (hints) | Cost | What it does |
|---|---|---|
| 🧲 Place a piece | 30 | puts one tray piece in its spot |
| 👁️ Peek | 15 | shows the whole picture faintly for 5 s |
| 🧩 Edges first | free | sorts the tray so border pieces come first |

New players start with 100 coins. No ads in v1 (rewarded "watch for coins" later).

---

## 🗂️ Structure

```
Puzzles/
├── project.godot
├── PLAN.md / README.md
├── autoload/      save_data.gd (progress, coins, settings, unfinished puzzle), audio.gd, lang.gd, palette.gd
├── logic/         rules only, unit-tested
│   ├── jigsaw_cut.gd    edge tabs + piece outlines (polygons) for an N×N grid
│   ├── puzzle_state.gd  which pieces are placed, mistakes, stars, save/load
│   ├── levels.gd        level number → picture + grid size
│   ├── economy.gd       coin rewards, hint prices
│   ├── catalog.gd       reads assets/puzzles/catalog.json
│   └── strings.gd       texts per language
├── scenes/        main (screen switcher), home_screen, gallery_screen, puzzle_screen
├── ui/            ui_kit, overlay panels, piece_node (textured polygon + outline)
├── assets/puzzles/  <category>/<id>.jpg, catalog.json, CREDITS.md
├── assets/sounds | fonts
├── tests/         test_runner.gd (rules), smoke_test (plays a whole puzzle)
└── tools/         fetch_pictures.py (Openverse CC0 → 1024×1024 JPG + credits)
```

### APK size
31 pictures add about 6 MB (lossy WebP import). 300 pictures ≈ +60 MB — still fine
for Google Play (AAB limit 200 MB), but consider 768 px pictures or Play Asset
Delivery if the library grows past ~400.

### Performance (keep it light like Bloxo)
- Each piece is one `Polygon2D` with the picture as texture (UVs = its spot in the
  picture) + a thin outline. Nothing is redrawn every frame except the dragged piece.
- Pictures are 1024×1024 JPG in the repo, imported as lossy WebP → small APK.
- Only the current puzzle's picture is loaded; thumbnails are small separate files.

---

## 🖼️ Pictures (legal and safe)

- Source: **Openverse** API, licenses **CC0** and **Public Domain Mark** only
  (mostly Wikimedia Commons), plus NASA (public domain).
- `tools/fetch_pictures.py` searches per category, skips small/odd images,
  center-crops to square, resizes to 1024, saves JPG and writes the credit
  (title, author, source URL, license) to `catalog.json` + `CREDITS.md`.
- Every picture is checked by eye before release (no logos, no faces of real
  people, nothing unsuitable for all ages). "Kids" means toys, cartoons-like
  colors, animals — never photos of children.

---

## 🧱 Next steps after v1
Daily puzzle · achievements · rotation hard mode · challenge mode · rewarded ads
for coins · Google Play Games leaderboards · user photo puzzles (from gallery).
