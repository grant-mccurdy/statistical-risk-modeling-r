# Methodology

## Analytical Question

Which teacher, course, and section patterns in the latest completed assessment
year deserve review before the next cycle after accounting for starting
performance, prior-year history, readiness, attendance, course track, grade
level, section composition, and school-year context?

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
prior-year performance history, attendance, course track, grade level, section
composition, and school-year context. The model estimates expected BOY/EOY
gain, then computes:

```text
adjusted growth residual = observed gain - expected gain
```

Candidate expected-growth models include:

- A naive prior-year mean-growth benchmark
- Direct growth linear baselines
- Lagged-history and section-composition parametric models
- Feature-engineered parametric models using BOY score bands, prior student
  history, prior trend and volatility, lagged teacher/course context, section
  composition, and selected interactions
- Direct growth polynomial terms
- Interaction surfaces for baseline score, readiness, track, and attendance
- Cyclic school-year terms inspired by parametric shape discovery
- GAM smooths for nonlinear baseline/readiness/attendance/year effects
- Regularized ridge, elastic-net, and lasso candidates
- Regression-tree candidates
- Random forest candidates
- Ranger forest candidates
- Gradient boosting candidates
- Adaptive MARS candidates
- Validation ensembles that average strong nonlinear, regularized, and
  parametric candidates
- Stacked ensembles that learn blend weights from out-of-fold predictions
- EOY-derived benchmarks that predict EOY first and then subtract BOY
- A teacher/course ID leakage benchmark that is excluded from operating
  selection

The model-selection process uses several validation views:

- Repeated 5-fold cross-validation on the training years to check sample
  stability.
- Rolling-origin temporal validation across the training years. Each validation
  year is predicted using only earlier years, so the validation design matches
  the future-facing deployment problem.
- Process validation on a fast subset of candidate families to check whether
  the search procedure itself remains stable when earlier years are held out.
- A locked latest-year holdout after the baseline is selected, used to assess
  the year being reviewed but not to choose the model.
- Bootstrap intervals, feature-stability checks, flag-stability checks, and a
  null-permutation benchmark as supporting diagnostics.

Temporal expected-gain RMSE is the primary selection criterion. When candidates
are within 0.01 points of the best rolling-origin temporal RMSE, repeated-CV
RMSE is used as the stability tie-breaker. Teacher IDs, course IDs, and section
IDs are excluded from the operating baseline because including them would absorb
the patterns the review layer is designed to surface. ID-heavy models and
future-planning variants that use lagged teacher/course context are reported
separately from the same-year judgment baseline.

The selected model must also beat the naive mean-growth benchmark on temporal
RMSE, temporal MAE, and latest-year RMSE. This check prevents the report from
using a complex baseline when a simple prior-year mean would perform as well.
The report also applies strict decision-grade targets for RMSE lift, MAE lift,
individual gain R-squared, aggregate teacher/course/section fit, and residual
bias. If the targets are not met, the report is required to describe the output
as directional review evidence instead of a definitive rating system.

The report separates two validation views:

- Expected-gain performance: how well the model predicts BOY/EOY improvement
  directly.
- EOY baseline performance: how well the model predicts the final score before
  converting it to expected gain.
- Aggregate planning performance: how well expected gain tracks teacher,
  course, and section mean growth, which is the level where review decisions
  are made.

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

A second shrinkage review fits a mixed-effects model on latest-year residuals
with teacher, course, and section random effects. This layer estimates those
review effects simultaneously and partially pools noisier groups toward zero.
It is used as supporting review evidence, not as the expected-growth baseline.

Signal categories are:

- Priority review
- Bright spot
- Watch
- In range
- Insufficient sample

The review labels are audit priorities. They identify where stakeholders should
review context, support needs, pacing, curriculum alignment, or transferable
practices before the next cycle. They are not causal claims.

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
- Rolling-origin temporal-validation diagnostics
- Process-validation, locked-holdout, null-permutation, and feature-stability
  diagnostics
- Latest-year prediction diagnostics
- Bootstrap performance intervals
- Naive-benchmark improvement checks
- Mixed-effects shrinkage review of latest-year residual patterns
- Residual checks
- Raw-vs-adjusted rank correlation
- Top-section overlap between raw and adjusted rankings
- Section-size sensitivity checks
- Model-search artifacts by family, tuned parameter grid, rolling-origin
  validation, repeated CV, AIC/BIC for applicable parametric models, and
  bootstrap intervals for latest-year prediction performance
