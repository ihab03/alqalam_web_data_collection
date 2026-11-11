# Mobile & Web Canvas Data Collection Specification v2 (Flutter Handoff)

**Document Version:** 3.2 (Capture Plan v2 — Task 6.5b; EVAL_SHORT redrawn as 20 random slots in Task 6.5b-2; "Start here" added in Task 6.5g)  
**Target Manifest:** `data/mobile_collection/collection_manifest_v2.json` (Seed `42`, built by `scripts/build_collection_manifest_v2.py`)  
**Deployment Target:** Flutter Web on iPad / Android Tablet browsers (Safari & Chrome) — same app as v1  
**Scope:**  
- **EVAL** (`tier: "eval_50"`): 3 named writer slots (`e01`–`e03`), 50 prompts/slot = **150 items** (same 50 prompts for every slot).
- **EVAL_SHORT** (`tier: "eval_short_15"`): 20 slots for new writers (`s01`–`s20`), 15 prompts/slot = **300 items** (each slot its own random draw on fresh ayahs).
- **TRAIN** (`tier: "train_120"`): 3 named writer slots (`t01`–`t03`), 120 prompts/slot = **360 items** (different text per slot).
- **Total:** 26 slots, **810 recordings** across **710 unique Quran spans**.
- **Intentional Errors:** 130 items (30 EVAL + 100 EVAL_SHORT), strictly `is_training_eligible: false`.

---

## Start here (Flutter developer)

**What to build:** no new app. Update the existing v1 collection app so it plays the v2 manifest. Four changes:
1. **Manifest:** load `collection_manifest_v2.json` instead of `collection_manifest.json`. Same top-level shape (`metadata` + `writers{slot: [items]}`) and the same item fields, plus one new field, `assignment` (§0, §4).
2. **Routing:** named slots only. A `?writer=<slot>` link is **required** (26 slots: `e01`–`e03`, `s01`–`s20`, `t01`–`t03`). Remove the crowd auto-claim and the "Contribute 15 More" flow. A missing or unknown slot shows an error screen (§1, §5.1).
3. **Prompts with up to 3 bands:** `multiline_cross_ayah` (2–3 bands) and the new `long_multiline` (always 3 bands, 5–7 words per band). Upload `line_0.png` … `line_2.png`. **Try a few long prompts on a real tablet before sending any links** (§3).
4. **record.json:** echo the manifest item unchanged, including `assignment`, `tier`, `pack_type` (§4).

**Unchanged from v1** (keep your v1 implementation): Pack D amber banner, 108 px bands and canvas guardrails, mouse blocker, stroke recorder (stroke `y` relative to each band, as in v1), PNG export, immediate per-prompt upload. These sections are in the v1 spec `docs/FLUTTER_COLLECTION_SPEC.md`.

**Files:** this spec and `data/mobile_collection/collection_manifest_v2.json` (SHA256 `8d846c41fb24d041db2c2b417bf3224695e07b37d5407f15611f4cb1c45a305f`).

**Links to send:** one per person, from the slot table in §1.1. **Done when:** every row of the §6 checklist passes on an iPad and an Android tablet.

---

## 0. What Changed vs v1

| Area | v1 (`collection_manifest.json`) | v2 (`collection_manifest_v2.json`) |
|:---|:---|:---|
| Purpose | Bulk collection (Core 130 + Crowd 15) | Held-out-text **evaluation** set + fresh **training** text |
| Sessions | `w01`–`w04` (130), `c001`–`c100` (15, auto-claimed) | `e01`–`e03` (50), `s01`–`s20` (15), `t01`–`t03` (120); **no crowd auto-claim** |
| Text overlap | Every Core writer wrote the same Pack A/C/D shared prompts; val/locked writers wrote the same texts as the training writers | **Every ayah is unused by all existing prompts** (v1 manifest, `capture_prompts*.json`, web-canvas writer_01..04). EVAL, `t01`–`t03` and `s01`–`s20` are pairwise ayah-disjoint and share no 4-word run |
| New item field | — | `assignment`: `"EVAL"` / `"EVAL_SHORT"` / `"TRAIN"` |
| `tier` values | `core_130`, `crowd_15` | `eval_50`, `eval_short_15`, `train_120` |
| `pack_type` values | `shared_core`, `disjoint_coverage`, `multiline_cross_ayah`, `intentional_error_eval` | `disjoint_coverage` (single line), `multiline_cross_ayah` (2–3 lines), **`long_multiline`** (new: 3 lines, 15–20 words), `intentional_error_eval`. `shared_core` is not used |
| Canvas lines | 1–3 | 1–3 (long prompts always 3 lines of 5–7 words) |
| Pack D | 6 categories, `ui_notice_ar` banner | Unchanged (same categories, same `error_meta`, same banner text) |
| Everything else | §2 banner, §3 guardrails, §4 record schema, §5 upload code | **Unchanged** — see v1 `docs/FLUTTER_COLLECTION_SPEC.md` |

