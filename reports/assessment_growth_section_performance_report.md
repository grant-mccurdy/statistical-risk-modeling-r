# Assessment Growth and Section Performance Analytics in R

## Recommendation

Use the latest completed assessment year, **2031-2032**, to identify teacher, course, and section patterns that deserve review before the next cycle. The stakeholder metric is **BOY/EOY score gain**: end-of-year score minus beginning-of-year score for the same public-safe student record.

The decision system does not ask whether old sections should be managed retroactively. It asks whether the most recent actual growth was materially above or below an expected-growth baseline trained only on prior years.

The baseline selected for operations is **Growth ensemble balanced**. It predicts **score gain directly** using a Validation ensemble specification. The selected tuning choice is an equal-weight blend of gradient boosting, GAM, and degree-3 polynomial growth predictions. The latest-year expected-gain RMSE is **4.660** points and the latest-year MAE is **3.725** points.

The latest-year gain R-squared is **0.110**; EOY R-squared is **0.933** and is reported only as secondary context. EOY is easier to predict because BOY score mechanically explains much of final score. The workflow uses the direct-growth model to create a fair expected-growth baseline, then makes decisions from aggregate teacher, course, and section residuals with bootstrap uncertainty checks.

| Slice | Priority or watch rows | Total reviewed |
| --- | --- | --- |
| Teachers | 1 | 5 |
| Courses | 3 | 9 |
| Sections | 8 | 24 |

| Decision | Slice | Target | N | Gap | 95% CI | q |
| --- | --- | --- | --- | --- | --- | --- |
| Intervention | Section | S19 | 12 | -2.87 | -5.29 to -0.17 | 0.160 |
| Intervention | Section | S21 | 12 | -2.71 | -5.10 to -0.36 | 0.160 |
| Intervention | Teacher | TCH-005 | 68 | -1.26 | -2.43 to -0.23 | 0.100 |
| Bright spot | Section | S13 | 9 | +2.51 | 0.54 to 4.44 | 0.080 |
| Bright spot | Section | S02 | 10 | +2.51 | 0.09 to 4.95 | 0.160 |

The full decision table, including watch-list rows, is generated as [reports/intervention_targets.csv](intervention_targets.csv).

<!-- PDF_PAGE_BREAK -->

## Plain-English Method

1. Build a paired BOY/EOY growth extract from public-safe assessment records.
2. Define the business outcome as score gain: EOY score minus BOY score.
3. Train candidate expected-growth models on prior years only, including parametric, smooth, tree-based, ensemble, and excluded leakage-check specifications.
4. Select the operating baseline using leave-one-year-out temporal validation, with repeated CV and bootstrap checks as supporting evidence.
5. Score the latest year against that prior-year baseline.
6. Aggregate observed-minus-expected growth by teacher, course, and section.
7. Flag review targets only when the gap is large enough to matter and the uncertainty check supports follow-up.

This design separates the prediction problem from the decision problem. The prediction model estimates what growth would be expected for a similar starting profile; the review layer asks where actual growth departed from that expectation.

## Direct Answers

1. The analysis covers 1,737 paired BOY/EOY records across 174 section-year groups and 5 public-safe teacher identifiers.
2. The training window is 2025-2026, 2026-2027, 2027-2028, 2028-2029, 2029-2030, 2030-2031; the action year is 2031-2032.
3. The average raw gain across the full extract is 5.72 points; the latest-year raw gain is 5.34 points.
4. The model search tested 19 candidate baselines across parametric, nonlinear, ensemble, and leakage-check families.
5. The selected direct-growth baseline has temporal expected-gain RMSE 4.631, temporal MAE 3.711, and latest-year expected-gain RMSE 4.660.
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

The model search used 1,485 prior-year pairs and held out 252 latest-year pairs for action-year evaluation. The primary selection metric is leave-one-year-out temporal expected-gain RMSE, not latest-year performance, so the system does not choose a model by looking at the year it later reviews.

The best eligible direct-growth temporal RMSE was **4.630** from **Growth ensemble nonlinear weighted**. The selected model's temporal RMSE was **4.631**, a difference of 0.001 points. Because that difference is below the 0.01-point practical tolerance, the selected model is the operating baseline because it has the strongest repeated-CV RMSE among the temporally tied direct-growth candidates.



