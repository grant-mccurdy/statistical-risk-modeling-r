source(file.path("R", "model_utils.R"))

ensure_project_dirs()

required_tables <- c(
  file.path("reports", "model_comparison_display.csv"),
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

account_risk <- read.csv(
  file.path("data", "processed", "synthetic_account_risk.csv"),
  stringsAsFactors = FALSE
)

model_comparison <- read_display_csv(
  file.path("reports", "model_comparison_display.csv"),
  check_names = FALSE
)
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

selected_model <- metric_value("Selected model")
holdout_auc <- metric_value("Holdout AUC")
holdout_log_loss <- metric_value("Holdout log loss")
holdout_brier <- metric_value("Holdout Brier score")
cv_log_loss <- metric_value("CV log loss")
cv_auc <- metric_value("CV AUC")

threshold_20 <- thresholds[thresholds$Threshold == "20%", , drop = FALSE]
if (nrow(threshold_20) == 0) {
  threshold_20 <- thresholds[1, , drop = FALSE]
}
top_two_capture <- decile_lift$Cumulative_capture[decile_lift$Decile == 2][1]
top_decile_lift <- decile_lift$Lift[decile_lift$Decile == 1][1]
best_economic <- decision_economics[
  which.max(as.numeric(gsub("[$, ]", "", decision_economics$Net_value))),
  ,
  drop = FALSE
]

event_rate <- mean(account_risk$escalation_flag)
missing_training_rate <- mean(is.na(account_risk$training_completion_rate))

report_lines <- c(
  "# Statistical Risk Modeling in R",
  "",
  "## Executive Summary",
  "",
  paste0(
    "This public-safe project models the probability that a synthetic B2B ",
    "account will require escalation review in the next quarter. The selected ",
    "interpretable GLM is **", selected_model, "**, chosen using repeated ",
    "stratified cross-validation and checked on a holdout set."
  ),
  "",
  paste0(
    "On the holdout set, the model achieved AUC **", holdout_auc,
    "**, log loss **", holdout_log_loss, "**, and Brier score **",
    holdout_brier, "**. Cross-validation produced log loss **", cv_log_loss,
    "** and AUC **", cv_auc, "** for the selected model."
  ),
  "",
  paste0(
    "At a ", threshold_20$Threshold[1], " review threshold, the workflow flags ",
    threshold_20$Flagged[1], " holdout accounts (",
    threshold_20$Flagged_share[1], "), captures ",
    threshold_20$Events_captured[1], " observed escalations, and produces PPV ",
    threshold_20$PPV[1], ". This threshold is a planning option, not a final ",
    "policy: review capacity and intervention cost should set the operating point."
  ),
  "",
  paste0(
    "The ranking view is stronger than a threshold alone: the highest-risk decile ",
    "has ", top_decile_lift, " lift over the base event rate, and the top two ",
    "deciles capture ", top_two_capture, " of observed escalations. Under the ",
    "illustrative economics assumptions documented below, the best tested ",
    "threshold is ", best_economic$Threshold[1], " with net value ",
    best_economic$Net_value[1], "."
  ),
  "",
  "## Data Overview",
  "",
  paste0(
    "The dataset contains ", format(nrow(account_risk), big.mark = ","),
    " synthetic account records. The generated escalation rate is ",
    format_pct(event_rate), ", and ", format_pct(missing_training_rate),
    " of accounts have missing training-completion values."
  ),
  "",
  "Predictors include account segment, region, contract value, tenure, product usage, active-seat ratio, training completion, support tickets, response time, prior incidents, and implementation complexity. No real customer, student, patient, credential, or private course data is used.",
  "",
  "## Model Journey",
  "",
  "Candidate logistic models were compared with repeated stratified 5-fold cross-validation on the training split. Log loss is the primary criterion because the business problem needs calibrated probabilities, not only rank ordering. A spline benchmark is included as a flexible model-family check, but the operating model is selected from interpretable GLM candidates.",
  "",
  markdown_table(model_comparison),
  "",
  "![Candidate model comparison](../figures/model_comparison.png)",
  "",
  "The selected model uses a one-standard-error rule: pick the simplest model whose repeated-CV log loss is statistically close to the best candidate. This keeps the model easier to explain when extra terms do not materially improve probability quality.",
  "",
  "## Validation Metrics",
  "",
  markdown_table(final_metrics),
  "",
  "Bootstrap intervals give a practical uncertainty band around the holdout metrics.",
  "",
  markdown_table(metric_uncertainty),
  "",
  "## Coefficient Interpretation",
  "",
  "The table reports adjusted odds ratios for the selected model. Continuous predictors are scaled to business-readable increments where useful.",
  "",
  markdown_table(odds_ratios),
  "",
  "## Diagnostics",
  "",
  "ROC checks ranking quality, while calibration checks whether predicted probabilities are on the right scale across risk bands.",
  "",
  "![ROC and calibration diagnostics](../figures/roc_calibration.png)",
  "",
  markdown_table(calibration),
  "",
  markdown_table(calibration_diagnostics),
  "",
  "Segment and implementation-complexity calibration checks help identify where monitoring should continue after deployment.",
  "",
  markdown_table(subgroup_calibration),
  "",
  "## Threshold Interpretation",
  "",
  "A threshold turns probabilities into an operating workflow. Lower thresholds catch more events but increase review burden; higher thresholds concentrate risk but miss more events.",
  "",
  "![Threshold tradeoffs](../figures/threshold_tradeoff.png)",
  "",
  markdown_table(thresholds),
  "",
  "The table below translates the threshold choices into an illustrative operating economics frame. Assumptions: $750 review cost per flagged account, $12,000 avoided escalation cost, and 55% intervention effectiveness for captured events. These are scenario assumptions, not claims about a real business.",
  "",
  markdown_table(decision_economics),
  "",
  "## Lift and Prioritization",
  "",
  "A ranked queue is often more useful than a single classification cutoff. The lift table shows how much event concentration appears in each predicted-risk decile.",
  "",
  "![Lift by predicted risk decile](../figures/lift_chart.png)",
  "",
  markdown_table(decile_lift),
  "",
  "Risk categories provide an executive-friendly bridge between probabilities and action queues.",
  "",
  markdown_table(risk_categories),
  "",
  "## Sensitivity Analysis",
  "",
  "The primary model imputes missing training completion with segment medians and includes a missingness indicator. The sensitivity model uses a conservative assumption: missing training completion is treated as zero. This tests whether the operating story depends on a favorable missing-data assumption.",
  "",
  "![Sensitivity analysis](../figures/sensitivity_analysis.png)",
  "",
  markdown_table(sensitivity),
  "",
  "## Scenario Profiles",
  "",
  "Scenario profiles translate the model into concrete account-review examples with probability intervals. These are synthetic profiles used for communication and model interpretation.",
  "",
  "![Scenario risk curves](../figures/scenario_usage_curves.png)",
  "",
  markdown_table(scenario_profiles),
  "",
  "## Decision-Support Implications",
  "",
  "- Use predicted risk to prioritize human account review, not to automate account decisions.",
  "- Choose the review threshold based on available review capacity, expected intervention cost, and tolerance for missed escalations.",
  "- Monitor calibration by segment and implementation complexity before treating risk bands as stable operating categories.",
  "- Refit and recalibrate the model when product usage, support operations, or customer mix materially changes.",
  "",
  "## Reproducibility",
  "",
  "Rebuild the full evidence packet with:",
  "",
  "```bash",
  "make all",
  "```",
  "",
  "The build uses base R only and does not require package installation, network access, credentials, or private data.",
  "",
  "## Public-Safety Statement",
  "",
  "This report is an original public-safe portfolio artifact. It excludes private coursework prompts, exams, rubrics, syllabi, lecture transcripts, source datasets, personal data, patient data, school-private records, credentials, and copyrighted source documents."
)

writeLines(report_lines, file.path("reports", "statistical_risk_modeling_report.md"))

executive_lines <- c(
  "# Executive Brief: Statistical Risk Modeling in R",
  "",
  paste0("**Recommendation:** use the **", selected_model, "** as an interpretable account-review prioritization model."),
  "",
  paste0("**Validation:** holdout AUC ", holdout_auc, ", log loss ", holdout_log_loss, ", Brier score ", holdout_brier, "."),
  "",
  paste0("**Prioritization value:** top decile lift is ", top_decile_lift, "; top two deciles capture ", top_two_capture, " of observed escalations."),
  "",
  paste0("**Operating option:** at the ", threshold_20$Threshold[1], " threshold, the model flags ", threshold_20$Flagged[1], " accounts and captures ", threshold_20$Events_captured[1], " observed escalations."),
  "",
  paste0("**Illustrative economics:** strongest tested threshold is ", best_economic$Threshold[1], " with net value ", best_economic$Net_value[1], " under documented assumptions."),
  "",
  "## Decision Notes",
  "",
  "- Use the model to rank accounts for human review rather than automate account decisions.",
  "- Pick thresholds from capacity and intervention economics, not from AUC alone.",
  "- Monitor segment-level calibration before adopting risk categories as stable operating labels.",
  "- Treat the spline benchmark as a model-family stress test; it did not justify replacing the interpretable GLM."
)

writeLines(executive_lines, file.path("reports", "executive_brief.md"))

model_card_lines <- c(
  "# Model Card",
  "",
  "## Intended Use",
  "",
  "Prioritize synthetic B2B accounts for human escalation-review planning in a public-safe portfolio project.",
  "",
  "## Not Intended For",
  "",
  "Automated customer decisions, real account scoring, credit decisions, employment decisions, clinical decisions, or use with private data without separate validation.",
  "",
  "## Data",
  "",
  paste0("Synthetic account-risk records generated locally with ", format(nrow(account_risk), big.mark = ","), " rows and no private source data."),
  "",
  "## Model",
  "",
  paste0("Selected model: ", selected_model, ". Candidate models include baseline, usage, support, full operating, interaction, and spline benchmark specifications."),
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
  "- Track calibration by segment and implementation complexity.",
  "- Recheck threshold economics when review staffing, support processes, or escalation cost assumptions change.",
  "- Refit the model if usage distributions or support-ticket patterns drift materially.",
  "",
  "## Public-Safety Boundary",
  "",
  "No private coursework prompts, raw source datasets, credentials, student records, patient records, or customer records are included."
)

writeLines(model_card_lines, file.path("docs", "model-card.md"))
message("Wrote reports/statistical_risk_modeling_report.md")
message("Wrote reports/executive_brief.md")
message("Wrote docs/model-card.md")
