# Assessment Growth and Section Performance Analytics in R

## Recommendation

Use the latest completed assessment year, **2024-2025**, to identify teacher, course, and section patterns that deserve review before the next cycle. The stakeholder metric is **BOY/EOY score gain**: end-of-year score minus beginning-of-year score for the same public-safe student record.

The decision system does not ask whether old sections should be managed retroactively. It asks whether the most recent actual growth was materially above or below an expected-growth baseline trained only on prior years.

## How To Read The Model Results

The model is **not** intended to forecast each student's exact score gain. Individual growth is noisy because similar students can improve by different amounts for reasons not fully captured in the extract. For that reason, the latest-year individual gain R-squared of **0.097** is treated as a signal-strength diagnostic, not the headline business result.

The business question is group-level: after adjusting for starting score, readiness, attendance, prior history, course track, grade level, and section composition, did a teacher, course, or section produce more or less average growth than expected? That comparison is more stable because student-level noise partly averages out across groups.

The EOY R-squared of **0.932** is reported only to show that final score is mechanically easier to predict from BOY score. It should not be read as evidence that the model precisely predicts improvement. The relevant evidence is out-of-sample lift versus a naive baseline, aggregate fit, residual calibration, uncertainty intervals, and flag stability.

The baseline selected for operations is **Growth lasso**. It predicts **score gain directly** using a Regularized regression specification. The selected tuning choice is alpha=1.00. Against a naive prior-year mean-growth baseline, the selected model improves temporal RMSE by **8.0%** and latest-year RMSE by **5.4%**.

Under the stricter validity framework, this model is best described as **directional review** evidence: 4 of 7 primary gates passed. The model is useful for structured review and prioritization, but the report should not overstate it as a definitive teacher or section rating system.

Because decisions are made at aggregate review levels, the planning-level fit is more relevant than the individual gain R-squared: latest-year gain R-squared is **0.266** for section means, **0.546** for course means, and **0.638** for teacher means.

The workflow uses the direct-growth model to create a fair expected-growth baseline, then makes decisions from aggregate teacher, course, and section residuals with bootstrap uncertainty checks.

| Slice | Priority or watch rows | Total reviewed |
| --- | --- | --- |
| Teachers | 1 | 5 |
| Courses | 3 | 9 |
| Sections | 8 | 24 |

| Decision | Slice | Target | N | Gap | 95% CI | q |
| --- | --- | --- | --- | --- | --- | --- |
| Intervention | Section | S21 | 12 | -2.67 | -5.15 to -0.31 | 0.200 |
| Intervention | Course | Precalc | 40 | -1.41 | -2.88 to -0.25 | 0.040 |

Bright spots, watch-list rows, and the full decision table are generated as [decision table](intervention_targets.csv).

## Plain-English Method

1. Build a paired BOY/EOY growth extract from public-safe assessment records.
2. Define the business outcome as score gain: EOY score minus BOY score.
3. Create leakage-safe engineered features from BOY data and prior completed years: multi-year student history, section composition, transformations, and interaction terms.
4. Search candidate expected-growth models across parametric, spline, GAM, regularized, tree-based, forest, boosting, MARS, ensemble, and excluded leakage-check specifications.
5. Select the operating baseline using rolling-origin temporal validation, with repeated CV, process validation, locked-holdout review, bootstrap checks, and feature-stability diagnostics as supporting evidence.
6. Score the latest year against the prior-year baseline.
7. Aggregate observed-minus-expected growth by teacher, course, and section.
8. Flag review targets only when the gap is large enough to matter and the uncertainty check supports follow-up.

This design separates the prediction problem from the decision problem. The prediction model estimates what growth would be expected for a similar starting profile; the review layer asks where actual growth departed from that expectation.

## Direct Answers

1. The analysis covers 1,737 paired BOY/EOY records across 174 section-year groups and 5 public-safe teacher identifiers.
2. The training window is 2018-2019, 2019-2020, 2020-2021, 2021-2022, 2022-2023, 2023-2024; the action year is 2024-2025.
3. The average raw gain across the full extract is 5.72 points; the latest-year raw gain is 5.34 points.
4. The model search tested 31 candidate baselines across parametric, nonlinear, ensemble, and leakage-check families.
5. The selected direct-growth baseline has temporal expected-gain RMSE 4.663, temporal MAE 3.725, latest-year RMSE 4.693, and latest-year MAE 3.739.
6. The modest individual gain R-squared is expected for a noisy improvement outcome; it is not the main business score.
7. Teacher, course, and section flags are audit priorities. They are not automatic personnel ratings or causal claims.

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
| Records with prior-year history | 1,066 |
| Mean section size | 10.4 |
| Mean BOY score | 48.5 |
| Mean EOY score | 54.2 |
| Mean BOY/EOY gain | 5.7 |
| Median section paired records | 10 |

