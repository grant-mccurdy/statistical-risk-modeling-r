source(file.path("R", "model_utils.R"))

ensure_project_dirs()

data_path <- file.path("data", "processed", "synthetic_account_risk.csv")
if (!file.exists(data_path)) {
  source(file.path("R", "generate_synthetic_data.R"))
}

account_risk <- read.csv(data_path, stringsAsFactors = FALSE)

account_risk$segment <- factor(
  account_risk$segment,
  levels = c("SMB", "Mid-Market", "Enterprise", "Strategic")
)
account_risk$region <- factor(
  account_risk$region,
  levels = c("North", "South", "East", "West")
)
account_risk$implementation_complexity <- factor(
  account_risk$implementation_complexity,
  levels = c("Low", "Medium", "High")
)

account_risk$log_contract_value <- log(account_risk$contract_value)
account_risk$training_completion_missing <- as.integer(
  is.na(account_risk$training_completion_rate)
)

segment_medians <- tapply(
  account_risk$training_completion_rate,
  account_risk$segment,
  median,
  na.rm = TRUE
)
overall_training_median <- median(account_risk$training_completion_rate, na.rm = TRUE)

account_risk$training_completion_imputed <- account_risk$training_completion_rate
for (segment_name in names(segment_medians)) {
  missing_idx <- is.na(account_risk$training_completion_imputed) &
    account_risk$segment == segment_name
  fill_value <- segment_medians[[segment_name]]
  if (is.na(fill_value)) {
    fill_value <- overall_training_median
  }
  account_risk$training_completion_imputed[missing_idx] <- fill_value
}
account_risk$training_completion_zero_filled <- ifelse(
  is.na(account_risk$training_completion_rate),
  0,
  account_risk$training_completion_rate
)

outcome <- "escalation_flag"
train_idx <- make_stratified_split(account_risk[[outcome]], train_prop = 0.80)
train_data <- account_risk[train_idx, , drop = FALSE]
holdout_data <- account_risk[-train_idx, , drop = FALSE]

candidate_formulas <- list(
  "Baseline exposure" = escalation_flag ~ log_contract_value + tenure_months + segment,
  "Usage behavior" = escalation_flag ~ log_contract_value + tenure_months + segment +
    product_usage_rate + active_seats_ratio + training_completion_imputed +
    training_completion_missing,
  "Support load" = escalation_flag ~ log_contract_value + tenure_months + segment +
    support_tickets_90d + avg_response_hours + prior_incident,
  "Full operating model" = escalation_flag ~ log_contract_value + tenure_months + segment +
    implementation_complexity + product_usage_rate + active_seats_ratio +
    training_completion_imputed + training_completion_missing +
    support_tickets_90d + avg_response_hours + prior_incident,
  "Full model with interaction" = escalation_flag ~ log_contract_value + tenure_months +
    segment + implementation_complexity + product_usage_rate + active_seats_ratio +
    training_completion_imputed + training_completion_missing + support_tickets_90d +
    avg_response_hours + prior_incident + product_usage_rate:support_tickets_90d,
  "Spline operating benchmark" = escalation_flag ~ log_contract_value + tenure_months +
    segment + implementation_complexity + splines::ns(product_usage_rate, df = 3) +
    splines::ns(active_seats_ratio, df = 3) + training_completion_imputed +
    training_completion_missing + support_tickets_90d +
    splines::ns(avg_response_hours, df = 3) + prior_incident
)

benchmark_models <- "Spline operating benchmark"

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

selection_candidates <- model_comparison[!(model_comparison$Model %in% benchmark_models), ]
best_row <- selection_candidates[which.min(selection_candidates$CV_LogLoss), ]
best_logloss_limit <- best_row$CV_LogLoss + best_row$CV_LogLoss_SD / sqrt(cv_repeats)
eligible <- selection_candidates[selection_candidates$CV_LogLoss <= best_logloss_limit, ]
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
    "Simplest model within one standard error of best repeated-CV log loss",
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
  tenure_months = 12,
  product_usage_rate = 0.10,
  active_seats_ratio = 0.10,
  training_completion_imputed = 0.10,
  training_completion_zero_filled = 0.10,
  support_tickets_90d = 3,
  avg_response_hours = 12,
  log_contract_value = 1
)

label_map <- list(
  log_contract_value = "Contract value, log scale",
  tenure_months = "Tenure",
  "segmentMid-Market" = "Segment: Mid-Market vs SMB",
  segmentEnterprise = "Segment: Enterprise vs SMB",
  segmentStrategic = "Segment: Strategic vs SMB",
  implementation_complexityMedium = "Implementation complexity: Medium vs Low",
  implementation_complexityHigh = "Implementation complexity: High vs Low",
  product_usage_rate = "Product usage rate",
  active_seats_ratio = "Active-seat ratio",
  training_completion_imputed = "Training completion",
  training_completion_missing = "Training completion missing",
  support_tickets_90d = "Support tickets, last 90 days",
  avg_response_hours = "Average response time",
  prior_incident = "Prior incident",
  `product_usage_rate:support_tickets_90d` = "Usage by support-ticket interaction"
)

