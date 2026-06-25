# Model Card

## Intended Use

Estimate an expected BOY/EOY assessment-growth baseline and identify public-safe teacher, course, and section patterns that deserve future instructional review.

## Not Intended For

Teacher evaluation, compensation, discipline, student placement, grading, employment, admissions, clinical decisions, or automated decisions with real student or personnel data.

## Data

Public-safe paired BOY/EOY assessment records with 1,737 modeled pairs. The action-year review uses 252 latest-year pairs. Identifiers are simulated and generalized; no real student-identifiable or personnel records are included.

## Model

Selected baseline: Growth ensemble balanced. The operating target is direct BOY/EOY score gain. Candidate families include linear baselines, polynomial terms, interaction surfaces, cyclic terms, GAM smooths, regression trees, random forests, gradient boosting, validation ensembles, EOY-derived benchmarks, and an excluded teacher/course ID leakage check.

## Validation

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

| Metric | Estimate | 95% interval |
| --- | --- | --- |
| Expected-gain RMSE | 4.660 | 4.226 to 5.081 |
| Expected-gain MAE | 3.725 | 3.359 to 4.071 |
| Expected-gain R-squared | 0.110 | 0.009 to 0.189 |
| EOY RMSE | 4.660 | 4.226 to 5.081 |
| EOY R-squared | 0.933 | 0.917 to 0.944 |

## Decision Layer

Latest-year teacher, course, and section residuals are summarized with bootstrap intervals, p-values, BH-adjusted q-values, reliability weighting, and decision labels. The labels are audit priorities, not causal claims.

## Monitoring Recommendations

- Track BOY/EOY pairing rates and missing EOY assessments.
- Monitor section sizes before ranking or escalating signals.
- Refit the model when course mix, assessment design, or attendance patterns change.
- Keep teacher, course, and section IDs out of the operating baseline when the goal is to surface those patterns for review.
- Compare raw and adjusted growth before communicating findings.

## Public-Safety Boundary

No private coursework prompts, raw private source datasets, credentials, real student records, real personnel records, patient records, or customer records are included.