---

## 1. Architecture & Session Routing

The app stays a zero-logic prompt player and stroke recorder. v2 has **only named slots** (no default/crowd flow).

```
                         USER ARRIVES VIA URL
                                  │
                 ?writer=<slot>  (required in v2)
                                  │
     ┌────────────────────────────┼────────────────────────────┐
     │                            │                            │
 e01..e03 (EVAL)          s01..s20 (EVAL_SHORT)        t01..t03 (TRAIN)
 50 prompts               15 prompts                   120 prompts
 single 25, multi 10,     single 6, multi 2,           single 100, multi 20
 long 5, Pack D 10        long 2, Pack D 5             (no Pack D)
     │                            │                            │
     └────────────────────────────┼────────────────────────────┘
                                  │
                       PROMPT PLAYER UI (as v1)
       - RTL prompt per canvas line (line_prompts[i].display_text_uthmani)
       - Amber banner when ui_notice_ar != null
       - 1–3 stacked canvas bands, 108 logical px each
                                  │
                          [ Submit & Next ]
                                  │
       IMMEDIATE HTTP UPLOAD: line_0.png (+ line_1.png, line_2.png) + record.json
```

### 1.1 Per-Writer Assignments

| Slot | Writer | Assignment | Prompts | URL |
|:---|:---|:---|:---|:---|
| `e01` | ihab | EVAL | 50 | `https://<domain>/#/?writer=e01` |
| `e02` | raja | EVAL | 50 | `https://<domain>/#/?writer=e02` |
| `e03` | ab | EVAL | 50 | `https://<domain>/#/?writer=e03` |
| `s01`–`s20` | up to 20 new writers (one slot each) | EVAL_SHORT | 15 | `https://<domain>/#/?writer=s01` … `s20` |
| `t01` | mosa | TRAIN | 120 | `https://<domain>/#/?writer=t01` |
| `t02` | ra1 | TRAIN | 120 | `https://<domain>/#/?writer=t02` |
| `t03` | ra2 | TRAIN | 120 | `https://<domain>/#/?writer=t03` |

The same mapping is stored in `metadata.assignments.<ASSIGNMENT>.intended_writers`. Give each person only their own link; a slot must be written by exactly one person.

Web-canvas (Steps 2–3) identities, for reference: `writer_01` = mosa, `writer_02` = ab, `writer_03` = ihab, `writer_04` = hakeem.

### 1.2 EVAL (`tier: "eval_50"`, `e01`–`e03`)
- **Session Length:** 50 prompts, identical text for all three slots (only `prompt_id`/`writer_id` prefixes differ).
- **Pack Distribution (in `seq_index` order):**
  - **Single line (`disjoint_coverage`, 25 items, seq 1–25):** 3–5 words; 15 mid-ayah, 6 ayah-edge/full, 4 cross-ayah. Chosen rarest letters first.
  - **Multiline (`multiline_cross_ayah`, 10 items, seq 26–35):** 5 × 2 lines (6–8 words) + 5 × 3 lines (9–12 words), 3–4 words/line, crossing an ayah boundary.
  - **Long (`long_multiline`, 5 items, seq 36–40):** 3 lines, 15–20 words total, 5–7 words/line.
  - **Pack D (`intentional_error_eval`, 10 items, seq 41–50):** fresh ayahs (not the EVAL clean ayahs), categories: confusable ×3, particle_drop, particle_swap ×2, word_omission, word_swap ×2, mutashabihat_trap.
- **Auto-Resume:** as v1 (lowest incomplete `seq_index`).

