source(file.path("R", "model_utils.R"))

ensure_project_dirs()

data_path <- file.path("data", "processed", "education_readiness_risk.csv")
if (!file.exists(data_path)) {
  source(file.path("R", "generate_synthetic_data.R"))
}

readiness <- read.csv(data_path, stringsAsFactors = FALSE)

readiness$assessment_window <- factor(
  readiness$assessment_window,
  levels = c("beginning_of_year", "end_of_year")
)
readiness$next_assessment_window <- factor(
  readiness$next_assessment_window,
  levels = c("beginning_of_year", "end_of_year")
)
readiness$attendance_category <- factor(
  readiness$attendance_category,
  levels = c("normal", "high", "at_risk")
)
readiness$course_track <- factor(
  readiness$course_track,
  levels = c("regular", "honors", "ap", "beyond_core")
)
readiness$grade_level <- factor(readiness$grade_level, levels = c(9, 10, 11, 12))
readiness$current_absent <- as.integer(readiness$current_absent)
readiness$current_readiness_missing <- as.integer(readiness$current_readiness_missing)

outcome <- "support_risk_next"
train_idx <- make_stratified_split(readiness[[outcome]], train_prop = 0.80)
train_data <- readiness[train_idx, , drop = FALSE]
holdout_data <- readiness[-train_idx, , drop = FALSE]

candidate_formulas <- list(
  "Context baseline" = support_risk_next ~ grade_level + course_track +
    assessment_window + attendance_category,
  "Linear readiness" = support_risk_next ~ grade_level + course_track +
    assessment_window + attendance_category + attendance_probability +
    current_readiness + school_year_offset,
  "Quadratic readiness" = support_risk_next ~ grade_level + course_track +
    assessment_window + attendance_category + attendance_probability +
    current_readiness_z + I(current_readiness_z^2) + school_year_offset,
  "Cubic polynomial readiness" = support_risk_next ~ grade_level + course_track +
    assessment_window + attendance_category + attendance_probability +
    current_readiness_z + I(current_readiness_z^2) +
    I(current_readiness_z^3) + school_year_offset,
  "Piecewise readiness" = support_risk_next ~ grade_level + course_track +
    assessment_window + attendance_category + attendance_probability +
    readiness_below_45 + readiness_45_to_60 + readiness_above_60 +
    school_year_offset,
  "Periodic context benchmark" = support_risk_next ~ grade_level + course_track +
    assessment_window + attendance_category + attendance_probability +
    current_readiness_z + I(current_readiness_z^2) +
    school_year_offset + annual_sin + annual_cos,
  "Spline readiness benchmark" = support_risk_next ~ grade_level + course_track +
    assessment_window + attendance_category + attendance_probability +
    splines::ns(current_readiness, df = 4) + school_year_offset
)

benchmark_models <- c("Periodic context benchmark", "Spline readiness benchmark")
cv_folds <- 5
cv_repeats <- 6

cv_results <- run_repeated_cv(
  data = train_data,
  formulas = candidate_formulas,
  outcome = outcome,
  k = cv_folds,
  repeats = cv_repeats
)

cv_summary <- summarize_cv(cv_results)
candidate_fits <- lapply(candidate_formulas, function(model_formula) {
  suppressWarnings(glm(model_formula, data = train_data, family = binomial()))
})

holdout_metrics <- do.call(rbind, lapply(names(candidate_fits), function(model_name) {
  predictions <- safe_predict_glm(candidate_fits[[model_name]], holdout_data)
  metrics <- evaluate_predictions(holdout_data[[outcome]], predictions)
  data.frame(
    Model = model_name,
    Holdout_LogLoss = metrics$LogLoss,
    Holdout_Brier = metrics$Brier,
    Holdout_AUC = metrics$AUC,
    AIC = AIC(candidate_fits[[model_name]]),
    Parameters = count_model_parameters(candidate_fits[[model_name]]),
    stringsAsFactors = FALSE
  )
}))

model_comparison <- merge(cv_summary, holdout_metrics, by = "Model")
model_comparison <- model_comparison[order(model_comparison$CV_LogLoss), ]

selection_candidates <- model_comparison[
  !(model_comparison$Model %in% benchmark_models),
]
best_row <- selection_candidates[which.min(selection_candidates$CV_LogLoss), ]
best_logloss_limit <- best_row$CV_LogLoss + best_row$CV_LogLoss_SD / sqrt(cv_repeats)
eligible <- selection_candidates[
  selection_candidates$CV_LogLoss <= best_logloss_limit,
]
eligible <- eligible[order(eligible$Parameters, eligible$CV_LogLoss), ]
selected_model_name <- eligible$Model[1]

model_comparison$Selected <- model_comparison$Model == selected_model_name
model_comparison$Delta_CV_LogLoss <- model_comparison$CV_LogLoss -
  min(model_comparison$CV_LogLoss)
