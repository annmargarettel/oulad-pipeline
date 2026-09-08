# Kinah, sandbox notes

student_info. Clean layer, data quality and documentation.

## What is in this folder

| File | What it is | Who asked for it |
|---|---|---|
| `01_student_info_25_dq_checks.sql` | 25 checks, one row per check, same shape for every table | Mia and @anjelikamarquez, to reference for their validations |
| `02_student_info_dq_dashboard_tiles.sql` | 9 DQ dashboard tiles, each with its caption in the comment | @ocharlenemae |
| `03_student_info_business_dashboard_tiles.sql` | 8 business tiles, the student_info half | @ocharlenemae |
| `04_student_info_day_zero_risk_gold.sql` | the bonus question, a transparent rubric over day zero columns only | anyone taking the bonus |
| `05_student_info_dim_candidate_fanout_fix.sql` | one row per student, and the fanout it prevents | whoever builds `dim_student` |

Nothing in here writes. Every file is SELECT only, with the `CREATE OR REPLACE`
line noted in the header comment where it would go, so nobody's layer gets
created out from under them.

All of it reads `oulad.clean.student_info`, which arrives with PR #2. That PR is
open pending the bronze validations. Until it merges, point the CTEs at your own
clean table and the logic is unchanged.

## Four things worth knowing about this table

**A null check on this file returns zero and it is lying.** All twelve columns
come back with zero nulls and zero blanks. The source writes "not known" for the
deprivation band as a literal question mark. A question mark is a present value,
so a null check passes it. 1,111 rows, 3.41 percent of the table.

**Those 1,111 rows are not missing at random.** They withdraw 21.24 percent
against 31.51 for reported bands, and take distinction at nearly twice the rate.
Dropping them for a tidy chart would have inflated the withdrawal rate. So they
are flagged, not dropped, and `imd_band_raw` keeps the original value.

**One band is written `10-20` with no percent sign**, 3,516 rows, while the other
nine carry a `%`. Normalised to `10-20%` so the bands sort into one series.

**72 students change `age_band` between presentations.** `SELECT DISTINCT` on the
demographic columns gives 28,857 rows for 28,785 students. Build `dim_student`
off that distinct and every fact row for those 72 joins twice. See file 05.

## And one about the checks themselves

Check 20 first reported 1,111 duplicate rows that do not exist.
`COUNT(DISTINCT a, b, c)` in Spark drops any row where any argument is NULL, so
the moment the cleaning turned that question mark into a real NULL, the check
counted the freshly cleaned rows as duplicates. It passed against raw and only
broke after the cleaning worked. The NULL safe form is a `COUNT` over a
`SELECT DISTINCT` subquery. The comment is left in file 01 so nobody puts it back.

A red light is a claim. It has to be verified like any other.

## Current numbers

32,593 rows in, 32,593 out, 0 deleted.
PASS 27,589 (84.65%), WARN 5,004 (15.35%), REJECT 0.
25 checks: 19 pass, 6 warn, 0 fail. No threshold breached.
