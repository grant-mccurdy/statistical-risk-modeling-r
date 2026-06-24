# Assessment Growth and Section Performance Analytics in R

## Recommendation

This study uses seven years of public-safe BOY/EOY assessment history to build an expected-score baseline for future instructional planning. The decision question is not which historical section requires action; those sections are already in the past. The decision question is which teachers and courses should receive closer review before the next assessment cycle because their historical growth patterns were directionally above or below expectation.

Use **BOY/EOY score gain** as the stakeholder metric: EOY score minus BOY score. Use the model only to set the expected baseline for students with similar starting scores, readiness, attendance, grade level, course track, and school-year context. A positive signal means growth was above expectation; a negative signal means growth was below expectation.

The future-facing review priorities are **TCH-001** for teacher support, **TCH-005** as a teacher bright spot, **Alg 1** for course support, and **Precalc** as a course bright spot. These are review priorities, not personnel ratings.

| Priority | Target | Gap | Evidence |
| --- | --- | --- | --- |
| Teacher support | TCH-001 | -0.17 | 23 historical sections and 229 records |
| Teacher bright spot | TCH-005 | 0.04 | 41 historical sections and 420 records |
| Course support | Alg 1 | -0.34 | 10 historical sections and 93 records |
| Course bright spot | Precalc | +0.10 | 21 historical sections and 216 records |

The gap column is the average observed-minus-expected BOY/EOY gain. The generated CSV also keeps the reliability-weighted review signal used to rank recurring patterns.

<!-- PDF_PAGE_BREAK -->

## Approach and Rationale

The analysis includes 1,737 paired BOY/EOY records across 174 historical section-year groups and 5 simulated teachers. The mean BOY score is 48.5, the mean EOY score is 54.2, and the mean raw gain is 5.72 points.

The selected baseline is **EOY readiness model**, a Linear model using the Predicted EOY target. The model search tested 13 candidates across linear, interaction, GAM, random-forest, gradient-boosting, and leakage-check specifications.

The model's holdout expected-gain R-squared is **0.180**, while its holdout EOY R-squared is **0.947**. This difference is expected: BOY score explains much of final EOY score, but year-over-year gain is noisier after the starting score is removed. That is why the report aggregates signals at the teacher and course level instead of acting on individual predictions.

The operating baseline intentionally excludes teacher IDs, course IDs, and section IDs. Including those IDs would make the prediction slightly different, but it would also subtract away the persistent teacher and course patterns this study is designed to surface for future review.

## Direct Answers

1. The main metric is BOY/EOY improvement: end-of-year score minus beginning-of-year score for the same public-safe student record.
2. The average raw gain is 5.72 points across 1,737 paired records.
3. The strongest baseline predicts EOY score and converts it to expected gain; holdout EOY R-squared is 0.947 and holdout expected-gain RMSE is 4.400.
4. Historical sections are evidence, not future action targets. The review layer flags 8 historical section-year groups above expected growth and 6 below expected growth, with 155 within expected range.
5. Recommended next-cycle review targets are TCH-001 for teacher support, TCH-005 for teacher bright-spot learning, Alg 1 for course support, and Precalc as a course bright spot.

## Data Audit

The analysis starts from a public-safe assessment extract. A record enters the growth model only when the same public-safe student has valid BOY and EOY scores in the same section and with the same simulated teacher. This keeps the improvement metric tied to one section experience instead of mixing students across sections.

| Measure | Value |
| --- | --- |
| Raw assessment rows | 4,018 |
| BOY/EOY candidate pairs | 2,009 |
| Included paired records | 1,737 |
| Unique public-safe student IDs | 671 |
| Unique section-year groups | 174 |
| Unique simulated teachers | 5 |
| Mean BOY score | 48.5 |
| Mean EOY score | 54.2 |
| Mean BOY/EOY gain | 5.7 |
| Median section paired records | 10 |

<!-- PDF_PAGE_BREAK -->

## Future Review Priorities

The recommendations below are the operational layer of the study. They use all seven years of historical evidence, weighted toward recurring teacher and course patterns. The purpose is to decide what to review before the next cycle, not to treat past sections as current operational units.

