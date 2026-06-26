# Executive Brief: Assessment Growth and Section Performance

**Purpose:** use prior completed assessment years to build and validate an expected-growth baseline, then apply it to the latest completed year for teacher, course, and section priority review before the next cycle.

**Action year:** 2024-2025; latest-year paired records: 252; latest-year raw gain: 5.34 points.

**Baseline:** Growth ensemble discovery weighted selected from 31 candidates using direct-growth temporal validation. It improves temporal RMSE by 8.5% and latest-year RMSE by 6.3% versus a naive mean-growth baseline.

**How to read performance:** the model is designed for group-level review rather than individual student forecasting. Individual gain R-squared is 0.115, while aggregate fit is stronger for teacher and course means. Use the baseline to compare group-level actual growth with expected growth.

**Review logic:** observed gain minus expected gain, reviewed by teacher, course, and section with bootstrap intervals, BH-adjusted q-values, flag stability, and mixed-effects shrinkage.

| Decision | Slice | Target | N | Gap | 95% CI | q |
| --- | --- | --- | --- | --- | --- | --- |
| Watch | Section | S19 | 12 | -2.71 | -5.14 to 0.01 | 0.320 |
| Watch | Section | S04 | 9 | -2.55 | -6.74 to 2.41 | 0.505 |
| Watch | Section | S21 | 12 | -2.48 | -4.99 to -0.18 | 0.267 |
| Watch | Section | S16 | 10 | -2.04 | -4.92 to 0.41 | 0.400 |
| Watch | Section | S23 | 9 | -1.78 | -4.28 to 0.68 | 0.434 |
| Watch | Section | S17 | 9 | -1.57 | -5.06 to 1.99 | 0.505 |
| Watch | Section | S05 | 11 | -1.49 | -4.09 to 1.53 | 0.505 |
| Watch | Section | S22 | 10 | -1.46 | -3.54 to 0.91 | 0.505 |

**Appropriate use:** the outputs are review priorities for planning and follow-up, not ratings or automated personnel decisions.
