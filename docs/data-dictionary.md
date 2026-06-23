# Data Dictionary

This project uses two public-safe CSV layers:

- `data/raw/synthetic_education_assessment_long.csv`: assessment-window extract
- `data/processed/education_section_growth.csv`: paired BOY/EOY growth table

The extract uses simulated identifiers and generalized score/readiness behavior
from a bootstrapped assessment workflow. It is not a real student-record or
personnel-record release.

## Growth Table

`data/processed/education_section_growth.csv` contains one row per same-student
beginning-of-year to end-of-year pair where both assessments are present and the
section and simulated teacher match across the pair.

| Field | Meaning |
| --- | --- |
| `school_year` | Academic year for the BOY/EOY pair |
| `school_year_offset` | Zero-based school-year index in the assessment sequence |
| `sis_user_id` | Simulated student identifier |
| `grade_level` | Grade level at BOY |
| `course_id` | Simulated course identifier |
| `course_name` | Course name used for analytics context |
| `course_track` | Course track such as regular, honors, AP, or beyond-core |
| `section_id` | Simulated section identifier |
| `section_label` | Public-safe section label |
| `teacher_id` | Simulated teacher identifier |
| `teacher_label` | Public-safe teacher label |
| `attendance_category` | Generalized attendance-risk category |
| `attendance_probability` | Simulated probability of assessment participation |
| `boy_score` | Beginning-of-year assessment score |
| `eoy_score` | End-of-year assessment score |
| `boy_readiness` | Beginning-of-year readiness estimate |
| `eoy_readiness` | End-of-year readiness estimate |
| `score_gain` | Main raw metric: `eoy_score - boy_score` |
| `readiness_gain` | Readiness change: `eoy_readiness - boy_readiness` |
| `boy_score_z` | Standardized BOY score |
| `boy_readiness_z` | Standardized BOY readiness |
| `boy_below_45` | Piecewise BOY score shortfall below 45 |
| `boy_45_to_60` | Piecewise BOY score segment from 45 to 60 |
| `boy_above_60` | Piecewise BOY score above 60 |
| `annual_sin`, `annual_cos` | Candidate recurring assessment-cycle terms |

## Modeling Target

The primary metric is:

```text
score_gain = eoy_score - boy_score
```

The report shows raw BOY/EOY improvement, then estimates expected gain from
starting performance/readiness and context. Section-level signals are based on:

```text
adjusted_growth_signal = observed_gain - expected_gain
```

The signal is intended for instructional review and follow-up analysis, not
automated teacher evaluation or personnel decisions.
