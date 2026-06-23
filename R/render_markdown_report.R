source(file.path("R", "model_utils.R"))

ensure_project_dirs()

required_tables <- c(
  file.path("reports", "education_extract_profile.csv"),
  file.path("reports", "model_comparison_display.csv"),
  file.path("reports", "parametric_family_review.csv"),
  file.path("reports", "final_metrics.csv"),
  file.path("reports", "metric_uncertainty.csv"),
  file.path("reports", "odds_ratios.csv"),
  file.path("reports", "calibration_table.csv"),
  file.path("reports", "calibration_diagnostics.csv"),
  file.path("reports", "threshold_table.csv"),
  file.path("reports", "decision_economics.csv"),
  file.path("reports", "decile_lift.csv"),
  file.path("reports", "subgroup_calibration.csv"),
  file.path("reports", "sensitivity_comparison.csv"),
  file.path("reports", "risk_categories.csv"),
  file.path("reports", "scenario_profiles.csv")
)

if (!all(file.exists(required_tables))) {
  source(file.path("R", "fit_risk_models.R"))
}

read_display_csv <- function(path, check_names = TRUE) {
  read.csv(
    path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = check_names
  )
}

readiness <- read.csv(
  file.path("data", "processed", "education_readiness_risk.csv"),
  stringsAsFactors = FALSE
)

extract_profile <- read_display_csv(file.path("reports", "education_extract_profile.csv"))
model_comparison <- read_display_csv(
  file.path("reports", "model_comparison_display.csv"),
  check_names = FALSE
)
family_review <- read_display_csv(file.path("reports", "parametric_family_review.csv"))
final_metrics <- read_display_csv(file.path("reports", "final_metrics.csv"))
metric_uncertainty <- read_display_csv(file.path("reports", "metric_uncertainty.csv"))
odds_ratios <- read_display_csv(file.path("reports", "odds_ratios.csv"))
calibration <- read_display_csv(file.path("reports", "calibration_table.csv"))
calibration_diagnostics <- read_display_csv(file.path("reports", "calibration_diagnostics.csv"))
thresholds <- read_display_csv(file.path("reports", "threshold_table.csv"))
decision_economics <- read_display_csv(file.path("reports", "decision_economics.csv"))
decile_lift <- read_display_csv(file.path("reports", "decile_lift.csv"))
subgroup_calibration <- read_display_csv(file.path("reports", "subgroup_calibration.csv"))
sensitivity <- read_display_csv(file.path("reports", "sensitivity_comparison.csv"))
risk_categories <- read_display_csv(file.path("reports", "risk_categories.csv"))
scenario_profiles <- read_display_csv(file.path("reports", "scenario_profiles.csv"))

metric_value <- function(metric_name) {
  final_metrics$Value[final_metrics$Metric == metric_name][1]
}

clean_label <- function(x) {
  x <- gsub("_", " ", x)
  x <- gsub("beginning of year", "beginning-of-year", x, fixed = TRUE)
  x <- gsub("end of year", "end-of-year", x, fixed = TRUE)
  x <- gsub("at risk", "at-risk", x, fixed = TRUE)
  x
}

