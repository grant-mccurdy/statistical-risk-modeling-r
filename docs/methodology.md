# Methodology

## Analytical Question

Which public-safe course sections show unusually high or low BOY/EOY assessment
improvement after accounting for starting performance, readiness, attendance,
course track, grade level, and school-year context?

The project treats section and teacher summaries as instructional review
signals. They are not automated teacher evaluation, compensation, discipline, or
personnel decisions.

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

- Context baseline
- Linear BOY score
- Quadratic BOY score
- Piecewise BOY score
- Readiness-augmented
- Spline BOY score benchmark

Model comparison uses repeated 5-fold cross-validation with RMSE as the primary
criterion and MAE/R-squared as secondary metrics. The selected model is the
simplest non-benchmark model within one standard error of the best repeated-CV
RMSE.

## Section Signals

Section-year adjusted signals are calculated from average residuals and then
weighted toward zero for smaller groups. This reliability weighting prevents
small sections from dominating the ranking.

Signal categories are:

- Above expected
- Within expected range
- Below expected
- Small group

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