## Model Selection

The model discovery system used 1,485 prior-year pairs and held out 252 latest-year pairs for action-year evaluation. The primary selection metric is rolling-origin temporal expected-gain RMSE, not latest-year performance, so each validation year is treated like the future.

The best eligible direct-growth rolling-origin RMSE was **4.663** from **Growth lasso**, so it is the operating baseline. Repeated-CV RMSE remains a stability check for candidates that are practically tied on rolling-origin RMSE.



The model-search guardrails were:

- Use direct BOY/EOY score gain as the operating target because that is the stakeholder performance metric.
- Select by rolling-origin temporal RMSE so the baseline is judged on future-facing generalization.
- Use repeated-CV RMSE as the tie-breaker when rolling-origin RMSE differs by less than 0.01 points.
- Keep teacher, course, and section identifiers out of the operating baseline because those are the review slices.
- Use feature engineering only when the feature is available at BOY or from prior completed years.
- Refit the selected production model on all completed years only after model selection.
- Report individual gain R-squared as a signal-strength diagnostic, not as the headline business result.
- Report EOY R-squared only as context because final score is mechanically easier to predict than growth.

The decision-grade target table below is intentionally strict. It prevents the project from claiming stronger performance judgment than the data support.

| Gate | Decision-grade | Actual | Status |
| --- | --- | --- | --- |
| Rolling RMSE lift vs naive | 10.0% | 8.0% | Below decision-grade |
| Rolling MAE lift vs naive | 8.0% | 8.6% | Pass |
| Temporal gain R-squared | 0.200 | 0.151 | Below decision-grade |
| Section mean gain R-squared | 0.300 | 0.266 | Below decision-grade |
| Course mean gain R-squared | 0.500 | 0.546 | Pass |
| Teacher mean gain R-squared | 0.600 | 0.638 | Pass |
| Overall residual bias | 0.200 | -0.258 | Review |
| Maximum subgroup residual bias | 0.500 | 3.252 | Review |

The first strength check is whether the selected model beats a naive baseline that predicts the training-year mean gain for every record. This is the minimum bar for using a model as an expected-growth baseline.

| Measure | Value |
| --- | --- |
| Naive temporal RMSE | 5.066 |
| Selected temporal RMSE | 4.663 |
| Temporal RMSE improvement | 8.0% |
| Naive latest-year RMSE | 4.960 |
| Selected latest-year RMSE | 4.693 |
| Latest-year RMSE improvement | 5.4% |
| Naive latest-year MAE | 4.026 |
| Selected latest-year MAE | 3.739 |
| Latest-year MAE improvement | 7.1% |
| Latest-year gain R-squared | 0.097 |
| Latest-year EOY R-squared | 0.932 |
| Section-mean gain R-squared | 0.266 |
| Teacher-mean gain R-squared | 0.638 |
| Course-mean gain R-squared | 0.546 |

<!-- PDF_PAGE_BREAK -->

The table below shows the strongest candidate baselines tested. The selected model was chosen by rolling-origin validation, not by whichever model looked best on the latest year. The leakage-check row is shown for transparency but is not eligible because it would absorb the teacher/course patterns the review layer is designed to detect.

| Candidate model | Model type | Used? | Rolling RMSE | Latest RMSE | Latest MAE | Gain R2 | Read |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Growth lasso | Regularized | Yes | 4.663 | 4.693 | 3.739 | 0.097 | Selected |
| Growth elastic net | Regularized |  | 4.666 | 4.699 | 3.740 | 0.095 | Near tie |
| Growth linear | Linear |  | 4.698 | 4.683 | 3.728 | 0.101 | Near tie |
| GBM 1 | Boosting |  | 4.702 | 4.727 | 3.814 | 0.084 | Near tie |
| GBM 2 | Boosting |  | 4.709 | 4.695 | 3.780 | 0.097 | Near tie |
| MARS 2 | MARS |  | 4.725 | 4.618 | 3.714 | 0.126 | Near tie |
| Ranger 1 | Ranger |  | 4.740 | 4.685 | 3.732 | 0.100 | Near tie |
| Leakage check | Leakage |  | 2436.990 | 4.658 | 3.708 | 0.111 | Leakage only |

