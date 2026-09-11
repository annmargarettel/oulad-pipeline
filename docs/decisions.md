# Decisions

Each entry records **what we chose**, **the alternative we rejected**, and **what would
change our minds**. An entry with no "changes if" is usually a decision nobody has really
made yet.

- [Architecture](#architecture) · D1–D4
- [Cleaning](#cleaning) · D5–D11
- [Validation](#validation) · D12–D17
- [Model](#model) · D18–D21
- [From the 11 September consultation](#from-the-11-september-consultation) · M1–M10
- [Change log](#change-log)
- [Open](#open)

---

## Architecture

### D1. Every raw column lands as STRING
**Rejected:** letting the reader infer types, or passing an explicit `schema =>`.

Inference and explicit schemas both hide the mess. A value that will not cast becomes
NULL at ingest, before anything can see it, so the clean layer finds a tidy NULL and the
schema checks report zero failures forever. They are not passing, they are blind. With
STRING raw, a bad value arrives intact, `TRY_CAST` turns it into a NULL that gets counted,
and the check fires.

**Changes if:** the source ever ships a schema file we can trust.

### D2. `TRY_CAST` everywhere, never bare `CAST`
**Rejected:** `CAST`, and letting the load fail loudly.

A failed load tells you the file is bad. A flagged NULL tells you which row and which
column, and the second is what you can act on before a meeting. This was the subject of
PR #15 and was reviewed again on 11 Sep — see [M1](#m1-the-cast-guidance-was-case-specific-try_cast-stands).

**Changes if:** we move to a system where a partial load is worse than no load.

### D3. Flag, never delete
**Rejected:** dropping or quarantining bad rows.

Rows in equals rows out at every layer, proven by a volume check on every table every
run. The mart filters on the flag, so the decision stays visible instead of buried in a
`WHERE` clause somebody has to go and find.

Two findings made this concrete rather than theoretical. The 1,111 enrolments with an
unknown deprivation band withdraw at **21.24%** against **31.51%** for reported bands and
take distinction at nearly twice the rate; dropping them for a tidy chart would have
reported a withdrawal rate higher than the truth. The 116 enrolments above 240 credits
look like typos and withdraw at **59.48%** against **31.06%**; they are the most at-risk
cohort in the file.

> [!WARNING]
> `student_vle` is the one place this does not hold. See [D19](#d19-student_vle-is-aggregated-in-the-clean-layer) and [O11](#open).

### D4. One catalog, `oulad`, with schemas per layer
**Rejected:** a catalog per person, or per week.

Work done in a personal catalog cannot be read by a teammate's script. This cost us a
round of rework when the `student_info` checks were written against `week07.silver` while
everything else was in `oulad.clean`.

---

## Cleaning

### D5. The missing value sentinel, handled explicitly everywhere
**Rejected:** relying on `TRY_CAST` to turn `?` into NULL by accident.

Every missing value in all seven files is a literal question mark, roughly 29,000 of them
across six columns. `TRY_CAST` does produce the right NULL without being asked, which is
exactly why this went unnoticed. But the validation layer has to know which NULLs were
sentinels: without the explicit `NULLIF(NULLIF(TRIM(col),''),'?')`, the schema check on
`student_registration` alone reports **22,560 failures on a perfectly clean load**, and
the dashboard shows a red light nobody can clear.

**Changes if:** a future extract uses a different sentinel. Then this becomes a list
rather than one value.

### D6. A bad value is kept, not nulled
**Rejected:** mapping unrecognised values to NULL "to be tidy".

Three separate cleaning scripts were doing this: an unknown `assessment_type` became
NULL, a wrong-length `code_module` became NULL. Each one makes the accepted-values check
downstream count zero failures and report PASS permanently. The bad value did not go
away, it stopped being visible.

**Changes if:** never. This is the same class of mistake as D1, one layer down.

### D7. Turn `?` into NULL in `imd_band`, keep the original in `imd_band_raw`
**Rejected:** leaving `?` in place, or overwriting it without keeping the original.

Leaving it means every downstream filter has to know the sentinel. Dropping the original
makes the cleaning unauditable. Keeping both costs one column.

### D8. Normalise `10-20` to `10-20%`
**Rejected:** leaving the label as the source wrote it.

It is the same band as the other nine and has to sort and join with them. This is the
only value in the clean layer that is rewritten rather than left alone, and it is flagged
too, so the change is visible in the check results.

**Changes if:** `10-20` turns out to mean something different from `10-20%`.

### D9. Preserve source category labels exactly, including "No Formal quals"
**Rejected:** title-casing them for tidiness.

Silently renaming a category breaks joins against anyone else's copy of the same file and
makes our table disagree with the source. Noted as an inconsistency instead of corrected.

**Changes if:** the whole team agrees a mapping table.

### D10. One type per concept across all seven tables
**Rejected:** each owner picking types for their own table.

`id_student` was INT in one table and BIGINT in two others. Spark widens silently, so
nothing breaks loudly, but every join carries an implicit cast and the schema stops being
a description of the data.

### D11. No `clean_` prefix on clean table names
**Rejected:** keeping `clean_assessments` and `clean_student_assessment`.

**Resolved 11 Sep.** Five of the seven clean tables already had no prefix — `courses`,
`student_info`, `student_registration`, `student_vle`, `vle` — and `03_mart/` creates
`dim_student` rather than `mart_dim_student`, so the repo's own convention is that the
schema carries the layer and the table name does not. Two renames rather than four.

This was not cosmetic. The half-applied version of it produced a
`table or view not found` in the 11 Sep call, and the merged `02_validate_staging.sql`
was left referencing **both** spellings, so it could not run.

---

## Validation

### D12. One results table, `oulad.validation.staging`
**Rejected:** a results table per person, which is what we had.

We were writing to four different destinations, including one in a different catalog, and
one section wrote no results at all. No dashboard can read that.

"staging" is this repo's word for the clean layer, so the siblings are
`oulad.validation.intermediate` and `.marts`, matching the files in `05_validation/`.

### D13. Scoped `DELETE`, never `TRUNCATE`
**Rejected:** `TRUNCATE TABLE` before each run, which one section was doing.

On a shared table `TRUNCATE` erases the other six owners' rows, so whoever ran last would
be the only table with results, and nothing would look wrong. Each owner deletes only
`WHERE table_name = '<mine>'`, so the seven sections run in any order, by different
people, on different days, with no coordination.

### D14. One status rule, and `severity` is separate from `status`
**Rejected:** the two different rules we had, one of which ignored severity.

```
fail_count = 0                  ->  PASS
fail_pct > threshold            ->  the check's own severity
fail_pct <= threshold, but > 0  ->  WARN, surfaced but not escalated
```

Severity is the contract: what this check *becomes* if it breaches. Status is the result:
what it *is* today. One earlier version escalated everything over threshold to FAIL,
which made the severity column decorative, and another used high/medium/low, which
neither rule read.

### D15. Full-row duplicate checks use `COUNT` over `SELECT DISTINCT`
**Rejected:** the shorter `COUNT(*) - COUNT(DISTINCT a, b, c, ...)`.

> [!CAUTION]
> `COUNT(DISTINCT ...)` in Spark drops any row where **any** argument is NULL. The moment
> the cleaning turned `imd_band`'s `?` into a proper NULL, that check reported 1,111
> duplicates that do not exist. It passed against raw and only broke after the cleaning
> worked.

The short form is still correct for composite keys where every column is separately
proven NOT NULL, which is why the key checks still use it. On `student_registration`,
where `date_unregistration` is NULL on 69% of rows, the short form would call two thirds
of the table duplicates.

This is not a preference. The short form is **wrong** for any nullable column set.

### D16. Referential integrity joins clean to clean
**Rejected:** joining the clean child to the raw parent, which is what we had.

Comparing trimmed, upper-cased values against untrimmed raw values works only while the
source file happens to be tidy, and invents orphans the moment it is not.

### D17. Checks live in the validation layer, not inside the cleaning scripts
**Rejected:** each cleaning script ending with its own checks.

A cleaning script that also validates cannot be rerun without rewriting results, and the
two concerns have different owners and different cadences.

---

## Model

### D18. Collapse to one row per student with "most recent presentation wins"
**Rejected:** a slowly changing dimension with one row per student per state.

An SCD is the textbook answer and is more than this project needs. The 72 affected
students are flagged, so promoting to an SCD later is a one-query change.

**Changes if:** a question needs a student's state as at a past date.

### D19. `student_vle` is aggregated in the clean layer
**Rejected:** aggregating in the mart, or asserting the grain and failing.

The source has 23.88% duplicate rows on the documented student/site/module/presentation/
date key. `06_clean_student_vle.sql` collapses them with `SUM(sum_click) GROUP BY` and
keeps `original_record_count` so the evidence survives.

This was originally proposed for the mart, on the grounds that the clean layer promises
rows in equals rows out. Doing it in clean is defensible — every downstream reader gets
the right grain without having to know it — but it has a price, and the price is that two
checks written under the old assumption now measure the wrong thing. Recorded as
[O13](#open), not changed.

**Changes if:** we decide the clean layer's row-count promise matters more than
downstream convenience, in which case the `GROUP BY` moves to `06_fact_vle_interactions.sql`.

### D20. `dim_student` carries no outcome columns
**Rejected:** putting `final_result`, `studied_credits` and `num_of_prev_attempts` on the
student dimension because they sit in the same source file.

Those three describe one enrolment, not one person. A student can pass BBB and withdraw
from DDD, so an outcome on a per-student dimension is a lie for one of the two.

### D21. Two fact tables, not one
**Rejected:** one wide fact table.

`sum_click` and `score` are measures at two different grains. Forcing both into one table
multiplies clicks by assessments and inflates every total.

---

## From the 11 September consultation

Recorded from the session with Sir Hans and the team. The audio is rough in places, so
anything marked **[confirm]** is a reading of a passage rather than a clean quote.

### M1. The `CAST` guidance was case-specific. `TRY_CAST` stands.
The point made was that in production you generally want a script to **error**, so the
load does not complete and dirty rows never reach a table someone else queries.
Troubleshooting an error beats another user reading a table without knowing part of it is
wrong. The water analogy: you only promote water that meets the standard.

That is sound, and it was about one specific case rather than a blanket rule. Our own
correction had already gone the other way — PR #15 changed `CAST` to `TRY_CAST`
deliberately — and the reason holds here: we pair `TRY_CAST` with **FAIL-severity checks**,
so a bad value still stops the mart, just one step later and with the row number attached.

**No change to the code.** [D2](#d2-try_cast-everywhere-never-bare-cast) stands.

### M2. Comments say what the code does. Reasoning goes in documentation.
The scripts were called bloated, and they were. Comments are a short explanation so a
reader can follow a block. Design rationale, overviews and the "why" belong in `docs/` —
which is what these files are for. The exception is a comment that stops someone
reintroducing a bug, such as the NULL-safety note above `INF_20`.

### M3. Notebooks instead of flat `.sql` files
A `.sql` file runs top to bottom, so an error anywhere tells you the script failed but not
which statement. One cell per script makes the failure point obvious, and markdown cells
carry commentary better than `--` ever will. We lost real time in the call to exactly
this: an error that turned out to be a table-name mismatch several hundred lines down.

**Adopted.** `05_validation/03_validate_intermediate.ipynb` is the first one.

### M4. `CREATE TABLE IF NOT EXISTS` over `CREATE OR REPLACE`, where it matters
`CREATE OR REPLACE` affects the Delta version history on the table. The verdict was that
version history is not a big deal for us right now, so this is a soft preference rather
than a rule. Results tables rebuilt every run are the clear exception and stay as replace.

### M5. `02_validate_sources.sql` dropped, validation files renumbered
Source-level validation is what the profiling script already does, so the separate file
was redundant.

| Was | Now |
|---|---|
| `02_validate_sources.sql` | removed |
| `03_validate_staging.sql` | `02_validate_staging.sql` |
| `04_validate_intermediate.sql` | `03_validate_intermediate.ipynb` |

**Done.**

### M6. Profiling is dynamic and lives in the validation folder
`01_profile_source_data.sql` drives off `oulad.information_schema.columns`, builds the
profiling SQL as a string and runs it with `EXECUTE IMMEDIATE`, so it fills itself in
across every table rather than being hand-written per column. The first version was
hand-written and reached about 700 lines.

Per column it returns: `total_rows`, `null_count`, `null_percentage`, `distinct_count`,
`distinct_percentage`, `min_value`, `max_value`, `most_common_value`.

> [!TIP]
> **Min and max only mean something on numeric columns.** On a string column you get `A`
> and `Z` and learn nothing. And on this dataset `null_count` reads 0 everywhere, because
> the missing values are `?` — **`most_common_value` is the column that exposes them.**

### M7. Everyone loads every table
Validation could not run in the call because not everyone had all the clean tables in
their own workspace. Each person now loads all seven so anyone can test end to end.

### M8. Pull from `main`, test in `staging`, push finished code to `main`
Pulling from `staging` brings down everybody's in-progress drafts, which is what caused
the push conflicts.

### M9. Clean table naming
Resolved in favour of dropping the prefix. See [D11](#d11-no-clean_-prefix-on-clean-table-names).

### M10. Define granularity per table, then test uniqueness on exactly those columns
For each table, identify which columns determine what one row represents. The uniqueness
check tests that combination and nothing else. A uniqueness test failing on the wrong
combination is not a data problem, it is a wrong test.

| Fact | One row is |
|---|---|
| `fact_assessments` | one student's submission for one assessment |
| `fact_vle_interactions` | one student, one resource, one day |

On `student_vle` it was suggested that repeats are fine as long as the site and activity
type differ. That is the right instinct but does not account for the measurement — see
[data-model.md](data-model.md#trap-1-the-student_vle-duplicate-grain).

---

## Change log

What actually changed in the pipeline, in order. Dates are from the repo history and the
Databricks catalog, not from memory.

### 7 September

| | |
|---|---|
| Repo created | `annmargarettel/oulad-pipeline`, scaffolded with the `00_setup` → `07_testing_sandbox` folder structure and five empty `docs/` files |
| Catalog agreed | one catalog `oulad`, schemas `raw`, `clean`, `mart`, `validation`, `bi_visualization`, `dq_visualization` |

### 8 September

| | |
|---|---|
| First tables land | `oulad.raw.student_info`, `oulad.raw.courses`, `oulad.clean.student_info` |
| PR #2 opened | `student_info` cleaning, the first clean script with row-level DQ flags built in |

### 9–10 September

| | |
|---|---|
| `CAST` → `TRY_CAST` | agreed in the huddle and applied, so a bad value becomes a countable NULL instead of killing the load. See [D2](#d2-try_cast-everywhere-never-bare-cast) |
| Quarantine tables removed | flag-never-delete replaces dropping rows. See [D3](#d3-flag-never-delete) |
| One DQ structure agreed | PASS / WARN / FAIL, same shape for every table |

### 11 September

| | |
|---|---|
| PR #2 reworked and merged | DQ flags taken **out** of `04_clean_student_info.sql`, so the clean script cleans and nothing else. The checks moved to the validation layer. See [D17](#d17-checks-live-in-the-validation-layer-not-inside-the-cleaning-scripts) |
| Raw re-read as STRING | every column, `inferSchema => 'false'`, `rescuedDataColumn` on. This is what makes the schema checks capable of failing at all. See [D1](#d1-every-raw-column-lands-as-string) |
| `?` identified as the sentinel | roughly 29,000 missing values across six columns, in every file, none of them SQL NULL. See [D5](#d5-the-missing-value-sentinel-handled-explicitly-everywhere) |
| DQ standardised | four destinations and two different status rules collapsed into one results table, `oulad.validation.staging`, with 104 checks across all seven tables. See [D12](#d12-one-results-table-ouladvalidationstaging) and [D14](#d14-one-status-rule-and-severity-is-separate-from-status) |
| Validation renumbered | `02_validate_sources.sql` dropped as redundant with profiling; `03_validate_staging.sql` → `02_validate_staging.sql`. See [M5](#m5-02_validate_sourcessql-dropped-validation-files-renumbered) |
| Profiling rewritten | hand-written ~700 lines replaced by a dynamic script driven off `information_schema.columns`. See [M6](#m6-profiling-is-dynamic-and-lives-in-the-validation-folder) |
| First notebook | `03_validate_intermediate.ipynb`, one cell per script so a failure points at the cell. See [M3](#m3-notebooks-instead-of-flat-sql-files) |
| Mart built | five dimensions and two facts, `01_dim_student.sql` through `07_fact_assessments.sql` |
| `06_clean_student_vle.sql` written | previously an empty file. Aggregates with `SUM(sum_click) GROUP BY` and keeps `original_record_count`. See [D19](#d19-student_vle-is-aggregated-in-the-clean-layer) |
| Consultation | ten items recorded as [M1–M10](#from-the-11-september-consultation) |
| Documentation | this set, first written |

### Still carrying a defect

These changed something and left something behind. None of them have been fixed; they are
recorded so the next person does not have to rediscover them.

| What | Consequence | Tracked as |
|---|---|---|
| The `clean_` prefix was half-removed | `02_validate_staging.sql` references both spellings, so it cannot run end to end | [O14](#open) |
| `student_vle` began aggregating | `SVL_15` compares row counts across it and will FAIL every run; `SVL_11` counts duplicates on an already-deduplicated table and reads 0 forever | [O13](#open) |
| `student_vle_final` added a filter | `WHERE sum_click <= 5000` deletes rows, and the `CASE` that should label them tests `> 1000` before `> 5000`, so `extreme_click_outlier` never fires | [O11](#open) |

---

## Open

| # | Question | Who decides |
|---|---|---|
| **O11** | `student_vle_final` filters `WHERE sum_click <= 5000`, which **deletes rows**, and its outlier `CASE` tests `> 1000` before `> 5000`, so `extreme_click_outlier` is unreachable and the dropped rows are never labelled first. Both need fixing together. | Crizza |
| **O13** | `SVL_15` compares row counts across a step that now aggregates, so it will FAIL every run. `SVL_11` counts duplicates on a table that is already deduplicated, so it reads 0 forever. Both were written before `06_clean_student_vle.sql` landed. | Crizza and Mia |
| **O14** | `02_validate_staging.sql` references both `oulad.clean.assessments` and `oulad.clean.clean_assessments`, and the same split for `student_assessment`. Only one of each exists, so the file cannot run end to end as committed. | Mia |
| O1 | Thresholds are currently each owner's opinion written down. They should be agreed as a team. | everyone |
| O2 | `oulad.validation.staging` is rebuilt each run, so there is no history. Appending instead of replacing is what lets you answer "when did this start". | Mia |
| O3 | No freshness check exists. Nothing currently notices if the data stops arriving. | Anje |
| O4 | The 85% threshold on `VLE_09` is the one number in the check set that nobody stated. | Anje |
| O5 | The checks are queries someone remembers to run, not a scheduled job. | everyone |
| O7 | Anything that ranks students by risk needs a policy on who sees it and what they do with it. | out of scope for us, but say so out loud |
| O12 | Should the `GROUP BY` sit in `02_clean` or `03_mart`? See [D19](#d19-student_vle-is-aggregated-in-the-clean-layer). | Garet and Crizza |