model_comparison <- model_comparison[
  order(model_comparison$CV_LogLoss),
  c(
    "Model", "Selected", "Parameters", "CV_LogLoss", "CV_LogLoss_SD",
    "CV_Brier", "CV_AUC", "CV_AUC_SD", "Holdout_LogLoss", "Holdout_Brier",
    "Holdout_AUC", "AIC", "Delta_CV_LogLoss"
  )
]

selected_formula <- candidate_formulas[[selected_model_name]]
final_model <- candidate_fits[[selected_model_name]]
final_predictions <- safe_predict_glm(final_model, holdout_data)
final_train_predictions <- safe_predict_glm(final_model, train_data)

final_holdout_metrics <- evaluate_predictions(holdout_data[[outcome]], final_predictions)
final_train_metrics <- evaluate_predictions(train_data[[outcome]], final_train_predictions)
metric_intervals <- bootstrap_metric_ci(
  holdout_data[[outcome]],
  final_predictions,
  reps = 800
)
calibration_diagnostics <- make_calibration_diagnostics(
  holdout_data[[outcome]],
  final_predictions
)

final_metrics <- data.frame(
  Metric = c(
    "Selected model",
    "Selection rule",
    "Shape discovery result",
    "Training rows",
    "Holdout rows",
    "Training event rate",
    "Holdout event rate",
    "Repeated CV folds",
    "Repeated CV repeats",
    "CV log loss",
    "CV AUC",
    "Holdout log loss",
    "Holdout Brier score",
    "Holdout AUC",
    "Calibration intercept",
    "Calibration slope",
    "Training log loss",
    "Training AUC"
  ),
  Value = c(
    selected_model_name,
    "Simplest non-benchmark model within one standard error of best repeated-CV log loss",
    "Nonparametric smoothing supported a threshold-like readiness curve; piecewise and polynomial candidates were tested against spline and periodic benchmarks.",
    nrow(train_data),
    nrow(holdout_data),
    format_pct(mean(train_data[[outcome]])),
    format_pct(mean(holdout_data[[outcome]])),
    cv_folds,
    cv_repeats,
    format_num(model_comparison$CV_LogLoss[model_comparison$Selected], 3),
    format_num(model_comparison$CV_AUC[model_comparison$Selected], 3),
    format_num(final_holdout_metrics$LogLoss, 3),
    format_num(final_holdout_metrics$Brier, 3),
    format_num(final_holdout_metrics$AUC, 3),
    format_num(calibration_diagnostics$Estimate[
      calibration_diagnostics$Diagnostic == "Calibration intercept"
    ], 3),
    format_num(calibration_diagnostics$Estimate[
      calibration_diagnostics$Diagnostic == "Calibration slope"
    ], 3),
    format_num(final_train_metrics$LogLoss, 3),
    format_num(final_train_metrics$AUC, 3)
  ),
  stringsAsFactors = FALSE
)

scale_map <- list(
  attendance_probability = 0.10,
  current_readiness = 5,
  current_readiness_z = 1,
  readiness_below_45 = 5,
  readiness_45_to_60 = 5,
  readiness_above_60 = 5,
  school_year_offset = 1
)

label_map <- list(
  "grade_level10" = "Grade 10 vs grade 9",
  "grade_level11" = "Grade 11 vs grade 9",
  "grade_level12" = "Grade 12 vs grade 9",
  course_trackhonors = "Honors track vs regular",
  course_trackap = "AP track vs regular",
  course_trackbeyond_core = "Beyond-core track vs regular",
  assessment_windowend_of_year = "Current window: end of year",
  attendance_categoryhigh = "Attendance category: high absence vs normal",
  attendance_categoryat_risk = "Attendance category: at-risk absence vs normal",
  attendance_probability = "Attendance probability",
  current_readiness = "Current readiness",
  current_readiness_z = "Current readiness, standardized",
  "I(current_readiness_z^2)" = "Current readiness squared",
  "I(current_readiness_z^3)" = "Current readiness cubed",
  readiness_below_45 = "Readiness shortfall below 45",
  readiness_45_to_60 = "Readiness gain from 45 to 60",
  readiness_above_60 = "Readiness gain above 60",
  school_year_offset = "School-year sequence",
  annual_sin = "Annual sine term",
  annual_cos = "Annual cosine term"
)

odds_ratios <- make_odds_ratio_table(
  final_model,
  scale_map = scale_map,
  label_map = label_map
)

odds_ratios_display <- data.frame(
  Predictor = odds_ratios$Predictor,
  Scale = odds_ratios$Scale,
  Odds_ratio = format_num(odds_ratios$OddsRatio, 2),
  CI_95 = paste0(
    format_num(odds_ratios$CI_Lower, 2),
    " to ",
    format_num(odds_ratios$CI_Upper, 2)
  ),
  P_value = format_p(odds_ratios$P_Value),
  stringsAsFactors = FALSE
)

