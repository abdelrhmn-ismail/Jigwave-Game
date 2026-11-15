#!/usr/bin/env python3
"""Fetch free-to-use puzzle pictures (CC0 / Public Domain only) from Openverse.

    python3 -I tools/fetch_pictures.py --per-query 2 --download-dir /tmp/pics

For each category and search phrase it asks the Openverse API for large CC0 /
Public Domain Mark images, skips anything already in the catalog or listed in
tools/picture_blocklist.txt, downloads a ~1600px version, center-crops it to a
square, and writes:

    assets/puzzles/<category>/<id>.jpg   1024x1024 puzzle picture
    assets/puzzles/thumbs/<id>.jpg       256x256 thumbnail for menus
    assets/puzzles/catalog.json          list of pictures + credits
    assets/puzzles/CREDITS.md            human-readable credits

Downloaded files are treated as untrusted: they are only opened with Pillow,
never executed, and kept in a separate download folder.
Every picture must still be checked by eye before release (no logos, no faces
of real people, nothing unsuitable for all ages).
"""
import argparse
import io
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "puzzles"
CATALOG = OUT / "catalog.json"
BLOCKLIST = Path(__file__).resolve().parent / "picture_blocklist.txt"
API = "https://api.openverse.org/v1/images/"
USER_AGENT = "PuzzlePictureFetcher/1.0 (open-source game asset tool)"
SIZE = 1024
THUMB = 256
MIN_SIDE = 1100  # skip images smaller than this on their short side

# Search phrases per category. Avoid people: photos of real, identifiable
# people (and above all children) need consent we do not have.
QUERIES = {
    "nature": ["mountain lake", "waterfall", "forest path", "beach sunset",
               "flower field", "autumn trees", "desert dunes", "snowy mountains"],
    "animals": ["red fox", "owl", "butterfly flower", "parrot", "tiger",
                "elephant", "puppy", "kitten", "horse meadow", "sea turtle"],
    "space": ["nebula", "galaxy", "earth from space", "moon surface", "aurora"],
    "art": ["landscape oil painting", "still life painting", "japanese woodblock print",
            "impressionist painting garden"],
    "cities": ["old town street", "lighthouse", "bridge at night", "castle",
               "harbor boats", "windmill"],
    "food": ["fruit bowl", "cupcakes", "vegetables market", "berries", "bread bakery"],
    "sports": ["football stadium", "soccer ball grass", "basketball court",
               "tennis ball court", "bicycle", "sailing boat race"],
    "kids": ["teddy bear", "colorful toys", "hot air balloons", "carousel",
             "colored pencils", "kites sky", "toy train", "balloons colorful"],
}

# Words in a title that usually mean people, brands or unwanted content.
SKIP_WORDS = re.compile(
    r"\b(man|men|woman|women|girl|boy|child|children|kid|kids|baby|people|person|"
    r"portrait|selfie|face|crowd|player|players|fans|team|logo|brand|nude|naked|"
    r"weapon|gun|war|dead|blood|protest|flag|map|diagram|chart|text|poster)\b",
    re.IGNORECASE)


def http_get(url: str, timeout: int = 60) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def search(query: str, page: int = 1) -> list:
    params = urllib.parse.urlencode({
        "q": query, "license": "cc0,pdm", "size": "large",
        "page_size": 20, "page": page, "mature": "false",
    })
    data = json.loads(http_get(f"{API}?{params}"))
    return data.get("results", [])


def download_url(result: dict) -> str:
    """A 1920px version for Wikimedia files (saves bandwidth), else the original.
    Wikimedia only serves standard thumbnail widths (1280, 1920, ...)."""
    url = result["url"]
    m = re.match(r"https://upload\.wikimedia\.org/wikipedia/commons/(\w)/(\w\w)/(.+)$", url)
    if m and url.lower().endswith((".jpg", ".jpeg", ".png")):
        name = m.group(3)
        return (f"https://upload.wikimedia.org/wikipedia/commons/thumb/"
                f"{m.group(1)}/{m.group(2)}/{name}/1920px-{name}")
    return url


def square(img: Image.Image, size: int) -> Image.Image:
    img = ImageOps.exif_transpose(img).convert("RGB")
    return ImageOps.fit(img, (size, size), Image.Resampling.LANCZOS, centering=(0.5, 0.5))


def load_catalog() -> list:
    if CATALOG.exists():
        return json.loads(CATALOG.read_text(encoding="utf-8"))
    return []


