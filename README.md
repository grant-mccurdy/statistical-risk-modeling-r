# Statistical Risk Modeling in R

Public-safe statistical risk modeling project in R: built an interpretable
probability model, compared candidate models, validated performance, translated
predictions into risk categories, and documented decision-support implications.

This project demonstrates an end-to-end business analytics workflow using
synthetic B2B account-risk data. The modeled outcome is whether an account
requires an escalation review in the next quarter. The analysis is designed for
business analytics, BI, and data strategy portfolio review: it emphasizes
method clarity, validation, model diagnostics, and executive-facing
communication rather than private coursework context.

## What This Project Demonstrates

- Synthetic public-safe data generation for a binary risk outcome
- Logistic regression / GLM probability modeling in R
- Candidate model comparison using repeated stratified cross-validation
- Flexible spline benchmark to test whether nonlinear model families improve
  validation enough to justify added complexity
- Holdout validation with AUC, log loss, and Brier score
- Bootstrap uncertainty intervals for holdout metrics
- Coefficient and odds-ratio interpretation
- ROC, lift, calibration, and subgroup diagnostics
- Sensitivity analysis for a conservative missing-data assumption
- Risk-threshold interpretation and illustrative operating economics
- Scenario profiles with confidence intervals for executive communication
- Executive-ready written summary and resume bullets

## Reviewer Path

1. Read `reports/executive_brief.md` for the one-page leadership summary.
2. Read `reports/statistical_risk_modeling_report.md` for the rendered
   executive-facing analysis.
3. Review `docs/model-card.md` for intended use, limitations, and monitoring.
4. Review `docs/methodology.md` for modeling choices and validation logic.
5. Inspect `R/` for the reproducible base-R implementation.
6. Run `make all` to regenerate the synthetic dataset, model artifacts,
   report, figures, and public-safety validation.

## Quick Start

The build is intentionally package-free. It requires only R and `make`.

```bash
cd /home/grant/repos/public/statistical-risk-modeling-r
make all
```

If `make` is unavailable, run the same steps directly:

```bash
Rscript --vanilla R/generate_synthetic_data.R
Rscript --vanilla R/fit_risk_models.R
Rscript --vanilla R/render_markdown_report.R
Rscript --vanilla R/validate_public_safety.R
```

Optional RMarkdown rendering is available when `rmarkdown` is installed:

```bash
make report-rmd
```

## Current Structure

```text
statistical-risk-modeling-r/
├── R/
│   ├── generate_synthetic_data.R
│   ├── model_utils.R
│   ├── fit_risk_models.R
│   ├── render_markdown_report.R
│   ├── run_pipeline.R
│   └── validate_public_safety.R
├── data/
│   ├── raw/
│   │   └── README.md
│   └── processed/
├── docs/
│   ├── methodology.md
│   └── public-safety.md
├── figures/
├── reports/
│   ├── statistical_risk_modeling_report.Rmd
│   └── statistical_risk_modeling_report.md
├── Makefile
├── LICENSE
└── README.md
```

## Evidence Packet

The generated evidence packet includes:

- `data/processed/synthetic_account_risk.csv`
- `reports/statistical_risk_modeling_report.md`
- `reports/executive_brief.md`
- `docs/model-card.md`
- `reports/model_comparison.csv`
- `reports/final_metrics.csv`
- `reports/metric_uncertainty.csv`
- `reports/odds_ratios.csv`
- `reports/calibration_table.csv`
- `reports/calibration_diagnostics.csv`
- `reports/threshold_table.csv`
- `reports/decision_economics.csv`
- `reports/decile_lift.csv`
- `reports/subgroup_calibration.csv`
- `reports/sensitivity_comparison.csv`
- `reports/scenario_profiles.csv`
- `figures/model_comparison.png`
- `figures/roc_calibration.png`
- `figures/threshold_tradeoff.png`
- `figures/lift_chart.png`
- `figures/sensitivity_analysis.png`
- `figures/scenario_usage_curves.png`

## Validation Commands

```bash
make all       # rebuilds data, models, report, figures, and safety checks
make data      # regenerates the synthetic data
make model     # runs model comparison and diagnostics
make report    # renders the Markdown report
make validate  # checks for private-source identifiers and raw data leakage
```

## Dependency Notes

This project uses base R only. No package installation, API credentials, private
files, or network access are required.

## Public Safety

The repository uses fully synthetic account-risk records. It does not include
private course prompts, instructor materials, exams, syllabi, lecture
transcripts, raw coursework files, real student data, real patient data,
credentials, or private exports.

See `docs/public-safety.md` for the release notes and exclusion policy.

## Resume Bullets

- Built a public-safe R risk-modeling project using synthetic account data,
  logistic regression, repeated cross-validation, AUC/log-loss validation,
  bootstrap uncertainty intervals, and calibration diagnostics to support
  decision-ready probability modeling.
- Compared interpretable GLM candidates against a flexible spline benchmark,
  translated coefficients into odds ratios, and documented threshold economics
  for account-review prioritization.
- Produced an executive brief, model card, scenario profiles, and reproducible
  base-R pipeline that turns synthetic records into metrics, figures,
  sensitivity checks, and portfolio-ready evidence.