| Priority | Target | Gap | Evidence |
| --- | --- | --- | --- |
| Teacher support | TCH-001 | -0.17 | 23 historical sections and 229 records |
| Teacher bright spot | TCH-005 | 0.04 | 41 historical sections and 420 records |
| Course support | Alg 1 | -0.34 | 10 historical sections and 93 records |
| Course bright spot | Precalc | +0.10 | 21 historical sections and 216 records |

The table below shows the historical section evidence behind those priorities. It is intentionally placed after the future priorities because historical sections explain the signal; they are not the action target.

| Priority | Section | Teacher | Course | N | Raw | Expected | Signal |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T support | 26-27 S03 | TCH-001 | Geometry | 9 | 3.27 | 6.43 | -1.50 |
| T support | 30-31 S01 | TCH-001 | Alg 1 | 10 | 3.28 | 6.10 | -1.41 |
| T bright | 27-28 S17 | TCH-005 | AP Calc AB | 11 | 8.79 | 5.74 | 1.60 |
| T bright | 30-31 S19 | TCH-005 | AP Calc AB | 12 | 9.09 | 6.28 | 1.53 |
| C support | 30-31 S01 | TCH-001 | Alg 1 | 10 | 3.28 | 6.10 | -1.41 |
| C support | 27-28 S01 | TCH-001 | Alg 1 | 10 | 5.83 | 7.38 | -0.78 |
| C bright | 29-30 S17 | TCH-003 | Precalc | 11 | 8.77 | 5.79 | 1.56 |
| C bright | 29-30 S18 | TCH-004 | Precalc | 7 | 8.73 | 5.73 | 1.24 |

The full future-priority table is generated as [reports/future_review_priorities.csv](future_review_priorities.csv), and the supporting historical evidence table is generated as [reports/historical_section_evidence.csv](historical_section_evidence.csv).

<!-- PDF_PAGE_BREAK -->

## Raw Section Improvement

The first descriptive layer calculates BOY/EOY score gain inside each historical section-year group and runs a paired-improvement t-test against zero. This answers whether a section improved, but it does not by itself show whether the section improved more than expected for its starting profile.

The table below shows high-signal historical section-year groups from the review layer, with raw BOY/EOY t-test results included for context. The full section t-test table is generated as [reports/section_ttests.csv](section_ttests.csv).

| Section | N | BOY | EOY | Gain | 95% CI | p-value |
| --- | --- | --- | --- | --- | --- | --- |
| 30-31 S06 | 9 | 42.4 | 52.8 | 10.39 | 7.18 to 13.60 | <0.001 |
| 27-28 S17 | 11 | 43.9 | 52.6 | 8.79 | 5.37 to 12.22 | <0.001 |
| 29-30 S17 | 11 | 37.1 | 45.9 | 8.77 | 5.77 to 11.78 | <0.001 |
| 30-31 S19 | 12 | 37.6 | 46.7 | 9.09 | 6.66 to 11.52 | <0.001 |
| 29-30 S03 | 12 | 41.0 | 49.7 | 8.73 | 6.24 to 11.22 | <0.001 |
| 31-32 S02 | 10 | 40.1 | 49.1 | 9.02 | 6.32 to 11.73 | <0.001 |
| 29-30 S22 | 10 | 41.5 | 49.9 | 8.38 | 4.71 to 12.05 | <0.001 |
| 30-31 S08 | 11 | 35.0 | 44.0 | 9.07 | 4.80 to 13.34 | <0.001 |

![Distribution of BOY/EOY improvement](../figures/growth_distribution.png)

## Expected-Growth Baseline

The adjusted model estimates expected BOY/EOY gain from starting score/readiness and context. This is the key step that makes the analysis more useful than a raw gain ranking: it accounts for floor effects, ceiling effects, attendance context, course track, grade level, and school-year timing.

![Nonparametric and parametric BOY score shape](../figures/baseline_growth_shape.png)

<!-- PDF_PAGE_BREAK -->

**Model family review**

| Family | Representative model | Decision | CV RMSE | Holdout RMSE |
| --- | --- | --- | --- | --- |
| Direct gain baseline | Gain readiness model | Compared | 4.705 | 4.400 |
| Predicted EOY baseline | EOY readiness model | Selected | 4.705 | 4.400 |
| Interaction surface | EOY interaction model | Compared | 4.712 | 4.413 |
| GAM smooths | EOY GAM | Compared | 4.710 | 4.425 |
| Random forest | Gain random forest | Compared | 4.820 | 4.612 |
| Gradient boosting | Gain gradient boosting | Compared | 4.804 | 4.534 |
| Teacher/course ID leakage check | Teacher/course leakage benchmark | Excluded | 4.723 | 4.428 |

