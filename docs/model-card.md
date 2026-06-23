# Model Card

## Intended Use

Prioritize public-safe assessment transitions for human support-review planning in a public-safe portfolio project.

## Not Intended For

Automated academic decisions, real student intervention assignment, grading, discipline, admissions, employment, clinical decisions, or use with private data without separate validation and governance.

## Data

Public-safe education assessment records with 3,322 modeled transitions, simulated identifiers, generalized score/readiness behavior, and no real student-identifiable records.

## Model

Selected model: Piecewise readiness. Candidate families include context-only, linear readiness, polynomial readiness, piecewise readiness, periodic benchmark, and spline benchmark specifications.

## Performance

| Metric | Estimate | 95% CI |
| --- | --- | --- |
| LogLoss | 0.309 | 0.268 to 0.352 |
| Brier | 0.093 | 0.079 to 0.107 |
| AUC | 0.938 | 0.919 to 0.955 |

## Calibration

| Diagnostic | Estimate | Interpretation |
| --- | --- | --- |
| Calibration intercept | 0.165 | Near 0 means predicted risk is not systematically high or low |
| Calibration slope | 1.025 | Near 1 means predicted probabilities are not overly extreme or compressed |

## Monitoring Recommendations

- Track calibration by course track, assessment window, and attendance group.
- Recheck thresholds when support capacity or readiness definitions change.
- Refit the model if the assessment sequence, attendance process, or student mix materially changes.

## Public-Safety Boundary

No private coursework prompts, raw private source datasets, credentials, real student records, patient records, or customer records are included.
