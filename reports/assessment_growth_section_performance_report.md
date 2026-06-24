# Assessment Growth and Section Performance Analytics in R

## Recommendation

Use the latest completed assessment year, **2031-2032**, to identify teacher, course, and section patterns that deserve review before the next cycle. The stakeholder metric is **BOY/EOY score gain**: end-of-year score minus beginning-of-year score for the same public-safe student record.

The decision system does not ask whether old sections should be managed retroactively. It asks whether the most recent actual growth was materially above or below an expected-growth baseline trained only on prior years.

The baseline selected for operations is **EOY linear benchmark**. It predicts EOY score and converts that prediction into expected gain. The latest-year EOY baseline R-squared is **0.932** and the latest-year expected-gain RMSE is **4.683** points.

The latest-year gain R-squared is **0.101**. That is not treated as a failure condition because individual score gain is noisy after starting score is removed. The workflow uses the model to create a fair baseline, then makes decisions from aggregate teacher, course, and section residuals with bootstrap uncertainty checks.

| Slice | Priority or watch rows | Total reviewed |
| --- | --- | --- |
| Teachers | 1 | 5 |
| Courses | 4 | 9 |
| Sections | 8 | 24 |

| Decision | Slice | Target | N | Gap | 95% CI | q |
| --- | --- | --- | --- | --- | --- | --- |
| Intervention | Section | S21 | 12 | -2.91 | -5.35 to -0.55 | 0.200 |
| Intervention | Section | S19 | 12 | -2.87 | -5.33 to -0.13 | 0.200 |
| Intervention | Teacher | TCH-005 | 68 | -1.24 | -2.42 to -0.20 | 0.167 |
| Bright spot | Section | S13 | 9 | +2.71 | 0.63 to 4.71 | 0.040 |

The full decision table, including watch-list rows, is generated as [reports/intervention_targets.csv](intervention_targets.csv).

<!-- PDF_PAGE_BREAK -->

## Plain-English Method

1. Build a paired BOY/EOY growth extract from public-safe assessment records.
2. Train candidate expected-growth models on prior years only.
3. Select the operating baseline using leave-one-year-out temporal validation, with repeated CV and bootstrap checks as supporting evidence.
4. Score the latest year against that prior-year baseline.
5. Aggregate observed-minus-expected growth by teacher, course, and section.
6. Flag review targets only when the gap is large enough to matter and the uncertainty check supports follow-up.

This design separates the prediction problem from the decision problem. The prediction model estimates what growth would be expected for a similar starting profile; the review layer asks where actual growth departed from that expectation.

## Direct Answers

1. The analysis covers 1,737 paired BOY/EOY records across 174 section-year groups and 5 public-safe teacher identifiers.
2. The training window is 2025-2026, 2026-2027, 2027-2028, 2028-2029, 2029-2030, 2030-2031; the action year is 2031-2032.
3. The average raw gain across the full extract is 5.72 points; the latest-year raw gain is 5.34 points.
4. The model search tested 13 candidate baselines across parametric, nonlinear, ensemble, and leakage-check families.
5. The selected baseline has temporal expected-gain RMSE 4.684 and latest-year expected-gain RMSE 4.683.
6. Teacher, course, and section flags are audit priorities. They are not automatic personnel ratings or causal claims.

## Data Audit

A record enters the growth model only when the same public-safe student has valid BOY and EOY scores in the same section and teacher context. This keeps improvement tied to one instructional experience instead of mixing students across sections.

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

## Model Selection

The model search used 1,485 prior-year pairs and held out 252 latest-year pairs for action-year evaluation. The primary selection metric is temporal expected-gain RMSE, not latest-year performance, so the system does not choose a model by looking at the year it later reviews.

The best raw temporal RMSE was **4.666** from **EOY GAM**. The selected model's temporal RMSE was **4.684**, a difference of 0.018 points. The simpler model was selected under the pre-specified rule because the difference was not operationally meaningful.

| Family | Representative model | Decision | Temporal RMSE | Latest RMSE |
| --- | --- | --- | --- | --- |
| Direct gain baseline | Gain readiness | Compared | 4.683 | 4.626 |
| Predicted EOY baseline | EOY linear | Selected | 4.684 | 4.683 |
| Interaction surface | EOY interaction | Compared | 4.705 | 4.616 |
| GAM smooths | EOY GAM | Compared | 4.666 | 4.640 |
| Random forest | Gain RF | Compared | 4.730 | 4.806 |
| Gradient boosting | Gain GBM | Compared | 4.704 | 4.839 |
| Teacher/course ID leakage check | Leakage check | Excluded | 4.706 | 4.658 |

