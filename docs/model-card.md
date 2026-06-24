# Model Card

## Intended Use

Estimate an expected BOY/EOY assessment-growth baseline and identify public-safe teacher/course patterns that deserve future instructional review.

## Not Intended For

Teacher evaluation, compensation, discipline, student placement, grading, employment, admissions, clinical decisions, or automated decisions with real student or personnel data.

## Data

Public-safe paired BOY/EOY assessment records with 1,737 modeled pairs, simulated identifiers, generalized score/readiness behavior, and no real student-identifiable or personnel records.

## Model

Selected baseline: EOY readiness model. Candidate families include direct gain models, predicted EOY models, interaction surfaces, GAM smooths, random forests, gradient boosting, and an excluded teacher/course ID leakage check.

## Performance

| Metric | Value |
| --- | --- |
| Selected model | EOY readiness model |
| Selected target strategy | Predicted EOY |
| Selected method | Linear model |
| Selection rule | Lowest repeated-CV expected-gain RMSE among operational candidates; teacher/course ID leakage benchmark excluded |
| Training paired records | 1,389 |
| Holdout paired records | 348 |
| Candidate models tested | 13 |
| Operational candidates tested | 12 |
| Excluded leakage benchmarks | 1 |
| Repeated CV folds | 5 |
| Repeated CV repeats | 3 |
| CV expected-gain RMSE | 4.705 |
| CV expected-gain MAE | 3.774 |
| CV expected-gain R-squared | 0.158 |
| CV EOY R-squared | 0.937 |
| Holdout expected-gain RMSE | 4.400 |
| Holdout expected-gain MAE | 3.514 |
| Holdout expected-gain R-squared | 0.180 |
| Holdout EOY RMSE | 4.400 |
| Holdout EOY R-squared | 0.947 |
| Mean BOY score | 48.5 |
| Mean EOY score | 54.2 |
| Mean raw BOY/EOY gain | 5.72 |
| Section-year groups | 174 |

## Monitoring Recommendations

- Track BOY/EOY pairing rates and missing EOY assessments.
- Monitor section sizes before ranking or escalating signals.
- Refit the model when course mix, assessment design, or attendance patterns change.
- Keep teacher, course, and section IDs out of the operating baseline when the goal is to surface those patterns for review.
- Compare raw and adjusted growth before communicating findings.

## Public-Safety Boundary

No private coursework prompts, raw private source datasets, credentials, real student records, real personnel records, patient records, or customer records are included.