odds_ratios <- make_odds_ratio_table(final_model,
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
thresholds <- make_threshold_table(holdout_data[[outcome]], final_predictions)
lift_table <- make_decile_lift_table(holdout_data[[outcome]], final_predictions, groups = 10)
decision_economics <- make_decision_economics(thresholds)

subgroup_calibration <- rbind(
  make_subgroup_calibration(
    data = holdout_data,
    group_var = "segment",
    y = holdout_data[[outcome]],
    p = final_predictions
  ),
  make_subgroup_calibration(
    data = holdout_data,
    group_var = "implementation_complexity",
    y = holdout_data[[outcome]],
    p = final_predictions
  )
)

sensitivity_formula_text <- paste(deparse(selected_formula), collapse = " ")
sensitivity_formula_text <- gsub(
  "training_completion_imputed",
  "training_completion_zero_filled",
  sensitivity_formula_text,
  fixed = TRUE
)
sensitivity_formula <- as.formula(sensitivity_formula_text)
sensitivity_model <- suppressWarnings(glm(
  sensitivity_formula,
  data = train_data,
  family = binomial()
))
sensitivity_predictions <- safe_predict_glm(sensitivity_model, holdout_data)
sensitivity_metrics <- evaluate_predictions(
  holdout_data[[outcome]],
  sensitivity_predictions
)

primary_category <- risk_category(final_predictions)
sensitivity_category <- risk_category(sensitivity_predictions)

sensitivity_comparison <- data.frame(
  Measure = c(
    "Holdout log loss",
    "Holdout Brier score",
    "Holdout AUC",
    "Mean absolute probability change",
    "Accounts changing risk category",
    "Maximum absolute probability change"
  ),
  Primary = c(
    format_num(final_holdout_metrics$LogLoss, 3),
    format_num(final_holdout_metrics$Brier, 3),
    format_num(final_holdout_metrics$AUC, 3),
    "Reference",
    "Reference",
    "Reference"
  ),
  Sensitivity = c(
    format_num(sensitivity_metrics$LogLoss, 3),
    format_num(sensitivity_metrics$Brier, 3),
    format_num(sensitivity_metrics$AUC, 3),
    format_pct(mean(abs(sensitivity_predictions - final_predictions)), 2),
    paste0(sum(primary_category != sensitivity_category), " of ", length(final_predictions)),
    format_pct(max(abs(sensitivity_predictions - final_predictions)), 2)
  ),
  stringsAsFactors = FALSE
)

risk_category_table <- as.data.frame(table(primary_category), stringsAsFactors = FALSE)
names(risk_category_table) <- c("RiskCategory", "Accounts")
risk_category_table$Share <- risk_category_table$Accounts / sum(risk_category_table$Accounts)
risk_category_rows <- lapply(levels(primary_category), function(level) {
  idx <- primary_category == level
  data.frame(
    RiskCategory = level,
    Accounts = sum(idx),
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
  Events_captured = paste0(thresholds$EventsCaptured, " of ", thresholds$TotalEvents),
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
  Expected_events = format_num(calibration$ExpectedEvents, 1),
  Observed_events = calibration$ObservedEvents,
  stringsAsFactors = FALSE
)

subgroup_display <- data.frame(
  Subgroup = subgroup_calibration$Subgroup,
  Level = subgroup_calibration$Level,
  N = subgroup_calibration$N,
  Mean_predicted = format_pct(subgroup_calibration$MeanPredicted),
  Observed_rate = format_pct(subgroup_calibration$ObservedRate),
  Calibration_gap = format_pct(subgroup_calibration$CalibrationGap),
  Observed_events = subgroup_calibration$ObservedEvents,
  stringsAsFactors = FALSE
)

model_comparison_display <- data.frame(
  Model = model_comparison$Model,
  Selected = ifelse(model_comparison$Selected, "Yes", ""),
  Role = ifelse(model_comparison$Model %in% benchmark_models, "Benchmark", "Selection candidate"),
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
  Accounts = risk_category_summary$Accounts,
  Share = format_pct(risk_category_summary$Share),
  Mean_predicted = format_pct(risk_category_summary$MeanPredicted),
  Observed_rate = format_pct(risk_category_summary$ObservedRate),
  Observed_events = risk_category_summary$Events,
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
  Events = lift_table$Events,
  Lift = paste0(format_num(lift_table$Lift, 2), "x"),
  Cumulative_capture = format_pct(lift_table$CumulativeCapture),
  stringsAsFactors = FALSE
)

decision_economics_display <- data.frame(
  Threshold = format_pct(decision_economics$Threshold, 0),
  Flagged = decision_economics$Flagged,
  Events_captured = decision_economics$EventsCaptured,
  Avoided_loss = paste0("$", format(round(decision_economics$AvoidedLoss), big.mark = ",", trim = TRUE)),
  Review_cost = paste0("$", format(round(decision_economics$ReviewCost), big.mark = ",", trim = TRUE)),
  Net_value = paste0("$", format(round(decision_economics$NetValue), big.mark = ",", trim = TRUE)),
  stringsAsFactors = FALSE
)

scenario_profiles <- data.frame(
  Scenario = c("Stable renewal", "Enablement watchlist", "Priority intervention"),
  segment = factor(c("Mid-Market", "SMB", "Enterprise"), levels = levels(train_data$segment)),
  region = factor(c("West", "South", "East"), levels = levels(train_data$region)),
  implementation_complexity = factor(c("Low", "Medium", "High"), levels = levels(train_data$implementation_complexity)),
  contract_value = c(78000, 42000, 285000),
  tenure_months = c(38, 14, 8),
  product_usage_rate = c(0.82, 0.55, 0.35),
  active_seats_ratio = c(0.78, 0.47, 0.32),
  training_completion_rate = c(0.83, 0.45, 0.25),
  support_tickets_90d = c(1, 4, 8),
  avg_response_hours = c(7, 16, 28),
  prior_incident = c(0, 0, 1),
  stringsAsFactors = FALSE
)
scenario_profiles$log_contract_value <- log(scenario_profiles$contract_value)
scenario_profiles$training_completion_missing <- 0
scenario_profiles$training_completion_imputed <- scenario_profiles$training_completion_rate
scenario_profiles$training_completion_zero_filled <- scenario_profiles$training_completion_rate

scenario_ci <- predict_probability_ci(final_model, scenario_profiles)
scenario_profile_output <- cbind(
  scenario_profiles[, c(
    "Scenario", "segment", "implementation_complexity", "contract_value",
    "tenure_months", "product_usage_rate", "active_seats_ratio",
    "training_completion_rate", "support_tickets_90d", "avg_response_hours",
    "prior_incident"
  )],
  scenario_ci
)
scenario_profile_display <- data.frame(
  Scenario = scenario_profile_output$Scenario,
  Segment = scenario_profile_output$segment,
  Complexity = scenario_profile_output$implementation_complexity,
  Usage = format_pct(scenario_profile_output$product_usage_rate),
  Support_tickets_90d = scenario_profile_output$support_tickets_90d,
  Response_hours = scenario_profile_output$avg_response_hours,
  Prior_incident = scenario_profile_output$prior_incident,
  Predicted_risk = format_pct(scenario_profile_output$PredictedRisk),
  CI_95 = paste0(
    format_pct(scenario_profile_output$Lower),
    " to ",
    format_pct(scenario_profile_output$Upper)
  ),
  Risk_category = as.character(risk_category(scenario_profile_output$PredictedRisk)),
  stringsAsFactors = FALSE
)

usage_grid <- seq(0.25, 0.90, length.out = 80)
scenario_curve <- do.call(rbind, lapply(seq_len(nrow(scenario_profiles)), function(row_id) {
  new_data <- scenario_profiles[rep(row_id, length(usage_grid)), ]
  new_data$product_usage_rate <- usage_grid
  new_data$active_seats_ratio <- pmin(
    0.98,
    pmax(0.02, scenario_profiles$active_seats_ratio[row_id] + 0.45 * (usage_grid - scenario_profiles$product_usage_rate[row_id]))
  )
  pred <- predict_probability_ci(final_model, new_data)
  data.frame(
    Scenario = scenario_profiles$Scenario[row_id],
    ProductUsageRate = usage_grid,
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
write.csv(scenario_curve, file.path("reports", "scenario_usage_curve.csv"), row.names = FALSE)

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
par(mar = c(5, 13, 4, 2))
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
  ylab = "Observed escalation rate",
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
  xlab = "Review threshold",
  ylab = "Sensitivity / PPV",
  main = "Threshold Tradeoffs for Account Review"
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
mtext("Share of accounts flagged", side = 4, line = 3)
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
  main = "Prediction Stability"
)
abline(0, 1, lty = 2, col = "#555555")
grid(col = "#E0E0E0")

hist(
  sensitivity_predictions - final_predictions,
  breaks = 24,
  col = "#C9DCE8",
  border = "#FFFFFF",
  xlab = "Sensitivity minus primary prediction",
  main = "Missing Training Assumption Impact"
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
  ylab = "Observed escalation rate",
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
mtext("Cumulative event capture", side = 4, line = 3)
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

png(file.path("figures", "scenario_usage_curves.png"), width = 1200, height = 720, res = 150)
par(mar = c(5, 5, 4, 2))
plot(
  range(scenario_curve$ProductUsageRate),
  range(c(scenario_curve$Lower, scenario_curve$Upper)),
  type = "n",
  xlab = "Product usage rate",
  ylab = "Predicted escalation risk",
  main = "Scenario Risk Curves with 95% Confidence Bands"
)
curve_colors <- c(
  "Stable renewal" = "#2D7D46",
  "Enablement watchlist" = "#1B6CA8",
  "Priority intervention" = "#8C2D19"
)
for (scenario in unique(scenario_curve$Scenario)) {
  rows <- scenario_curve[scenario_curve$Scenario == scenario, ]
  polygon(
    c(rows$ProductUsageRate, rev(rows$ProductUsageRate)),
    c(rows$Lower, rev(rows$Upper)),
    col = adjustcolor(curve_colors[[scenario]], alpha.f = 0.14),
    border = NA
  )
  lines(
    rows$ProductUsageRate,
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