| Model | Use | Target | Method | CV RMSE | Temporal RMSE | Latest RMSE | Latest EOY R2 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EOY GAM |  | Predicted EOY | GAM | 4.657 | 4.666 | 4.640 | 0.933 |
| Gain GAM |  | Predicted gain | GAM | 4.657 | 4.666 | 4.640 | 0.933 |
| EOY readiness |  | Predicted EOY | Linear model | 4.651 | 4.683 | 4.626 | 0.934 |
| Gain readiness |  | Predicted gain | Linear model | 4.651 | 4.683 | 4.626 | 0.934 |
| EOY linear | Yes | Predicted EOY | Linear model | 4.675 | 4.684 | 4.683 | 0.932 |
| Gain linear |  | Predicted gain | Linear model | 4.675 | 4.684 | 4.683 | 0.932 |
| Gain GBM |  | Predicted gain | Gradient boosting | 4.750 | 4.704 | 4.839 | 0.928 |
| EOY interaction |  | Predicted EOY | Linear model | 4.651 | 4.705 | 4.616 | 0.934 |
| Leakage check |  | Predicted EOY | Linear model | 4.680 | 4.706 | 4.658 | 0.933 |

Full model artifacts: [reports/growth_model_comparison_display.csv](growth_model_comparison_display.csv), [reports/model_temporal_validation.csv](model_temporal_validation.csv), and [reports/model_bootstrap_validation.csv](model_bootstrap_validation.csv).

![Expected-growth model comparison](../figures/growth_model_comparison.png)

<!-- PDF_PAGE_BREAK -->

## Latest-Year Review Targets

The latest-year review layer compares observed gain with expected gain for 24 section groups. The decision labels use a practical audit threshold: material gap, bootstrap interval direction, and BH-adjusted q-value for multiple-review control.

**Teacher review**

| Target | N | Raw | Expected | Gap | CI | q | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TCH-005 | 68 | 3.81 | 5.05 | -1.24 | -2.42 to -0.20 | 0.167 | Intervention |

**Course review**

| Target | N | Raw | Expected | Gap | CI | q | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AP Calc AB | 49 | 4.31 | 5.47 | -1.16 | -2.58 to 0.05 | 0.180 | Watch |
| Precalc | 40 | 4.99 | 5.95 | -0.95 | -2.32 to 0.19 | 0.180 | Watch |
| Alg 2 H | 26 | 6.18 | 5.40 | +0.78 | -0.79 to 2.70 | 0.514 | Watch |
| AP Precalc | 30 | 6.11 | 4.55 | +1.57 | -0.07 to 2.83 | 0.180 | Watch |

**Section evidence**

| Target | N | Raw | Expected | Gap | CI | q | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S21 | 12 | 3.10 | 6.01 | -2.91 | -5.35 to -0.55 | 0.200 | Intervention |
| S19 | 12 | 2.41 | 5.28 | -2.87 | -5.33 to -0.13 | 0.200 | Intervention |
| S13 | 9 | 7.18 | 4.47 | +2.71 | 0.63 to 4.71 | 0.040 | Bright spot |
| S04 | 9 | 4.01 | 6.45 | -2.44 | -6.53 to 2.42 | 0.582 | Watch |
| S23 | 9 | 1.89 | 3.87 | -1.99 | -4.45 to 0.49 | 0.400 | Watch |
| S16 | 10 | 4.11 | 5.92 | -1.81 | -4.73 to 0.62 | 0.582 | Watch |
| S05 | 11 | 4.00 | 5.28 | -1.28 | -3.86 to 1.69 | 0.686 | Watch |
| S14 | 10 | 4.81 | 5.76 | -0.95 | -3.93 to 2.11 | 0.747 | Watch |

Full review tables: [reports/latest_teacher_review.csv](latest_teacher_review.csv), [reports/latest_course_review.csv](latest_course_review.csv), and [reports/latest_section_review.csv](latest_section_review.csv).

<!-- PDF_PAGE_BREAK -->

## Section Evidence

Raw section improvement is useful for communication, but it is not the final comparison. A section can show positive raw gain and still fall below expected growth if its starting profile suggested a larger increase.

