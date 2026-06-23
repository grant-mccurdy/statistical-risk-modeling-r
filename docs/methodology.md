# Methodology

## Analytical Question

Which public-safe assessment transitions are most likely to require support
review at the next assessment window, and how should a support team translate
predicted probabilities into review thresholds?

The project treats the model as decision support. Predictions rank public-safe
assessment transitions for human review and planning; they are not automated
academic decisions.

## Public-Safe Education Extract

The analysis starts from a public-safe assessment extract with one row per
assessment window. Identifiers and institutional context are simulated, while
score/readiness behavior is generalized from a bootstrapped assessment workflow.
The modeling table converts consecutive assessment windows into prediction
records: current-window information predicts whether the next window crosses
the support-risk definition.

The primary binary outcome is `support_risk_next`, defined as a next assessment
score below 50 or next-window nonparticipation. A sensitivity outcome lowers
the score cut point to 45.

Predictors include:

- Current readiness
- Current assessment window
- Course track
- Grade level
- Attendance category and attendance probability
- Current assessment participation
- Assessment sequence timing

## Model Discovery

The workflow separates shape discovery from model selection.

First, binned risk rates and kernel smooths inspect the relationship between
current readiness and next-window support risk. This identifies whether a simple
linear probability shape is adequate or whether the curve has a threshold-like
or nonlinear form.

Second, candidate parametric logistic models are compared:

- Context baseline
- Linear readiness
- Quadratic readiness
- Cubic polynomial readiness
- Piecewise readiness
- Periodic context benchmark
- Spline readiness benchmark

The polynomial, periodic, and spline families are included to test whether a
more flexible shape materially improves validated probability quality. The
final operating model is selected from interpretable GLM candidates unless a
benchmark clearly earns its added complexity.

## Validation

Model comparison uses repeated stratified 5-fold cross-validation on the
training split. Log loss is the primary metric because the workflow needs
probabilities that are useful on the risk scale. AUC and Brier score are
reported as secondary metrics.

The selected model is then evaluated on a holdout split. Bootstrap intervals
provide practical uncertainty ranges around holdout log loss, Brier score, and
AUC.

## Diagnostics

The diagnostic layer includes:

- ROC curve and holdout AUC
- Calibration table and calibration plot
- Calibration intercept and slope
- Bootstrap metric intervals
- Decile lift and cumulative support-risk capture
- Subgroup calibration by course track, assessment window, and attendance group
- Threshold operating table
- Sensitivity analysis for the alternate support-risk definition

## Interpretation

The report translates model coefficients into odds ratios and uses scenario
profiles to show how predicted risk changes across readiness levels. Threshold
tables convert probabilities into review workload, sensitivity, specificity,
precision, and missed-risk tradeoffs.