### 1.3 EVAL_SHORT (`tier: "eval_short_15"`, `s01`–`s20`)
- **Session Length:** 15 prompts per slot, **different text for every slot**. Each slot is its own seeded random draw (seed `42000 + k` for `s<k>`, stored in `metadata.eval_short_seeds`) on fresh ayahs: disjoint from EVAL, TRAIN, every existing prompt and every other slot.
- **Composition (seq order):** 6 single (`disjoint_coverage`, seq 1–6, lengths 3/4/5 all present, picked for letter coverage), 2 multiline (`multiline_cross_ayah`, seq 7–8: one 2-line, one 3-line), 2 long (`long_multiline`, seq 9–10), 5 Pack D (`intentional_error_eval`, seq 11–15, 5 distinct categories). Each slot's 10 clean prompts cover 36/36 letters.
- **Prompt IDs:** `s07_009_short_long_001`, `s07_011_short_error_001`, etc.

### 1.4 TRAIN (`tier: "train_120"`, `t01`–`t03`)
- **Session Length:** 120 prompts per slot, **different text for each slot** (`t01`, `t02`, `t03` are ayah-disjoint from each other, from EVAL and from EVAL_SHORT).
- **Pack Distribution:** 100 single line (`disjoint_coverage`, seq 1–100: 60 mid, 25 edge/full, 15 cross-ayah, 3–5 words) + 20 multiline (`multiline_cross_ayah`, seq 101–120: 10 × 2 lines + 10 × 3 lines). No Pack D; all items `is_training_eligible: true`.

---

## 2. Intentional Error Banner (`ui_notice_ar != null`)

Unchanged from v1 §2 (same text, same amber card, same Dart widget). In v2 the banner appears on all 130 Pack D items (EVAL seq 41–50, EVAL_SHORT seq 11–15) and never on TRAIN.

---

## 3. Web Canvas Guardrails & Touch Tracking

Unchanged from v1 §3 (108 logical px bands, max width 840, mouse blocker, immediate per-prompt upload).  
**v2 note:** `long_multiline` items put 5–7 words on each band (v1 multiline had 3–4). Keep the full 840 px width on tablets; do not shrink the band height to fit. **Not yet tested on a device:** before sending links, write a few `long_multiline` prompts (e.g. `e01` seq 36–40) on a real iPad and Android tablet and confirm 5–7 words fit one band without wrapping or shrinking. Report back if they don't fit, so the prompts can be re-split.

---

## 4. Output Bundle Schema & Concrete Example

For every prompt submission, generate `line_<i>.png` for each `i < num_canvas_lines` (up to `line_2.png`) and `record.json`. `record.json` echoes the manifest item (including the new `assignment` field) plus `capture_meta` and `lines` exactly as in v1 §4.1.

### 4.1 Manifest Item Example (`long_multiline`)

```json
{
  "seq_index": 36,
  "prompt_id": "e01_036_eval_long_001",
  "writer_id": "e01",
  "tier": "eval_50",
  "assignment": "EVAL",
  "pack_type": "long_multiline",
  "is_training_eligible": true,
  "num_canvas_lines": 3,
  "surah": 57,
  "ayah_start": 25,
  "ayah_end": 25,
  "g_start": 70270,
  "g_end": 70288,
  "display_text_uthmani": "لَقَدْ أَرْسَلْنَا رُسُلَنَا بِٱلْبَيِّنَٰتِ وَأَنزَلْنَا مَعَهُمُ ٱلْكِتَٰبَ وَٱلْمِيزَانَ لِيَقُومَ ٱلنَّاسُ بِٱلْقِسْطِ وَأَنزَلْنَا ٱلْحَدِيدَ فِيهِ بَأْسٌ شَدِيدٌ وَمَنَٰفِعُ لِلنَّاسِ وَلِيَعْلَمَ",
  "written_imlai": "لقد أرسلنا رسلنا بالبينات وأنزلنا معهم الكتاب والميزان ليقوم الناس بالقسط وأنزلنا الحديد فيه بأس شديد ومنافع للناس وليعلم",
  "canonical_imlai": "لقد أرسلنا رسلنا بالبينات وأنزلنا معهم الكتاب والميزان ليقوم الناس بالقسط وأنزلنا الحديد فيه بأس شديد ومنافع للناس وليعلم",
  "line_prompts": [
    {"line_index": 0, "g_start": 70270, "g_end": 70274, "display_text_uthmani": "لَقَدْ أَرْسَلْنَا رُسُلَنَا بِٱلْبَيِّنَٰتِ وَأَنزَلْنَا", "written_imlai": "لقد أرسلنا رسلنا بالبينات وأنزلنا"},
    {"line_index": 1, "g_start": 70275, "g_end": 70281, "display_text_uthmani": "مَعَهُمُ ٱلْكِتَٰبَ وَٱلْمِيزَانَ لِيَقُومَ ٱلنَّاسُ بِٱلْقِسْطِ وَأَنزَلْنَا", "written_imlai": "معهم الكتاب والميزان ليقوم الناس بالقسط وأنزلنا"},
    {"line_index": 2, "g_start": 70282, "g_end": 70288, "display_text_uthmani": "ٱلْحَدِيدَ فِيهِ بَأْسٌ شَدِيدٌ وَمَنَٰفِعُ لِلنَّاسِ وَلِيَعْلَمَ", "written_imlai": "الحديد فيه بأس شديد ومنافع للناس وليعلم"}
  ],
  "error_meta": null,
  "ui_notice_ar": null
}
```

