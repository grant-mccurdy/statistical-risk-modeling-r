# Executive Brief: Education Readiness Risk Modeling

**Recommendation:** use the **Piecewise readiness** to rank public-safe assessment transitions for human support review.

**Validation:** holdout AUC 0.938, log loss 0.309, Brier score 0.093.

**Model discovery:** Nonparametric smoothing supported a threshold-like readiness curve; piecewise and polynomial candidates were tested against spline and periodic benchmarks.

**Prioritization value:** top decile lift is 1.92x; top two deciles capture 38.3% of observed support-risk cases.

**Operating option:** at the 50% threshold, the model flags 326 holdout transitions and captures 298 of 347 support-risk cases.

**Illustrative planning value:** strongest tested threshold is 45% with net value $43,200 under documented assumptions.

## Decision Notes

- Use the model as a review-prioritization layer, not an automated academic decision system.
- Pick thresholds from support capacity and missed-risk tolerance, not from AUC alone.
- Monitor calibration by course track, assessment window, and attendance group.
- Treat flexible spline and periodic terms as benchmark checks; they do not replace the interpretable operating model unless validation materially improves.
