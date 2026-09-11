# Validation

The 104 checks, what they mean, and the last measured run.

- [What this layer is for](#what-this-layer-is-for)
- [Profiling comes first](#profiling-comes-first)
- [Where results go](#where-results-go)
- [The five things every check declares](#the-five-things-every-check-declares)
- [The status rule](#the-status-rule)
- [Check types and dimensions](#check-types-and-dimensions)
- [Granularity decides the uniqueness check](#granularity-decides-the-uniqueness-check)
- [Coverage](#coverage)
- [Results](#results)
- [Three rules that keep these checks honest](#three-rules-that-keep-these-checks-honest)
- [Two checks worth understanding](#two-checks-worth-understanding)
- [Dashboard](#dashboard)
- [What we would do next](#what-we-would-do-next)

---

## What this layer is for

A reader should be able to answer **"can I trust this data"** in ten seconds, then drill
from overview, to dataset, to check, to the failing rows.

Data quality is not an end-of-pipeline activity. Each check sits at the layer where its
question can actually be answered:

| Layer | The question it answers |
|---|---|
| Raw | Did we receive the data? Does every column cast? Did we lose rows? |
| Clean | Did we clean it correctly? Nulls, domains, ranges, uniqueness, consistency. |
| Mart | Does the business model make sense? Do the keys hold without fanning out? |
| Report | Can users trust what they see? |

---

## Profiling comes first

`05_validation/01_profile_source_data.sql` runs before any check is written. It replaced
the separate source-validation file.

It is **dynamic**: it reads `oulad.information_schema.columns`, builds the profiling SQL
as a string, and runs it with `EXECUTE IMMEDIATE`, so it covers every table and column
without being hand-written. The first version was hand-written and reached about 700
lines.

| Output column | What it tells you |
|---|---|
| `total_rows`, `null_count`, `null_percentage` | how much is missing |
| `distinct_count`, `distinct_percentage` | is this a key, a category, or free text |
| `min_value`, `max_value` | the range |
| `most_common_value` | the mode |

> [!TIP]
> **Read `most_common_value` first on this dataset.** `null_count` reads 0 on every
> column, because the missing values are the literal string `?`. The mode is what exposes
> them. `min` and `max` only mean something on numeric columns — on a string column you
> get `A` and `Z` and learn nothing.

---

## Where results go

One table, `oulad.validation.staging`, one row per check per run. Schema in
[dictionary.md](dictionary.md#ouladvalidationstaging). Written by
`05_validation/02_validate_staging.sql`.

Each section deletes only its own rows and re-inserts:

```sql
DELETE FROM oulad.validation.staging WHERE table_name = 'student_info';
INSERT INTO oulad.validation.staging ...
```

> [!CAUTION]
> Never `TRUNCATE`. See [decisions.md](decisions.md#d13-scoped-delete-never-truncate).

---

## The five things every check declares

Defined before anything breaks, not after:

| Field | Question it answers |
|---|---|
| `expectation` | what are we checking, and what does acceptable look like |
| `threshold` | how much failure is allowed |
| `severity` | WARN or FAIL if it breaches |
| `owner` | who investigates |
| `business_question` | what this check protects |

That last one is the filter for whether a check was worth writing. **A check that protects
nothing did not get written.**

---

## The status rule

```
fail_count = 0                  ->  PASS
fail_pct > threshold            ->  the check's own severity (WARN or FAIL)
fail_pct <= threshold, but > 0  ->  WARN, surfaced but not escalated
```

> [!IMPORTANT]
> **`severity` is the contract, `status` is the result.** Severity says what this check
> *becomes* if it breaches. Status says what it *is* on this run.
>
> A check can find something, sit under its agreed threshold, and correctly read WARN.
> That combination is the whole point of having thresholds, and it is why a 76% pass rate
> can still mean "usable".

---

## Check types and dimensions

| `check_type` | What it mechanically does |
|---|---|
| `NULL` | counts missing values |
| `ACCEPTED VALUES` | counts values outside a known domain |
| `RANGE` | counts values outside a numeric bound |
| `SCHEMA` | counts values in raw that will not cast |
| `UNIQUE` | counts duplicate keys or rows |
| `REFERENTIAL INTEGRITY` | counts orphans |
| `VOLUME` | counts rows or measures lost between layers |

| `dq_dimension` | The promise to the reader it protects |
|---|---|
| Completeness | the value is there |
| Validity | the value is allowed |
| Uniqueness | the grain holds |
| Consistency | the value agrees with itself across rows |
| Accuracy | the value is plausible |
| Referential integrity | the value points at something real |

---

## Granularity decides the uniqueness check

For each table, identify which columns determine the grain — what one row represents. The
uniqueness check then tests that combination and nothing else.

> [!NOTE]
> A uniqueness test failing on the wrong combination is not a data problem, it is a wrong
> test. `id_student` repeating across a fact table is expected; the same student on the
> same resource on the same day is not.

| Table | Columns that define the grain |
|---|---|
| `assessments` | `id_assessment` |
| `courses` | `code_module, code_presentation` |
| `student_assessment` | `id_student, id_assessment` |
| `student_info` | `code_module, code_presentation, id_student` |
| `student_registration` | `code_module, code_presentation, id_student` |
| `student_vle` | `id_student, id_site, code_module, code_presentation, date` |
| `vle` | `id_site` |

`student_vle` holds this grain only **after** the clean layer aggregates. See
[data-model.md](data-model.md#trap-1-the-student_vle-duplicate-grain).

---

## Coverage

**104 checks.** Every table has, at minimum: null checks on its key columns, accepted
values on its coded columns, a uniqueness check on its grain, a schema check against raw,
referential integrity to its parents, and a volume check.

| Table | Checks | Prefix | Owner |
|---|---|---|---|
| `assessments` | 14 | `ASM_` | Mia |
| `courses` | 10 | `CRS_` | Garet |
| `student_assessment` | 11 | `SAS_` | Mia |
| `student_info` | 25 | `INF_` | Kinah |
| `student_registration` | 15 | `REG_` | Charlene |
| `student_vle` | 15 | `SVL_` | Crizza |
| `vle` | 14 | `VLE_` | Anje |

---

## Results

Run against the actual CSVs on the shared volume, 11 Sep 2026. Six tables verified in
full; `student_vle` verified on its header and a 588,132-row sample, because the file is
433 MB.

| Table | Checks | PASS | WARN | FAIL | What flags |
|---|---|---|---|---|---|
| `assessments` | 14 | 13 | 1 | 0 | `weight` never missing, so ASM_08 passes |
| `courses` | 10 | 10 | 0 | 0 | clean |
| `student_assessment` | 11 | 10 | 1 | 0 | 173 unsubmitted scores |
| `student_info` | 25 | 19 | 6 | 0 | 1,111 / 3,516 / 116 / 198 / 152 / 72 |
| `student_registration` | 15 | 11 | 4 | 0 | 45 / 10,072 / 2 / 53 |
| `vle` | 14 | 13 | 1 | 0 | 5,243 resources with no week range |
| **Total (6 verified)** | **89** | **76** | **13** | **0** | |
| `student_vle` | 15 | — | — | — | not re-run since the clean layer began aggregating; `SVL_15` will FAIL, see below |

Anything outside those numbers on a fresh run is either a change in the data or a change
in the code, and is worth looking at rather than waving through.

> [!NOTE]
> The six verified tables were measured **before** `06_clean_student_vle.sql` landed, so
> they are unaffected by it. `student_vle`'s fifteen have not been re-run since, and two
> of them no longer match what the clean layer does. See
> [below](#svl_11-and-svl_15-which-no-longer-match-the-layer-they-check).

<details>
<summary><b>The thirteen that flag, and why none of them escalate</b></summary>

| Check | Count | Why it is tolerated |
|---|---|---|
| `INF_01` imd_band_is_known | 1,111 (3.41%) | Source wrote `?`. Threshold 5%. |
| `INF_10` imd_band_label_format | 3,516 (10.79%) | Source omitted the `%` on one band. Threshold 15%. |
| `INF_14` studied_credits_within_p99 | 116 (0.36%) | Real heavy loads, not typos. Threshold 1%. |
| `INF_15` num_of_prev_attempts_within_tail | 198 (0.61%) | The long tail of repeats. Threshold 1%. |
| `INF_21` age_band_stable_per_student | 152 (0.47%) | 72 students aged into the next bracket. Threshold 1%. |
| `INF_22` one_row_per_student_after_collapse | 72 (0.25%) | The fanout guard. Threshold 1%. |
| `REG_03` date_registration missingness | 45 (0.14%) | Threshold 0.20%. |
| `REG_04` unregistered share | 10,072 (30.9%) | Expected retention band. Threshold 35%. |
| `REG_07` date_registration_within_bounds | 2 | Threshold 0.50%. |
| `REG_13` registration_date_stable | 53 | Threshold 2%. |
| `SAS_07` score_missing | 173 (0.10%) | Unsubmitted work, a real state. |
| `ASM_08` weight_missing | 0 | Passes. |
| `VLE_09` week_range_known | 5,243 (82.39%) | Expected: whole-course resources. Threshold 85%. |

</details>

---

## Three rules that keep these checks honest

### 1. NULL safety

`COUNT(*) - COUNT(DISTINCT a, b, c)` drops any row where **any** argument is NULL, so it
reports missing values as duplicates. Safe only when every column in the key is separately
proven NOT NULL, which is why the composite-key checks still use it. Full-row duplicate
checks use `COUNT` over a `SELECT DISTINCT` subquery, which treats NULL as a value.

> [!CAUTION]
> This is not theoretical. `INF_20` once reported 1,111 duplicate rows that do not exist,
> because the cleaning had just turned `imd_band`'s `?` into a real NULL. The check passed
> against raw and only broke **after** the cleaning worked.
>
> **A red light is a claim. It has to be verified like any other.**

### 2. Schema checks run against raw, and raw is STRING

A cast check against a typed source cannot fail: the bad value was already turned into a
NULL at ingest. These checks only mean something because the raw layer reads every column
as STRING.

They must also exclude the `?` sentinel. Without that exclusion,
`student_registration` alone reports **22,560 failures on a clean load**.

### 3. Referential integrity compares clean to clean

Joining trimmed, upper-cased values against untrimmed raw values works only while the
source file happens to be tidy.

---

## Two checks worth understanding

### `INF_11`, the check that can only pass

It asserts that the literal string `?` never survives into the clean layer. It can only
ever pass, and **that is the point**: it is a regression test proving the `?`-to-NULL rule
actually ran. If someone edits the cleaning query and drops that `CASE` branch, `INF_11`
turns and the dashboard says so before anyone reads a wrong chart.

### `SVL_11` and `SVL_15`, which no longer match the layer they check

> [!WARNING]
> These two checks were written when `student_vle` was expected to keep every raw row.
> `06_clean_student_vle.sql` now aggregates, so both are measuring the wrong thing. This
> is recorded, not fixed. See [decisions.md](decisions.md#open) O13.

| Check | What it does today | What that produces |
|---|---|---|
| `SVL_11` `source_grain_duplicate_rate` | counts duplicate grain keys on `oulad.clean.student_vle` | Clean is deduplicated by the `GROUP BY`, so this reads **0 on every run whatever the source does**. It reports PASS and tells you nothing. Its expectation text still says "mart must aggregate", which stopped being true when the clean layer took that job. |
| `SVL_15` `clean_row_count_equals_raw` | compares raw row count to clean row count | Clean holds fewer rows **on purpose**, so this will **FAIL every run**, and it will be the only FAIL in the set. |

An aggregating step does not promise to preserve rows. It promises to preserve the
measure. Whoever picks this up will probably want `SVL_15` comparing `SUM(sum_click)`
across the two layers, and `SVL_11` pointed at raw where the duplication is real, but
that is a change for the owner to make, not a change made here.

---

## Dashboard

Seven datasets, all in section 99 of `02_validate_staging.sql`, all covering the whole
clean layer rather than one table.

| Tile | Answers |
|---|---|
| Health header | Can I trust this, in one line, with a timestamp |
| **Coverage** | Which of the seven tables reported at all |
| Pass rate by check type | What kind of thing is breaking |
| Pass rate by dimension | Which promise to the reader is weakest |
| Critical failures | Anything that should stop us shipping |
| What flagged, with headroom | "bad" versus "known and tolerated" |
| Full table | the record |

> [!IMPORTANT]
> The **coverage** tile catches the real failure mode on a team project: a table with no
> results at all, because nobody ran theirs. Seven rows expected. **A missing row is not a
> passing table.**

<details>
<summary><b>Design rules for the DQ page</b></summary>

- Three semantic colours only: PASS `#1B6E45`, WARN `#B26A00`, FAIL `#A62B1F`. They never
  mean anything else on this page, so nobody checks a legend twice.
- Colour is never the only carrier. Every flagged series is also labelled in text.
- No pie or donut charts. Every tile here is a comparison, and comparing bar lengths is
  easier than comparing angles.
- No truncated y axis on a percentage chart.
- Every tile has a one-line caption saying what it means. A chart without one makes the
  reader guess, and they guess generously.
- The critical-failures tile stays on the page when it is empty, showing 0 in grey. An
  absent tile and an empty tile look identical to a reader who does not know the page, and
  only one of them is reassuring.
- For the results table itself, a heat map reads faster than plain numbers: colour the
  cell by value within its column.

</details>

---

## What we would do next

1. Make the checks a scheduled job instead of a query someone remembers to run.
2. Append each run instead of replacing, so "when did this start" and "is quality getting
   worse" become answerable.
3. Add a freshness check. Nothing currently notices if the data stops arriving.
4. Agree the thresholds as a team. Right now a threshold is one person's opinion written
   down.
5. Show the failing rows, not just the count. A count tells you something is wrong; the
   rows tell you what to fix.