| Section | Course | N | BOY | EOY | Gain | 95% CI | p-value |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S13 | AP Precalc | 9 | 63.5 | 70.7 | 7.18 | 5.20 to 9.16 | <0.001 |
| S02 | Geometry | 10 | 40.1 | 49.1 | 9.02 | 6.32 to 11.73 | <0.001 |
| S11 | AP Precalc | 10 | 69.0 | 74.7 | 5.67 | 1.52 to 9.83 | 0.013 |
| S10 | Alg 2 H | 12 | 63.1 | 70.0 | 6.90 | 3.98 to 9.83 | <0.001 |
| S06 | Alg 2 | 11 | 41.0 | 48.6 | 7.63 | 4.97 to 10.30 | <0.001 |
| S18 | AP Calc AB | 13 | 49.4 | 56.1 | 6.69 | 3.06 to 10.31 | 0.002 |
| S03 | Geometry | 9 | 43.2 | 50.2 | 7.02 | 3.12 to 10.92 | 0.003 |
| S01 | Alg 1 | 13 | 42.1 | 49.2 | 7.13 | 4.19 to 10.08 | <0.001 |

![Distribution of BOY/EOY improvement](../figures/growth_distribution.png)

<!-- PDF_PAGE_BREAK -->

The adjusted section signal is observed gain minus expected gain, reliability-weighted toward zero for smaller sections.

| Section | Teacher | Course | N | Raw | Expected | Signal | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S13 | TCH-004 | AP Precalc | 9 | 7.18 | 4.47 | +1.25 | Above expected |
| S02 | TCH-002 | Geometry | 10 | 9.02 | 6.70 | +1.13 | Within expected range |
| S11 | TCH-004 | AP Precalc | 10 | 5.67 | 3.98 | +0.83 | Within expected range |
| S10 | TCH-003 | Alg 2 H | 12 | 6.90 | 5.44 | +0.78 | Within expected range |
| S16 | TCH-004 | Precalc | 10 | 4.11 | 5.92 | -0.88 | Within expected range |
| S05 | TCH-001 | Geometry | 11 | 4.00 | 5.28 | -0.66 | Within expected range |
| S14 | TCH-003 | Precalc | 10 | 4.81 | 5.76 | -0.46 | Within expected range |
| S22 | TCH-005 | AP Calc BC | 10 | 3.10 | 4.02 | -0.45 | Within expected range |

![Sections above or below expected growth](../figures/section_adjusted_signals.png)

The full section signal table is generated as [reports/section_adjusted_signals.csv](section_adjusted_signals.csv).

<!-- PDF_PAGE_BREAK -->

## Teacher and Course Summaries

These summaries aggregate the latest-year evidence into planning views. They support review conversations about pacing, curriculum alignment, attendance mix, and transferable practices. They should not be read as standalone personnel scores.

| Teacher | Sections | Records | Raw | Expected | Signal |
| --- | --- | --- | --- | --- | --- |
| TCH-004 | 5 | 43 | 5.21 | 4.85 | +0.16 |
| TCH-002 | 5 | 52 | 6.60 | 6.56 | +0.02 |
| TCH-001 | 3 | 33 | 6.06 | 6.02 | +0.01 |
| TCH-003 | 5 | 56 | 5.70 | 5.70 | 0.00 |
| TCH-005 | 6 | 68 | 3.81 | 5.05 | -0.70 |

| Course | Sections | Records | Raw | Expected | Signal |
| --- | --- | --- | --- | --- | --- |
| AP Precalc | 3 | 30 | 6.11 | 4.55 | +0.78 |
| Alg 2 H | 2 | 26 | 6.18 | 5.40 | +0.36 |
| Alg 1 | 1 | 13 | 7.13 | 6.52 | +0.19 |
| Alg 2 | 3 | 33 | 6.57 | 6.54 | +0.01 |
| Geometry | 4 | 39 | 5.99 | 6.13 | -0.08 |
| Beyond Core | 1 | 3 | -0.11 | 4.35 | -0.41 |
| Precalc | 4 | 40 | 4.99 | 5.95 | -0.55 |
| AP Calc BC | 2 | 19 | 2.52 | 3.95 | -0.55 |
| AP Calc AB | 4 | 49 | 4.31 | 5.47 | -0.72 |

![Teacher and course growth summaries](../figures/teacher_course_summary.png)