Full model artifacts: [model comparison](growth_model_comparison_display.csv), [model search grid](growth_model_search_grid.csv), [model strength](growth_model_strength.csv), [family summary](growth_model_family_summary.csv), [selection rationale](growth_model_selection_rationale.csv), [temporal validation](model_temporal_validation.csv), [rolling-origin validation](rolling_origin_validation.csv), [process validation](process_validation.csv), [locked holdout](locked_holdout_validation.csv), [validity targets](model_validity_targets.csv), and [bootstrap validation](model_bootstrap_validation.csv).

## Feature Discovery

The model search includes leakage-safe feature engineering: multi-year prior student growth, prior trend and volatility, BOY score bands, section composition, attendance mix, nonlinear basis terms, and selected interactions. The table below shows which features mattered most when permuted in the locked action-year data.

| Feature | RMSE lift if permuted | SD |
| --- | --- | --- |
| course track | 0.056 | 0.034 |
| student prior year count | 0.022 | 0.009 |
| grade level | 0.015 | 0.006 |
| section pct high absence | 0.006 | 0.002 |
| student prior attendance mean | 0.000 | 0.000 |
| boy readiness | 0.000 | 0.000 |
| boy score | 0.000 | 0.000 |
| school year offset | 0.000 | 0.000 |
| section attendance mean | 0.000 | 0.000 |
| section boy mean | 0.000 | 0.000 |

Feature stability asks whether the same predictors continue to matter across repeated perturbations.

| Feature | Positive importance | Top-quartile importance |
| --- | --- | --- |
| course track | 88% | 88% |
| student prior year count | 100% | 100% |
| grade level | 100% | 100% |
| section pct high absence | 100% | 100% |
| student prior attendance mean | 62% | 62% |
| boy readiness | 0% | 100% |
| boy score | 0% | 100% |
| school year offset | 0% | 100% |
| section attendance mean | 0% | 100% |
| section boy mean | 0% | 100% |

Feature artifacts: [feature importance](feature_importance.csv) and [feature stability](feature_stability.csv).

![Model search by family and tuned candidate](../figures/growth_model_search.png)

![Expected-growth model comparison](../figures/growth_model_comparison.png)

<!-- PDF_PAGE_BREAK -->

## Latest-Year Review Targets

The latest-year review layer compares observed gain with expected gain for 24 section groups. The decision labels use a practical audit threshold: material gap, bootstrap interval direction, and BH-adjusted q-value for multiple-review control.

**Teacher review**

| Target | N | Raw | Expected | Gap | CI | q | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TCH-005 | 68 | 3.81 | 4.80 | -0.99 | -2.19 to 0.06 | 0.367 | Watch |

**Course review**

| Target | N | Raw | Expected | Gap | CI | q | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Precalc | 40 | 4.99 | 6.41 | -1.41 | -2.88 to -0.25 | 0.040 | Intervention |
| AP Precalc | 30 | 6.11 | 4.18 | +1.93 | 0.30 to 3.20 | 0.030 | Bright spot |
| AP Calc AB | 49 | 4.31 | 5.17 | -0.86 | -2.23 to 0.37 | 0.384 | Watch |

**Section evidence**

| Target | N | Raw | Expected | Gap | CI | q | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S21 | 12 | 3.10 | 5.77 | -2.67 | -5.15 to -0.31 | 0.200 | Intervention |
| S02 | 10 | 9.02 | 6.56 | +2.46 | 0.16 to 4.92 | 0.200 | Bright spot |
| S13 | 9 | 7.18 | 4.28 | +2.90 | 0.98 to 4.80 | 0.040 | Bright spot |
| S19 | 12 | 2.41 | 5.01 | -2.60 | -5.04 to 0.12 | 0.320 | Watch |
| S04 | 9 | 4.01 | 6.45 | -2.44 | -6.44 to 2.33 | 0.556 | Watch |
| S16 | 10 | 4.11 | 6.27 | -2.15 | -5.05 to 0.27 | 0.347 | Watch |
| S17 | 9 | 4.78 | 6.72 | -1.94 | -5.60 to 1.70 | 0.556 | Watch |
| S23 | 9 | 1.89 | 3.75 | -1.87 | -4.37 to 0.64 | 0.366 | Watch |

Full review tables: [teacher review](latest_teacher_review.csv), [course review](latest_course_review.csv), and [section review](latest_section_review.csv).

A second review layer fits a mixed-effects shrinkage model on the latest-year residuals. It estimates teacher, course, and section effects at the same time and pulls noisier small-group estimates toward zero, so the strongest flags are less likely to be one-off small-section artifacts.

