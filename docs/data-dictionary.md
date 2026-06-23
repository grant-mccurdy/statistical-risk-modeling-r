# Data Dictionary

This project uses two public-safe CSV layers:

- `data/raw/synthetic_education_assessment_long.csv`: assessment-window extract
- `data/processed/education_readiness_risk.csv`: modeling table used by the R
  analysis

The extract uses simulated identifiers and generalized score/readiness behavior
from a bootstrapped assessment workflow. It is not a real student-record
release.

## Modeling Table

`data/processed/education_readiness_risk.csv` contains one row per consecutive
assessment transition. Current-window fields are used to predict whether the
next assessment window requires support review.

| Field | Meaning |
| --- | --- |
| `school_year` | Academic year for the current assessment window |
| `school_year_offset` | Zero-based year index in the assessment sequence |
| `sis_user_id` | Simulated student identifier |
| `grade_level` | Current grade level |
| `course_id` | Simulated course identifier |
| `course_name` | Course name used for analytics context |
| `course_track` | Course track such as regular, honors, AP, or beyond-core |
| `section_id` | Simulated section identifier |
| `assessment_window` | Current window: beginning-of-year or end-of-year |
| `sequence_index` | Ordered assessment-window index |
| `attendance_category` | Generalized attendance-risk category |
| `attendance_probability` | Simulated probability of assessment participation |
| `score` | Current observed assessment score |
| `posterior_readiness_after` | Current readiness estimate after the assessment |
| `is_present_bool` | Whether the current assessment was completed |
| `next_sequence_index` | Next assessment-window index for the same simulated student |
| `next_assessment_window` | Next assessment window |
| `next_score` | Next observed assessment score |
| `next_present` | Whether the next assessment was completed |
| `next_readiness` | Next readiness estimate |
| `support_risk_next` | Primary binary target: next score below 50 or next nonparticipation |
| `support_risk_next_45` | Sensitivity target using a lower score cut point of 45 |
| `current_absent` | Current-window nonparticipation indicator |
| `current_readiness_missing` | Indicator that current readiness was imputed |
| `current_readiness` | Modeling readiness value after imputation |
| `current_readiness_z` | Standardized current readiness |
| `sequence_z` | Standardized sequence index |
| `readiness_below_45` | Piecewise shortfall below readiness 45 |
| `readiness_45_to_60` | Piecewise readiness segment from 45 to 60 |
| `readiness_above_60` | Piecewise readiness above 60 |
| `semester_sin`, `semester_cos` | Candidate periodic timing terms |
| `annual_sin`, `annual_cos` | Candidate recurring assessment-cycle terms |

## Modeling Target

The primary target is:

```text
support_risk_next = next_score < 50 OR next_present is false
```

This definition creates a decision-support task: prioritize transitions for
human review before the next assessment window. It is not intended for automated
student decisions.