### 4.2 Manifest Top Level
`{"metadata": {...}, "writers": {"e01": [...50], "e02": [...], "e03": [...], "s01": [...15], ..., "s20": [...], "t01": [...120], "t02": [...], "t03": [...]}}` — same shape as v1. `metadata.assignments` lists slots, intended writers, prompts per slot and pack counts; `metadata.exclusion` records the exclusion sources and counts.

---

## 5. Flutter Web Implementation Reference

Unchanged from v1 §5.2 (stroke recorder) and §5.3 (rasterizer + upload; loop over all `num_canvas_lines` bands). Only routing changes:

### 5.1 Query Parameter Routing (v2: named slots only)
```dart
class SessionManagerV2 {
  /// v2 has no crowd batches: a valid ?writer=<slot> is required.
  static String? resolveWriterId(Map<String, List<dynamic>> manifestWriters) {
    final writerParam = Uri.base.queryParameters['writer'];
    if (writerParam != null && manifestWriters.containsKey(writerParam)) {
      return writerParam; // e01..e03, s01..s20, t01..t03
    }
    return null; // show "invalid or missing link" screen; do not auto-assign
  }
}
```

---

## 6. Frontend Verification Checklist

| Requirement | Implementation Verification |
|:---|:---|
| **URL Routing** | `?writer=e01` loads 50 prompts, `?writer=s03` loads 15, `?writer=t02` loads 120; missing/unknown slot shows an error screen (no auto-claim). |
| **3-Band Prompts** | `multiline_cross_ayah` (2–3 bands) and `long_multiline` (3 bands) render one band per `line_prompts[i]`; uploads `line_0..line_2.png`. |
| **Notice Banner** | Amber banner on all 130 Pack D items (`ui_notice_ar != null`); none on TRAIN. |
| **Record Echo** | `record.json` includes `assignment`, `tier`, `pack_type` from the manifest item unchanged. |
| **Stroke Frame** | Stroke `y` is relative to its own 108 px band (0 = band top), as in v1. Check one record from an iPad: ink y values should mostly fall inside 0–108. A patched web capture page once saved full-canvas y (+72 px), which made those recordings unreadable for the model. |
| **Long Prompts** | `long_multiline` (5–7 words per band) tested on a real iPad and Android tablet before links go out (§3). |
| **Mouse Blocking / Aspect Ratio / Immediate Upload / Clean PNG** | As v1 §6. |

---

## Appendix A. Counts

Generated by `scripts/build_collection_manifest_v2.py` (seed 42; EVAL_SHORT slot seeds 42001–42020). Manifest SHA256: `8d846c41fb24d041db2c2b417bf3224695e07b37d5407f15611f4cb1c45a305f`. EVAL and TRAIN items are byte-identical to the Task 6.5b manifest (`59ed2830…`); only EVAL_SHORT changed.

Exclusion set: **1,886 ayahs** (1,770 touched by the 2,020 v1 manifest items, +116 from 164 line prompts in `capture_prompts*.json` and the web-canvas `writer_01`..`writer_04` manifests). All 164 text lines were located in the index. Ayahs used by v2: EVAL 69, `t01` 159, `t02` 158, `t03` 156, EVAL_SHORT 473 (20 slots).

