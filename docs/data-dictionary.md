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
| `has_prior_year` | Indicator that the simulated student has a prior-year matched record |
| `prior_boy_score` | Prior-year BOY score, imputed from public-safe peer groups when missing |
| `prior_eoy_score` | Prior-year EOY score, imputed from public-safe peer groups when missing |
| `prior_score_gain` | Prior-year score gain, imputed from public-safe peer groups when missing |
| `prior_boy_readiness` | Prior-year BOY readiness estimate |
| `prior_eoy_readiness` | Prior-year EOY readiness estimate |
| `prior_attendance_probability` | Prior-year assessment participation probability |
| `prior_boy_score_z` | Standardized prior-year BOY score |
| `prior_score_gain_z` | Standardized prior-year score gain |
| `prior_readiness_gain` | Prior-year readiness change |
| `student_prior_year_count` | Number of earlier completed BOY/EOY pairs for the simulated student |
| `student_prior_mean_gain` | Simulated student's mean score gain from earlier completed years |
| `student_prior_gain_sd` | Simulated student's prior gain volatility |
| `student_prior_gain_trend` | Simulated student's prior gain trend by year |
| `student_prior_mean_eoy` | Simulated student's mean prior EOY score |
| `student_prior_attendance_mean` | Simulated student's mean prior attendance probability |
| `student_prior_mean_gain_z` | Standardized multi-year prior student gain |
| `student_prior_gain_sd_z` | Standardized prior student gain volatility |
| `student_prior_gain_trend_z` | Standardized prior student gain trend |
| `student_prior_mean_eoy_z` | Standardized prior student EOY level |
| `student_prior_attendance_mean_z` | Standardized prior student attendance |
| `teacher_prior_mean_gain` | Prior-year mean gain for the simulated teacher context |
| `teacher_prior_gain_sd` | Prior-year gain volatility for the simulated teacher context |
| `teacher_prior_gain_trend` | Prior-year gain trend for the simulated teacher context |
| `course_prior_mean_gain` | Prior-year mean gain for the course context |
| `course_prior_gain_sd` | Prior-year gain volatility for the course context |
| `course_prior_gain_trend` | Prior-year gain trend for the course context |
| `teacher_prior_mean_gain_z` | Standardized teacher prior mean gain |
| `course_prior_mean_gain_z` | Standardized course prior mean gain |
| `section_size` | Number of modeled pairs in the section-year group |
| `section_boy_mean` | Section-year mean BOY score |
| `section_boy_sd` | Section-year BOY-score standard deviation |
| `section_readiness_mean` | Section-year mean BOY readiness |
| `section_attendance_mean` | Section-year mean attendance probability |
| `section_prior_gain_mean` | Section-year mean prior gain |
| `section_pct_below_45` | Share of section-year BOY scores below 45 |
| `section_pct_45_to_60` | Share of section-year BOY scores from 45 to below 60 |
| `section_pct_above_60` | Share of section-year BOY scores at or above 60 |
| `section_pct_at_risk` | Share of section-year records in the at-risk attendance category |
| `section_pct_high_absence` | Share of section-year records in the high-absence category |
| `section_boy_mean_z` | Standardized section-year mean BOY score |
| `section_prior_gain_mean_z` | Standardized section-year mean prior gain |
| `section_student_prior_mean_gain` | Section-year mean of students' multi-year prior gains |
| `section_student_prior_gain_sd` | Section-year mean of students' prior gain volatility |
| `section_student_prior_mean_gain_z` | Standardized section student-history mean |
| `section_student_prior_gain_sd_z` | Standardized section student-history volatility |
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
starting performance, prior-year history, section composition, readiness, and
context. Section-level signals are based on:

```text
adjusted_growth_signal = observed_gain - expected_gain
```

The signal is intended for instructional review and follow-up analysis, not
automated teacher evaluation or personnel decisions.