| Model | Target | Method | CV RMSE | Gain R2 | EOY R2 | Holdout RMSE |
| --- | --- | --- | --- | --- | --- | --- |
| EOY readiness | Predicted EOY | Linear model | 4.705 | 0.158 | 0.937 | 4.400 |
| Gain readiness | Predicted gain | Linear model | 4.705 | 0.158 | 0.937 | 4.400 |
| EOY GAM | Predicted EOY | GAM | 4.710 | 0.156 | 0.937 | 4.425 |
| Gain GAM | Predicted gain | GAM | 4.710 | 0.156 | 0.937 | 4.425 |
| EOY interaction | Predicted EOY | Linear model | 4.712 | 0.155 | 0.937 | 4.413 |
| Gain interaction | Predicted gain | Linear model | 4.712 | 0.155 | 0.937 | 4.413 |
| Leakage check | Predicted EOY | Linear model | 4.723 | 0.151 | 0.937 | 4.428 |

The compact table shows the strongest candidates by repeated-CV RMSE plus the leakage check. The full model-comparison table is generated as [reports/growth_model_comparison_display.csv](growth_model_comparison_display.csv).

![Expected-growth model comparison](../figures/growth_model_comparison.png)

<!-- PDF_PAGE_BREAK -->

## Historical Section Signals

For each historical section-year group, the adjusted signal is the reliability-weighted average residual: observed gain minus expected gain, weighted toward zero for smaller groups. Positive values mean the section improved more than expected for its starting mix; negative values mean it improved less than expected.

| Section | Teacher | Course | N | Raw | Expected | Signal | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 30-31 S06 | TCH-002 | Alg 2 | 9 | 10.39 | 6.53 | 1.83 | Above |
| 27-28 S17 | TCH-005 | AP Calc AB | 11 | 8.79 | 5.74 | 1.60 | In range |
| 29-30 S17 | TCH-003 | Precalc | 11 | 8.77 | 5.79 | 1.56 | Above |
| 30-31 S19 | TCH-005 | AP Calc AB | 12 | 9.09 | 6.28 | 1.53 | Above |
| 26-27 S13 | TCH-004 | AP Precalc | 10 | 2.27 | 5.23 | -1.48 | Below |
| 25-26 S13 | TCH-003 | Alg 2 H | 11 | 3.99 | 6.71 | -1.42 | In range |
| 30-31 S01 | TCH-001 | Alg 1 | 10 | 3.28 | 6.10 | -1.41 | Below |
| 31-32 S19 | TCH-005 | AP Calc AB | 12 | 2.41 | 4.90 | -1.36 | In range |

![Sections above or below expected growth](../figures/section_adjusted_signals.png)

The full section signal table is generated as [reports/section_adjusted_signals.csv](section_adjusted_signals.csv) so reviewers can inspect all historical section-year groups, not only the highlights shown in the report.

<!-- PDF_PAGE_BREAK -->

## Teacher and Course Signal Summary

Teacher and course summaries aggregate the historical section evidence into future-facing review signals. They are useful for identifying where leaders may want to inspect pacing, curriculum alignment, attendance mix, or practices worth transferring. They should not be treated as standalone teacher quality scores.

| Teacher | Sections | Records | Raw | Expected | Signal |
| --- | --- | --- | --- | --- | --- |
| TCH-005 | 41 | 420 | 4.81 | 4.77 | 0.02 |
| TCH-002 | 40 | 424 | 6.48 | 6.45 | 0.02 |
| TCH-004 | 36 | 313 | 5.11 | 5.10 | 0.01 |
| TCH-003 | 34 | 351 | 5.95 | 5.93 | 0.01 |
| TCH-001 | 23 | 229 | 6.49 | 6.67 | -0.07 |

**Course-level summary**