| Slot group | Items | Single | Multiline | Long | Pack D | Words (total) | Distinct ayahs | Letters covered |
|---|---|---|---|---|---|---|---|---|
| EVAL | 50 | 25 | 10 | 5 | 10 | 325 | 69 | 36/36 |
| TRAIN t01 | 120 | 100 | 20 | 0 | 0 | 575 | 159 | 36/36 |
| TRAIN t02 | 120 | 100 | 20 | 0 | 0 | 572 | 158 | 36/36 |
| TRAIN t03 | 120 | 100 | 20 | 0 | 0 | 576 | 156 | 36/36 |

EVAL_SHORT slots (each: 6 single, 2 multiline, 2 long, 5 Pack D; letters counted on the 10 clean prompts):

| Slot | Seed | Words (total) | Distinct ayahs | Letters covered | Pack D categories |
|---|---|---|---|---|---|
| s01 | 42001 | 98 | 22 | 36/36 | confusable, particle_drop, particle_swap, word_omission, word_swap |
| s02 | 42002 | 95 | 23 | 36/36 | confusable, mutashabihat_trap, particle_drop, word_omission, word_swap |
| s03 | 42003 | 97 | 23 | 36/36 | confusable, mutashabihat_trap, particle_drop, particle_swap, word_swap |
| s04 | 42004 | 99 | 23 | 36/36 | confusable, mutashabihat_trap, particle_drop, particle_swap, word_swap |
| s05 | 42005 | 94 | 22 | 36/36 | confusable, mutashabihat_trap, particle_drop, particle_swap, word_swap |
| s06 | 42006 | 98 | 23 | 36/36 | confusable, particle_drop, particle_swap, word_omission, word_swap |
| s07 | 42007 | 101 | 28 | 36/36 | confusable, particle_drop, particle_swap, word_omission, word_swap |
| s08 | 42008 | 98 | 28 | 36/36 | confusable, particle_drop, particle_swap, word_omission, word_swap |
| s09 | 42009 | 96 | 24 | 36/36 | confusable, particle_drop, particle_swap, word_omission, word_swap |
| s10 | 42010 | 101 | 29 | 36/36 | confusable, particle_drop, particle_swap, word_omission, word_swap |
| s11 | 42011 | 103 | 24 | 36/36 | confusable, particle_drop, particle_swap, word_omission, word_swap |
| s12 | 42012 | 97 | 23 | 36/36 | confusable, particle_drop, particle_swap, word_omission, word_swap |
| s13 | 42013 | 101 | 24 | 36/36 | confusable, particle_drop, particle_swap, word_omission, word_swap |
| s14 | 42014 | 94 | 24 | 36/36 | confusable, particle_drop, particle_swap, word_omission, word_swap |
| s15 | 42015 | 99 | 24 | 36/36 | confusable, particle_drop, particle_swap, word_omission, word_swap |
| s16 | 42016 | 102 | 19 | 36/36 | confusable, particle_drop, particle_swap, word_omission, word_swap |
| s17 | 42017 | 96 | 22 | 36/36 | confusable, particle_drop, particle_swap, word_omission, word_swap |
| s18 | 42018 | 105 | 25 | 36/36 | confusable, particle_drop, particle_swap, word_omission, word_swap |
| s19 | 42019 | 95 | 18 | 36/36 | confusable, particle_drop, particle_swap, word_omission, word_swap |
| s20 | 42020 | 97 | 25 | 36/36 | confusable, particle_drop, particle_swap, word_omission, word_swap |

Pack D categories — EVAL: confusable 3, particle_drop 1, particle_swap 2, word_omission 1, word_swap 2, mutashabihat_trap 1. EVAL_SHORT (all 20 slots, 100 items): confusable 20, particle_drop 20, word_swap 20, particle_swap 19, word_omission 17, mutashabihat_trap 4. Each slot draws 5 of the 6 categories at random; free fresh ayahs containing a mutashabihat trap phrase ran out after 4 slots, so later draws of that category fall back to the unused category (every slot keeps 5 distinct categories).