<!-- PDF_PAGE_BREAK -->

## Diagnostics and Sensitivity

The baseline is strong for final-score expectation and weaker for individual gain variation. That pattern is expected: BOY score explains much of EOY score, while individual improvement contains more unobserved classroom, attendance, and assessment noise.

| Diagnostic | Estimate | Interpretation |
| --- | --- | --- |
| Latest-year expected-gain RMSE | 4.683 | Typical out-of-sample prediction error on latest-year BOY/EOY gain |
| Latest-year expected-gain R-squared | 0.101 | Share of latest-year gain variation explained by the expected-growth model |
| Latest-year EOY R-squared | 0.932 | Share of latest-year EOY score variation explained by the baseline |
| Latest-year residual mean | -0.258 | Near 0 means expected gain is centered in the action year |
| Latest-year residual SD | 4.686 | Latest-year residual spread used for slice uncertainty |

| Metric | Estimate | 95% interval |
| --- | --- | --- |
| Expected-gain RMSE | 4.683 | 4.270 to 5.104 |
| Expected-gain MAE | 3.728 | 3.375 to 4.072 |
| Expected-gain R-squared | 0.101 | -0.007 to 0.186 |
| EOY RMSE | 4.683 | 4.270 to 5.104 |
| EOY R-squared | 0.932 | 0.916 to 0.944 |

| Measure | Value |
| --- | --- |
| Training paired records | 1,485 |
| Latest-year paired records | 252 |
| Latest-year section-year groups | 24 |
| Latest-year mean raw BOY/EOY gain | 5.34 |
| Latest-year raw-vs-adjusted rank correlation | 0.875 |
| Latest-year top-10 overlap, raw vs adjusted ranking | 70.0% |

![Growth model diagnostics](../figures/growth_diagnostics.png)

## Technical Appendix

The operating model excludes teacher IDs, course IDs, and section IDs. A leakage benchmark is reported only to show what would happen if persistent IDs were included in the baseline; it is not used for review because it would absorb the teacher/course patterns the decision layer is designed to detect.

| Package | Installed |
| --- | --- |
| mgcv | Available |
| randomForest | Available |
| gbm | Available |

| Metric | Value |
| --- | --- |
| Selected model | EOY linear benchmark |
| Selected target strategy | Predicted EOY |
| Selected method | Linear model |
| Selection rule | Lowest temporal-validation expected-gain RMSE among operational candidates; ties within 1% choose simpler model |
| Training paired records | 1,485 |
| Latest-year action paired records | 252 |
| Training years | 2025-2026, 2026-2027, 2027-2028, 2028-2029, 2029-2030, 2030-2031 |
| Action year | 2031-2032 |
| Candidate models tested | 13 |
| Operational candidates tested | 12 |
| Excluded leakage benchmarks | 1 |
| Repeated CV folds | 5 |
| Repeated CV repeats | 3 |
| Temporal expected-gain RMSE | 4.684 |
| Temporal expected-gain R-squared | 0.153 |
| Temporal EOY R-squared | 0.937 |
| Latest-year expected-gain RMSE | 4.683 |
| Latest-year expected-gain R-squared | 0.101 |
| Latest-year EOY R-squared | 0.932 |

The full selected-model metrics table is generated as [reports/growth_final_metrics.csv](growth_final_metrics.csv).

## Conclusion

The project should be read as a statistical decision-support system, not as a simple prediction demo. The strongest business value is the workflow: choose a validated expected-growth baseline, compare latest actual growth to that baseline, quantify uncertainty by slice, and translate the evidence into review priorities.

The recommended stakeholder action is to review the flagged teacher, course, and section patterns before the next assessment cycle. Priority targets deserve support or investigation; positive anomalies deserve study for transferable practices; watch-list rows deserve context review before escalation.

The important limitation is that the data are public-safe and generalized from an assessment workflow. The outputs demonstrate the analysis pattern and should not be used as real student, teacher, or personnel decisions.

## Reproducibility

Rebuild the full evidence packet with `make all`. The pipeline uses the included public-safe extract and no credentials, private files, or network access.

## Public-Safety Statement

This report is an original public-safe portfolio artifact. It excludes private coursework prompts, exams, rubrics, syllabi, lecture transcripts, source datasets, personal data, real student-identifiable records, real personnel records, credentials, and copyrighted source documents.