roc_curve <- make_roc_curve(holdout_data[[outcome]], final_predictions)
calibration <- make_calibration_table(holdout_data[[outcome]], final_predictions, bins = 8)
thresholds <- make_threshold_table(
  holdout_data[[outcome]],
  final_predictions,
  thresholds = c(0.35, 0.45, 0.50, 0.55, 0.65, 0.75)
)
lift_table <- make_decile_lift_table(holdout_data[[outcome]], final_predictions, groups = 10)
decision_economics <- make_decision_economics(
  thresholds,
  review_cost = 75,
  case_value = 500,
  intervention_effect = 0.45
)

subgroup_calibration <- rbind(
  make_subgroup_calibration(
    data = holdout_data,
    group_var = "course_track",
    y = holdout_data[[outcome]],
    p = final_predictions
  ),
  make_subgroup_calibration(
    data = holdout_data,
    group_var = "assessment_window",
    y = holdout_data[[outcome]],
    p = final_predictions
  ),
  make_subgroup_calibration(
    data = holdout_data,
    group_var = "attendance_category",
    y = holdout_data[[outcome]],
    p = final_predictions
  )
)
subgroup_calibration <- subgroup_calibration[subgroup_calibration$N >= 25, , drop = FALSE]

sensitivity_formula_text <- paste(deparse(selected_formula), collapse = " ")
sensitivity_formula_text <- sub(
  "^support_risk_next",
  "support_risk_next_45",
  sensitivity_formula_text
)
sensitivity_formula <- as.formula(sensitivity_formula_text)
sensitivity_model <- suppressWarnings(glm(
  sensitivity_formula,
  data = train_data,
  family = binomial()
))
sensitivity_predictions <- safe_predict_glm(sensitivity_model, holdout_data)
sensitivity_metrics <- evaluate_predictions(
  holdout_data$support_risk_next_45,
  sensitivity_predictions
)

primary_category <- risk_category(final_predictions)
sensitivity_category <- risk_category(sensitivity_predictions)
rank_correlation <- suppressWarnings(cor(
  final_predictions,
  sensitivity_predictions,
  method = "spearman"
))
top_primary <- order(final_predictions, decreasing = TRUE)[
  seq_len(ceiling(length(final_predictions) * 0.20))
]
top_sensitivity <- order(sensitivity_predictions, decreasing = TRUE)[
  seq_len(ceiling(length(sensitivity_predictions) * 0.20))
]
top_overlap <- length(intersect(top_primary, top_sensitivity)) / length(top_primary)

sensitivity_comparison <- data.frame(
  Measure = c(
    "Primary holdout event rate",
    "Sensitivity holdout event rate",
    "Sensitivity holdout log loss",
    "Sensitivity holdout Brier score",
    "Sensitivity holdout AUC",
    "Rank correlation with primary predictions",
    "Top-quintile overlap with primary ranking",
    "Students changing risk category"
  ),
  Primary = c(
    format_pct(mean(holdout_data$support_risk_next)),
    "Reference",
    format_num(final_holdout_metrics$LogLoss, 3),
    format_num(final_holdout_metrics$Brier, 3),
    format_num(final_holdout_metrics$AUC, 3),
    "Reference",
    "Reference",
    "Reference"
  ),
  Sensitivity = c(
    "Reference",
    format_pct(mean(holdout_data$support_risk_next_45)),
    format_num(sensitivity_metrics$LogLoss, 3),
    format_num(sensitivity_metrics$Brier, 3),
    format_num(sensitivity_metrics$AUC, 3),
    format_num(rank_correlation, 3),
    format_pct(top_overlap),
    paste0(sum(primary_category != sensitivity_category), " of ", length(final_predictions))
  ),
  stringsAsFactors = FALSE
)

risk_category_rows <- lapply(levels(primary_category), function(level) {
  idx <- primary_category == level
  data.frame(
    RiskCategory = level,
    Students = sum(idx),
    Share = sum(idx) / length(primary_category),
    MeanPredicted = ifelse(sum(idx) == 0, NA_real_, mean(final_predictions[idx])),
    ObservedRate = ifelse(sum(idx) == 0, NA_real_, mean(holdout_data[[outcome]][idx])),
    Events = ifelse(sum(idx) == 0, 0, sum(holdout_data[[outcome]][idx])),
    stringsAsFactors = FALSE
  )
})
risk_category_summary <- do.call(rbind, risk_category_rows)