Disjointness checks asserted by the builder:
- every v2 ayah is outside the exclusion set; EVAL, `t01`–`t03` and `s01`–`s20` pairwise ayah-disjoint; no two items in a pack share an ayah;
- no v2 text shares a 4-word run with any existing prompt text or with another v2 pack/slot; no 3-word v2 text is contained in an existing prompt, and none contains a 3-word existing prompt;
- all EVAL slots identical; every EVAL_SHORT slot has 6/2/2/5 items, single lengths {3, 4, 5}, ≥ 4 Pack D categories, 36/36 letters;
- 0 OOV characters (letter set from the index's own `ctc`/`ctc_ids`); Pack D flags and banner set exactly on Pack D.

## Appendix B. Length Histogram (canonical words per prompt)

| Words | EVAL | EVAL_SHORT (per slot avg) | TRAIN (per slot avg) |
|---|---|---|---|
| 3 | 8 | 3.15 | 32.3 |
| 4 | 13 | 3.55 | 35.0 |
| 5 | 14 | 4.30 | 32.7 |
| 6 | 2 | 0.20 | 2.7 |
| 7 | 2 | 0.65 | 4.7 |
| 8 | 1 | 0.15 | 2.7 |
| 9 | 0 | 0.20 | 1.7 |
| 10 | 3 | 0.30 | 4.0 |
| 11 | 2 | 0.25 | 3.0 |
| 12 | 0 | 0.25 | 1.3 |
| 15 | 0 | 0.05 | 0.0 |
| 16 | 0 | 0.25 | 0.0 |
| 17 | 1 | 0.60 | 0.0 |
| 18 | 1 | 0.30 | 0.0 |
| 19 | 2 | 0.70 | 0.0 |
| 20 | 1 | 0.10 | 0.0 |

EVAL and EVAL_SHORT counts include Pack D items (3–5 words, canonical length).

## Appendix C. Letter Coverage (rarest first; occurrences in clean items)

| Letter | Corpus freq | EVAL | t01 | t02 | t03 |
|---|---|---|---|---|---|
| ؤ | 673 | 4 | 5 | 3 | 5 |
| ظ | 853 | 1 | 4 | 8 | 12 |
| ئ | 1182 | 5 | 6 | 11 | 9 |
| غ | 1221 | 6 | 10 | 8 | 11 |
| ط | 1273 | 6 | 6 | 12 | 17 |
| ث | 1414 | 3 | 13 | 10 | 8 |
| آ | 1511 | 3 | 10 | 14 | 6 |
| ء | 1578 | 9 | 6 | 9 | 10 |
| ز | 1599 | 5 | 15 | 11 | 10 |
| ض | 1686 | 4 | 12 | 9 | 13 |
| ص | 2072 | 13 | 14 | 14 | 23 |
| ش | 2124 | 9 | 12 | 23 | 13 |
| ة | 2344 | 7 | 22 | 21 | 12 |
| خ | 2497 | 10 | 13 | 14 | 17 |
| ى | 2595 | 6 | 19 | 15 | 22 |
| ج | 3317 | 14 | 27 | 23 | 32 |
| ح | 4364 | 19 | 31 | 24 | 42 |
| ذ | 4932 | 18 | 33 | 43 | 41 |
| إ | 5108 | 21 | 36 | 43 | 40 |
| د | 5991 | 31 | 48 | 42 | 32 |
| س | 6124 | 24 | 42 | 43 | 43 |
| ق | 7034 | 34 | 49 | 64 | 46 |
| ف | 8747 | 30 | 63 | 83 | 70 |
| أ | 9119 | 40 | 61 | 60 | 67 |
| ع | 9405 | 34 | 74 | 63 | 65 |
| ك | 10497 | 35 | 82 | 91 | 64 |
| ت | 10520 | 36 | 74 | 69 | 82 |
| ب | 11603 | 37 | 85 | 79 | 80 |
| ر | 12627 | 50 | 98 | 108 | 93 |
| ه | 14962 | 43 | 103 | 109 | 122 |
| ي | 22085 | 87 | 171 | 153 | 172 |
| و | 24813 | 91 | 178 | 194 | 174 |
| م | 27071 | 106 | 207 | 195 | 181 |
| ن | 27382 | 115 | 208 | 200 | 207 |
| ل | 38639 | 143 | 272 | 257 | 260 |
| ا | 43875 | 164 | 335 | 293 | 311 |
