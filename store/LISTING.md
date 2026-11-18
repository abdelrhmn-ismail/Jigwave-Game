# Jigwave — Google Play listing kit

Everything needed to publish on Google Play. Upload file: **`build/jigwave-release.aab`**
(made by `tools/export_release.sh`, signed with `keys/jigwave-release.keystore`).

| Item | Value |
|---|---|
| App name | **Jigwave: Jigsaw Puzzles** (≤ 30 chars) |
| Package | `com.abdelrhmnismail.jigwave` (cannot change after the first upload) |
| Version | versionCode **1**, versionName **1.0.0** |
| Category | Game → **Puzzle** |
| Free / paid | **Free**, no in-app purchases, **no ads** |
| Privacy policy URL | <https://github.com/abdelrhmn-ismail/Jigwave-Game/blob/main/PRIVACY.md> |
| App icon | `store/app_icon_512.png` (512×512) |
| Feature graphic | `store/feature_graphic_1024x500.png` (1024×500) |
| Phone screenshots | `store/screenshots/1_home.jpg` … `7_arabic.jpg` (1080×1920) |

---

## English

**Short description** (≤ 80 chars)
> Relaxing jigsaw puzzles: real pieces, 260+ free pictures, endless levels.

**Full description**
> Slow down and piece it together. **Jigwave** turns beautiful pictures into real
> jigsaw puzzles with classic tabs and blanks — drag each piece from the tray and
> feel it snap into place.
>
> 🧩 **Real jigsaw pieces** — from a gentle 9 pieces up to a 100-piece challenge
> 🖼️ **260+ pictures** — nature, animals, space, art, places, food, sports and fun toys
> ♾️ **Endless levels** — every picture comes back with more pieces, so there is no last level
> ⭐ **Stars, not stress** — a wrong spot just sends the piece back; fewer mistakes, more stars
> 🪙 **Coins and helpers** — Peek at the picture, Place a piece, or bring the Edges first
> 🎨 **Gallery** — replay any picture you reached, in any size
> 🎵 **Calm music and soft sounds**, made just for Jigwave
> 🌍 **English and Arabic**
> ✈️ **Plays offline**, no ads, no accounts, no data collected
>
> All pictures are free to use (CC0 / public domain).

## العربية (Arabic)

**الوصف القصير**
> ألغاز صور مريحة بقطع بازل حقيقية، أكثر من 260 صورة ومستويات بلا نهاية.

**الوصف الكامل**
> استرخِ وركّب الصورة قطعة قطعة. **Jigwave** يحوّل صورًا جميلة إلى ألغاز بازل حقيقية
> بنتوءات وتجاويف كلاسيكية — اسحب كل قطعة من الصينية واشعر بها وهي تستقر في مكانها.
>
> 🧩 **قطع بازل حقيقية** — من 9 قطع للبداية حتى 100 قطعة للتحدي
> 🖼️ **أكثر من 260 صورة** — طبيعة، حيوانات، فضاء، فن، أماكن، طعام، رياضة وألعاب
> ♾️ **مستويات بلا نهاية** — كل صورة تعود بعدد قطع أكبر
> ⭐ **نجوم بلا توتر** — القطعة الخطأ تعود للصينية فقط؛ أخطاء أقل = نجوم أكثر
> 🪙 **عملات ومساعدات** — لمحة للصورة، ضع قطعة، أو قطع الحواف أولًا
> 🎨 **المعرض** — العب أي صورة وصلت إليها بأي عدد قطع
> 🎵 **موسيقى هادئة وأصوات ناعمة** صُنعت خصيصًا للعبة
> 🌍 **العربية والإنجليزية**
> ✈️ **تعمل بدون إنترنت**، بلا إعلانات، بلا حسابات، ولا نجمع أي بيانات

---

## Play Console answers

| Form | Answer |
|---|---|
| **Ads** | No, the app contains no ads |
| **App access** | All functionality is available without special access |
| **Content rating** (IARC questionnaire) | Category: Game (Puzzle). No violence, no sexual content, no bad language, no gambling, no user interaction / chat, no sharing of location, no purchases → expected rating **Everyone / PEGI 3** |
| **Target audience** | Recommended: **13+** (simplest). If you add younger ages, the Families policy applies — the app already fits it (no ads, no data) |
| **Data safety** | Data collected: **None**. Data shared: **None**. Encryption in transit: not applicable (no network). Deletion: data is on-device only |
| **News app / COVID / Government** | No |

## Release steps
1. Play Console → **Create app** → name *Jigwave: Jigsaw Puzzles*, Game, Free.
2. Fill **Store listing** with the texts, icon, feature graphic and screenshots above
   (add the Arabic translation under *Translations*).
3. Fill the **App content** forms using the table above.
4. **Testing → Closed testing**: upload `build/jigwave-release.aab`, add **12+ testers**
   and keep the test running **14 days** (required for new personal developer accounts).
5. Then **Production → Create release** with the same (or a newer) AAB.
6. Every update: raise `version/code` in both Android presets in `export_presets.cfg`,
   run `tools/export_release.sh`, upload the new AAB.

> Google Play App Signing: on the first upload Google keeps the app signing key;
> `keys/jigwave-release.keystore` becomes your **upload key**. Keep it backed up.