extract_profile$Value <- clean_label(extract_profile$Value)
names(family_review) <- c("Family", "Why tested", "Decision", "CV loss", "Holdout AUC")
names(model_comparison) <- c(
  "Model", "Selected", "Role", "Params", "CV loss", "CV SD", "CV AUC",
  "Holdout loss", "Holdout AUC", "Delta"
)
names(metric_uncertainty) <- c("Metric", "Estimate", "95% CI")
names(odds_ratios) <- c("Predictor", "Scale", "Odds ratio", "95% CI", "p-value")
names(calibration) <- c("Band", "N", "Pred", "Obs", "Expected", "Cases")
names(calibration_diagnostics) <- c("Diagnostic", "Estimate", "Interpretation")
names(thresholds) <- c("Threshold", "Flagged", "Flagged %", "Captured", "Sens", "Spec", "PPV", "NPV")
names(decision_economics) <- c("Threshold", "Flagged", "Captured", "Benefit", "Cost", "Net")
names(decile_lift) <- c("Decile", "N", "Pred", "Obs", "Cases", "Lift", "Capture")
names(subgroup_calibration) <- c("Group", "Level", "N", "Pred", "Obs", "Gap", "Cases")
subgroup_calibration$Group <- clean_label(subgroup_calibration$Group)
subgroup_calibration$Level <- clean_label(subgroup_calibration$Level)
names(risk_categories) <- c("Category", "Students", "Share", "Pred", "Obs", "Cases")
names(sensitivity) <- c("Measure", "Primary", "Sensitivity")
names(scenario_profiles) <- c("Scenario", "Grade", "Track", "Window", "Attendance", "Readiness", "Risk", "95% CI", "Category")
scenario_profiles$Window <- clean_label(scenario_profiles$Window)
scenario_profiles$Attendance <- clean_label(scenario_profiles$Attendance)

selected_model <- metric_value("Selected model")
holdout_auc <- metric_value("Holdout AUC")
holdout_log_loss <- metric_value("Holdout log loss")
holdout_brier <- metric_value("Holdout Brier score")
cv_log_loss <- metric_value("CV log loss")
cv_auc <- metric_value("CV AUC")
holdout_event_rate <- metric_value("Holdout event rate")
shape_result <- metric_value("Shape discovery result")

threshold_50 <- thresholds[thresholds$Threshold == "50%", , drop = FALSE]
if (nrow(threshold_50) == 0) {
  threshold_50 <- thresholds[which.min(abs(as.numeric(gsub("%", "", thresholds$Threshold)) - 50)), , drop = FALSE]
}

top_two_capture <- decile_lift$Capture[decile_lift$Decile == 2][1]
top_decile_lift <- decile_lift$Lift[decile_lift$Decile == 1][1]
best_economic <- decision_economics[
  which.max(as.numeric(gsub("[$, ]", "", decision_economics$Net))),
  ,
  drop = FALSE
]

