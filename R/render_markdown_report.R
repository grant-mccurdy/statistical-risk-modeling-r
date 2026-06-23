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
names(risk_categories) <- c("Category", "Transitions", "Share", "Pred", "Obs", "Cases")
names(sensitivity) <- c("Measure", "Primary", "Sensitivity")
names(scenario_profiles) <- c("Scenario", "Grade", "Track", "Window", "Attendance", "Readiness", "Risk", "95% CI", "Category")
scenario_profiles$Window <- clean_label(scenario_profiles$Window)
scenario_profiles$Attendance <- clean_label(scenario_profiles$Attendance)

selected_model <- metric_value("Selected model")
holdout_rows <- metric_value("Holdout rows")
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

threshold_65 <- thresholds[thresholds$Threshold == "65%", , drop = FALSE]
if (nrow(threshold_65) == 0) {
  threshold_65 <- thresholds[which.min(abs(as.numeric(gsub("%", "", thresholds$Threshold)) - 65)), , drop = FALSE]
}

top_two_capture <- decile_lift$Capture[decile_lift$Decile == 2][1]
top_decile_lift <- decile_lift$Lift[decile_lift$Decile == 1][1]
best_economic <- decision_economics[
  which.max(as.numeric(gsub("[$, ]", "", decision_economics$Net))),
  ,
  drop = FALSE
]

risk_action_lookup <- data.frame(
  Category = c("Monitor", "Watch", "Review", "Priority"),
  Suggested_action = c(
    "Routine monitoring",
    "Check trend and attendance",
    "Add to review queue",
    "Review first if capacity is limited"
  ),
  stringsAsFactors = FALSE
)

risk_category_actions <- merge(
  risk_categories[, c("Category", "Transitions", "Obs")],
  risk_action_lookup,
  by = "Category",
  all.x = TRUE,
  sort = FALSE
)
risk_category_actions <- risk_category_actions[
  match(risk_action_lookup$Category, risk_category_actions$Category),
  ,
  drop = FALSE
]
names(risk_category_actions) <- c(
  "Category", "Transitions", "Observed risk", "Suggested action"
)

stakeholder_decisions <- data.frame(
  Decision = c(
    "Who should be reviewed first?",
    "What workload does the starting threshold create?",
    "What coverage does the starting threshold provide?",
    "What if review capacity is tighter?",
    "What should the model not do?"
  ),
  Practical_answer = c(
    "Begin with transitions above the support-review threshold, then use educator context before taking action.",
    paste0(
      "A ", threshold_50$Threshold[1], " threshold flags ",
      threshold_50$Flagged[1], " of ", holdout_rows, " holdout transitions (",
      threshold_50$`Flagged %`[1], ")."
    ),
    paste0(
      "That threshold captures ", threshold_50$Captured[1],
      " observed support-risk cases, or ", threshold_50$Sens[1],
      " of the cases in the holdout set."
    ),
    paste0(
      "A ", threshold_65$Threshold[1], " threshold flags ",
      threshold_65$Flagged[1], " transitions and captures ",
      threshold_65$Captured[1], " observed support-risk cases."
    ),
    "It should not automatically assign intervention, placement, grading, or discipline decisions."
  ),
  stringsAsFactors = FALSE
)
names(stakeholder_decisions) <- c("Decision", "Practical answer")

