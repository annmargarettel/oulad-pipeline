# Student Registration Dictionary

The `studentRegistration` table contains information about students who registered for specific module presentations in the Open University Learning Analytics Dataset (OULAD). Each record tracks a student's enrollment timeline for a given course, including when they registered and, if applicable, when they unregistered or withdrew.

---

| Field Name | Variable Description | Sample Inputs |
|---|---|---|
| `code_module` | Identification code for the course/module. | `AAA`, `BBB`, `CCC`, `DDD`, `EEE`, `FFF`, `GGG` |
| `code_presentation` | Identification code for the module presentation/semester. Consists of the year and `B` (starts in February) or `J` (starts in October). | `2013J`, `2014B`, `2014J` |
| `id_student` | Unique identification number for the student. | `11391`, `28400`, `2341817` |
| `date_registration` | Number of days relative to the start date of the module presentation when the student registered:<br>• **Negative (&lt; 0):** Enrolled before the start date.<br>• **Zero (0):** Enrolled on the official start date.<br>• **Positive (> 0):** Enrolled late (after the start date).<br>• **Null/Missing:** Registration date was unrecorded. | `-159`, `-30`, `0`, `12`, `null` |
| `date_unregistration` | Number of days relative to the start date of the module presentation when the student unregistered/withdrew. Missing or `null` indicates the student completed the course or remained registered throughout the presentation. | `-12`, `45`, `205`, `null` |