| Slice | Target | N | Raw gap | Shrunken gap | 95% CI | q | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Course | AP Precalc | 30 | +1.93 | +0.66 | -0.36 to 1.69 | 0.869 | In range |
| Course | Precalc | 40 | -1.41 | -0.43 | -1.40 to 0.54 | 0.869 | In range |
| Section | S02 | 10 | +2.46 | +0.34 | -0.68 to 1.36 | 0.965 | In range |
| Section | S19 | 12 | -2.60 | -0.31 | -1.32 to 0.70 | 0.965 | In range |
| Section | S21 | 12 | -2.67 | -0.30 | -1.31 to 0.70 | 0.965 | In range |
| Course | AP Calc AB | 49 | -0.86 | -0.30 | -1.24 to 0.63 | 0.869 | In range |
| Section | S18 | 13 | +1.33 | +0.29 | -0.72 to 1.29 | 0.965 | In range |
| Section | S13 | 9 | +2.90 | +0.26 | -0.76 to 1.28 | 0.965 | In range |
| Section | S04 | 9 | -2.44 | -0.25 | -1.27 to 0.78 | 0.965 | In range |
| Section | S06 | 11 | +1.13 | +0.19 | -0.82 to 1.20 | 0.965 | In range |
| Course | Alg 2 H | 26 | +0.32 | +0.18 | -0.87 to 1.23 | 0.869 | In range |
| Section | S23 | 9 | -1.87 | -0.17 | -1.20 to 0.85 | 0.965 | In range |

Flag stability estimates how often a slice remains beyond the practical one-point gap threshold under bootstrap resampling. Directional rows should be reviewed with context; stable rows have stronger evidence for action.

| Level | Target | N | Adjusted gap | Decision | Stability | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Section | Y06-SEC-013 / MATH-AP-PRECALC / TCH-004 | 9 | +2.90 | Positive anomaly | 96% | Stable |
| Section | Y06-SEC-021 / MATH-AP-CALC-AB / TCH-005 | 12 | -2.67 | Intervention target | 90% | Stable |
| Section | Y06-SEC-019 / MATH-AP-CALC-AB / TCH-005 | 12 | -2.60 | Watch list | 89% | Stable |
| Course | MATH-AP-PRECALC | 30 | +1.93 | Positive anomaly | 88% | Stable |
| Section | Y06-SEC-002 / MATH-GEOM / TCH-002 | 10 | +2.46 | Positive anomaly | 88% | Stable |
| Section | Y06-SEC-016 / MATH-PRECALC / TCH-004 | 10 | -2.15 | Watch list | 82% | Stable |
| Section | Y06-SEC-011 / MATH-AP-PRECALC / TCH-004 | 10 | +2.07 | Watch list | 78% | Stable |
| Section | Y06-SEC-023 / MATH-AP-CALC-BC / TCH-005 | 9 | -1.87 | Watch list | 77% | Stable |
| Section | Y06-SEC-004 / MATH-GEOM / TCH-002 | 9 | -2.44 | Watch list | 74% | Stable |
| Course | MATH-PRECALC | 40 | -1.41 | Intervention target | 69% | Directional |

Shrinkage artifacts: [shrinkage status](shrinkage_status.csv) and [shrinkage review](shrinkage_review.csv). Flag-stability artifacts: [flag stability](flag_stability.csv).

<!-- PDF_PAGE_BREAK -->

## Section Evidence

Raw section improvement is useful for communication, but it is not the final comparison. A section can show positive raw gain and still fall below expected growth if its starting profile suggested a larger increase.

| Section | Course | N | BOY | EOY | Gain | 95% CI | p-value |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S13 | AP Precalc | 9 | 63.5 | 70.7 | 7.18 | 5.20 to 9.16 | <0.001 |
| S02 | Geometry | 10 | 40.1 | 49.1 | 9.02 | 6.32 to 11.73 | <0.001 |
| S11 | AP Precalc | 10 | 69.0 | 74.7 | 5.67 | 1.52 to 9.83 | 0.013 |
| S18 | AP Calc AB | 13 | 49.4 | 56.1 | 6.69 | 3.06 to 10.31 | 0.002 |
| S06 | Alg 2 | 11 | 41.0 | 48.6 | 7.63 | 4.97 to 10.30 | <0.001 |
| S12 | AP Precalc | 11 | 59.5 | 65.1 | 5.64 | 1.86 to 9.43 | 0.008 |
| S10 | Alg 2 H | 12 | 63.1 | 70.0 | 6.90 | 3.98 to 9.83 | <0.001 |
| S03 | Geometry | 9 | 43.2 | 50.2 | 7.02 | 3.12 to 10.92 | 0.003 |

