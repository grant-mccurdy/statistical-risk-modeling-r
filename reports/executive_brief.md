# Executive Brief: Support Review Prioritization

**Purpose:** identify which public-safe assessment transitions should be reviewed first before the next assessment window when support capacity is limited.

**Recommendation:** start with a 50% support-review threshold. It flags 326 of 666 holdout transitions (48.9%) and captures 298 of 347 observed support-risk cases.

**Capacity option:** if the team needs a smaller review queue, the 65% threshold flags 283 transitions and captures 267 of 347 observed support-risk cases.

**Why the model is useful:** current readiness provides meaningful signal, and the highest-risk decile has 1.92x lift over the base rate. The top two deciles capture 38.3% of observed support-risk cases.

**Technical support:** the operating model is Piecewise readiness, with holdout AUC 0.938, log loss 0.309, and Brier score 0.093.

**Model discovery:** Nonparametric smoothing supported a threshold-like readiness curve; piecewise and polynomial candidates were tested against spline and periodic benchmarks. Flexible spline and periodic terms were retained as benchmarks, not as the operating recommendation.

**Illustrative planning value:** strongest tested threshold is 45% with net value $43,200 under documented support-planning assumptions.

## Decisions for Stakeholders

- Confirm the review capacity that can be handled before the next assessment window.
- Use risk categories as workflow labels: monitor, watch, review, and priority review.
- Keep the score as a human review queue, not an automated placement, grading, discipline, or intervention assignment rule.
- Monitor calibration by course track, assessment window, and attendance group before operational use.