| Course | Sections | Records | Raw | Expected | Signal |
| --- | --- | --- | --- | --- | --- |
| Precalc | 21 | 216 | 5.73 | 5.63 | 0.05 |
| AP Calc AB | 27 | 294 | 5.21 | 5.14 | 0.04 |
| Alg 2 | 23 | 236 | 6.57 | 6.52 | 0.03 |
| Alg 2 H | 20 | 198 | 6.12 | 6.12 | 0.00 |
| Beyond Core | 6 | 21 | 3.08 | 3.08 | 0.00 |
| Geometry | 31 | 334 | 6.39 | 6.40 | -0.00 |
| AP Precalc | 22 | 214 | 5.10 | 5.14 | -0.02 |
| AP Calc BC | 14 | 131 | 3.86 | 3.97 | -0.04 |
| Alg 1 | 10 | 93 | 6.60 | 6.94 | -0.10 |

![Teacher and course growth summaries](../figures/teacher_course_summary.png)

<!-- PDF_PAGE_BREAK -->

## Diagnostics and Sensitivity

The diagnostics below separate two questions: how well the model predicts the expected baseline, and how much raw section rankings change after adjustment. The EOY R-squared describes baseline strength; the gain R-squared describes how noisy individual growth remains after BOY score is removed.

| Diagnostic | Estimate | Interpretation |
| --- | --- | --- |
| Holdout expected-gain RMSE | 4.400 | Typical holdout prediction error on BOY/EOY gain |
| Holdout expected-gain MAE | 3.514 | Average absolute holdout prediction error |
| Holdout expected-gain R-squared | 0.180 | Share of holdout gain variation explained by the expected-growth model |
| Holdout EOY RMSE | 4.400 | Typical holdout prediction error on final EOY score |
| Holdout EOY R-squared | 0.947 | Share of holdout EOY score variation explained by the baseline |
| Residual mean, all pairs | 0.000 | Near 0 means expected gain is centered overall |
| Residual SD, all pairs | 4.598 | Residual spread used to judge section signal uncertainty |

| Measure | Value |
| --- | --- |
| Included paired records | 1,737 |
| Section-year groups | 174 |
| Groups with at least 5 paired records | 169 |
| Groups with at least 8 paired records | 159 |
| Mean raw BOY/EOY gain | 5.72 |
| Raw-vs-adjusted rank correlation | 0.797 |
| Top-10 overlap, raw vs adjusted ranking | 70.0% |

![Growth model diagnostics](../figures/growth_diagnostics.png)

## Technical Appendix

The expanded model search used the installed R packages below. The operating model excludes persistent teacher, course, and section IDs; the leakage benchmark is reported only to show why those fields should not be used inside the baseline.

| Package | Installed |
| --- | --- |
| mgcv | Available |
| randomForest | Available |
| gbm | Available |

| Metric | Value |
| --- | --- |
| Selected model | EOY readiness model |
| Selected target strategy | Predicted EOY |
| Selected method | Linear model |
| Candidate models tested | 13 |
| Operational candidates tested | 12 |
| Repeated CV folds | 5 |
| Repeated CV repeats | 3 |
| CV expected-gain RMSE | 4.705 |
| CV expected-gain R-squared | 0.158 |
| CV EOY R-squared | 0.937 |
| Holdout expected-gain RMSE | 4.400 |
| Holdout expected-gain R-squared | 0.180 |
| Holdout EOY R-squared | 0.947 |
| Mean raw BOY/EOY gain | 5.72 |

The full selected-model metrics table is generated as [reports/growth_final_metrics.csv](growth_final_metrics.csv).

## Bottom Line

- BOY/EOY improvement is the right stakeholder metric because it is easy to explain and aligned with instructional growth.
- The expected-score baseline should be used to create fairer teacher and course review signals, not to rank individual students or automate personnel decisions.
- Historical sections should be treated as evidence. Future action should focus on recurring teacher and course patterns before the next cycle.
- The model predicts final EOY score strongly, but individual gain remains noisy; aggregate signals and human review are necessary.

## Reproducibility

Rebuild the full evidence packet with `make all`. The pipeline uses the included public-safe extract and no credentials, private files, or network access.

## Public-Safety Statement

This report is an original public-safe portfolio artifact. It excludes private coursework prompts, exams, rubrics, syllabi, lecture transcripts, source datasets, personal data, real student-identifiable records, real personnel records, credentials, and copyrighted source documents.