report_lines <- c(
  "# Education Readiness Risk Modeling in R",
  "",
  "## Recommendation",
  "",
  paste0(
    "Use **", selected_model,
    "** as an interpretable next-assessment support-risk model for public-safe education planning. ",
    "The model should rank students for human review and support planning; it should not automate academic decisions."
  ),
  "",
  paste0(
    "The selected model achieved holdout AUC **", holdout_auc,
    "**, log loss **", holdout_log_loss, "**, and Brier score **",
    holdout_brier, "**. Repeated cross-validation produced log loss **",
    cv_log_loss, "** and AUC **", cv_auc, "**."
  ),
  "",
  paste0(
    "At a ", threshold_50$Threshold[1], " support-review threshold, the workflow flags ",
    threshold_50$Flagged[1], " holdout student transitions (",
    threshold_50$`Flagged %`[1], "), captures ",
    threshold_50$Captured[1], " observed support-risk cases, and produces PPV ",
    threshold_50$PPV[1], ". This is an operating example; capacity and intervention policy should set the final threshold."
  ),
  "",
  paste0(
    "The ranking view is valuable even without a single cutoff: the highest-risk decile has ",
    top_decile_lift, " lift over the base rate, and the top two deciles capture ",
    top_two_capture, " of observed support-risk cases."
  ),
  "",
  "## Direct Answers",
  "",
  paste0("1. The primary modeled outcome is next-window support risk, defined as a next assessment score below 50 or next-window nonparticipation. The holdout event rate is ", holdout_event_rate, "."),
  paste0("2. The best operating model is **", selected_model, "**, selected from interpretable GLM candidates after comparing nonlinear and benchmark model families."),
  paste0("3. The mathematical discovery step matters: ", shape_result),
  "4. The model is strongest as a prioritization tool. Thresholds convert probabilities into workload, missed-risk, and precision tradeoffs.",
  "5. The analysis is public-safe: it uses simulated identifiers and generalized assessment behavior, and excludes private prompts, exams, real student-identifiable records, credentials, and private source documents.",
  "",
  "## Data Audit",
  "",
  "The analysis uses a public-safe assessment extract with one row per assessment window. The modeling table turns consecutive assessment windows into prediction records: current assessment information is used to predict support risk at the next assessment.",
  "",
  markdown_table(extract_profile),
  "",
  "The data is public-safe by design. Student, teacher, section, and course identifiers are simulated labels; score/readiness behavior is generalized from a bootstrapped assessment workflow and should not be treated as a real student-record extract.",
  "",
  "## Model Journey",
  "",
  "The model search followed the same statistical logic used in the private MS statistics work, but with an original public-safe education framing: inspect the shape first, test candidate parametric families second, and keep the final model interpretable unless a flexible benchmark clearly earns its complexity.",
  "",
  "![Nonparametric and parametric shape discovery](../figures/shape_discovery.png)",
  "",
  markdown_table(family_review),
  "",
  "Candidate logistic models were then compared with repeated stratified 5-fold cross-validation on the training split. Log loss is the primary criterion because a support-prioritization workflow needs useful probabilities, not only rank ordering.",
  "",
  markdown_table(model_comparison),
  "",
  "![Candidate model comparison](../figures/model_comparison.png)",
  "",
  "The selection rule favors the simplest non-benchmark model within one standard error of the best repeated-CV log loss. That rule protects the portfolio story from choosing a visually impressive model that does not materially improve validated probability quality.",
  "",
  "## Final Model",
  "",
  markdown_table(final_metrics),
  "",
  "Bootstrap intervals give a practical uncertainty band around the holdout metrics.",
  "",
  markdown_table(metric_uncertainty),
  "",
  "The adjusted odds ratios below translate the selected GLM into stakeholder-readable effects.",
  "",
  markdown_table(odds_ratios),
  "",
  "## Probability Scale",
  "",
  "Risk categories provide a bridge between calibrated probabilities and support workflows.",
  "",
  markdown_table(risk_categories),
  "",
  "A threshold turns probabilities into a work queue. Lower thresholds catch more support-risk cases but create more reviews; higher thresholds focus capacity but miss more students.",
  "",
  "![Threshold tradeoffs](../figures/threshold_tradeoff.png)",
  "",
  markdown_table(thresholds),
  "",
  "The table below uses illustrative support-planning economics to show how a threshold can be chosen from capacity and intervention assumptions. These values are scenario assumptions, not claims about a real school system.",
  "",
  markdown_table(decision_economics),
  "",
  "## Model Checks",
  "",
  "ROC checks ranking quality. Calibration checks whether predicted probabilities are on the right scale across ordered risk bands.",
  "",
  "![ROC and calibration diagnostics](../figures/roc_calibration.png)",
  "",
  markdown_table(calibration),
  "",
  markdown_table(calibration_diagnostics),
  "",
  "Subgroup calibration checks show where monitoring would matter before operational use. The table reports groups with at least 25 holdout records.",
  "",
  markdown_table(subgroup_calibration),
  "",
  "A ranked queue is often more useful than a single classification cutoff. The lift chart shows how concentrated support-risk cases are in the highest predicted-risk deciles.",
  "",
  "![Lift by predicted risk decile](../figures/lift_chart.png)",
  "",
  markdown_table(decile_lift),
  "",
  "## Sensitivity Check",
  "",
  "The sensitivity analysis lowers the support-risk score cut point from 50 to 45 and refits the selected model family. This tests whether the prioritization story depends on one particular threshold definition.",
  "",
  "![Sensitivity analysis](../figures/sensitivity_analysis.png)",
  "",
  markdown_table(sensitivity),
  "",
  "## Scenario Profiles",
  "",
  "Scenario profiles translate the model into concrete, public-safe support-planning examples with probability intervals.",
  "",
  "![Scenario readiness risk curves](../figures/scenario_readiness_curves.png)",
  "",
  markdown_table(scenario_profiles),
  "",
  "## Bottom Line",
  "",
  "- Use the model to prioritize human review and early support planning, not to automate student-level decisions.",
  "- Keep the piecewise readiness shape because it captures the discovered nonlinear risk pattern while staying easier to explain than a flexible spline.",
  "- Choose operating thresholds from review capacity, support cost, and tolerance for missed support-risk cases.",
  "- Monitor calibration by course track, assessment window, and attendance group before treating risk categories as stable operating labels.",
  "",
  "## Reproducibility",
  "",
  "Rebuild the full evidence packet with `make all`. The core pipeline uses base R, the included public-safe extract, and no credentials, private files, or network access.",
  "",
  "## Public-Safety Statement",
  "",
  "This report is an original public-safe portfolio artifact. It excludes private coursework prompts, exams, rubrics, syllabi, lecture transcripts, source datasets, personal data, patient data, school-private records, credentials, and copyrighted source documents."
)

