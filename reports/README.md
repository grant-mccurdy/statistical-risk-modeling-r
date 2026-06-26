# Reports

Primary preview artifact:

[assessment_growth_section_performance_report.pdf](assessment_growth_section_performance_report.pdf)

This PDF is the reviewer-ready report for the project. It is generated from
`assessment_growth_section_performance_report.Rmd` and should be treated as the
main portfolio preview artifact.

Other useful report files:

- `executive_brief.md`: one-page leadership summary.
- `assessment_growth_section_performance_report.md`: GitHub-readable Markdown
  version of the full report.
- `growth_extract_profile.csv`: BOY/EOY paired extract summary.
- `growth_model_comparison.csv`: repeated-CV, rolling-origin temporal, and
  latest-year expected-growth model comparison.
- `growth_model_comparison_display.csv`: reviewer-facing model-comparison
  table.
- `growth_model_search_grid.csv`: full candidate grid with family, tuning,
  eligibility, validation metrics, AIC/BIC where available, and leakage status.
- `growth_model_strength.csv`: naive benchmark comparison for the selected
  expected-growth baseline.
- `growth_model_family_summary.csv`: best candidate by model family.
- `growth_model_selection_rationale.csv`: selected baseline and decision-rule
  summary.
- `growth_final_metrics.csv`: selected model and validation summary.
- `model_temporal_validation.csv`: compatibility copy of rolling-origin
  validation results used for baseline selection.
- `rolling_origin_validation.csv`: year-by-year validation where each year is
  predicted using only earlier years.
- `process_validation.csv`: process-level holdout results for a fast subset of
  candidate families.
- `locked_holdout_validation.csv`: latest-year holdout review after the
  operating baseline is selected.
- `model_validity_targets.csv`: decision-grade target gates and pass/fail
  status.
- `model_signal_ceiling.csv`: aggregate signal ceiling diagnostics by student,
  section, course, and teacher means.
- `null_permutation_benchmark.csv`: null-label benchmark for prediction signal
  sanity checking.
- `feature_importance.csv`: locked-holdout permutation importance for selected
  predictors.
- `feature_stability.csv`: feature-importance stability across perturbations.
- `flag_stability.csv`: bootstrap stability of latest-year review flags.
- `model_bootstrap_validation.csv`: bootstrap uncertainty intervals for
  latest-year model performance.
- `shrinkage_status.csv`: mixed-effects shrinkage review status.
- `shrinkage_review.csv`: partially pooled teacher/course/section residual
  review table.
- `review_evidence_reconciliation.csv`: primary latest-year review packet that
  reconciles adjusted gaps, bootstrap stability, shrinkage, and multiple-review
  control into stakeholder-readable evidence labels.
- `intervention_targets.csv`: compatibility artifact for latest-year teacher,
  course, and section review targets with intervals, p-values, q-values, and
  decision labels.
- `latest_teacher_review.csv`: latest-year teacher-level review table.
- `latest_course_review.csv`: latest-year course-level review table.
- `latest_section_review.csv`: latest-year section-level review table.
- `future_review_priorities.csv`: compact future-facing review-priority table.
- `historical_section_evidence.csv`: compatibility table with latest action-year
  evidence behind the review priorities.
- `model_dependency_status.csv`: optional modeling packages used or skipped.
- `section_ttests.csv`: raw section-year BOY/EOY improvement tests.
- `section_adjusted_signals.csv`: adjusted section-year growth signals.
- `teacher_growth_summary.csv`: public-safe teacher-level summary view.
- `course_growth_summary.csv`: course-level summary view.
- `growth_diagnostics.csv`: latest-year model and residual diagnostics.
- `growth_sensitivity.csv`: raw-vs-adjusted ranking sensitivity checks.