report_lines <- c(
  "# Education Readiness Risk Modeling in R",
  "",
  "## Recommendation",
  "",
  "This study uses public-safe education assessment data to answer a practical planning question: which assessment records should be reviewed before the next assessment window when support capacity is limited? In plain English, the model estimates whether the next assessment is likely to show a low score or nonparticipation.",
  "",
  paste0(
    "I recommend using the model as a **ranked human review queue**, not as an automatic decision rule. The ",
    threshold_50$Threshold[1],
    " support-review threshold is the best default planning option in this analysis. It flags ",
    threshold_50$Flagged[1], " of ", holdout_rows, " holdout transitions (",
    threshold_50$`Flagged %`[1], ") and captures ",
    threshold_50$Captured[1],
    " observed support-risk cases."
  ),
  "",
  paste0(
    "If the team has less review capacity, the ", threshold_65$Threshold[1],
    " threshold is the next practical option. It flags ",
    threshold_65$Flagged[1],
    " transitions and captures ",
    threshold_65$Captured[1],
    " observed support-risk cases. This creates a smaller queue, but it accepts more missed support-risk cases."
  ),
  "",
  paste0(
    "The main statistical conclusion is that current readiness is the central signal, but the relationship is not purely linear. The selected ",
    selected_model,
    " model captures the threshold-like readiness pattern while staying easier to explain than a flexible spline benchmark."
  ),
  "",
  "## Direct Answers",
  "",
  "1. The purpose of the study is to turn assessment-readiness evidence into a review-prioritization workflow. The output is a ranked queue for human review before the next assessment window.",
  paste0("2. The modeled outcome is next-window support risk, defined as a next assessment score below 50 or next-window nonparticipation. The holdout event rate is ", holdout_event_rate, "."),
  paste0("3. The recommended starting threshold is ", threshold_50$Threshold[1], ". It flags ", threshold_50$Flagged[1], " of ", holdout_rows, " holdout transitions and captures ", threshold_50$Captured[1], " observed support-risk cases."),
  paste0("4. The main modeling discovery is that readiness has a threshold-like relationship with future support risk. That is why the final model uses ", selected_model, " rather than a simple linear readiness term."),
  "5. The conclusion should be used operationally, not mechanically: review the highest-risk records first, confirm context, and avoid automated placement, grading, discipline, or intervention decisions.",
  "",
  paste0(
    "The ranking view is useful even before choosing a hard cutoff. The highest-risk decile has ",
    top_decile_lift, " lift over the base rate, and the top two deciles capture ",
    top_two_capture, " of observed support-risk cases."
  ),
  "",
  "## Data Audit",
  "",
  "The analysis uses a public-safe assessment extract with one row per assessment window. The modeling table turns consecutive assessment windows into prediction records: current assessment information is used to predict whether the next assessment window should be reviewed for possible support needs.",
  "",
  markdown_table(extract_profile),
  "",
  "The extract uses simulated identifiers and generalized assessment behavior from a bootstrapped assessment workflow. It should not be treated as a release of real student-level records.",
  "",
  "## Risk Categories and Suggested Actions",
  "",
  "Risk categories make the model easier to use in a planning conversation. They are operating labels for a public-safe portfolio analysis, not permanent labels for real students.",
  "",
  markdown_table(risk_category_actions),
  "",
  "## Operating Summary",
  "",
  markdown_table(stakeholder_decisions),
  "",
  "The score should be used to decide what gets reviewed first, not what happens automatically. A support team would still confirm context, look at recent trajectory, and decide whether any action is appropriate.",
  "",
  "## Technical Validation Summary",
  "",
  paste0(
    "The selected technical model is **", selected_model,
    "**. On the holdout set, it achieved AUC **", holdout_auc,
    "**, log loss **", holdout_log_loss, "**, and Brier score **",
    holdout_brier, "**. Repeated cross-validation produced log loss **",
    cv_log_loss, "** and AUC **", cv_auc, "**."
  ),
  "",
  paste0(
    "The holdout event rate is ", holdout_event_rate,
    ", so the evaluation is not based on a rare-event edge case. Bootstrap intervals, calibration diagnostics, lift checks, subgroup calibration, and sensitivity testing are included below."
  ),
  "",
  "## Model Journey",
  "",
  "The model search follows a disciplined workflow: inspect the shape first, test candidate parametric families second, and keep the final model interpretable unless a flexible benchmark clearly earns its complexity.",
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
  "## Case Studies",
  "",
  "Public-safe case studies translate the model into concrete support-planning examples with probability intervals.",
  "",
  "![Scenario readiness risk curves](../figures/scenario_readiness_curves.png)",
  "",
  markdown_table(scenario_profiles),
  "",
  "## Bottom Line",
  "",
  "- Start with the 50% review threshold as a planning default, then adjust for staffing capacity and support cost.",
  "- Use the ranked queue to prioritize human review and early support planning, not to automate student-level decisions.",
  "- Keep the piecewise readiness model because it captures the discovered nonlinear risk pattern while staying easier to explain than a flexible spline.",
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
  "# Executive Brief: Support Review Prioritization",
  "",
  "**Purpose:** use public-safe assessment-readiness evidence to decide which records should be reviewed before the next assessment window when support capacity is limited.",
  "",
  paste0(
    "**Recommendation:** use the model as a ranked human review queue, not as an automatic decision rule. Start with the ",
    threshold_50$Threshold[1], " threshold. It flags ",
    threshold_50$Flagged[1], " of ", holdout_rows, " holdout transitions (",
    threshold_50$`Flagged %`[1], ") and captures ",
    threshold_50$Captured[1], " observed support-risk cases."
  ),
  "",
  paste0(
    "**Capacity option:** if the team needs a smaller review queue, the ",
    threshold_65$Threshold[1], " threshold flags ",
    threshold_65$Flagged[1], " transitions and captures ",
    threshold_65$Captured[1], " observed support-risk cases."
  ),
  "",
  paste0(
    "**Main conclusion:** current readiness is the central signal, but the relationship is threshold-like rather than purely linear. The selected ",
    selected_model, " model keeps that shape explainable."
  ),
  "",
  paste0(
    "**Prioritization value:** the highest-risk decile has ", top_decile_lift,
    " lift over the base rate, and the top two deciles capture ",
    top_two_capture, " of observed support-risk cases."
  ),
  "",
  paste0(
    "**Validation:** holdout AUC ", holdout_auc, ", log loss ",
    holdout_log_loss, ", and Brier score ", holdout_brier, "."
  ),
  "",
  paste0(
    "**Model discovery:** ", shape_result,
    " Flexible spline and periodic terms were retained as benchmarks, not as the operating recommendation."
  ),
  "",
  paste0(
    "**Illustrative planning value:** strongest tested threshold is ",
    best_economic$Threshold[1], " with net value ", best_economic$Net[1],
    " under documented support-planning assumptions."
  ),
  "",
  "## Decisions for Stakeholders",
  "",
  "- Confirm the review capacity that can be handled before the next assessment window.",
  "- Use risk categories as workflow labels: monitor, watch, review, and priority review.",
  "- Keep the score as a human review queue, not an automated placement, grading, discipline, or intervention assignment rule.",
  "- Monitor calibration by course track, assessment window, and attendance group before operational use."
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
