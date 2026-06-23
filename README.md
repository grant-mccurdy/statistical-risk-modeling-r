# Assessment Growth and Section Performance Analytics in R

Public-safe education analytics project in R that evaluates beginning-of-year
to end-of-year assessment improvement and identifies section-level growth
signals. The report answers a stakeholder question first: which course sections
improved more or less than expected after accounting for starting performance,
readiness, attendance, course track, grade level, and school-year context?

The extract uses simulated identifiers and generalized readiness behavior from
a bootstrapped assessment workflow. It is not a release of the original
assessment artifacts or real student-level records. The project is designed for
business analytics, BI, education analytics, and data strategy portfolio review:
the emphasis is decision framing, BOY/EOY improvement analysis, adjusted growth
modeling, section performance signals, validation, and clear communication.

Portfolio page:
https://grant-mccurdy.github.io/projects/statistical-risk-modeling-r.html

## Primary Preview

Open the knitted PDF report first:

[reports/assessment_growth_section_performance_report.pdf](reports/assessment_growth_section_performance_report.pdf)

This is the primary reviewer artifact. It uses a formal statistics-report
structure: recommendation and direct answers first, data audit next, then raw
section improvement, adjusted growth modeling, section signals, diagnostics,
and public-safety notes.

![Sections above or below expected growth](figures/section_adjusted_signals.png)

## Stakeholder Preview

- **Purpose:** identify public-safe course sections with unusually high or low
  BOY/EOY improvement.
- **Headline metric:** average raw BOY/EOY gain is 5.72 points across 1,737
  paired records.
- **Analytic layer:** compare observed section gain with expected gain after
  controlling for starting score/readiness, attendance, course track, grade
  level, and school-year context.
- **Guardrail:** use section signals for instructional review and follow-up,
  not automated teacher evaluation or personnel decisions.

## Technical Skills Demonstrated

- Public-safe bootstrapped/generalized education extract and reproducible
  BOY/EOY growth table
- Paired section improvement analysis and confidence intervals
- Adjusted expected-growth modeling in R
- Candidate-family comparison across context-only, linear, quadratic,
  piecewise, readiness-augmented, and spline specifications
- Repeated cross-validation using RMSE and MAE
- Holdout validation and residual diagnostics
- Reliability-weighted section performance signals
- Teacher/course summary views for instructional review
- Sensitivity checks comparing raw and adjusted section rankings
- Executive-facing communication with public-safety guardrails

## Reviewer Path

1. Open `reports/assessment_growth_section_performance_report.pdf` for the
   primary preview report.
2. Read `reports/executive_brief.md` for the one-page leadership summary.
3. Review `docs/model-card.md` for intended use, limitations, and monitoring.
4. Review `docs/data-dictionary.md` for modeling table definitions.
5. Review `docs/methodology.md` for modeling choices and validation logic.
6. Inspect `R/` for the reproducible base-R implementation.
7. Run `make all` to regenerate the public-safe extract, model artifacts,
   report, figures, and public-safety validation.

## Quick Start

The core build uses base R and `make`.

```bash
cd /home/grant/repos/public/statistical-risk-modeling-r
make all
```

If `make` is unavailable, run the same steps directly:

```bash
Rscript --vanilla R/generate_synthetic_data.R
Rscript --vanilla R/fit_growth_models.R
Rscript --vanilla R/render_markdown_report.R
Rscript --vanilla R/validate_public_safety.R
```

Optional PDF rendering is available when `rmarkdown`, Pandoc, and a LaTeX
engine such as `xelatex` are installed:

```bash
make report-pdf
```

## Current Structure

```text
statistical-risk-modeling-r/
├── R/
│   ├── generate_synthetic_data.R
│   ├── model_utils.R
│   ├── fit_growth_models.R
│   ├── render_markdown_report.R
│   ├── run_pipeline.R
│   └── validate_public_safety.R
├── data/
│   ├── raw/
│   │   ├── README.md
│   │   └── synthetic_education_assessment_long.csv
│   └── processed/
├── docs/
│   ├── methodology.md
│   ├── data-dictionary.md
│   ├── model-card.md
│   └── public-safety.md
├── figures/
├── reports/
│   ├── README.md
│   ├── assessment_growth_section_performance_report.Rmd
│   ├── assessment_growth_section_performance_report.md
│   ├── assessment_growth_section_performance_report.pdf
│   └── executive_brief.md
├── Makefile
├── LICENSE
└── README.md
```

## Evidence Packet

The generated evidence packet includes:

- `data/raw/synthetic_education_assessment_long.csv`
- `data/processed/education_section_growth.csv`
- `reports/assessment_growth_section_performance_report.pdf`
- `reports/assessment_growth_section_performance_report.md`
- `reports/executive_brief.md`
- `docs/data-dictionary.md`
- `docs/model-card.md`
- `reports/growth_model_comparison.csv`
- `reports/growth_final_metrics.csv`
- `reports/section_ttests.csv`
- `reports/section_adjusted_signals.csv`
- `reports/teacher_growth_summary.csv`
- `reports/course_growth_summary.csv`
- `reports/growth_diagnostics.csv`
- `reports/growth_sensitivity.csv`
- `figures/growth_distribution.png`
- `figures/baseline_growth_shape.png`
- `figures/growth_model_comparison.png`
- `figures/section_adjusted_signals.png`
- `figures/teacher_course_summary.png`
- `figures/growth_diagnostics.png`

## Validation Commands

```bash
make all        # rebuilds data, models, report, figures, and safety checks
make data       # regenerates the modeling extract
make model      # runs model comparison and diagnostics
make report     # renders the Markdown report
make report-pdf # renders the knitted PDF report
make validate   # checks public-safety rules
```

## Dependency Notes

The core pipeline uses base R only:

```bash
make all
```

The optional knitted PDF target uses `rmarkdown`, `knitr`, Pandoc, and
`pdflatex`. No API credentials, private files, or network access are required.

## Public Safety

The repository uses public-safe education assessment records with simulated
identifiers and generalized score/readiness behavior. It does not include
private course prompts, instructor materials, exams, syllabi, lecture
transcripts, raw private coursework files, real student-identifiable data, real
patient data, credentials, or private exports.

See `docs/public-safety.md` for the release notes and exclusion policy.
