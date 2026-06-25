# Methodology

## Analytical Question

Which teacher, course, and section patterns in the latest completed assessment
year deserve review before the next cycle after accounting for starting
performance, readiness, attendance, course track, grade level, and school-year
context?

The workflow is future-facing. Prior years train and select the expected-growth
baseline. The latest completed year is then scored against that prior-year
baseline to identify review targets. Section rows are evidence about the most
recent operating context; the outputs are not automated teacher evaluation,
compensation, discipline, or personnel decisions.

## Public-Safe BOY/EOY Extract

The analysis starts from a public-safe assessment-window extract. The processed
growth table pairs beginning-of-year and end-of-year records for the same
simulated student in the same school year.

A pair is included only when:

- BOY and EOY scores are both present
- the section is the same at BOY and EOY
- the simulated teacher is the same at BOY and EOY

This design keeps the growth metric tied to a section experience. It also means
the analysis excludes nonparticipating or section-changing pairs, so pairing
rates should be monitored before operational use.

## Raw Improvement

The headline raw metric is:

```text
BOY/EOY gain = EOY score - BOY score
```

For each section-year group, the report calculates mean BOY score, mean EOY
score, mean gain, confidence intervals, and a one-sample t-test of gain against
zero. This answers whether a section improved, but raw gain alone is not enough
for fair section comparison.

## Adjusted Growth Model

Raw gains are adjusted because sections differ in starting score, readiness,
attendance, course track, grade level, and school-year context. The model
estimates expected BOY/EOY gain, then computes:

```text
adjusted growth residual = observed gain - expected gain
```

Candidate expected-growth models include:

- Direct growth linear baselines
- Direct growth polynomial terms
- Interaction surfaces for baseline score, readiness, track, and attendance
- Cyclic school-year terms inspired by parametric shape discovery
- GAM smooths for nonlinear baseline/readiness/attendance/year effects
- Regression-tree candidates
- Random forest candidates
- Gradient boosting candidates
- Validation ensembles that average strong nonlinear and parametric candidates
- EOY-derived benchmarks that predict EOY first and then subtract BOY
- A teacher/course ID leakage benchmark that is excluded from operating
  selection

The model-selection process uses three validation views:

- Repeated 5-fold cross-validation on the training years to check sample
  stability.
- Leave-one-year-out temporal validation across the training years to test
  year-to-year generalization.
- Latest-year action evaluation after the baseline is selected, used to assess
  the year being reviewed but not to choose the model.

Temporal expected-gain RMSE is the primary selection criterion. When candidates
are within 0.01 points of the best leave-one-year-out temporal RMSE, repeated-CV
RMSE is used as the stability tie-breaker. Teacher IDs, course IDs, and section
IDs are excluded from the operating baseline because including them would absorb
the patterns the review layer is designed to surface. Those ID-heavy models are
reported only as leakage checks.

The report separates two validation views:

- Expected-gain performance: how well the model predicts BOY/EOY improvement
  directly.
- EOY baseline performance: how well the model predicts the final score before
  converting it to expected gain.

The EOY R-squared is expected to be higher because BOY score explains much of
final EOY score. Gain R-squared is lower because individual improvement remains
noisy after starting score is removed.

The purpose of the model is therefore not to maximize a visually impressive
EOY R-squared. It is to construct the strongest public-safe expected-growth
baseline available from prior-year information, then use aggregate residuals to
identify latest-year teacher, course, and section patterns that merit review.

## Latest-Year Decision Signals

After model selection, the chosen baseline is fit on the prior years and scored
on the latest completed year. Teacher, course, and section signals are
calculated from the latest-year residuals:

```text
review gap = observed gain - expected gain
```

Each slice receives a bootstrap confidence interval, p-value, BH-adjusted
q-value, and reliability weight. Reliability weighting prevents small groups
from dominating the ranking.

Signal categories are:

- Intervention target
- Positive anomaly
- Watch list
- In range
- Insufficient sample

The decision labels are audit priorities. They identify where stakeholders
should review context, support needs, pacing, curriculum alignment, or
transferable practices before the next cycle. They are not causal claims.

## Teacher and Course Review Signals

Teacher and course summaries aggregate latest-year section evidence into
future-facing review signals. The stakeholder-facing gap is the average
observed-minus-expected gain. The ranking signal applies reliability shrinkage
so smaller groups are pulled toward zero.

## Diagnostics and Sensitivity

The diagnostic layer includes:

- Raw BOY/EOY gain distribution
- Nonparametric BOY-score shape checks
- Candidate model comparison
- Temporal-validation diagnostics
- Latest-year prediction diagnostics
- Bootstrap performance intervals
- Residual checks
- Raw-vs-adjusted rank correlation
- Top-section overlap between raw and adjusted rankings
- Section-size sensitivity checks
- Model-search artifacts by family, tuned parameter grid, temporal validation,
  repeated CV, AIC/BIC for applicable parametric models, and bootstrap
  intervals for latest-year prediction performance