![Distribution of BOY/EOY improvement](../figures/growth_distribution.png)

<!-- PDF_PAGE_BREAK -->

The adjusted section signal is observed gain minus expected gain, reliability-weighted toward zero for smaller sections.

| Section | Teacher | Course | N | Raw | Expected | Signal | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S13 | TCH-004 | AP Precalc | 9 | 7.18 | 4.28 | +1.34 | Above |
| S02 | TCH-002 | Geometry | 10 | 9.02 | 6.56 | +1.20 | In range |
| S11 | TCH-004 | AP Precalc | 10 | 5.67 | 3.60 | +1.01 | In range |
| S18 | TCH-005 | AP Calc AB | 13 | 6.69 | 5.35 | +0.74 | In range |
| S17 | TCH-003 | Precalc | 9 | 4.78 | 6.72 | -0.90 | In range |
| S23 | TCH-005 | AP Calc BC | 9 | 1.89 | 3.75 | -0.86 | In range |
| S05 | TCH-001 | Geometry | 11 | 4.00 | 5.31 | -0.67 | In range |
| S14 | TCH-003 | Precalc | 10 | 4.81 | 6.04 | -0.60 | In range |

![Sections above or below expected growth](../figures/section_adjusted_signals.png)

The full section signal table is generated as [section signals](section_adjusted_signals.csv).

<!-- PDF_PAGE_BREAK -->

## Teacher and Course Summaries

These summaries aggregate the latest-year evidence into planning views. They support review conversations about pacing, curriculum alignment, attendance mix, and transferable practices. They should not be read as standalone personnel scores.

| Teacher | Sections | Records | Raw | Expected | Signal |
| --- | --- | --- | --- | --- | --- |
| TCH-004 | 5 | 43 | 5.21 | 4.59 | +0.28 |
| TCH-001 | 3 | 33 | 6.06 | 5.90 | +0.06 |
| TCH-002 | 5 | 52 | 6.60 | 6.65 | -0.02 |
| TCH-003 | 5 | 56 | 5.70 | 6.18 | -0.25 |
| TCH-005 | 6 | 68 | 3.81 | 4.80 | -0.56 |

| Course | Sections | Records | Raw | Expected | Signal |
| --- | --- | --- | --- | --- | --- |
| AP Precalc | 3 | 30 | 6.11 | 4.18 | +0.97 |
| Alg 1 | 1 | 13 | 7.13 | 6.32 | +0.24 |
| Alg 2 H | 2 | 26 | 6.18 | 5.86 | +0.15 |
| Geometry | 4 | 39 | 5.99 | 6.06 | -0.04 |
| Alg 2 | 3 | 33 | 6.57 | 6.73 | -0.08 |
| Beyond Core | 1 | 3 | -0.11 | 3.14 | -0.30 |
| AP Calc BC | 2 | 19 | 2.52 | 3.85 | -0.51 |
| AP Calc AB | 4 | 49 | 4.31 | 5.17 | -0.54 |
| Precalc | 4 | 40 | 4.99 | 6.41 | -0.81 |

![Teacher and course growth summaries](../figures/teacher_course_summary.png)

<!-- PDF_PAGE_BREAK -->

## Diagnostics and Sensitivity

The baseline is strong for final-score expectation and weaker for individual gain variation. That pattern is expected and is part of the interpretation, not something to hide: BOY score explains much of EOY score, while individual improvement contains more unobserved classroom, attendance, motivation, and assessment noise. For review decisions, the model is used to build expected growth and then aggregate residuals by teacher, course, and section.

| Diagnostic | Estimate | Interpretation |
| --- | --- | --- |
| Latest-year expected-gain RMSE | 4.693 | Typical out-of-sample prediction error on latest-year BOY/EOY gain |
| Latest-year expected-gain R-squared | 0.097 | Share of latest-year gain variation explained by the expected-growth model |
| Latest-year EOY R-squared | 0.932 | Share of latest-year EOY score variation explained by the baseline |
| Latest-year residual mean | -0.258 | Near 0 means expected gain is centered in the action year |
| Latest-year residual SD | 4.695 | Latest-year residual spread used for slice uncertainty |