thresholds_display <- data.frame(
  Threshold = format_pct(thresholds$Threshold, 0),
  Flagged = thresholds$Flagged,
  Flagged_share = format_pct(thresholds$FlaggedRate),
  Risks_captured = paste0(thresholds$EventsCaptured, " of ", thresholds$TotalEvents),
  Sensitivity = format_pct(thresholds$Sensitivity),
  Specificity = format_pct(thresholds$Specificity),
  PPV = format_pct(thresholds$PPV),
  NPV = format_pct(thresholds$NPV),
  stringsAsFactors = FALSE
)

calibration_display <- data.frame(
  Risk_band = calibration$RiskBand,
  N = calibration$N,
  Mean_predicted = format_pct(calibration$MeanPredicted),
  Observed_rate = format_pct(calibration$ObservedRate),
  Expected_risks = format_num(calibration$ExpectedEvents, 1),
  Observed_risks = calibration$ObservedEvents,
  stringsAsFactors = FALSE
)

subgroup_display <- data.frame(
  Subgroup = subgroup_calibration$Subgroup,
  Level = subgroup_calibration$Level,
  N = subgroup_calibration$N,
  Mean_predicted = format_pct(subgroup_calibration$MeanPredicted),
  Observed_rate = format_pct(subgroup_calibration$ObservedRate),
  Calibration_gap = format_pct(subgroup_calibration$CalibrationGap),
  Observed_risks = subgroup_calibration$ObservedEvents,
  stringsAsFactors = FALSE
)

model_comparison_display <- data.frame(
  Model = model_comparison$Model,
  Selected = ifelse(model_comparison$Selected, "Yes", ""),
  Role = ifelse(
    model_comparison$Model %in% benchmark_models,
    "Benchmark",
    "Selection candidate"
  ),
  Parameters = model_comparison$Parameters,
  CV_log_loss = format_num(model_comparison$CV_LogLoss, 3),
  CV_log_loss_SD = format_num(model_comparison$CV_LogLoss_SD, 3),
  CV_AUC = format_num(model_comparison$CV_AUC, 3),
  Holdout_log_loss = format_num(model_comparison$Holdout_LogLoss, 3),
  Holdout_AUC = format_num(model_comparison$Holdout_AUC, 3),
  Delta_CV_log_loss = format_num(model_comparison$Delta_CV_LogLoss, 3),
  stringsAsFactors = FALSE
)

risk_category_display <- data.frame(
  Risk_category = risk_category_summary$RiskCategory,
  Students = risk_category_summary$Students,
  Share = format_pct(risk_category_summary$Share),
  Mean_predicted = format_pct(risk_category_summary$MeanPredicted),
  Observed_rate = format_pct(risk_category_summary$ObservedRate),
  Observed_risks = risk_category_summary$Events,
  stringsAsFactors = FALSE
)

metric_intervals_display <- data.frame(
  Metric = metric_intervals$Metric,
  Estimate = format_num(metric_intervals$Estimate, 3),
  Bootstrap_95_CI = paste0(
    format_num(metric_intervals$CI_Lower, 3),
    " to ",
    format_num(metric_intervals$CI_Upper, 3)
  ),
  stringsAsFactors = FALSE
)

calibration_diagnostics_display <- data.frame(
  Diagnostic = calibration_diagnostics$Diagnostic,
  Estimate = format_num(calibration_diagnostics$Estimate, 3),
  Interpretation = calibration_diagnostics$Interpretation,
  stringsAsFactors = FALSE
)

lift_display <- data.frame(
  Decile = lift_table$Decile,
  N = lift_table$N,
  Mean_predicted = format_pct(lift_table$MeanPredicted),
  Observed_rate = format_pct(lift_table$ObservedRate),
  Risks = lift_table$Events,
  Lift = paste0(format_num(lift_table$Lift, 2), "x"),
  Cumulative_capture = format_pct(lift_table$CumulativeCapture),
  stringsAsFactors = FALSE
)

decision_economics_display <- data.frame(
  Threshold = format_pct(decision_economics$Threshold, 0),
  Students_flagged = decision_economics$Flagged,
  Risks_captured = decision_economics$EventsCaptured,
  Illustrative_benefit = paste0("$", format(round(decision_economics$AvoidedLoss), big.mark = ",", trim = TRUE)),
  Review_cost = paste0("$", format(round(decision_economics$ReviewCost), big.mark = ",", trim = TRUE)),
  Net_value = paste0("$", format(round(decision_economics$NetValue), big.mark = ",", trim = TRUE)),
  stringsAsFactors = FALSE
)