The model-search guardrails were:

- Use direct BOY/EOY score gain as the operating target because that is the stakeholder performance metric.
- Select by temporal-CV RMSE so the baseline is judged on year-to-year generalization.
- Use repeated-CV RMSE as the tie-breaker when temporal-CV RMSE differs by less than 0.01 points.
- Keep teacher, course, and section identifiers out of the operating baseline because those are the review slices.
- Report EOY R-squared only as context because final score is mechanically easier to predict than growth.

| Family | Candidates | Eligible | Best model | Selected | Temporal RMSE | Temporal R2 | Latest RMSE |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Validation ensemble | 2 | 2 | Growth ensemble balanced | Yes | 4.631 | 0.172 | 4.660 |
| Non-parametric boosting | 2 | 2 | GBM 1 |  | 4.661 | 0.161 | 4.803 |
| Semi-parametric GAM | 2 | 2 | GAM k4 |  | 4.665 | 0.160 | 4.640 |
| Parametric polynomial | 2 | 2 | Growth poly d3 |  | 4.666 | 0.160 | 4.591 |
| EOY-derived benchmark | 2 | 0 | EOY readiness |  | 4.683 | 0.153 | 4.626 |
| Parametric linear | 2 | 2 | Growth readiness |  | 4.683 | 0.153 | 4.626 |
| Leakage benchmark | 1 | 0 | Leakage check |  | 4.706 | 0.145 | 4.658 |
| Parametric interactions | 1 | 1 | Growth interactions |  | 4.719 | 0.140 | 4.614 |
| Non-parametric random forest | 2 | 2 | RF 1 |  | 4.729 | 0.136 | 4.805 |
| Non-parametric tree | 2 | 2 | Tree 1 |  | 4.730 | 0.135 | 4.859 |
| Parametric cyclic | 1 | 1 | Growth cyclic |  | 4.744 | 0.132 | 4.617 |

| Family | Representative model | Decision | Temporal RMSE | Latest RMSE |
| --- | --- | --- | --- | --- |
| Direct growth linear baselines | Growth readiness | Compared | 4.683 | 4.626 |
| Direct growth polynomial terms | Growth poly d3 | Compared | 4.666 | 4.591 |
| Direct growth interaction surfaces | Growth interactions | Compared | 4.719 | 4.614 |
| GAM smooths | GAM k4 | Compared | 4.665 | 4.640 |
| Regression trees | Tree 1 | Compared | 4.730 | 4.859 |
| Random forests | RF 1 | Compared | 4.729 | 4.805 |
| Gradient boosting | GBM 1 | Compared | 4.661 | 4.803 |
| Validation ensembles | Growth ensemble balanced | Selected | 4.631 | 4.660 |
| EOY-derived benchmarks | EOY readiness | Compared | 4.683 | 4.626 |
| Teacher/course ID leakage check | Leakage check | Excluded | 4.706 | 4.658 |

| Model | Use | Family | CV RMSE | Temporal RMSE | Temporal R2 | Latest RMSE | Latest R2 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Growth ensemble nonlinear weighted |  | Validation ensemble | 4.646 | 4.630 | 0.172 | 4.690 | 0.098 |
| Growth ensemble balanced | Yes | Validation ensemble | 4.640 | 4.631 | 0.172 | 4.660 | 0.110 |
| GBM 1 |  | Non-parametric boosting | 4.692 | 4.661 | 0.161 | 4.803 | 0.054 |
| GAM k4 |  | Semi-parametric GAM | 4.660 | 4.665 | 0.160 | 4.640 | 0.118 |
| GAM k8 |  | Semi-parametric GAM | 4.660 | 4.666 | 0.160 | 4.640 | 0.118 |
| Growth poly d3 |  | Parametric polynomial | 4.642 | 4.666 | 0.160 | 4.591 | 0.136 |
| GBM 2 |  | Non-parametric boosting | 4.722 | 4.682 | 0.153 | 4.813 | 0.050 |
| Growth readiness |  | Parametric linear | 4.650 | 4.683 | 0.153 | 4.626 | 0.123 |
| Growth linear |  | Parametric linear | 4.677 | 4.684 | 0.153 | 4.683 | 0.101 |
| Growth poly d2 |  | Parametric polynomial | 4.648 | 4.689 | 0.151 | 4.627 | 0.122 |
| Leakage check |  | Leakage benchmark | 4.678 | 4.706 | 0.145 | 4.658 | 0.111 |

