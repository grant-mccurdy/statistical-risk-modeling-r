# Executive Brief: Assessment Growth and Section Performance

**Purpose:** use prior-year BOY/EOY assessment history to build an expected-growth baseline, then review the latest completed year for teacher, course, and section patterns that deserve action before the next cycle.

**Action year:** 2024-2025; latest-year paired records: 252; latest-year raw gain: 5.34 points.

**Baseline:** Growth lasso selected from 31 candidates using direct-growth temporal validation. It improves temporal RMSE by 8.0% and latest-year RMSE by 5.4% versus a naive mean-growth baseline.

**How to read performance:** the model is not a precise forecast of each student's score gain. Individual gain R-squared is 0.097, while aggregate fit is stronger for teacher and course means. Use the baseline to compare group-level actual growth with expected growth, not as a student-level prediction score.

**Decision logic:** observed gain minus expected gain, reviewed by teacher, course, and section with bootstrap intervals and BH-adjusted q-values.

| Decision | Slice | Target | N | Gap | 95% CI | q |
| --- | --- | --- | --- | --- | --- | --- |
| Intervention | Section | S21 | 12 | -2.67 | -5.15 to -0.31 | 0.200 |
| Intervention | Course | Precalc | 40 | -1.41 | -2.88 to -0.25 | 0.040 |
| Bright spot | Course | AP Precalc | 30 | +1.93 | 0.30 to 3.20 | 0.030 |
| Bright spot | Section | S02 | 10 | +2.46 | 0.16 to 4.92 | 0.200 |
| Bright spot | Section | S13 | 9 | +2.90 | 0.98 to 4.80 | 0.040 |

**Guardrail:** the outputs are review priorities, not automatic teacher evaluation, compensation, discipline, or personnel decisions.
