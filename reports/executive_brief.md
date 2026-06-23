# Executive Brief: Statistical Risk Modeling in R

**Recommendation:** use the **Full operating model** as an interpretable account-review prioritization model.

**Validation:** holdout AUC 0.719, log loss 0.422, Brier score 0.129.

**Prioritization value:** top decile lift is 2.71x; top two deciles capture 50.0% of observed escalations.

**Operating option:** at the 20% threshold, the model flags 77 accounts and captures 28 of 48 observed escalations.

**Illustrative economics:** strongest tested threshold is 15% with net value $127,350 under documented assumptions.

## Decision Notes

- Use the model to rank accounts for human review rather than automate account decisions.
- Pick thresholds from capacity and intervention economics, not from AUC alone.
- Monitor segment-level calibration before adopting risk categories as stable operating labels.
- Treat the spline benchmark as a model-family stress test; it did not justify replacing the interpretable GLM.
