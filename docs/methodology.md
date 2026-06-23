# Methodology

## Analytical Question

Which accounts are most likely to require escalation review in the next
quarter, and how should a business team interpret risk thresholds when review
capacity is limited?

The project treats the model as a decision-support tool, not an automated
decision system. Predictions rank accounts for human review and planning.

## Synthetic Dataset

The data generator creates account-level records with realistic business-risk
signals:

- Contract value and tenure
- Customer segment and region
- Product usage and active-seat ratio
- Training completion
- Support ticket load and response time
- Prior incident history
- Implementation complexity

The binary target, `escalation_flag`, is generated from a known logistic data
generating process. The true generating probability is not included in the
analysis dataset, so the modeling workflow behaves like a normal analyst
project.

## Model Candidates

The analysis compares several logistic regression candidates:

- Baseline exposure model
- Usage behavior model
- Support load model
- Full operating model
- Full model with a usage-by-support interaction
- Spline operating benchmark

The selection criterion is repeated stratified cross-validation log loss on the
training set. AUC and Brier score are reported as secondary validation metrics.
The selected model is then evaluated on a holdout set.

The spline benchmark is included as a flexible model-family check. It tests
whether nonlinear usage, seat-activation, and support-response patterns improve
validated probability quality enough to justify less direct interpretation. The
operating model is selected from interpretable GLM candidates so the final
recommendation can be communicated through odds ratios, risk categories, and
scenario profiles.

## Metrics

- **Log loss** measures probability quality and heavily penalizes confident
  wrong predictions.
- **AUC** measures ranking quality across all thresholds.
- **Brier score** measures squared probability error.
- **Calibration** compares predicted risk to observed event rates across risk
  bands.
- **Lift** measures how strongly the model concentrates events in the top-ranked
  account groups.
- **Bootstrap intervals** provide practical uncertainty ranges around holdout
  metrics.

## Interpretation

The report translates model coefficients into odds ratios and explains each
term on a business-friendly scale. It also includes operating-characteristic
tables for candidate review thresholds so stakeholders can see the tradeoff
between workload, sensitivity, specificity, and precision.

The project also includes scenario profiles with probability confidence bands.
These translate the model into concrete account-review examples without using
real customers or private data.

## Sensitivity Analysis

The primary preprocessing strategy imputes missing training completion using
segment medians and adds a missingness indicator. The sensitivity check uses a
more conservative assumption: missing training completion is treated as zero.
The report compares metrics, risk-category movement, and prediction differences
under this alternate assumption.

## Diagnostics

The diagnostic layer includes:

- ROC curve and holdout AUC
- Calibration table and calibration plot
- Calibration intercept and slope
- Bootstrap metric intervals
- Decile lift and cumulative event capture
- Threshold operating table
- Illustrative decision economics table
- Segment-level calibration review
- Sensitivity analysis for missing-data handling