Full model artifacts: [reports/growth_model_comparison_display.csv](growth_model_comparison_display.csv), [reports/growth_model_search_grid.csv](growth_model_search_grid.csv), [reports/growth_model_family_summary.csv](growth_model_family_summary.csv), [reports/growth_model_selection_rationale.csv](growth_model_selection_rationale.csv), [reports/model_temporal_validation.csv](model_temporal_validation.csv), and [reports/model_bootstrap_validation.csv](model_bootstrap_validation.csv).

![Model search by family and tuned candidate](../figures/growth_model_search.png)

![Expected-growth model comparison](../figures/growth_model_comparison.png)

<!-- PDF_PAGE_BREAK -->

## Latest-Year Review Targets

The latest-year review layer compares observed gain with expected gain for 24 section groups. The decision labels use a practical audit threshold: material gap, bootstrap interval direction, and BH-adjusted q-value for multiple-review control.

**Teacher review**

| Target | N | Raw | Expected | Gap | CI | q | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TCH-005 | 68 | 3.81 | 5.08 | -1.26 | -2.43 to -0.23 | 0.100 | Intervention |

**Course review**

| Target | N | Raw | Expected | Gap | CI | q | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Precalc | 40 | 4.99 | 6.13 | -1.13 | -2.48 to 0.00 | 0.160 | Watch |
| AP Calc AB | 49 | 4.31 | 5.39 | -1.08 | -2.51 to 0.10 | 0.216 | Watch |
| AP Precalc | 30 | 6.11 | 4.80 | +1.31 | -0.30 to 2.59 | 0.216 | Watch |

**Section evidence**

| Target | N | Raw | Expected | Gap | CI | q | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S19 | 12 | 2.41 | 5.28 | -2.87 | -5.29 to -0.17 | 0.160 | Intervention |
| S21 | 12 | 3.10 | 5.81 | -2.71 | -5.10 to -0.36 | 0.160 | Intervention |
| S13 | 9 | 7.18 | 4.66 | +2.51 | 0.54 to 4.44 | 0.080 | Bright spot |
| S02 | 10 | 9.02 | 6.52 | +2.51 | 0.09 to 4.95 | 0.160 | Bright spot |
| S04 | 9 | 4.01 | 6.78 | -2.76 | -6.94 to 2.23 | 0.553 | Watch |
| S23 | 9 | 1.89 | 4.14 | -2.26 | -4.80 to 0.25 | 0.293 | Watch |
| S16 | 10 | 4.11 | 5.99 | -1.87 | -4.78 to 0.49 | 0.457 | Watch |
| S05 | 11 | 4.00 | 5.28 | -1.29 | -3.93 to 1.74 | 0.651 | Watch |

Full review tables: [reports/latest_teacher_review.csv](latest_teacher_review.csv), [reports/latest_course_review.csv](latest_course_review.csv), and [reports/latest_section_review.csv](latest_section_review.csv).

<!-- PDF_PAGE_BREAK -->

## Section Evidence

Raw section improvement is useful for communication, but it is not the final comparison. A section can show positive raw gain and still fall below expected growth if its starting profile suggested a larger increase.

| Section | Course | N | BOY | EOY | Gain | 95% CI | p-value |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S02 | Geometry | 10 | 40.1 | 49.1 | 9.02 | 6.32 to 11.73 | <0.001 |
| S13 | AP Precalc | 9 | 63.5 | 70.7 | 7.18 | 5.20 to 9.16 | <0.001 |
| S10 | Alg 2 H | 12 | 63.1 | 70.0 | 6.90 | 3.98 to 9.83 | <0.001 |
| S18 | AP Calc AB | 13 | 49.4 | 56.1 | 6.69 | 3.06 to 10.31 | 0.002 |
| S06 | Alg 2 | 11 | 41.0 | 48.6 | 7.63 | 4.97 to 10.30 | <0.001 |
| S11 | AP Precalc | 10 | 69.0 | 74.7 | 5.67 | 1.52 to 9.83 | 0.013 |
| S01 | Alg 1 | 13 | 42.1 | 49.2 | 7.13 | 4.19 to 10.08 | <0.001 |
| S12 | AP Precalc | 11 | 59.5 | 65.1 | 5.64 | 1.86 to 9.43 | 0.008 |

