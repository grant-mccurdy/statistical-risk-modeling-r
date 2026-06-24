# Model Card

## Intended Use

Estimate an expected BOY/EOY assessment-growth baseline and identify public-safe teacher, course, and section patterns that deserve future instructional review.

## Not Intended For

Teacher evaluation, compensation, discipline, student placement, grading, employment, admissions, clinical decisions, or automated decisions with real student or personnel data.

## Data

Public-safe paired BOY/EOY assessment records with 1,737 modeled pairs. The action-year review uses 252 latest-year pairs. Identifiers are simulated and generalized; no real student-identifiable or personnel records are included.

## Model

Selected baseline: EOY linear benchmark. Candidate families include direct gain models, predicted EOY models, interaction surfaces, GAM smooths, random forests, gradient boosting, and an excluded teacher/course ID leakage check.

## Validation

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

| Metric | Estimate | 95% interval |
| --- | --- | --- |
| Expected-gain RMSE | 4.683 | 4.270 to 5.104 |
| Expected-gain MAE | 3.728 | 3.375 to 4.072 |
| Expected-gain R-squared | 0.101 | -0.007 to 0.186 |
| EOY RMSE | 4.683 | 4.270 to 5.104 |
| EOY R-squared | 0.932 | 0.916 to 0.944 |

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