family_review <- data.frame(
  Model_family = c(
    "Context baseline",
    "Linear readiness",
    "Quadratic readiness",
    "Cubic polynomial readiness",
    "Piecewise readiness",
    "Periodic context benchmark",
    "Spline readiness benchmark"
  ),
  Why_tested = c(
    "Tests whether demographic and operating context alone is enough.",
    "Adds the main readiness signal with a simple monotone probability shape.",
    "Tests whether risk accelerates near low readiness values.",
    "Checks whether a more flexible polynomial improves fit enough to justify instability risk.",
    "Uses the smooth shape discovery to encode separate readiness regions.",
    "Tests recurring assessment-window structure without making periodicity the headline.",
    "Flexible nonlinear benchmark for the readiness curve."
  ),
  Decision = c(
    "Rejected; validation is much weaker without readiness.",
    "Rejected; ranking is strong but probability quality is worse.",
    "Rejected; close to selected model, but less directly aligned with the discovered threshold shape.",
    "Rejected; added polynomial curvature without improving the operating story.",
    ifelse(
      selected_model_name == "Piecewise readiness",
      "Selected as the operating model.",
      "Useful interpretable challenger."
    ),
    "Benchmark only; periodic terms did not justify replacing the operating model.",
    "Benchmark only; used to test whether flexible curvature changes the conclusion."
  ),
  CV_log_loss = model_comparison_display$CV_log_loss[
    match(
      c(
        "Context baseline", "Linear readiness", "Quadratic readiness",
        "Cubic polynomial readiness", "Piecewise readiness",
        "Periodic context benchmark", "Spline readiness benchmark"
      ),
      model_comparison_display$Model
    )
  ],
  Holdout_AUC = model_comparison_display$Holdout_AUC[
    match(
      c(
        "Context baseline", "Linear readiness", "Quadratic readiness",
        "Cubic polynomial readiness", "Piecewise readiness",
        "Periodic context benchmark", "Spline readiness benchmark"
      ),
      model_comparison_display$Model
    )
  ],
  stringsAsFactors = FALSE
)

readiness_mean <- mean(readiness$current_readiness)
readiness_sd <- sd(readiness$current_readiness)

make_profile_data <- function(current_readiness_values, scenario_row) {
  new_data <- scenario_row[rep(1, length(current_readiness_values)), ]
  new_data$current_readiness <- current_readiness_values
  new_data$current_readiness_z <- (current_readiness_values - readiness_mean) / readiness_sd
  new_data$readiness_below_45 <- pmax(45 - current_readiness_values, 0)
  new_data$readiness_45_to_60 <- pmin(pmax(current_readiness_values - 45, 0), 15)
  new_data$readiness_above_60 <- pmax(current_readiness_values - 60, 0)
  new_data$semester_sin <- sin(pi * new_data$sequence_index)
  new_data$semester_cos <- cos(pi * new_data$sequence_index)
  new_data$annual_sin <- sin(2 * pi * new_data$sequence_index / 4)
  new_data$annual_cos <- cos(2 * pi * new_data$sequence_index / 4)
  new_data
}

scenario_profiles <- data.frame(
  Scenario = c("On-track checkpoint", "Attendance watch", "Priority support"),
  grade_level = factor(c(10, 9, 11), levels = levels(train_data$grade_level)),
  course_track = factor(c("regular", "regular", "honors"), levels = levels(train_data$course_track)),
  assessment_window = factor(
    c("beginning_of_year", "beginning_of_year", "end_of_year"),
    levels = levels(train_data$assessment_window)
  ),
  next_assessment_window = factor(
    c("end_of_year", "end_of_year", "beginning_of_year"),
    levels = levels(train_data$next_assessment_window)
  ),
  attendance_category = factor(c("normal", "high", "at_risk"), levels = levels(train_data$attendance_category)),
  attendance_probability = c(0.96, 0.84, 0.68),
  current_readiness = c(72, 51, 39),
  score = c(73, 50, 38),
  current_absent = c(0, 0, 0),
  current_readiness_missing = c(0, 0, 0),
  school_year_offset = c(2, 2, 2),
  sequence_index = c(5, 5, 6),
  stringsAsFactors = FALSE
)
scenario_profiles$current_readiness_z <- (
  scenario_profiles$current_readiness - readiness_mean
) / readiness_sd
scenario_profiles$sequence_z <- (
  scenario_profiles$sequence_index - mean(readiness$sequence_index)
) / sd(readiness$sequence_index)
scenario_profiles$readiness_below_45 <- pmax(45 - scenario_profiles$current_readiness, 0)
scenario_profiles$readiness_45_to_60 <- pmin(pmax(scenario_profiles$current_readiness - 45, 0), 15)
scenario_profiles$readiness_above_60 <- pmax(scenario_profiles$current_readiness - 60, 0)
scenario_profiles$semester_sin <- sin(pi * scenario_profiles$sequence_index)
scenario_profiles$semester_cos <- cos(pi * scenario_profiles$sequence_index)
scenario_profiles$annual_sin <- sin(2 * pi * scenario_profiles$sequence_index / 4)
scenario_profiles$annual_cos <- cos(2 * pi * scenario_profiles$sequence_index / 4)

