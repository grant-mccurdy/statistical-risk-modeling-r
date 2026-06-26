# Model Card

## Intended Use

Estimate an expected BOY/EOY assessment-growth baseline from prior completed years and identify latest-year teacher, course, and section patterns that deserve future instructional review.

## Not Intended For

Teacher evaluation, compensation, discipline, student placement, grading, employment, admissions, clinical decisions, or automated decisions with real student or personnel data.

## Data

Public-safe paired BOY/EOY assessment records with 1,737 modeled pairs. The action-year review uses 252 latest-year pairs. Identifiers are simulated and generalized; no real student-identifiable or personnel records are included.

## Model

Selected baseline: Growth ensemble discovery weighted. The operating target is direct BOY/EOY score gain. Candidate families include a naive mean-growth benchmark, linear baselines, lagged-history and section-composition parametric models, polynomial terms, interaction surfaces, cyclic terms, GAM smooths, regularized regression, regression trees, random forests, gradient boosting, hand-weighted ensembles, stacked ensembles, EOY-derived benchmarks, and an excluded teacher/course ID benchmark.

## Validation

| Measure | Value |
| --- | --- |
| Naive temporal RMSE | 5.002 |
| Selected temporal RMSE | 4.576 |
| Temporal RMSE improvement | 8.5% |
| Naive latest-year RMSE | 4.960 |
| Selected latest-year RMSE | 4.646 |
| Latest-year RMSE improvement | 6.3% |
| Naive latest-year MAE | 4.026 |
| Selected latest-year MAE | 3.714 |
| Latest-year MAE improvement | 7.8% |
| Latest-year gain R-squared | 0.115 |
| Latest-year EOY R-squared | 0.933 |
| Section-mean gain R-squared | 0.263 |
| Teacher-mean gain R-squared | 0.663 |
| Course-mean gain R-squared | 0.524 |

| Metric | Value |
| --- | --- |
| Selected model | Growth ensemble discovery weighted |
| Selected target strategy | Direct growth |
| Selected method | Ensemble |
| Selected family | Validation ensemble |
| Selected tuned parameters | Growth gradient boosting 1 weight=2; Growth ranger forest 1 weight=2; Growth MARS 2 weight=1; Growth GAM k4 weight=1; Growth elastic net weight=1; Growth feature discovery model weight=1 |
| Selection rule | Lowest stable rolling-origin temporal RMSE among eligible direct-growth candidates; temporal folds require at least 3 prior completed years, and repeated-CV RMSE is the tie-breaker within 0.01 points |
| Training paired records | 1,485 |
| Latest-year action paired records | 252 |
| Training years | 2018-2019, 2019-2020, 2020-2021, 2021-2022, 2022-2023, 2023-2024 |
| Action year | 2024-2025 |
| Candidate models tested | 31 |
| Operational candidates tested | 26 |
| Excluded ID benchmarks | 5 |
| Repeated CV folds | 5 |
| Repeated CV repeats | 2 |
| Temporal expected-gain RMSE | 4.576 |
| Temporal expected-gain MAE | 3.649 |
| Temporal expected-gain R-squared | 0.160 |
| Temporal expected-gain RMSE SD | 0.241 |
| Temporal EOY R-squared | 0.931 |
| Latest-year expected-gain RMSE | 4.646 |
| Latest-year expected-gain MAE | 3.714 |
| Latest-year expected-gain R-squared | 0.115 |
| Latest-year EOY R-squared | 0.933 |

| Metric | Estimate | 95% interval |
| --- | --- | --- |
| Expected-gain RMSE | 4.646 | 4.254 to 5.026 |
| Expected-gain MAE | 3.714 | 3.355 to 4.035 |
| Expected-gain R-squared | 0.115 | 0.017 to 0.199 |
| EOY RMSE | 4.646 | 4.254 to 5.026 |
| EOY R-squared | 0.933 | 0.918 to 0.944 |

## Decision Layer

Latest-year teacher, course, and section residuals are summarized with bootstrap intervals, p-values, BH-adjusted q-values, reliability weighting, flag stability, mixed-effects shrinkage review, and priority labels. The labels are review priorities for planning and follow-up, not automated ratings.

## Monitoring Recommendations

- Track BOY/EOY pairing rates and missing EOY assessments.
- Monitor section sizes before ranking or escalating signals.
- Refit the model when course mix, assessment design, or attendance patterns change.
- Keep teacher, course, and section IDs out of the operating baseline when the goal is to surface those patterns for review.
- Compare raw and adjusted growth before communicating findings.

## Public-Safety Boundary

No private coursework prompts, raw private source datasets, credentials, real student records, real personnel records, patient records, or customer records are included.
