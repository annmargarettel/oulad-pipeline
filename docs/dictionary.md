# Data dictionary

Every column of every clean table, plus the validation results table.

> [!NOTE]
> Every count and range below was **measured against the files on the shared volume**,
> not copied from the source's own documentation. Where the source documentation and the
> file disagree, the file wins and the disagreement is called out.

- [Source files](#source-files)
- [Shared conventions](#shared-conventions)
- [Clean tables](#clean-tables)
- [oulad.validation.staging](#ouladvalidationstaging)

---

## Source files

Seven CSVs on the shared R2 volume. All values are quoted.

> [!WARNING]
> **Every missing value in every file is the literal string `?`**, never an empty field
> and never the text `null`. A null count on the raw file returns zero for all of them.

| File | Rows | Columns |
|---|---|---|
| `assessments.csv` | 206 | code_module, code_presentation, id_assessment, assessment_type, date, weight |
| `courses.csv` | 22 | code_module, code_presentation, module_presentation_length |
| `studentAssessment.csv` | 173,912 | id_assessment, id_student, date_submitted, is_banked, score |
| `studentInfo.csv` | 32,593 | code_module, code_presentation, id_student, gender, region, highest_education, imd_band, age_band, num_of_prev_attempts, studied_credits, disability, final_result |
| `studentRegistration.csv` | 32,593 | code_module, code_presentation, id_student, date_registration, date_unregistration |
| `studentVle.csv` | ~10.6 M | code_module, code_presentation, id_student, id_site, date, sum_click |
| `vle.csv` | 6,364 | id_site, code_module, code_presentation, activity_type, week_from, week_to |

> [!CAUTION]
> **Two corrections to earlier versions of this dictionary.**
> 1. The `studentVle.csv` column is `sum_click`, **singular**, confirmed against the file
>    header. Code written against `sum_clicks` will not run.
> 2. `assessments.weight` is **never missing**. An earlier profiling note recorded 14
>    missing weights, all TMA. Every one of the 206 rows carries a numeric weight. What
>    the note saw was `weight = 0`, which appears 56 times and is legitimate.

---

## Shared conventions

| Column | Meaning |
|---|---|
| `code_module` | module code. Seven values, AAA to GGG. |
| `code_presentation` | the term. Four values: 2013B, 2013J, 2014B, 2014J. B is a February start, J is October. Sorts chronologically as plain text, so no date parsing is needed anywhere. |
| `date`, `date_submitted`, `date_registration`, `date_unregistration` | day offsets relative to the presentation start day, which is day 0. **Negative values are normal** and mean "before the course began". |
| `_cleaned_at` | when the clean layer built this row. On every clean table. |

---

## Clean tables

<details open>
<summary><b><code>oulad.clean.student_info</code></b> — 32,593 rows, 28,785 students · Owner: Kinah</summary>

One row per student enrolment in one module presentation.

| Column | Type | Origin | Meaning |
|---|---|---|---|
| `enrolment_key` | string | derived | MD5 of `code_module\|code_presentation\|id_student`. A single-column stand-in for the composite key. Unique. |
| `code_module` | string | source | AAA to GGG. Part of the composite key. |
| `code_presentation` | string | source | 2013B, 2013J, 2014B, 2014J. Part of the composite key. |
| `id_student` | int | source | 3,733 to 2,716,795. 28,785 distinct. **Repeats across presentations**, so not a primary key on its own. |
| `gender` | string | source | M 17,875, F 14,718. |
| `region` | string | source | 13 values, East Anglian Region to Yorkshire Region. Never missing. |
| `highest_education` | string | source | 5 values. Source casing preserved, including the lowercase "quals" in "No Formal quals". |
| `imd_band` | string | source, cleaned | Deprivation decile band, `0-10%` (most deprived) to `90-100%`. NULL means not known, 1,111 rows. |
| `imd_band_raw` | string | lineage | `imd_band` exactly as the file wrote it, including `?` and `10-20`. Keeps every cleaning decision auditable. |
| `age_band` | string | source | `0-35` 22,944, `35-55` 9,433, `55<=` 216. The `55<=` label is the source's and means 55 and over. |
| `num_of_prev_attempts` | int | source | 0 to 6. 87.2% are 0. |
| `studied_credits` | int | source | 30 to 655, median 60, 99th percentile 240. Values above 240 are real, not typos. |
| `disability` | string | source | Y 3,164 (9.71%), N 29,429. |
| `final_result` | string | source | Pass 12,361 · Withdrawn 10,156 · Fail 7,052 · Distinction 3,024. The outcome measure for Q1 and the cohort definition for Q2. |
| `imd_band_is_missing` | boolean | derived | TRUE where the source wrote `?`. Lets a tile separate the unknown group without testing for NULL. |
| `imd_decile_low` | int | derived | The band's lower bound, 0 to 90. Exists so bands sort numerically instead of alphabetically. |
| `age_bands_seen_for_student` | int | derived | Distinct `age_band` values for this student. 1 for everyone except 72 students. **This is what makes the `dim_student` fanout visible.** |
| `credit_load_band` | string | derived | `60 or less`, `61-120`, `121-240`, `over 240 (flagged outlier)`. The strongest single predictor of withdrawal in this table. |
| `is_withdrawn` | boolean | derived | `final_result = 'Withdrawn'`. Defined once so every tile agrees. |
| `_cleaned_at` | timestamp | lineage | |

**Two cleaning rules on `imd_band`.** The source encodes "not known" as `?`, a present,
non-null, non-blank value, so a completeness check written the obvious way passes the
column and ships 1,111 sentinel values into the mart. The source also writes one band as
`10-20` with no percent sign while the other nine carry one, 3,516 rows; left alone it
becomes its own category and puts a hole in the middle of every deprivation chart.
Normalised to `10-20%`. **This is the only value anywhere in the clean layer that is
deliberately rewritten**, and `imd_band_raw` keeps the original.

</details>

<details>
<summary><b><code>oulad.clean.courses</code></b> — 22 rows · Owner: Garet</summary>

| Column | Type | Meaning |
|---|---|---|
| `code_module` | string | AAA to GGG |
| `code_presentation` | string | 2013B, 2013J, 2014B, 2014J |
| `module_presentation_length` | int | duration in days. 234 to 269, average 255. |
| `_cleaned_at` | timestamp | |

Only the **pair** is unique. `code_module` repeats across terms, `code_presentation`
repeats across modules, and two modules can legitimately run the same number of days.
That is the check, not the columns.

</details>

<details>
<summary><b><code>oulad.clean.assessments</code></b> — 206 rows · Owner: Mia</summary>

| Column | Type | Meaning |
|---|---|---|
| `id_assessment` | int | primary key, 206 distinct |
| `code_module` | string | |
| `code_presentation` | string | |
| `assessment_type` | string | TMA (tutor marked), CMA (computer marked), Exam |
| `date` | int | deadline day. NULL on 11 rows, **all of them Exam**, which is structural: final exam dates are often unset. |
| `weight` | double | 0 to 100, 24 distinct values. **Never missing.** `weight = 0` appears 56 times (10 TMA, 46 CMA) and is legitimate; module GGG accounts for 27 and runs all its continuous assessment at zero weight. |
| `_cleaned_at` | timestamp | |

</details>

<details>
<summary><b><code>oulad.clean.student_assessment</code></b> — 173,912 rows · Owner: Mia</summary>

| Column | Type | Meaning |
|---|---|---|
| `id_assessment` | int | FK to `assessments` |
| `id_student` | int | |
| `date_submitted` | int | day submitted, relative to presentation start |
| `is_banked` | int | 1 if the score was transferred from a previous attempt, else 0 |
| `score` | double | 0 to 100. NULL on 173 rows. |
| `_cleaned_at` | timestamp | |

> [!IMPORTANT]
> A NULL `score` means the work was **not submitted**. That is a real state, not
> corruption. Do not `COALESCE` it to zero: a non-submission and a zero mark are
> different facts and averaging over them gives a different answer.

</details>

<details>
<summary><b><code>oulad.clean.student_registration</code></b> — 32,593 rows · Owner: Charlene</summary>

| Column | Type | Meaning |
|---|---|---|
| `code_module` | string | |
| `code_presentation` | string | |
| `id_student` | int | |
| `date_registration` | int | day the student registered. Negative means pre-registration. NULL on 45 rows. |
| `date_unregistration` | int | day the student unregistered. **NULL on 22,521 rows (69.10%), and that is the normal case**: it means they never unregistered. 10,072 rows carry a value. |
| `_cleaned_at` | timestamp | |

> [!IMPORTANT]
> Do not fill `date_unregistration`. Setting it to 0 turns every completing student into
> someone who quit on day zero.

</details>

<details>
<summary><b><code>oulad.clean.student_vle</code></b> and its two successors · Owner: Crizza</summary>

`06_clean_student_vle.sql` produces **three** tables. Know which one you are reading.

**`student_vle`** — aggregated, one row per student per resource per day.

| Column | Type | Meaning |
|---|---|---|
| `code_module` | string | |
| `code_presentation` | string | |
| `id_student` | int | |
| `id_site` | int | FK to `vle` |
| `date` | int | day of the interaction. Negative is normal. |
| `sum_click` | int | **`SUM()` over the raw rows for this key**, not a raw value |
| `original_record_count` | int | how many raw rows collapsed into this one. Usually 1, up to 7. |

**`student_vle_with_flags`** — the above plus three label columns:
`click_outlier_flag`, `date_outlier_flag`, `quality_flag`.

**`student_vle_final`** — the flagged table filtered to `sum_click <= 5000`, with three
booleans: `is_pre_course_access`, `is_late_access`, `is_high_click_outlier`.

> [!CAUTION]
> Two open problems with this script, tracked as [decisions.md](decisions.md) O11.
>
> 1. **`student_vle_final` deletes rows.** `WHERE sum_click <= 5000` removes the extreme
>    outliers rather than flagging them, which is the one place in the pipeline that
>    breaks "flag, never delete".
> 2. **`extreme_click_outlier` is unreachable.** The CASE tests `sum_click > 1000` before
>    `sum_click > 5000`, so the first branch catches everything and the second never
>    fires. The rows that get dropped by the filter are therefore never labelled first.

</details>

<details>
<summary><b><code>oulad.clean.vle</code></b> — 6,364 rows · Owner: Anje</summary>

| Column | Type | Meaning |
|---|---|---|
| `id_site` | int | primary key, 6,364 distinct |
| `code_module` | string | |
| `code_presentation` | string | |
| `activity_type` | string | 20 distinct values: forumng, resource, oucontent, url, quiz, page and others. Lower-cased. |
| `week_from` | int | first week the resource is planned to be used. NULL on 5,243 rows. |
| `week_to` | int | last week. NULL on 5,243 rows. |
| `_cleaned_at` | timestamp | |

82.39% of resources have no week range, and that is **expected behaviour rather than
missing data**: homepages and general forums are open for the whole course instead of a
specific week range.

</details>

---

## `oulad.validation.staging`

One row per data quality check per run, for the whole clean layer.

> [!NOTE]
> Rebuilt by a rerun. Never put anything in this table that a rerun cannot reproduce.

| Column | Type | Meaning |
|---|---|---|
| `executed_at` | timestamp | when this run happened. Drives the "last checked" tile. |
| `layer` | string | raw, clean or mart |
| `table_name` | string | the clean table the check is about. Also the key each owner deletes on. |
| `check_id` | string | `ASM_01`, `CRS_01` and so on. Unique across the table, stable enough to name in a meeting. |
| `check_name` | string | snake_case name |
| `check_type` | string | NULL, ACCEPTED VALUES, RANGE, SCHEMA, UNIQUE, REFERENTIAL INTEGRITY, VOLUME |
| `dq_dimension` | string | Completeness, Validity, Uniqueness, Consistency, Accuracy, Referential integrity |
| `column_name` | string | the column or key under test |
| `expectation` | string | what acceptable looks like, in a sentence |
| `threshold` | decimal(5,2) | how much failure is allowed, as a percentage |
| `severity` | string | WARN or FAIL. What the check **becomes** if it breaches its threshold. |
| `total_count` | bigint | rows the check looked at |
| `fail_count` | bigint | rows that did not meet the expectation |
| `fail_pct` | decimal(9,4) | |
| `status` | string | PASS, WARN or FAIL. What the check **is** on this run. |
| `business_question` | string | which question this check protects |
| `owner` | string | who investigates |

`severity` and `status` are different things and the distinction carries weight. Severity
is the contract, status is the result. See [validation.md](validation.md).