scenario_ci <- predict_probability_ci(final_model, scenario_profiles)
scenario_profile_output <- cbind(scenario_profiles, scenario_ci)
scenario_profile_display <- data.frame(
  Scenario = scenario_profile_output$Scenario,
  Grade = scenario_profile_output$grade_level,
  Track = scenario_profile_output$course_track,
  Window = scenario_profile_output$assessment_window,
  Attendance = scenario_profile_output$attendance_category,
  Current_readiness = format_num(scenario_profile_output$current_readiness, 1),
  Predicted_risk = format_pct(scenario_profile_output$PredictedRisk),
  CI_95 = paste0(
    format_pct(scenario_profile_output$Lower),
    " to ",
    format_pct(scenario_profile_output$Upper)
  ),
  Risk_category = as.character(risk_category(scenario_profile_output$PredictedRisk)),
  stringsAsFactors = FALSE
)

readiness_grid <- seq(
  max(15, floor(min(readiness$current_readiness))),
  min(95, ceiling(max(readiness$current_readiness))),
  length.out = 100
)
scenario_curve <- do.call(rbind, lapply(seq_len(nrow(scenario_profiles)), function(row_id) {
  new_data <- make_profile_data(readiness_grid, scenario_profiles[row_id, ])
  pred <- predict_probability_ci(final_model, new_data)
  data.frame(
    Scenario = scenario_profiles$Scenario[row_id],
    CurrentReadiness = readiness_grid,
    PredictedRisk = pred$PredictedRisk,
    Lower = pred$Lower,
    Upper = pred$Upper,
    stringsAsFactors = FALSE
  )
}))

write.csv(model_comparison, file.path("reports", "model_comparison.csv"), row.names = FALSE)
write.csv(model_comparison_display, file.path("reports", "model_comparison_display.csv"), row.names = FALSE)
write.csv(final_metrics, file.path("reports", "final_metrics.csv"), row.names = FALSE)
write.csv(metric_intervals_display, file.path("reports", "metric_uncertainty.csv"), row.names = FALSE)
write.csv(odds_ratios, file.path("reports", "odds_ratios_raw.csv"), row.names = FALSE)
write.csv(odds_ratios_display, file.path("reports", "odds_ratios.csv"), row.names = FALSE)
write.csv(calibration_display, file.path("reports", "calibration_table.csv"), row.names = FALSE)
write.csv(calibration_diagnostics_display, file.path("reports", "calibration_diagnostics.csv"), row.names = FALSE)
write.csv(thresholds_display, file.path("reports", "threshold_table.csv"), row.names = FALSE)
write.csv(decision_economics_display, file.path("reports", "decision_economics.csv"), row.names = FALSE)
write.csv(lift_display, file.path("reports", "decile_lift.csv"), row.names = FALSE)
write.csv(subgroup_display, file.path("reports", "subgroup_calibration.csv"), row.names = FALSE)
write.csv(sensitivity_comparison, file.path("reports", "sensitivity_comparison.csv"), row.names = FALSE)
write.csv(risk_category_display, file.path("reports", "risk_categories.csv"), row.names = FALSE)
write.csv(scenario_profile_display, file.path("reports", "scenario_profiles.csv"), row.names = FALSE)
write.csv(scenario_curve, file.path("reports", "scenario_readiness_curve.csv"), row.names = FALSE)
write.csv(family_review, file.path("reports", "parametric_family_review.csv"), row.names = FALSE)

saveRDS(
  list(
    selected_model_name = selected_model_name,
    selected_formula = selected_formula,
    final_model = final_model,
    model_comparison = model_comparison,
    final_predictions = final_predictions,
    sensitivity_predictions = sensitivity_predictions,
    scenario_profiles = scenario_profile_output,
    holdout_data = holdout_data,
    train_rows = nrow(train_data),
    holdout_rows = nrow(holdout_data)
  ),
  file.path("reports", "model_artifacts.rds")
)

png(file.path("figures", "model_comparison.png"), width = 1200, height = 760, res = 150)
ordered_models <- model_comparison[order(model_comparison$CV_LogLoss, decreasing = TRUE), ]
y_pos <- seq_len(nrow(ordered_models))
x_min <- min(ordered_models$CV_LogLoss - ordered_models$CV_LogLoss_SD) - 0.01
x_max <- max(ordered_models$CV_LogLoss + ordered_models$CV_LogLoss_SD) + 0.01
par(mar = c(5, 15, 4, 2))
plot(
  ordered_models$CV_LogLoss,
  y_pos,
  xlim = c(x_min, x_max),
  yaxt = "n",
  xlab = "Repeated-CV log loss",
  ylab = "",
  pch = 19,
  col = ifelse(ordered_models$Selected, "#1B6CA8", "#555555"),
  main = "Candidate Model Comparison"
)
segments(
  ordered_models$CV_LogLoss - ordered_models$CV_LogLoss_SD,
  y_pos,
  ordered_models$CV_LogLoss + ordered_models$CV_LogLoss_SD,
  y_pos,
  col = "#888888"
)
axis(2, at = y_pos, labels = ordered_models$Model, las = 1)
abline(v = min(model_comparison$CV_LogLoss), lty = 2, col = "#8C2D19")
legend(
  "bottomright",
  legend = c("Selected model", "Other candidate", "Best mean CV log loss"),
  pch = c(19, 19, NA),
  lty = c(NA, NA, 2),
  col = c("#1B6CA8", "#555555", "#8C2D19"),
  bty = "n"
)
dev.off()