writeLines(report_lines, file.path("reports", "statistical_risk_modeling_report.md"))

executive_lines <- c(
  "# Executive Brief: Education Readiness Risk Modeling",
  "",
  paste0("**Recommendation:** use the **", selected_model, "** to rank public-safe assessment transitions for human support review."),
  "",
  paste0("**Validation:** holdout AUC ", holdout_auc, ", log loss ", holdout_log_loss, ", Brier score ", holdout_brier, "."),
  "",
  paste0("**Model discovery:** ", shape_result),
  "",
  paste0("**Prioritization value:** top decile lift is ", top_decile_lift, "; top two deciles capture ", top_two_capture, " of observed support-risk cases."),
  "",
  paste0("**Operating option:** at the ", threshold_50$Threshold[1], " threshold, the model flags ", threshold_50$Flagged[1], " holdout transitions and captures ", threshold_50$Captured[1], " support-risk cases."),
  "",
  paste0("**Illustrative planning value:** strongest tested threshold is ", best_economic$Threshold[1], " with net value ", best_economic$Net[1], " under documented assumptions."),
  "",
  "## Decision Notes",
  "",
  "- Use the model as a review-prioritization layer, not an automated academic decision system.",
  "- Pick thresholds from support capacity and missed-risk tolerance, not from AUC alone.",
  "- Monitor calibration by course track, assessment window, and attendance group.",
  "- Treat flexible spline and periodic terms as benchmark checks; they do not replace the interpretable operating model unless validation materially improves."
)

writeLines(executive_lines, file.path("reports", "executive_brief.md"))

model_card_lines <- c(
  "# Model Card",
  "",
  "## Intended Use",
  "",
  "Prioritize public-safe assessment transitions for human support-review planning in a public-safe portfolio project.",
  "",
  "## Not Intended For",
  "",
  "Automated academic decisions, real student intervention assignment, grading, discipline, admissions, employment, clinical decisions, or use with private data without separate validation and governance.",
  "",
  "## Data",
  "",
  paste0("Public-safe education assessment records with ", format(nrow(readiness), big.mark = ","), " modeled transitions, simulated identifiers, generalized score/readiness behavior, and no real student-identifiable records."),
  "",
  "## Model",
  "",
  paste0("Selected model: ", selected_model, ". Candidate families include context-only, linear readiness, polynomial readiness, piecewise readiness, periodic benchmark, and spline benchmark specifications."),
  "",
  "## Performance",
  "",
  markdown_table(metric_uncertainty),
  "",
  "## Calibration",
  "",
  markdown_table(calibration_diagnostics),
  "",
  "## Monitoring Recommendations",
  "",
  "- Track calibration by course track, assessment window, and attendance group.",
  "- Recheck thresholds when support capacity or readiness definitions change.",
  "- Refit the model if the assessment sequence, attendance process, or student mix materially changes.",
  "",
  "## Public-Safety Boundary",
  "",
  "No private coursework prompts, raw private source datasets, credentials, real student records, patient records, or customer records are included."
)

writeLines(model_card_lines, file.path("docs", "model-card.md"))
message("Wrote reports/statistical_risk_modeling_report.md")
message("Wrote reports/executive_brief.md")
message("Wrote docs/model-card.md")