def save_catalog(items: list) -> None:
    CATALOG.write_text(json.dumps(items, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    lines = ["# Picture credits", "",
             "All puzzle pictures are CC0 or Public Domain (no permission needed).",
             "Credits are listed anyway, with thanks to the authors.", ""]
    for it in items:
        lines.append(f"- **{it['id']}** ({it['category']}): \"{it['title']}\" by "
                     f"{it['creator'] or 'unknown'} — {it['license'].upper()} — {it['landing_url']}")
    (OUT / "CREDITS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def next_id(items: list, cat: str) -> str:
    """category_NNN, one higher than any id ever used (removed ids are not reused)."""
    used = [int(i["id"].rsplit("_", 1)[1]) for i in items if i["category"] == cat]
    if BLOCKLIST.exists():
        for line in BLOCKLIST.read_text().splitlines():
            m = re.search(r"#\s*(\w+)_(\d{3})\b", line)
            if m and m.group(1) == cat:
                used.append(int(m.group(2)))
    return f"{cat}_{max(used, default=0) + 1:03d}"


def remove(ids: list) -> None:
    """Deletes pictures and blocklists them so they are never fetched again."""
    items = load_catalog()
    keep = []
    with BLOCKLIST.open("a") as bl:
        for it in items:
            if it["id"] in ids:
                for path in (OUT / it["category"] / f"{it['id']}.jpg", OUT / "thumbs" / f"{it['id']}.jpg"):
                    path.unlink(missing_ok=True)
                    Path(str(path) + ".import").unlink(missing_ok=True)
                bl.write(f"{it['openverse_id']}  # {it['id']} {it['title'][:60]}\n")
                print(f"  - removed {it['id']}")
            else:
                keep.append(it)
    save_catalog(keep)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--per-query", type=int, default=2, help="pictures to keep per search phrase")
    ap.add_argument("--page", type=int, default=1, help="result page (use 2, 3... for more)")
    ap.add_argument("--download-dir", default="", help="scratch folder for raw downloads")
    ap.add_argument("--categories", default="", help="comma list (default: all)")
    ap.add_argument("--remove", default="", help="comma list of picture ids to delete + blocklist")
    args = ap.parse_args()
    if args.remove:
        remove([i.strip() for i in args.remove.split(",") if i.strip()])
        return 0

    if not args.download_dir:
        ap.error("--download-dir is required when fetching")
    dl_dir = Path(args.download_dir)
    dl_dir.mkdir(parents=True, exist_ok=True)
    blocked = set()
    if BLOCKLIST.exists():
        blocked = {l.split("#")[0].strip() for l in BLOCKLIST.read_text().splitlines()} - {""}
    items = load_catalog()
    known = {it["openverse_id"] for it in items}
    cats = [c for c in args.categories.split(",") if c] or list(QUERIES)

    for cat in cats:
        (OUT / cat).mkdir(parents=True, exist_ok=True)
        for query in QUERIES[cat]:
            kept = 0
            try:
                results = search(query, args.page)
            except Exception as exc:  # network / rate limit: skip this phrase
                print(f"  search failed for '{query}': {exc}", file=sys.stderr)
                time.sleep(5)
                continue
            for r in results:
                if kept >= args.per_query:
                    break
                if r["id"] in known or r["id"] in blocked:
                    continue
                if r.get("license") not in ("cc0", "pdm"):
                    continue
                w, h = r.get("width") or 0, r.get("height") or 0
                if min(w, h) < MIN_SIDE or max(w, h) > 2.2 * min(w, h):
                    continue
                if SKIP_WORDS.search(r.get("title") or ""):
                    continue
                try:
                    try:
                        raw = http_get(download_url(r))
                    except urllib.error.HTTPError:
                        raw = http_get(r["url"])  # no such thumbnail: use the original
                    (dl_dir / f"{r['id']}.bin").write_bytes(raw)
                    img = Image.open(io.BytesIO(raw))
                    img.load()
                except Exception as exc:
                    print(f"  skip {r['id']}: {exc}", file=sys.stderr)
                    continue
                if min(img.size) < 800:
                    continue
                pid = next_id(items, cat)
                square(img, SIZE).save(OUT / cat / f"{pid}.jpg", quality=84, optimize=True)
                (OUT / "thumbs").mkdir(exist_ok=True)
                square(img, THUMB).save(OUT / "thumbs" / f"{pid}.jpg", quality=80, optimize=True)
                items.append({
                    "id": pid, "category": cat,
                    "file": f"res://assets/puzzles/{cat}/{pid}.jpg",
                    "thumb": f"res://assets/puzzles/thumbs/{pid}.jpg",
                    "title": (r.get("title") or "").strip()[:120],
                    "creator": (r.get("creator") or "").strip()[:80],
                    "license": r["license"],
                    "landing_url": r.get("foreign_landing_url") or "",
                    "openverse_id": r["id"],
                })
                known.add(r["id"])
                kept += 1
                print(f"  + {pid}: {r.get('title')!r} ({r['license']})")
                save_catalog(items)
                time.sleep(1.0)
            time.sleep(1.5)
    save_catalog(items)
    print(f"catalog: {len(items)} pictures")
    return 0


if __name__ == "__main__":
    sys.exit(main())