![Distribution of BOY/EOY improvement](../figures/growth_distribution.png)

<!-- PDF_PAGE_BREAK -->

The adjusted section signal is observed gain minus expected gain, reliability-weighted toward zero for smaller sections.

| Section | Teacher | Course | N | Raw | Expected | Signal | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S02 | TCH-002 | Geometry | 10 | 9.02 | 6.52 | +1.22 | In range |
| S13 | TCH-004 | AP Precalc | 9 | 7.18 | 4.66 | +1.16 | Above |
| S10 | TCH-003 | Alg 2 H | 12 | 6.90 | 5.56 | +0.72 | In range |
| S18 | TCH-005 | AP Calc AB | 13 | 6.69 | 5.41 | +0.70 | In range |
| S16 | TCH-004 | Precalc | 10 | 4.11 | 5.99 | -0.91 | In range |
| S05 | TCH-001 | Geometry | 11 | 4.00 | 5.28 | -0.66 | In range |
| S22 | TCH-005 | AP Calc BC | 10 | 3.10 | 4.36 | -0.61 | In range |
| S14 | TCH-003 | Precalc | 10 | 4.81 | 5.88 | -0.52 | In range |

![Sections above or below expected growth](../figures/section_adjusted_signals.png)

The full section signal table is generated as [reports/section_adjusted_signals.csv](section_adjusted_signals.csv).

<!-- PDF_PAGE_BREAK -->

## Teacher and Course Summaries

These summaries aggregate the latest-year evidence into planning views. They support review conversations about pacing, curriculum alignment, attendance mix, and transferable practices. They should not be read as standalone personnel scores.

| Teacher | Sections | Records | Raw | Expected | Signal |
| --- | --- | --- | --- | --- | --- |
| TCH-004 | 5 | 43 | 5.21 | 5.03 | +0.08 |
| TCH-002 | 5 | 52 | 6.60 | 6.64 | -0.02 |
| TCH-001 | 3 | 33 | 6.06 | 6.23 | -0.07 |
| TCH-003 | 5 | 56 | 5.70 | 5.87 | -0.09 |
| TCH-005 | 6 | 68 | 3.81 | 5.08 | -0.72 |

| Course | Sections | Records | Raw | Expected | Signal |
| --- | --- | --- | --- | --- | --- |
| AP Precalc | 3 | 30 | 6.11 | 4.80 | +0.66 |
| Alg 2 H | 2 | 26 | 6.18 | 5.53 | +0.30 |
| Alg 1 | 1 | 13 | 7.13 | 6.71 | +0.13 |
| Alg 2 | 3 | 33 | 6.57 | 6.64 | -0.04 |
| Geometry | 4 | 39 | 5.99 | 6.27 | -0.16 |
| Beyond Core | 1 | 3 | -0.11 | 4.21 | -0.39 |
| Precalc | 4 | 40 | 4.99 | 6.13 | -0.65 |
| AP Calc BC | 2 | 19 | 2.52 | 4.26 | -0.67 |
| AP Calc AB | 4 | 49 | 4.31 | 5.39 | -0.67 |

![Teacher and course growth summaries](../figures/teacher_course_summary.png)

<!-- PDF_PAGE_BREAK -->

## Diagnostics and Sensitivity

The baseline is strong for final-score expectation and weaker for individual gain variation. That pattern is expected: BOY score explains much of EOY score, while individual improvement contains more unobserved classroom, attendance, and assessment noise.

