# Model Card

## Intended Use

Estimate expected BOY/EOY assessment improvement and identify public-safe section-year groups whose growth is higher or lower than expected for instructional review.

## Not Intended For

Teacher evaluation, compensation, discipline, student placement, grading, employment, admissions, clinical decisions, or automated decisions with real student or personnel data.

## Data

Public-safe paired BOY/EOY assessment records with 1,737 modeled pairs, simulated identifiers, generalized score/readiness behavior, and no real student-identifiable or personnel records.

## Model

Selected expected-growth model: Readiness-augmented. Candidate families include context-only, linear BOY score, quadratic BOY score, piecewise BOY score, readiness-augmented, and spline benchmark specifications.

## Performance

| Metric | Value |
| --- | --- |
| Selected model | Readiness-augmented |
| Selection rule | Simplest non-benchmark model within one standard error of best repeated-CV RMSE |
| Training paired records | 1,389 |
| Holdout paired records | 348 |
| Repeated CV folds | 5 |
| Repeated CV repeats | 6 |
| CV RMSE | 4.700 |
| CV MAE | 3.773 |
| CV R-squared | 0.159 |
| Holdout RMSE | 4.399 |
| Holdout MAE | 3.512 |
| Holdout R-squared | 0.181 |
| Mean BOY score | 48.5 |
| Mean EOY score | 54.2 |
| Mean raw BOY/EOY gain | 5.72 |
| Section-year groups | 174 |

## Monitoring Recommendations

- Track BOY/EOY pairing rates and missing EOY assessments.
- Monitor section sizes before ranking or escalating section signals.
- Refit the model when course mix, assessment design, or attendance patterns change.
- Compare raw and adjusted growth before communicating section findings.

## Public-Safety Boundary

No private coursework prompts, raw private source datasets, credentials, real student records, real personnel records, patient records, or customer records are included.