| Metric | Estimate | 95% interval |
| --- | --- | --- |
| Expected-gain RMSE | 4.693 | 4.305 to 5.085 |
| Expected-gain MAE | 3.739 | 3.377 to 4.079 |
| Expected-gain R-squared | 0.097 | -0.005 to 0.181 |
| EOY RMSE | 4.693 | 4.305 to 5.085 |
| EOY R-squared | 0.932 | 0.917 to 0.943 |

| Metric | Value |
| --- | --- |
| Selected locked-holdout RMSE | 4.693 |
| Naive locked-holdout RMSE | 4.960 |
| Locked-holdout RMSE lift | 5.4% |
| Selected locked-holdout MAE | 3.739 |
| Naive locked-holdout MAE | 4.026 |
| Locked-holdout MAE lift | 7.1% |
| Locked-holdout gain R-squared | 0.097 |

| Diagnostic | Value |
| --- | --- |
| Individual gain SD | 5.079 |
| Student mean-gain R-squared | 0.208 |
| Section mean-gain R-squared | 0.266 |
| Course mean-gain R-squared | 0.546 |
| Teacher mean-gain R-squared | 0.638 |
| Selected train-validation R-squared gap | 0.045 |

| Measure | Value |
| --- | --- |
| Training paired records | 1,485 |
| Latest-year paired records | 252 |
| Latest-year section-year groups | 24 |
| Latest-year mean raw BOY/EOY gain | 5.34 |
| Latest-year raw-vs-adjusted rank correlation | 0.826 |
| Latest-year top-10 overlap, raw vs adjusted ranking | 70.0% |

![Growth model diagnostics](../figures/growth_diagnostics.png)

## Technical Appendix

The operating model excludes teacher IDs, course IDs, and section IDs. A leakage benchmark is reported only to show what would happen if persistent IDs were included in the baseline; it is not used for review because it would absorb the teacher/course patterns the decision layer is designed to detect.

| Package | Installed |
| --- | --- |
| mgcv | Available |
| randomForest | Available |
| ranger | Available |
| gbm | Available |
| rpart | Available |
| glmnet | Available |
| earth | Available |
| lme4 | Available |

| Metric | Value |
| --- | --- |
| Selected model | Growth lasso |
| Selected target strategy | Direct growth |
| Selected method | Elastic net |
| Selected family | Regularized regression |
| Selected tuned parameters | alpha=1.00 |
| Selection rule | Lowest rolling-origin temporal RMSE among eligible direct-growth candidates; repeated-CV RMSE is the tie-breaker within 0.01 points |
| Training paired records | 1,485 |
| Latest-year action paired records | 252 |
| Training years | 2018-2019, 2019-2020, 2020-2021, 2021-2022, 2022-2023, 2023-2024 |
| Action year | 2024-2025 |
| Candidate models tested | 31 |
| Operational candidates tested | 26 |
| Excluded leakage benchmarks | 5 |
| Repeated CV folds | 5 |
| Repeated CV repeats | 2 |
| Temporal expected-gain RMSE | 4.663 |
| Temporal expected-gain MAE | 3.725 |
| Temporal expected-gain R-squared | 0.151 |
| Temporal expected-gain RMSE SD | 0.244 |
| Temporal EOY R-squared | 0.934 |
| Latest-year expected-gain RMSE | 4.693 |
| Latest-year expected-gain MAE | 3.739 |
| Latest-year expected-gain R-squared | 0.097 |
| Latest-year EOY R-squared | 0.932 |

The full selected-model metrics table is generated as [selected-model metrics](growth_final_metrics.csv).

## Conclusion

The project should be read as a statistical decision-support system, not as a simple prediction demo. The strongest business value is the workflow: choose a validated expected-growth baseline, compare latest actual growth to that baseline at the group level, quantify uncertainty by slice, and translate the evidence into review priorities.

The recommended stakeholder action is to review the flagged teacher, course, and section patterns before the next assessment cycle. Priority targets deserve support or investigation; positive anomalies deserve study for transferable practices; watch-list rows deserve context review before escalation.

The important limitation is that the data are public-safe and generalized from an assessment workflow. The outputs demonstrate the analysis pattern and should not be used as real student, teacher, or personnel decisions.

## Reproducibility

Rebuild the full evidence packet with `make all`. The pipeline uses the included public-safe extract and no credentials, private files, or network access.

## Public-Safety Statement

This report is an original public-safe portfolio artifact. It excludes private coursework prompts, exams, rubrics, syllabi, lecture transcripts, source datasets, personal data, real student-identifiable records, real personnel records, credentials, and copyrighted source documents.
