# Mobile & Web Canvas Data Collection Specification v3 (Flutter Handoff)

**Document Version:** 4.0 (Capture Plan v3 — Task 7.41)  
**Target Manifest:** `data/mobile_collection/collection_manifest_v3.json` (Seed `42`, built by `scripts/build_collection_manifest_v3.py`)  
**Deployment Target:** Flutter Web on iPad / Android tablet browsers (Safari & Chrome) — same app as v2  

> **`line_N.png` (3.0 logical px) is display/audit only; the model input is rendered from `record.json` points per the [render contract](inference_contract.md#8-render-contract-authoritative) (Task 7.20).**

**Scope:**  
- **TEST** (`assignment: "TEST"`, tier `test_30`): 3 slots (`v3_x01`–`v3_x03`), 30 prompts each (27 clean + 3 Pack D), **different text per slot**.
- **VAL** (`assignment: "VAL"`, tier `val_150`): 1 slot (`v3_v01`, ihab), 150 prompts (135 clean + 15 Pack D).
- **TRAIN** (`assignment: "TRAIN"`): close writers `v3_c01`–`v3_c07` (tier `train_close_30`, 30 each), less-close writers `v3_l01`–`v3_l05` (tier `train_less_close_15`, 15 each), spare walk-in slots `v3_s01`–`v3_s05` (tier `train_spare_30`, 30 each). No Pack D.
- **Total:** 21 slots, **675 prompts = 675 recordings** (every slot has its own text; one person per slot). 24 Pack D items, all `is_training_eligible: false`.

---

## Start here (Flutter developer)

**What to build:** no new app. Update the v2 app so it plays the v3 manifest. Changes:
1. **Manifest:** load `collection_manifest_v3.json`. Same top-level shape (`metadata` + `writers{slot: [items]}`) and the same item fields as v2, plus two new fields, `highlight_word_index` and `ui_note_ar` (§4).
2. **Routing:** the link is `?w=<slot>` (e.g. `https://<domain>/#/?w=v3_c03`). The slot **is** the writer's identity and selects the prompt list. **No name field, no free-text input.** Missing or unknown slot -> error screen (§1, §5.1).
3. **Upload folder = slot id** (e.g. `v3_c03/<prompt_id>/`), never a typed name or a browser uid. A browser uid may still go into `record.json` `capture_meta`, for information only.
4. **Clamp x like y:** every stroke point is clamped to `0 <= x <= band width` and `0 <= y <= 108` before it is stored (§3).
5. **Pack D:** highlight the word at `highlight_word_index` in the prompt; show `ui_note_ar` under the banner when it is not null (§2).
6. **Pointer kind:** record the real kind of every point; **do not block touch** (a pen that reports as touch must still write). Keep the mouse blocker (§3).
7. **Pending uploads:** before the finish screen, show how many uploads are still pending and a Retry button; show "done" only at 0 pending (§3).

**Unchanged from v2** (keep your implementation): 108 px bands and canvas guardrails, Pack D amber banner text, stroke recorder (stroke `y` relative to each band), PNG export, immediate per-prompt upload, 1–3 bands per prompt, `record.json` echoes the manifest item unchanged. Those sections are in `docs/FLUTTER_COLLECTION_SPEC.md` (v1) and `docs/flutter_collection_spec_v2.md`.

**Files:** this spec and `data/mobile_collection/collection_manifest_v3.json` (SHA256 `6caf84057adc95730a1e708d6418dc35f78efeeb024e5aeaa91247314eb18a75`).

**Links to send:** one per person, from §1.1, after applying the mapping rule (§1.2). **Done when:** every row of the §6 checklist passes on the M11, raja's device and an iPad.

---

## 0. What Changed vs v2

| Area | v2 (`collection_manifest_v2.json`) | v3 (`collection_manifest_v3.json`) |
|:---|:---|:---|
| Purpose | held-out-text EVAL + fresh TRAIN text | unseen-writer TEST, ihab VAL, more TRAIN writers |
| Slots | `e01`–`e03`, `s01`–`s20`, `t01`–`t03` | `v3_x01`–`x03`, `v3_v01`, `v3_c01`–`c07`, `v3_l01`–`l05`, `v3_s01`–`s05` |
| Link | `?writer=<slot>`; the app also asked for a name, so people were mapped by folder | **`?w=<slot>`**; slot = identity; no name; folder = slot id |
| Shared text | EVAL slots shared one 50-prompt set | **no shared sets**: every slot has its own text |
| Text overlap | ayah-disjoint from all earlier prompts | ayah-disjoint from **all v1 and v2 prompts** (incl. every v2 slot, recorded or not) and between all 21 slots; no shared 4-word run, also per band (Appendix A) |
| `assignment` | `EVAL` / `EVAL_SHORT` / `TRAIN` | `TEST` / `VAL` / `TRAIN` |
| `tier` | `eval_50`, `eval_short_15`, `train_120` | `test_30`, `val_150`, `train_close_30`, `train_less_close_15`, `train_spare_30` |
| `pack_type` | `disjoint_coverage`, `multiline_cross_ayah`, `long_multiline`, `intentional_error_eval` | **same four** (no new pack type) |
| Shape per slot | mostly single-line | ~70 % multi-band (about 1 in 4 of them `long_multiline`), ~30 % single |
| Pack D | banner only | banner + **`highlight_word_index`**; drops get **`ui_note_ar`**; TEST uses substitutions only |
| New item fields | — | `highlight_word_index` (int or null), `ui_note_ar` (string or null) |
| Stroke x | not clamped (ink left of the band was lost) | **clamped** to the band like y |
| Pointer kind | touch could be blocked | recorded, **never blocked** except mouse |
| Finish | — | pending-upload warning before the finish screen |

---

## 1. Architecture & Session Routing

```
                    USER ARRIVES VIA URL  ?w=<slot>  (required)
                                  │
   ┌──────────────┬───────────────┼────────────────┬────────────────┐
 v3_x01..x03     v3_v01         v3_c01..c07      v3_l01..l05      v3_s01..s05
 TEST 30         VAL 150        TRAIN 30         TRAIN 15         TRAIN 30
 (27 + 3 D)      (135 + 15 D)   close            less-close       walk-in, interleaved
   └──────────────┴───────────────┼────────────────┴────────────────┘
                                  │
                     PROMPT PLAYER UI (as v2) + Pack D highlight
                                  │
                          [ Submit & Next ]
                                  │
       IMMEDIATE HTTP UPLOAD to <slot>/<prompt_id>/: line_0.png (… line_2.png) + record.json
```

### 1.1 Per-Slot Assignments

Shape = clean items: multiline (2 / 3 bands) + long + single. Pack D items are single-band, 3–5 words, spread evenly through the slot (never first or last).

| Slot | Role | Device (`metadata.intended`) | Clean | Pack D | Multiline | Long | Single | URL |
|:---|:---|:---|---|---|---|---|---|:---|
| `v3_x01` | TEST, fat writing | M11 | 27 | 3 | 14 (7/7) | 5 | 8 | `https://<domain>/#/?w=v3_x01` |
| `v3_x02` | TEST, close | M11 | 27 | 3 | 14 (7/7) | 5 | 8 | `…?w=v3_x02` |
| `v3_x03` | TEST, close | raja's device | 27 | 3 | 14 (7/7) | 5 | 8 | `…?w=v3_x03` |
| `v3_v01` | VAL, ihab | ihab's Android | 135 | 15 | 71 (36/35) | 24 | 40 | `…?w=v3_v01` |
| `v3_c01`, `v3_c02` | TRAIN, close | M11 | 30 | 0 | 16 (8/8) | 5 | 9 | `…?w=v3_c01` … |
| `v3_c03`–`v3_c07` | TRAIN, close | raja's device | 30 | 0 | 16 (8/8) | 5 | 9 | `…?w=v3_c03` … |
| `v3_l01`–`v3_l05` | TRAIN, less-close | iPad | 15 | 0 | 8 (4/4) | 2 | 5 | `…?w=v3_l01` … |
| `v3_s01`–`v3_s05` | TRAIN, spare (walk-in) | any | 30 | 0 | 16 (8/8) | 5 | 9 | `…?w=v3_s01` … |

Shapes (as v2): single = 1 band, 3–5 words (`disjoint_coverage`); multiline = 2 bands / 6–8 words or 3 bands / 9–12 words, 3–4 words per band, crossing an ayah boundary (`multiline_cross_ayah`); long = 3 bands, 15–20 words, 5–7 words per band (`long_multiline`).

Order in a slot (`seq_index`, Task 7.42): **every slot is interleaved** so any prefix keeps the shape mix (a writer may stop early); Pack D is spread evenly and is never the first or last item. Play items in `seq_index` order. S = single, M = multiline, L = long, D = Pack D:
- `v3_x01`–`x03`: `M S L M D M S M L S M M S M L D M S M M S L M S M D M L S M` (Pack D at seq 5, 16, 26)
- `v3_v01`: Pack D at seq 5, 15, 26, 36, 45, 56, 65, 76, 86, 95, 106, 115, 125, 136, 146
- `v3_c*`, `v3_s*`: `M S M L M S M S M L M S M M S L M M S M L M S M S M L M S M`
- `v3_l*`: `M S M L S M M S M M S L M S M`

### 1.2 Mapping rule (who gets which slot)

- **TEST slots (`v3_x*`) only for people never recorded in v1 or v2** (fat writing is OK for `v3_x01`).
- **Any person already recorded in v1 or v2 -> an `l` or `s` TRAIN slot** (never TEST).
- **An unused TEST slot -> another unseen close writer.**
- `v3_v01` is ihab's. One person per slot; give each person only their own link and never reuse a slot for a second person.

The intended role and device per slot are in `metadata.intended`; the rule is repeated in `metadata.mapping_rule`.

---

## 2. Intentional Error Banner + Highlight (`ui_notice_ar != null`)

- **Banner:** unchanged from v1 / v2 (same text, same amber card).
- **Highlight:** when `highlight_word_index` is an integer, highlight that word of the prompt (index into `line_prompts[0].display_text_uthmani.split(" ")`; Pack D prompts are always one band). Any clear marking is fine (e.g. amber background or underline on that word).
- **Removed word:** for the two drop categories (`particle_drop`, `word_omission`, VAL only) `highlight_word_index` is `null` and `ui_note_ar` holds a fixed note; show it under the banner:
  - `ui_note_ar` = `حُذفت كلمة عمداً — اكتب النص المعروض كما تراه بالضبط.` (meaning: "a word was removed on purpose - write exactly what you see").
- Clean items have `highlight_word_index: null`, `ui_note_ar: null`, `ui_notice_ar: null`.
- TEST Pack D uses substitutions only (confusable, particle_swap, word_swap), so every TEST Pack D item has a highlight.

---

## 3. Canvas, Pointer Kind, Uploads

Unchanged from v2 §3 / v1 §3 (108 logical px bands, max width 840, aspect lock, immediate per-prompt upload), with these changes:

- **Clamp x like y.** Store `x = clamp(x, 0, bandWidth)` and `y = clamp(y, 0, 108)` for every point (`bandWidth` = the band's logical width). In v2 only y was clamped; ink drawn past the left band edge (the end of an RTL line) was lost later in rendering.
- **Pointer kind, no blocking.** Store the real `PointerDeviceKind` of every point as `kind` (`"stylus"`, `"invertedStylus"`, `"touch"`, `"unknown"`, …) and keep `primary_pointer_kind` in `capture_meta`. **Do not block touch:** on some tablets a pen reports as touch. Keep the desktop **mouse blocker** as in v1 §3.2.
- **Pending uploads before finish.** Failed uploads are kept as in v1 (`hafs_pending_<prompt_id>` in local storage). Before the finish screen, count them: if any are pending, show the number and a **Retry** button and do not show "done"; show "done" only when 0 are pending.

---

## 4. Output Bundle Schema & Concrete Example

`record.json` echoes the manifest item unchanged (now including `highlight_word_index` and `ui_note_ar`) plus `capture_meta` and `lines` exactly as in v1 §4.1. `writer_id` in the item is the slot id and is the writer's identity.

### 4.1 Manifest Item Example (TEST Pack D, `confusable`)

```json
{
  "seq_index": 5,
  "prompt_id": "v3_x01_005_test_error_001",
  "writer_id": "v3_x01",
  "tier": "test_30",
  "assignment": "TEST",
  "pack_type": "intentional_error_eval",
  "is_training_eligible": false,
  "num_canvas_lines": 1,
  "surah": 74,
  "ayah_start": 31,
  "ayah_end": 31,
  "g_start": 75041,
  "g_end": 75044,
  "display_text_uthmani": "أُوتُوا۟ ٱلْكِتَٰبَ وَيَزْدَادَ ٱلَّذِى",
  "written_imlai": "أوتوا الكتاب ويزداد الذي",
  "canonical_imlai": "أوتوا الكتاب ويزداد الذين",
  "line_prompts": [
    {"line_index": 0, "g_start": 75041, "g_end": 75044, "display_text_uthmani": "أُوتُوا۟ ٱلْكِتَٰبَ وَيَزْدَادَ ٱلَّذِى", "written_imlai": "أوتوا الكتاب ويزداد الذي"}
  ],
  "error_meta": {"category": "confusable", "target_word_index": 3, "canonical_token": "الذين", "mutated_token": "الذي", "description": "Confusable word swap: 'الذين' -> 'الذي'"},
  "ui_notice_ar": "<v1 banner text>",
  "highlight_word_index": 3,
  "ui_note_ar": null
}
```

Here word 3 of the display text (`ٱلَّذِى`) is highlighted. A drop example (`v3_v01_045_val_error_005`, `particle_drop`): `written_imlai` `السحرة كانوا`, `highlight_word_index: null`, `ui_note_ar` = the fixed note above.

### 4.2 Manifest Top Level
`{"metadata": {...}, "writers": {"v3_x01": [...30], ..., "v3_v01": [...150], "v3_c01": [...30], ..., "v3_l05": [...15], "v3_s01": [...30], ...}}` — same shape as v2. `metadata.intended` lists role, device, writer, prompt and pack counts per slot; `metadata.exclusion` lists the exclusion sources and counts; `metadata.slot_seeds` the per-slot seeds.

---

## 5. Flutter Web Implementation Reference

### 5.1 Query Parameter Routing (v3: `?w=<slot>`)
```dart
class SessionManagerV3 {
  /// v3: the slot from ?w=<slot> is the writer identity and selects the prompt list. No name input.
  static String? resolveSlot(Map<String, List<dynamic>> manifestWriters) {
    final slot = Uri.base.queryParameters['w'];
    if (slot != null && manifestWriters.containsKey(slot)) {
      return slot; // v3_x01..x03, v3_v01, v3_c01..c07, v3_l01..l05, v3_s01..s05
    }
    return null; // show "invalid or missing link" screen; do not auto-assign
  }
}
```

### 5.2 Point clamp and kind
```dart
// in the pointer handler, before recorder.startStroke / appendPoint
if (event.kind == PointerDeviceKind.mouse) { showMouseBlockedDialog(); return; }   // unchanged
final x = event.localPosition.dx.clamp(0.0, bandWidth);
final y = event.localPosition.dy.clamp(0.0, 108.0);
final kind = event.kind.name; // "stylus", "invertedStylus", "touch", "unknown", ... — never block touch
```

Stroke recorder, rasterizer and upload: unchanged from v1 §5.2 / §5.3 (loop over all `num_canvas_lines` bands).

---

## 6. Frontend Verification Checklist

| Requirement | Implementation Verification |
|:---|:---|
| **URL Routing** | `?w=v3_x01` loads 30 prompts, `?w=v3_v01` 150, `?w=v3_l02` 15, `?w=v3_s03` 30; missing/unknown slot shows an error screen; no name field anywhere. |
| **Upload Folder** | uploads land under `<slot>/<prompt_id>/` (e.g. `v3_c03/v3_c03_001_train_single_001/`). |
| **Pack D Highlight** | on `v3_x01` seq 5 the word `ٱلَّذِى` is highlighted; on a `v3_v01` drop item (e.g. seq 45) no word is highlighted and `ui_note_ar` shows under the banner. |
| **Clamp x / y** | draw past the left and right band edges: stored x stays in `[0, bandWidth]`, y in `[0, 108]`. |
| **Pointer Kind** | finger and pen both write; `kind` per point and `primary_pointer_kind` show the real kind; mouse is still blocked. |
| **Pending Uploads** | with the network off, submit 2 prompts, try to finish: the app shows 2 pending + Retry; after reconnect + Retry it shows done. |
| **3-Band Prompts** | `multiline_cross_ayah` and `long_multiline` render one band per `line_prompts[i]`; try a few `long_multiline` prompts (5–7 words per band) on each device. |
| **Record Echo** | `record.json` includes `assignment`, `tier`, `pack_type`, `highlight_word_index`, `ui_note_ar` unchanged. |
| **Stroke Frame / Mouse Blocking / Aspect Ratio / Clean PNG** | As v2 §6 / v1 §6. |

---

## Appendix A. Counts and Disjointness

Generated by `scripts/build_collection_manifest_v3.py` (seed 42; per-slot seeds 42101–42121 in `metadata.slot_seeds`). Manifest SHA256 `6caf84057adc95730a1e708d6418dc35f78efeeb024e5aeaa91247314eb18a75` (two builds byte-identical).

Exclusion set: **2,902 ayahs** (2,785 touched by the 2,020 v1 + 810 v2 manifest items, +117 from 164 line prompts in `capture_prompts*.json` and the web-canvas `writer_01`..`writer_04` manifests). v3 uses 1,255 ayahs.

| Slot | Items | Single | Multiline (2/3) | Long | Pack D | Words | Distinct ayahs | Letters (clean) |
|---|---|---|---|---|---|---|---|---|
| v3_x01 | 30 | 8 | 14 (7/7) | 5 | 3 | 253 | 53 | 36/36 |
| v3_x02 | 30 | 8 | 14 (7/7) | 5 | 3 | 249 | 52 | 36/36 |
| v3_x03 | 30 | 8 | 14 (7/7) | 5 | 3 | 255 | 57 | 36/36 |
| v3_v01 | 150 | 40 | 71 (36/35) | 24 | 15 | 1254 | 271 | 36/36 |
| v3_c01 | 30 | 9 | 16 (8/8) | 5 | 0 | 265 | 60 | 36/36 |
| v3_c02 | 30 | 9 | 16 (8/8) | 5 | 0 | 266 | 55 | 36/36 |
| v3_c03 | 30 | 9 | 16 (8/8) | 5 | 0 | 262 | 57 | 36/36 |
| v3_c04 | 30 | 9 | 16 (8/8) | 5 | 0 | 265 | 60 | 36/36 |
| v3_c05 | 30 | 9 | 16 (8/8) | 5 | 0 | 266 | 60 | 36/36 |
| v3_c06 | 30 | 9 | 16 (8/8) | 5 | 0 | 268 | 57 | 36/36 |
| v3_c07 | 30 | 9 | 16 (8/8) | 5 | 0 | 272 | 57 | 36/36 |
| v3_l01 | 15 | 5 | 8 (4/4) | 2 | 0 | 121 | 25 | 36/36 |
| v3_l02 | 15 | 5 | 8 (4/4) | 2 | 0 | 121 | 26 | 36/36 |
| v3_l03 | 15 | 5 | 8 (4/4) | 2 | 0 | 123 | 32 | 36/36 |
| v3_l04 | 15 | 5 | 8 (4/4) | 2 | 0 | 129 | 28 | 36/36 |
| v3_l05 | 15 | 5 | 8 (4/4) | 2 | 0 | 123 | 30 | 36/36 |
| v3_s01 | 30 | 9 | 16 (8/8) | 5 | 0 | 266 | 52 | 36/36 |
| v3_s02 | 30 | 9 | 16 (8/8) | 5 | 0 | 267 | 61 | 36/36 |
| v3_s03 | 30 | 9 | 16 (8/8) | 5 | 0 | 268 | 59 | 36/36 |
| v3_s04 | 30 | 9 | 16 (8/8) | 5 | 0 | 261 | 50 | 36/36 |
| v3_s05 | 30 | 9 | 16 (8/8) | 5 | 0 | 262 | 53 | 36/36 |

Pack D categories — TEST (each slot): confusable 1, particle_swap 1, word_swap 1. VAL: confusable 5, particle_drop 2, particle_swap 3, word_omission 2, word_swap 3. The planned 1 mutashabihat_trap fell back to confusable (no free fresh ayah holds a trap word; the same happened in v2; recorded in `metadata.pack_d_fallbacks`).

Disjointness (asserted by the builder and recomputed independently by `scripts/diagnostics/check_v3_text_disjoint.py`, all counts 0):
- no v3 ayah or word position is used by any v1 / v2 manifest item, `capture_prompts*.json` line or web-canvas prompt; the 21 slots are pairwise ayah-disjoint; no ayah repeats inside a slot;
- on normalized tokens (alef forms, ى/ي, ة/ه, tatweel), for the whole prompt **and each band**: no v3 text equals an old text, shares a 4-word run with an old or another-slot text, is a 3-word text inside an old or other v3 text, or contains a 3-word old text;
- old texts = v1 / v2 manifest texts (canonical, written, every band), the recorded v1 texts (`flutter_splits_v1.json`) and the prompt files; every recorded v2 prompt id is in the v2 manifest; local `data/capture_web_extra/*/manifest.csv` (not in git) is also checked when present;
- every slot has its planned shape, 36/36 letters on its clean items (asserted, never relaxed) and correct Pack D flags / highlight / note; 0 OOV characters (builder assert).

## Appendix B. Length Histogram (canonical words per prompt, all 21 slots)

| Words | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 15 | 16 | 17 | 18 | 19 | 20 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Items | 77 | 74 | 70 | 46 | 78 | 49 | 19 | 65 | 66 | 22 | 2 | 23 | 25 | 35 | 19 | 5 |

Counts include Pack D items (canonical length 3–5).
