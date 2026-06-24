# Methodology

## Analytical Question

Which future teacher and course review priorities are supported by seven years
of public-safe BOY/EOY assessment history after accounting for starting
performance, readiness, attendance, course track, grade level, and school-year
context?

Historical section-year groups are treated as evidence. Future action targets
are recurring teacher and course patterns, not old sections that no longer
exist. The outputs are not automated teacher evaluation, compensation,
discipline, or personnel decisions.

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

- Direct gain linear baselines
- Predicted EOY linear baselines
- Interaction surfaces for baseline score, readiness, track, and attendance
- GAM smooths for nonlinear baseline/readiness/attendance/year effects
- Random forest candidates
- Gradient boosting candidates
- A teacher/course ID leakage benchmark that is excluded from operating
  selection

Model comparison uses repeated 5-fold cross-validation with RMSE as the primary
criterion and MAE/R-squared as secondary metrics. The selected model is the
operational candidate with the lowest repeated-CV expected-gain RMSE. Teacher
IDs, course IDs, and section IDs are excluded from the operating baseline
because including them would absorb the recurring patterns the review layer is
designed to surface.

The report separates two validation views:

- Expected-gain performance: how well the model predicts BOY/EOY improvement
  directly.
- EOY baseline performance: how well the model predicts the final score before
  converting it to expected gain.

The EOY R-squared is expected to be higher because BOY score explains much of
final EOY score. Gain R-squared is lower because individual improvement remains
noisy after starting score is removed.

## Section Signals

Section-year adjusted signals are calculated from average residuals and then
weighted toward zero for smaller groups. This reliability weighting prevents
small sections from dominating the ranking.

Signal categories are:

- Above expected
- Within expected range
- Below expected
- Small group

## Teacher and Course Review Signals

Teacher and course summaries aggregate historical section evidence into
future-facing review signals. The stakeholder-facing gap is the average
observed-minus-expected gain. The ranking signal applies reliability shrinkage
so smaller groups are pulled toward zero.

## Diagnostics and Sensitivity

The diagnostic layer includes:

- Raw BOY/EOY gain distribution
- Nonparametric BOY-score shape checks
- Candidate model comparison
- Holdout prediction diagnostics
- Residual checks
- Raw-vs-adjusted rank correlation
- Top-section overlap between raw and adjusted rankings
- Section-size sensitivity checks
