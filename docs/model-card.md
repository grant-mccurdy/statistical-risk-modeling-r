# Model Card

## Intended Use

Prioritize synthetic B2B accounts for human escalation-review planning in a public-safe portfolio project.

## Not Intended For

Automated customer decisions, real account scoring, credit decisions, employment decisions, clinical decisions, or use with private data without separate validation.

## Data

Synthetic account-risk records generated locally with 1,400 rows and no private source data.

## Model

Selected model: Full operating model. Candidate models include baseline, usage, support, full operating, interaction, and spline benchmark specifications.

## Performance

| Metric | Estimate | Bootstrap_95_CI |
| --- | --- | --- |
| LogLoss | 0.422 | 0.346 to 0.515 |
| Brier | 0.129 | 0.103 to 0.160 |
| AUC | 0.719 | 0.637 to 0.797 |

## Calibration

| Diagnostic | Estimate | Interpretation |
| --- | --- | --- |
| Calibration intercept | 0.035 | Near 0 means predicted risk is not systematically high or low |
| Calibration slope | 0.655 | Near 1 means predicted probabilities are not overly extreme or compressed |

## Monitoring Recommendations

- Track calibration by segment and implementation complexity.
- Recheck threshold economics when review staffing, support processes, or escalation cost assumptions change.
- Refit the model if usage distributions or support-ticket patterns drift materially.

## Public-Safety Boundary

No private coursework prompts, raw source datasets, credentials, student records, patient records, or customer records are included.