png(file.path("figures", "shape_discovery.png"), width = 1300, height = 700, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
rank_groups <- cut(
  rank(train_data$current_readiness, ties.method = "first"),
  breaks = seq(0, nrow(train_data), length.out = 13),
  include.lowest = TRUE,
  labels = seq_len(12)
)
binned <- aggregate(
  cbind(support_risk_next, current_readiness) ~ rank_groups,
  train_data,
  mean
)
plot(
  binned$current_readiness,
  binned$support_risk_next,
  pch = 19,
  col = "#1B6CA8",
  xlab = "Current readiness",
  ylab = "Observed next-window support risk",
  ylim = c(0, 1),
  main = "Nonparametric Shape Check"
)
for (bandwidth in c(4, 8, 12)) {
  smooth <- ksmooth(
    train_data$current_readiness,
    train_data$support_risk_next,
    kernel = "normal",
    bandwidth = bandwidth,
    x.points = readiness_grid
  )
  lines(smooth$x, pmin(pmax(smooth$y, 0), 1), lwd = 2)
}
grid(col = "#E0E0E0")
legend(
  "topright",
  legend = c("Binned risk", "h = 4", "h = 8", "h = 12"),
  pch = c(19, NA, NA, NA),
  lty = c(NA, 1, 1, 1),
  lwd = c(NA, 2, 2, 2),
  col = c("#1B6CA8", "#000000", "#666666", "#999999"),
  bty = "n"
)

typical_profile <- scenario_profiles[1, ]
typical_grid <- make_profile_data(readiness_grid, typical_profile)
curve_models <- c(
  "Linear readiness",
  "Quadratic readiness",
  "Piecewise readiness",
  "Spline readiness benchmark"
)
plot(
  range(readiness_grid),
  c(0, 1),
  type = "n",
  xlab = "Current readiness",
  ylab = "Predicted next-window support risk",
  main = "Parametric Family Search"
)
curve_cols <- c("#555555", "#8C2D19", "#1B6CA8", "#2D7D46")
for (i in seq_along(curve_models)) {
  model_name <- curve_models[i]
  lines(
    readiness_grid,
    safe_predict_glm(candidate_fits[[model_name]], typical_grid),
    lwd = ifelse(model_name == selected_model_name, 3, 2),
    col = curve_cols[i]
  )
}
grid(col = "#E0E0E0")
legend(
  "topright",
  legend = curve_models,
  col = curve_cols,
  lwd = ifelse(curve_models == selected_model_name, 3, 2),
  bty = "n"
)
dev.off()

png(file.path("figures", "roc_calibration.png"), width = 1200, height = 620, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
plot(
  roc_curve$fpr,
  roc_curve$sensitivity,
  type = "l",
  lwd = 2,
  col = "#1B6CA8",
  xlab = "False positive rate",
  ylab = "Sensitivity",
  main = paste0("Holdout ROC (AUC = ", format_num(final_holdout_metrics$AUC, 3), ")")
)
abline(0, 1, lty = 2, col = "#888888")
grid(col = "#E0E0E0")
plot(
  calibration$MeanPredicted,
  calibration$ObservedRate,
  pch = 19,
  cex = 1.2,
  col = "#8C2D19",
  xlim = c(0, max(calibration$MeanPredicted, calibration$ObservedRate) * 1.15),
  ylim = c(0, max(calibration$MeanPredicted, calibration$ObservedRate) * 1.15),
  xlab = "Mean predicted risk",
  ylab = "Observed support-risk rate",
  main = "Holdout Calibration by Risk Band"
)
abline(0, 1, lty = 2, col = "#666666")
text(calibration$MeanPredicted, calibration$ObservedRate, labels = seq_len(nrow(calibration)), pos = 3, cex = 0.8)
grid(col = "#E0E0E0")
dev.off()

png(file.path("figures", "threshold_tradeoff.png"), width = 1200, height = 700, res = 150)
par(mar = c(5, 5, 4, 5))
plot(
  thresholds$Threshold,
  thresholds$Sensitivity,
  type = "b",
  pch = 19,
  lwd = 2,
  col = "#1B6CA8",
  ylim = c(0, 1),
  xlab = "Support-review threshold",
  ylab = "Sensitivity / PPV",
  main = "Threshold Tradeoffs for Student Support Review"
)
lines(thresholds$Threshold, thresholds$PPV, type = "b", pch = 17, lwd = 2, col = "#8C2D19")
par(new = TRUE)
plot(
  thresholds$Threshold,
  thresholds$FlaggedRate,
  type = "b",
  pch = 15,
  lwd = 2,
  col = "#2D7D46",
  axes = FALSE,
  xlab = "",
  ylab = "",
  ylim = c(0, 1)
)
axis(4)
mtext("Share of students flagged", side = 4, line = 3)
grid(col = "#E0E0E0")
legend(
  "topright",
  legend = c("Sensitivity", "PPV", "Flagged share"),
  col = c("#1B6CA8", "#8C2D19", "#2D7D46"),
  pch = c(19, 17, 15),
  lwd = 2,
  bty = "n"
)
dev.off()

png(file.path("figures", "sensitivity_analysis.png"), width = 1200, height = 620, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
plot(
  final_predictions,
  sensitivity_predictions,
  pch = 19,
  cex = 0.7,
  col = rgb(27, 108, 168, maxColorValue = 255, alpha = 120),
  xlab = "Primary predicted risk",
  ylab = "Sensitivity predicted risk",
  main = "Prediction Stability Under Lower Cut Point"
)
abline(0, 1, lty = 2, col = "#555555")
grid(col = "#E0E0E0")
hist(
  sensitivity_predictions - final_predictions,
  breaks = 24,
  col = "#C9DCE8",
  border = "#FFFFFF",
  xlab = "Sensitivity minus primary prediction",
  main = "Risk Threshold Sensitivity"
)
abline(v = 0, lwd = 2, col = "#8C2D19")
dev.off()

png(file.path("figures", "lift_chart.png"), width = 1200, height = 680, res = 150)
par(mar = c(5, 5, 4, 5))
barplot(
  lift_table$ObservedRate,
  names.arg = paste0("D", lift_table$Decile),
  col = "#C9DCE8",
  border = "#FFFFFF",
  ylim = c(0, max(lift_table$ObservedRate) * 1.25),
  xlab = "Risk decile, highest predicted risk first",
  ylab = "Observed support-risk rate",
  main = "Lift by Predicted Risk Decile"
)
abline(h = mean(holdout_data[[outcome]]), lty = 2, col = "#8C2D19", lwd = 2)
par(new = TRUE)
plot(
  seq_along(lift_table$CumulativeCapture),
  lift_table$CumulativeCapture,
  type = "b",
  pch = 19,
  lwd = 2,
  col = "#1B6CA8",
  axes = FALSE,
  xlab = "",
  ylab = "",
  ylim = c(0, 1)
)
axis(4)
mtext("Cumulative risk capture", side = 4, line = 3)
legend(
  "topright",
  legend = c("Observed rate", "Base event rate", "Cumulative capture"),
  fill = c("#C9DCE8", NA, NA),
  border = c("#FFFFFF", NA, NA),
  lty = c(NA, 2, 1),
  pch = c(NA, NA, 19),
  col = c("#C9DCE8", "#8C2D19", "#1B6CA8"),
  bty = "n"
)
dev.off()

png(file.path("figures", "scenario_readiness_curves.png"), width = 1200, height = 720, res = 150)
par(mar = c(5, 5, 4, 2))
plot(
  range(scenario_curve$CurrentReadiness),
  range(c(scenario_curve$Lower, scenario_curve$Upper)),
  type = "n",
  xlab = "Current readiness",
  ylab = "Predicted next-window support risk",
  main = "Scenario Risk Curves with 95% Confidence Bands"
)
curve_colors <- c(
  "On-track checkpoint" = "#2D7D46",
  "Attendance watch" = "#1B6CA8",
  "Priority support" = "#8C2D19"
)
for (scenario in unique(scenario_curve$Scenario)) {
  rows <- scenario_curve[scenario_curve$Scenario == scenario, ]
  polygon(
    c(rows$CurrentReadiness, rev(rows$CurrentReadiness)),
    c(rows$Lower, rev(rows$Upper)),
    col = adjustcolor(curve_colors[[scenario]], alpha.f = 0.14),
    border = NA
  )
  lines(
    rows$CurrentReadiness,
    rows$PredictedRisk,
    lwd = 2,
    col = curve_colors[[scenario]]
  )
}
grid(col = "#E0E0E0")
legend(
  "topright",
  legend = names(curve_colors),
  col = curve_colors,
  lwd = 2,
  bty = "n"
)
dev.off()

message("Wrote model artifacts, report tables, and figures.")
message("Selected model: ", selected_model_name)
