# Data Profiling to Data Quality Handover (Student Registation)

Serves as the technical contract bridging Bronze layer discovery with downstream transformation logic. Translates column-level profile statistics into actionable Data Quality checks, thresholds, and pipeline enforcement actions required for the handoff into Silver and Gold layers.

---

| Core DQ Check | Field / Target Schema Context | Findings | Silver Layer Rule | Gold Layer Target Schema Rule |
| :--- | :--- | :--- | :--- | :--- |
| **Volume** | `student_registration` Batch Ingest | 32,593 raw records across 7 modules & 4 presentations | **Batch Drift Guard:** Alert if raw row count deviates by > &plusmn;10% vs historical mean | Enforce row-count audit reconciliation against Silver prior to loading `dim_student` |
| **Unique** | `id_student, code_module, code_presentation` | 0 composite duplicates across 32,593 records | **PK Validation:** `REJECT` and isolate composite duplicates to prevent Cartesian joins downstream | Guarantees compound key uniqueness for `dim_demographics` (`PK`) |
| **Null** | Primary Keys: `id_student`, `code_module`, `code_presentation` | 0 missing values (0.00%) | **Strict Mandatory Check:** `REJECT` any record containing `NULL` key values | Guarantees non-null join integrity across all fact tables (`fact_assessments`, `fact_vle_interactions`) |
| **Null** | `date_registration` &rarr; `dim_student` | 45 missing values (0.14%) | **Soft Flag:** Retain rows with `NULL` registration dates and tag `WARN: MISSING_REG_DATE` | Map directly to `dim_student.date_registration`<br>*(Treat `NULL` as unrecorded entry date)* |
| **Null / Logic** | `date_unregistration` &rarr; `dim_student` | 22,521 missing values (69.10%) | **Derived Logic Execution:** Retain `NULL` as completed/retained<br>*(Derive `is_withdrawn = CASE WHEN date_unregistration IS NOT NULL THEN TRUE ELSE FALSE END`)* | Map fields to `dim_student.date_unregistration` and boolean `dim_student.is_withdrawn` |
| **Range** | `date_registration` | Spans -322 to 167 days (~98.5% registered &lt; 0) | **Boundary Validation:** Tag integer values outside `[-365, 120]` with `WARN: OUT_OF_RANGE_REG` | Load clean integers into `dim_student.date_registration` for relative registration window analytics |
| **Accepted Values** | `code_presentation` | 4 distinct codes (`2013B`, `2013J`, `2014B`, `2014J`) | **Format Validation:** `REJECT` values failing pattern `^\d{4}[BJ]$` | Ensures clean FK matches when joining to `dim_module_presentation` |
| **Referential Integrity** | `code_module` & `code_presentation` FKs | Matches `dim_course` and `dim_module_presentation` | Validate FK presence against module and presentation lookup lists | Enforce 100% FK match to `dim_course.code_module` and `dim_module_presentation.(code_module, code_presentation)` |