| Diagnostic | Estimate | Interpretation |
| --- | --- | --- |
| Latest-year expected-gain RMSE | 4.660 | Typical out-of-sample prediction error on latest-year BOY/EOY gain |
| Latest-year expected-gain R-squared | 0.110 | Share of latest-year gain variation explained by the expected-growth model |
| Latest-year EOY R-squared | 0.933 | Share of latest-year EOY score variation explained by the baseline |
| Latest-year residual mean | -0.380 | Near 0 means expected gain is centered in the action year |
| Latest-year residual SD | 4.654 | Latest-year residual spread used for slice uncertainty |

| Metric | Estimate | 95% interval |
| --- | --- | --- |
| Expected-gain RMSE | 4.660 | 4.226 to 5.081 |
| Expected-gain MAE | 3.725 | 3.359 to 4.071 |
| Expected-gain R-squared | 0.110 | 0.009 to 0.189 |
| EOY RMSE | 4.660 | 4.226 to 5.081 |
| EOY R-squared | 0.933 | 0.917 to 0.944 |

| Measure | Value |
| --- | --- |
| Training paired records | 1,485 |
| Latest-year paired records | 252 |
| Latest-year section-year groups | 24 |
| Latest-year mean raw BOY/EOY gain | 5.34 |
| Latest-year raw-vs-adjusted rank correlation | 0.897 |
| Latest-year top-10 overlap, raw vs adjusted ranking | 70.0% |

![Growth model diagnostics](../figures/growth_diagnostics.png)

## Technical Appendix

The operating model excludes teacher IDs, course IDs, and section IDs. A leakage benchmark is reported only to show what would happen if persistent IDs were included in the baseline; it is not used for review because it would absorb the teacher/course patterns the decision layer is designed to detect.

| Package | Installed |
| --- | --- |
| mgcv | Available |
| randomForest | Available |
| gbm | Available |
| rpart | Available |

| Metric | Value |
| --- | --- |
| Selected model | Growth ensemble balanced |
| Selected target strategy | Direct growth |
| Selected method | Ensemble |
| Selected family | Validation ensemble |
| Selected tuned parameters | Growth gradient boosting 1 weight=1; Growth GAM k4 weight=1; Growth polynomial degree 3 weight=1 |
| Selection rule | Lowest repeated-CV RMSE among direct-growth candidates within 0.01 points of the best temporal-CV RMSE |
| Training paired records | 1,485 |
| Latest-year action paired records | 252 |
| Training years | 2025-2026, 2026-2027, 2027-2028, 2028-2029, 2029-2030, 2030-2031 |
| Action year | 2031-2032 |
| Candidate models tested | 19 |
| Operational candidates tested | 16 |
| Excluded leakage benchmarks | 3 |
| Repeated CV folds | 5 |
| Repeated CV repeats | 2 |
| Temporal expected-gain RMSE | 4.631 |
| Temporal expected-gain MAE | 3.711 |
| Temporal expected-gain R-squared | 0.172 |
| Temporal expected-gain RMSE SD | 0.229 |
| Temporal EOY R-squared | 0.938 |
| Latest-year expected-gain RMSE | 4.660 |
| Latest-year expected-gain MAE | 3.725 |
| Latest-year expected-gain R-squared | 0.110 |
| Latest-year EOY R-squared | 0.933 |

The full selected-model metrics table is generated as [reports/growth_final_metrics.csv](growth_final_metrics.csv).

## Conclusion

The project should be read as a statistical decision-support system, not as a simple prediction demo. The strongest business value is the workflow: choose a validated expected-growth baseline, compare latest actual growth to that baseline, quantify uncertainty by slice, and translate the evidence into review priorities.

The recommended stakeholder action is to review the flagged teacher, course, and section patterns before the next assessment cycle. Priority targets deserve support or investigation; positive anomalies deserve study for transferable practices; watch-list rows deserve context review before escalation.

The important limitation is that the data are public-safe and generalized from an assessment workflow. The outputs demonstrate the analysis pattern and should not be used as real student, teacher, or personnel decisions.

## Reproducibility

Rebuild the full evidence packet with `make all`. The pipeline uses the included public-safe extract and no credentials, private files, or network access.

## Public-Safety Statement

This report is an original public-safe portfolio artifact. It excludes private coursework prompts, exams, rubrics, syllabi, lecture transcripts, source datasets, personal data, real student-identifiable records, real personnel records, credentials, and copyrighted source documents.
