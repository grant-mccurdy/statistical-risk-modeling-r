source(file.path("R", "model_utils.R"))

ensure_project_dirs()

required_tables <- c(
  file.path("reports", "growth_extract_profile.csv"),
  file.path("reports", "growth_model_comparison_display.csv"),
  file.path("reports", "growth_model_search_grid.csv"),
  file.path("reports", "growth_model_strength.csv"),
  file.path("reports", "growth_model_family_summary.csv"),
  file.path("reports", "growth_model_selection_rationale.csv"),
  file.path("reports", "growth_shape_review.csv"),
  file.path("reports", "growth_final_metrics.csv"),
  file.path("reports", "model_dependency_status.csv"),
  file.path("reports", "model_temporal_validation.csv"),
  file.path("reports", "rolling_origin_validation.csv"),
  file.path("reports", "process_validation.csv"),
  file.path("reports", "locked_holdout_validation.csv"),
  file.path("reports", "model_validity_targets.csv"),
  file.path("reports", "feature_importance.csv"),
  file.path("reports", "feature_stability.csv"),
  file.path("reports", "flag_stability.csv"),
  file.path("reports", "null_permutation_benchmark.csv"),
  file.path("reports", "model_signal_ceiling.csv"),
  file.path("reports", "model_bootstrap_validation.csv"),
  file.path("reports", "shrinkage_status.csv"),
  file.path("reports", "shrinkage_review.csv"),
  file.path("reports", "future_review_priorities.csv"),
  file.path("reports", "intervention_targets.csv"),
  file.path("reports", "latest_teacher_review.csv"),
  file.path("reports", "latest_course_review.csv"),
  file.path("reports", "latest_section_review.csv"),
  file.path("reports", "section_ttests.csv"),
  file.path("reports", "section_adjusted_signals.csv"),
  file.path("reports", "section_signal_highlights.csv"),
  file.path("reports", "teacher_growth_summary.csv"),
  file.path("reports", "course_growth_summary.csv"),
  file.path("reports", "growth_diagnostics.csv"),
  file.path("reports", "growth_sensitivity.csv")
)

if (!all(file.exists(required_tables))) {
  source(file.path("R", "fit_growth_models.R"))
}

read_display_csv <- function(path, check_names = TRUE) {
  read.csv(
    path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = check_names
  )
}

metric_value <- function(metric_name, default = "") {
  value <- final_metrics$Value[final_metrics$Metric == metric_name]
  if (length(value) == 0 || is.na(value[1])) {
    return(default)
  }
  value[1]
}

profile_value <- function(measure_name, default = "") {
  value <- profile$Value[profile$Measure == measure_name]
  if (length(value) == 0 || is.na(value[1])) {
    return(default)
  }
  value[1]
}

strength_value <- function(measure_name, default = "") {
  value <- model_strength$Value[model_strength$Measure == measure_name]
  if (length(value) == 0 || is.na(value[1])) {
    return(default)
  }
  value[1]
}

as_report_num <- function(x) {
  suppressWarnings(as.numeric(gsub(",", "", x)))
}

signed_text <- function(x, digits = 2) {
  value <- as_report_num(x)
  ifelse(value > 0, paste0("+", format_num(value, digits)), format_num(value, digits))
}

artifact_ref <- function(path) {
  file <- basename(path)
  labels <- c(
    "intervention_targets.csv" = "decision table",
    "growth_model_comparison_display.csv" = "model comparison",
    "growth_model_search_grid.csv" = "model search grid",
    "growth_model_strength.csv" = "model strength",
    "growth_model_family_summary.csv" = "family summary",
    "growth_model_selection_rationale.csv" = "selection rationale",
    "model_temporal_validation.csv" = "temporal validation",
    "rolling_origin_validation.csv" = "rolling-origin validation",
    "process_validation.csv" = "process validation",
    "locked_holdout_validation.csv" = "locked holdout",
    "model_validity_targets.csv" = "validity targets",
    "feature_importance.csv" = "feature importance",
    "feature_stability.csv" = "feature stability",
    "flag_stability.csv" = "flag stability",
    "null_permutation_benchmark.csv" = "null benchmark",
    "model_signal_ceiling.csv" = "signal ceiling",
    "model_bootstrap_validation.csv" = "bootstrap validation",
    "latest_teacher_review.csv" = "teacher review",
    "latest_course_review.csv" = "course review",
    "latest_section_review.csv" = "section review",
    "shrinkage_status.csv" = "shrinkage status",
    "shrinkage_review.csv" = "shrinkage review",
    "section_adjusted_signals.csv" = "section signals",
    "growth_final_metrics.csv" = "selected-model metrics"
  )
  label <- ifelse(file %in% names(labels), unname(labels[file]), file)
  paste0("[", label, "](", file, ")")
}

top_n <- function(df, n = 10) {
  if (nrow(df) == 0) {
    return(df)
  }
  df[seq_len(min(nrow(df), n)), , drop = FALSE]
}

pretty_course <- function(course) {
  key <- sub("^MATH-", "", course)
  labels <- c(
    "ALG1" = "Alg 1",
    "ALG2" = "Alg 2",
    "ALG2-H" = "Alg 2 H",
    "GEOM" = "Geometry",
    "PRECALC" = "Precalc",
    "AP-PRECALC" = "AP Precalc",
    "AP-CALC-AB" = "AP Calc AB",
    "AP-CALC-BC" = "AP Calc BC",
    "BEYOND-CORE" = "Beyond Core"
  )
  ifelse(key %in% names(labels), unname(labels[key]), gsub("-", " ", key))
}

pretty_target <- function(target) {
  ifelse(grepl("^MATH-", target), pretty_course(target), target)
}

short_model_name <- function(model) {
  labels <- c(
    "Naive prior-year mean growth" = "Naive mean growth",
    "Growth linear benchmark" = "Growth linear",
    "Growth readiness model" = "Growth readiness",
    "Growth history-composition model" = "Growth history/composition",
    "Growth history interaction model" = "Growth history interactions",
    "Growth feature discovery model" = "Feature discovery LM",
    "Growth future planning benchmark" = "Future planning",
    "Growth spline history model" = "Spline history",
    "Growth polynomial degree 2" = "Growth poly d2",
    "Growth polynomial degree 3" = "Growth poly d3",
    "Growth interaction model" = "Growth interactions",
    "Growth cyclic interaction model" = "Growth cyclic",
    "Growth GAM k4" = "GAM k4",
    "Growth GAM k6" = "GAM k6",
    "Growth GAM k8" = "GAM k8",
    "Growth GAM k10" = "GAM k10",
    "Growth regression tree 1" = "Tree 1",
    "Growth regression tree 2" = "Tree 2",
    "Growth regression tree 3" = "Tree 3",
    "Growth random forest 1" = "RF 1",
    "Growth random forest 2" = "RF 2",
    "Growth random forest 3" = "RF 3",
    "Growth ranger forest 1" = "Ranger 1",
    "Growth gradient boosting 1" = "GBM 1",
    "Growth gradient boosting 2" = "GBM 2",
    "Growth gradient boosting 3" = "GBM 3",
    "Growth ridge" = "Growth ridge",
    "Growth elastic net" = "Growth elastic net",
    "Growth lasso" = "Growth lasso",
    "Growth MARS 1" = "MARS 1",
    "Growth MARS 2" = "MARS 2",
    "Growth stacked ensemble" = "Growth stacked ensemble",
    "EOY readiness benchmark" = "EOY readiness",
    "EOY interaction benchmark" = "EOY interaction",
    "Teacher/course leakage benchmark" = "ID benchmark",
    "Growth ensemble balanced" = "Ensemble balanced",
    "Growth ensemble nonlinear weighted" = "Ensemble weighted",
    "Growth ensemble discovery weighted" = "Discovery ensemble"
  )
  ifelse(model %in% names(labels), unname(labels[model]), model)
}

short_family_name <- function(family) {
  labels <- c(
    "Naive baseline" = "Naive",
    "Validation ensemble" = "Ensemble",
    "Stacked validation ensemble" = "Stacked",
    "Non-parametric boosting" = "Boosting",
    "Non-parametric random forest" = "RF",
    "Non-parametric ranger forest" = "Ranger",
    "Non-parametric tree" = "Tree",
    "Adaptive spline MARS" = "MARS",
    "Semi-parametric GAM" = "GAM",
    "Feature-engineered parametric" = "Feature LM",
    "Natural spline regression" = "Spline",
    "Regularized regression" = "Regularized",
    "Parametric polynomial" = "Polynomial",
    "Parametric linear" = "Linear",
    "Parametric interactions" = "Interactions",
    "Parametric cyclic" = "Cyclic",
    "Parametric history/composition" = "History",
    "Lagged teacher/course context" = "Future context",
    "EOY-derived benchmark" = "EOY benchmark",
    "Leakage benchmark" = "ID benchmark"
  )
  ifelse(family %in% names(labels), unname(labels[family]), family)
}

short_section_label <- function(section) {
  section_num <- suppressWarnings(as.integer(sub("^Y[0-9]+-SEC-", "", section)))
  ifelse(is.na(section_num), section, sprintf("S%02d", section_num))
}

decision_priority <- function(decision) {
  priorities <- c(
    "Intervention target" = 1,
    "Positive anomaly" = 2,
    "Watch list" = 3,
    "Insufficient sample" = 4,
    "In range" = 5
  )
  out <- priorities[decision]
  out[is.na(out)] <- 9
  as.integer(out)
}

compact_review <- function(df, id_col, n = 8) {
  if (nrow(df) == 0) {
    return(df)
  }
  df$PriorityOrder <- decision_priority(df$Decision)
  df$GapValue <- as_report_num(df$Adjusted_gap)
  df <- df[
    df$Decision != "In range" & df$Decision != "Insufficient sample",
    ,
    drop = FALSE
  ]
  if (nrow(df) == 0) {
    return(data.frame(
      Target = character(),
      N = character(),
      Raw = character(),
      Expected = character(),
      Gap = character(),
      CI = character(),
      q = character(),
      Decision = character(),
      stringsAsFactors = FALSE
    ))
  }
  df <- df[order(df$PriorityOrder, df$GapValue), , drop = FALSE]
  df <- top_n(df, n)
  target <- df[[id_col]]
  if (id_col == "course_id") {
    target <- pretty_course(target)
  }
  if (id_col == "section_id") {
    target <- short_section_label(target)
  }
  decision_label <- c(
    "Intervention target" = "Intervention",
    "Positive anomaly" = "Bright spot",
    "Watch list" = "Watch"
  )
  decision <- ifelse(df$Decision %in% names(decision_label),
    unname(decision_label[df$Decision]),
    df$Decision
  )
  data.frame(
    Target = target,
    N = df$N,
    Raw = df$Raw_gain,
    Expected = df$Expected_gain,
    Gap = signed_text(df$Adjusted_gap, 2),
    CI = df$CI_95,
    q = df$Q_value,
    Decision = decision,
    stringsAsFactors = FALSE
  )
}

compact_intervention_targets <- function(df, n = 14) {
  if (nrow(df) == 0) {
    return(df)
  }
  df$PriorityOrder <- decision_priority(df$Decision)
  df$GapValue <- as_report_num(df$Adjusted_gap)
  df <- df[order(df$PriorityOrder, df$GapValue), , drop = FALSE]
  df <- top_n(df, n)
  target <- df$Target
  target[df$Level == "Course"] <- pretty_course(target[df$Level == "Course"])
  target[df$Level == "Section"] <- sub(" / .*", "", target[df$Level == "Section"])
  target[df$Level == "Section"] <- sub(" \\| .*", "", target[df$Level == "Section"])
  target[df$Level == "Section"] <- short_section_label(target[df$Level == "Section"])
  decision_label <- c(
    "Intervention target" = "Intervention",
    "Positive anomaly" = "Bright spot",
    "Watch list" = "Watch"
  )
  decision <- ifelse(df$Decision %in% names(decision_label),
    unname(decision_label[df$Decision]),
    df$Decision
  )
  data.frame(
    Decision = decision,
    Slice = df$Level,
    Target = target,
    N = df$N,
    Gap = signed_text(df$Adjusted_gap, 2),
    `95% CI` = df$CI_95,
    q = df$Q_value,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

shrinkage_priority <- function(decision) {
  priorities <- c(
    "Shrunken intervention" = 1,
    "Shrunken positive" = 2,
    "Monitor" = 3,
    "Insufficient sample" = 4,
    "In range" = 5
  )
  out <- priorities[decision]
  out[is.na(out)] <- 9
  as.integer(out)
}

compact_shrinkage_review <- function(df, n = 12) {
  if (nrow(df) == 0) {
    return(df)
  }
  df$PriorityOrder <- shrinkage_priority(df$Decision)
  df$EffectValue <- as_report_num(df$`Shrunken gap`)
  df$AbsEffect <- abs(df$EffectValue)
  flagged <- df[
    df$Decision != "In range" & df$Decision != "Insufficient sample",
    ,
    drop = FALSE
  ]
  if (nrow(flagged) == 0) {
    flagged <- df[df$Decision == "In range", , drop = FALSE]
    if (nrow(flagged) == 0) {
      flagged <- df
    }
    flagged <- flagged[order(-flagged$AbsEffect), , drop = FALSE]
  } else {
    flagged <- flagged[order(flagged$PriorityOrder, flagged$EffectValue), , drop = FALSE]
  }
  flagged <- top_n(flagged, n)
  target <- flagged$Target
  target[flagged$Level == "Course"] <- pretty_course(target[flagged$Level == "Course"])
  target[flagged$Level == "Section"] <- short_section_label(target[flagged$Level == "Section"])
  decision_label <- c(
    "Shrunken intervention" = "Intervention",
    "Shrunken positive" = "Bright spot",
    "Monitor" = "Monitor",
    "Insufficient sample" = "Small n",
    "In range" = "In range"
  )
  decision <- ifelse(flagged$Decision %in% names(decision_label),
    unname(decision_label[flagged$Decision]),
    flagged$Decision
  )
  data.frame(
    Slice = flagged$Level,
    Target = target,
    N = flagged$N,
    `Raw gap` = signed_text(flagged$`Raw gap`, 2),
    `Shrunken gap` = signed_text(flagged$`Shrunken gap`, 2),
    `95% CI` = flagged$`95% CI`,
    q = flagged$`q-value`,
    Decision = decision,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

profile <- read_display_csv(file.path("reports", "growth_extract_profile.csv"))
model_comparison <- read_display_csv(
  file.path("reports", "growth_model_comparison_display.csv"),
  check_names = FALSE
)
model_search_grid <- read_display_csv(file.path("reports", "growth_model_search_grid.csv"))
model_strength <- read_display_csv(file.path("reports", "growth_model_strength.csv"))
family_summary <- read_display_csv(file.path("reports", "growth_model_family_summary.csv"))
selection_rationale <- read_display_csv(file.path("reports", "growth_model_selection_rationale.csv"))
shape_review <- read_display_csv(file.path("reports", "growth_shape_review.csv"))
final_metrics <- read_display_csv(file.path("reports", "growth_final_metrics.csv"))
dependency_status <- read_display_csv(file.path("reports", "model_dependency_status.csv"))
temporal_validation <- read_display_csv(file.path("reports", "model_temporal_validation.csv"))
rolling_origin_validation <- read_display_csv(file.path("reports", "rolling_origin_validation.csv"))
process_validation <- read_display_csv(file.path("reports", "process_validation.csv"))
locked_holdout_validation <- read_display_csv(file.path("reports", "locked_holdout_validation.csv"))
model_validity_targets <- read_display_csv(file.path("reports", "model_validity_targets.csv"))
feature_importance <- read_display_csv(file.path("reports", "feature_importance.csv"))
feature_stability <- read_display_csv(file.path("reports", "feature_stability.csv"))
flag_stability <- read_display_csv(file.path("reports", "flag_stability.csv"))
null_permutation_benchmark <- read_display_csv(file.path("reports", "null_permutation_benchmark.csv"))
model_signal_ceiling <- read_display_csv(file.path("reports", "model_signal_ceiling.csv"))
bootstrap_validation <- read_display_csv(file.path("reports", "model_bootstrap_validation.csv"))
shrinkage_status <- read_display_csv(file.path("reports", "shrinkage_status.csv"))
shrinkage_review <- read_display_csv(file.path("reports", "shrinkage_review.csv"))
future_priorities <- read_display_csv(file.path("reports", "future_review_priorities.csv"))
intervention_targets <- read_display_csv(file.path("reports", "intervention_targets.csv"))
latest_teacher_review <- read_display_csv(file.path("reports", "latest_teacher_review.csv"))
latest_course_review <- read_display_csv(file.path("reports", "latest_course_review.csv"))
latest_section_review <- read_display_csv(file.path("reports", "latest_section_review.csv"))
section_ttests <- read_display_csv(file.path("reports", "section_ttests.csv"))
section_signals <- read_display_csv(file.path("reports", "section_adjusted_signals.csv"))
section_highlights <- read_display_csv(file.path("reports", "section_signal_highlights.csv"))
teacher_summary <- read_display_csv(file.path("reports", "teacher_growth_summary.csv"))
course_summary <- read_display_csv(file.path("reports", "course_growth_summary.csv"))
diagnostics <- read_display_csv(file.path("reports", "growth_diagnostics.csv"))
sensitivity <- read_display_csv(file.path("reports", "growth_sensitivity.csv"))

names(model_comparison) <- c(
  "Model", "Selected", "Role", "Target", "Method", "Family", "Complexity",
  "Tuned", "Eligible", "Params", "CV RMSE", "CV SD", "CV MAE", "CV R2",
  "CV EOY R2", "Temporal RMSE", "Temporal SD", "Temporal R2",
  "Temporal EOY R2", "Latest RMSE", "Latest MAE", "Latest R2",
  "Latest EOY R2", "Train R2", "Adj R2", "AIC", "BIC", "Delta"
)
names(model_strength) <- c("Measure", "Value")
names(family_summary) <- c(
  "Family", "Candidates", "Eligible", "Best model", "Selected family",
  "Best temporal RMSE", "Best delta RMSE", "Best temporal MAE",
  "Best temporal R2", "Best latest RMSE", "Best latest R2",
  "Best tuned parameters"
)
names(selection_rationale) <- c("Decision", "Rationale")
names(shape_review) <- c(
  "Family", "Representative model", "Why tested", "Decision",
  "Temporal RMSE", "Latest RMSE"
)
names(dependency_status) <- c("Package", "Installed")
names(model_validity_targets) <- c(
  "Metric", "Minimum", "Decision grade", "Stretch", "Actual", "Direction",
  "Evidence role", "Status", "Actual display", "Decision display"
)
names(feature_importance) <- c("Feature", "RMSE increase", "RMSE increase SD", "Rank")
names(feature_stability) <- c("Feature", "Positive importance", "Top-quartile importance", "Rank")
names(flag_stability) <- c(
  "Level", "Target", "N", "Adjusted gap", "Decision", "Stability",
  "Required stability", "Status"
)
names(locked_holdout_validation) <- c("Metric", "Value", "Display value")
names(model_signal_ceiling) <- c("Diagnostic", "Value", "Display value")
names(shrinkage_status) <- c("Measure", "Value")
names(shrinkage_review) <- c(
  "Level", "Target", "N", "Raw gap", "Shrunken gap", "95% CI",
  "p-value", "q-value", "Decision"
)
names(section_ttests) <- c(
  "Section", "Teacher", "Course", "Year", "N", "BOY", "EOY",
  "Gain", "95% CI", "p-value", "q-value"
)
names(section_signals) <- c(
  "Section", "Teacher", "Course", "Year", "N", "Raw gain", "Expected gain",
  "Adjusted signal", "Residual CI", "Category"
)
names(section_highlights) <- c(
  "Section", "Teacher", "Course", "Year", "N", "Raw gain", "Expected gain",
  "Adjusted signal", "Category"
)
names(teacher_summary) <- c(
  "Teacher", "Sections", "Records", "BOY", "EOY", "Raw gain",
  "Expected gain", "Adjusted signal"
)
names(course_summary) <- c(
  "Course", "Track", "Sections", "Records", "BOY", "EOY", "Raw gain",
  "Expected gain", "Adjusted signal"
)
names(diagnostics) <- c("Diagnostic", "Estimate", "Interpretation")
names(sensitivity) <- c("Measure", "Value")

selected_model <- metric_value("Selected model")
selected_target <- metric_value("Selected target strategy")
selected_method <- metric_value("Selected method")
selected_family <- metric_value("Selected family")
selected_tuned <- metric_value("Selected tuned parameters")
selected_tuned_text <- if (selected_model == "Growth ensemble balanced") {
  "an equal-weight blend of gradient boosting, GAM, elastic-net, and history/composition growth predictions"
} else if (selected_model == "Growth ensemble nonlinear weighted") {
  "a GBM-weighted blend of nonlinear, regularized, and history/composition growth predictions"
} else if (selected_model == "Growth stacked ensemble") {
  "an out-of-fold learned blend of nonlinear, regularized, and history/composition growth predictions"
} else {
  selected_tuned
}
selection_rule <- metric_value("Selection rule")
candidate_count <- metric_value("Candidate models tested")
included_pairs <- profile_value("Included paired records")
section_groups <- profile_value("Unique section-year groups")
teachers <- profile_value("Unique simulated teachers")
training_records <- metric_value("Training paired records")
action_records <- metric_value("Latest-year action paired records")
training_years <- metric_value("Training years")
action_year <- metric_value("Action year")
mean_gain <- metric_value("Mean raw BOY/EOY gain")
latest_gain <- sensitivity$Value[sensitivity$Measure == "Latest-year mean raw BOY/EOY gain"][1]
temporal_gain_rmse <- metric_value("Temporal expected-gain RMSE")
temporal_gain_mae <- metric_value("Temporal expected-gain MAE")
temporal_gain_r2 <- metric_value("Temporal expected-gain R-squared")
temporal_gain_sd <- metric_value("Temporal expected-gain RMSE SD")
temporal_eoy_r2 <- metric_value("Temporal EOY R-squared")
latest_gain_rmse <- metric_value("Latest-year expected-gain RMSE")
latest_gain_mae <- metric_value("Latest-year expected-gain MAE")
latest_gain_r2 <- metric_value("Latest-year expected-gain R-squared")
latest_eoy_r2 <- metric_value("Latest-year EOY R-squared")
latest_section_groups <- metric_value("Latest-year section groups")
temporal_rmse_improvement <- strength_value("Temporal RMSE improvement percent")
latest_rmse_improvement <- strength_value("Latest-year RMSE improvement percent")
latest_mae_improvement <- strength_value("Latest-year MAE improvement percent")
section_mean_r2 <- strength_value("Latest-year section-mean gain R-squared")
teacher_mean_r2 <- strength_value("Latest-year teacher-mean gain R-squared")
course_mean_r2 <- strength_value("Latest-year course-mean gain R-squared")

selected_row <- model_comparison[model_comparison$Selected == "Yes", , drop = FALSE]
eligible_model_rows <- model_comparison[
  model_comparison$Eligible == "Yes" &
    model_comparison$Role == "Operational candidate" &
    model_comparison$Target == "Direct growth",
  ,
  drop = FALSE
]
best_temporal_row <- if (nrow(eligible_model_rows) > 0) {
  eligible_model_rows[order(as_report_num(eligible_model_rows$`Temporal RMSE`)), , drop = FALSE][1, , drop = FALSE]
} else {
  model_comparison[1, , drop = FALSE]
}
best_overall_row <- model_comparison[1, , drop = FALSE]

teacher_priority <- compact_review(latest_teacher_review, "teacher_id", 8)
course_priority <- compact_review(latest_course_review, "course_id", 8)
section_priority <- compact_review(latest_section_review, "section_id", 8)
target_report <- compact_intervention_targets(intervention_targets, 14)
priority_target_report <- compact_intervention_targets(
  intervention_targets[
    intervention_targets$Decision %in% c("Intervention target", "Positive anomaly"),
    ,
    drop = FALSE
  ],
  8
)
if (nrow(priority_target_report) == 0) {
  priority_target_report <- compact_intervention_targets(intervention_targets, 8)
}
front_priority_report <- compact_intervention_targets(
  intervention_targets[
    intervention_targets$Decision == "Intervention target",
    ,
    drop = FALSE
  ],
  5
)
if (nrow(front_priority_report) == 0) {
  front_priority_report <- priority_target_report
}

decision_counts <- data.frame(
  Slice = c("Teachers", "Courses", "Sections"),
  `Priority or watch rows` = c(nrow(teacher_priority), nrow(course_priority), nrow(section_priority)),
  `Total reviewed` = c(
    nrow(latest_teacher_review),
    nrow(latest_course_review),
    nrow(latest_section_review)
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

model_strength_report <- model_strength[
  model_strength$Measure %in% c(
    "Naive temporal RMSE",
    "Selected temporal RMSE",
    "Temporal RMSE improvement percent",
    "Naive latest-year RMSE",
    "Selected latest-year RMSE",
    "Latest-year RMSE improvement percent",
    "Naive latest-year MAE",
    "Selected latest-year MAE",
    "Latest-year MAE improvement percent",
    "Selected latest-year gain R-squared",
    "Selected latest-year EOY R-squared",
    "Latest-year section-mean gain R-squared",
    "Latest-year teacher-mean gain R-squared",
    "Latest-year course-mean gain R-squared"
  ),
  ,
  drop = FALSE
]
model_strength_report$Measure <- c(
  "Naive temporal RMSE",
  "Selected temporal RMSE",
  "Temporal RMSE improvement",
  "Naive latest-year RMSE",
  "Selected latest-year RMSE",
  "Latest-year RMSE improvement",
  "Naive latest-year MAE",
  "Selected latest-year MAE",
  "Latest-year MAE improvement",
  "Latest-year gain R-squared",
  "Latest-year EOY R-squared",
  "Section-mean gain R-squared",
  "Teacher-mean gain R-squared",
  "Course-mean gain R-squared"
)

target_status_counts <- table(model_validity_targets$Status)
primary_targets <- model_validity_targets[
  model_validity_targets$`Evidence role` == "Primary gate",
  ,
  drop = FALSE
]
primary_pass_count <- sum(primary_targets$Status == "Pass")
primary_total_count <- nrow(primary_targets)
decision_grade_status <- ifelse(
  primary_pass_count == primary_total_count &&
    all(model_validity_targets$Status[model_validity_targets$`Evidence role` == "Calibration gate"] == "Pass"),
  "decision-grade",
  "review-priority"
)
validity_report <- model_validity_targets[
  model_validity_targets$Metric %in% c(
    "Rolling RMSE lift vs naive",
    "Rolling MAE lift vs naive",
    "Temporal gain R-squared",
    "Section mean gain R-squared",
    "Course mean gain R-squared",
    "Teacher mean gain R-squared",
    "Overall residual bias",
    "Maximum subgroup residual bias"
  ),
  c("Metric", "Decision display", "Actual display", "Status"),
  drop = FALSE
]
names(validity_report) <- c("Gate", "Decision-grade", "Actual", "Status")

feature_importance_report <- top_n(feature_importance, 10)
feature_importance_report$Feature <- gsub("_", " ", feature_importance_report$Feature)
feature_importance_report$`RMSE increase` <- format_num(as_report_num(feature_importance_report$`RMSE increase`), 3)
feature_importance_report$`RMSE increase SD` <- format_num(as_report_num(feature_importance_report$`RMSE increase SD`), 3)
feature_importance_report <- feature_importance_report[
  ,
  c("Feature", "RMSE increase", "RMSE increase SD"),
  drop = FALSE
]
names(feature_importance_report) <- c("Feature", "RMSE lift if permuted", "SD")

feature_stability_report <- top_n(feature_stability, 10)
feature_stability_report$Feature <- gsub("_", " ", feature_stability_report$Feature)
feature_stability_report$`Positive importance` <- format_pct(as_report_num(feature_stability_report$`Positive importance`), 0)
feature_stability_report$`Top-quartile importance` <- format_pct(as_report_num(feature_stability_report$`Top-quartile importance`), 0)
feature_stability_report <- feature_stability_report[
  ,
  c("Feature", "Positive importance", "Top-quartile importance"),
  drop = FALSE
]

flag_stability_report <- flag_stability[
  flag_stability$Decision != "In range" &
    flag_stability$Decision != "Insufficient sample",
  ,
  drop = FALSE
]
flag_stability_report <- flag_stability_report[
  order(as_report_num(flag_stability_report$Stability), decreasing = TRUE),
  ,
  drop = FALSE
]
flag_stability_report <- top_n(flag_stability_report, 10)
flag_stability_report$`Adjusted gap` <- signed_text(flag_stability_report$`Adjusted gap`, 2)
flag_stability_report$Stability <- format_pct(as_report_num(flag_stability_report$Stability), 0)
flag_stability_report$`Required stability` <- format_pct(as_report_num(flag_stability_report$`Required stability`), 0)
flag_stability_report <- flag_stability_report[
  ,
  c("Level", "Target", "N", "Adjusted gap", "Decision", "Stability", "Status"),
  drop = FALSE
]

holdout_report <- locked_holdout_validation[
  ,
  c("Metric", "Display value"),
  drop = FALSE
]
names(holdout_report) <- c("Metric", "Value")

signal_ceiling_report <- model_signal_ceiling[
  ,
  c("Diagnostic", "Display value"),
  drop = FALSE
]
names(signal_ceiling_report) <- c("Diagnostic", "Value")

shrinkage_report <- compact_shrinkage_review(shrinkage_review, 12)

model_comparison_compact <- model_comparison
model_comparison_compact$Model <- short_model_name(model_comparison_compact$Model)
model_comparison_compact$Family <- short_family_name(model_comparison_compact$Family)
model_comparison_compact$Interpretation <- ifelse(
  model_comparison_compact$Selected == "Yes",
  "Selected",
  ifelse(
    model_comparison$Role == "Excluded leakage benchmark",
    "Excluded",
    ifelse(
      model_comparison_compact$Eligible == "Yes" &
        as_report_num(model_comparison_compact$Delta) <= 0.10,
      "Near tie",
      "Not selected"
    )
  )
)
model_rows <- unique(c(
  which(model_comparison_compact$Eligible == "Yes")[seq_len(min(7, sum(model_comparison_compact$Eligible == "Yes")))],
  which(model_comparison$Role == "Excluded leakage benchmark")[1]
))
model_rows <- model_rows[!is.na(model_rows)]
model_comparison_report <- model_comparison_compact[
  model_rows,
  c(
    "Model", "Family", "Selected",
    "Temporal RMSE", "Latest RMSE", "Latest MAE", "Latest R2",
    "Interpretation"
  ),
  drop = FALSE
]
names(model_comparison_report) <- c(
  "Candidate model", "Model type", "Used?",
  "Rolling RMSE", "Latest RMSE", "Latest MAE", "Gain R2",
  "Read"
)

family_summary_report <- family_summary[
  ,
  c(
    "Family", "Best model", "Selected family",
    "Best temporal RMSE", "Best latest RMSE"
  ),
  drop = FALSE
]
family_summary_report$Family <- short_family_name(family_summary_report$Family)
family_summary_report[["Best model"]] <- short_model_name(family_summary_report[["Best model"]])
names(family_summary_report) <- c(
  "Family", "Best model", "Selected",
  "Temporal RMSE", "Latest RMSE"
)
family_summary_report <- top_n(family_summary_report, 8)

shape_review_report <- shape_review[
  ,
  c("Family", "Representative model", "Decision", "Temporal RMSE", "Latest RMSE"),
  drop = FALSE
]
shape_review_report[["Representative model"]] <- short_model_name(
  shape_review_report[["Representative model"]]
)
shape_review_report$Decision <- ifelse(
  grepl("^Selected", shape_review_report$Decision),
  "Selected",
  ifelse(grepl("^Excluded", shape_review_report$Decision), "Excluded", "Compared")
)
names(shape_review_report) <- c(
  "Family", "Representative model", "Decision", "Temporal RMSE", "Latest RMSE"
)

bootstrap_report <- bootstrap_validation
names(bootstrap_report) <- c("Metric", "Estimate", "CI lower", "CI upper")
bootstrap_report$Estimate <- format_num(as_report_num(bootstrap_report$Estimate), 3)
bootstrap_report$`95% interval` <- paste0(
  format_num(as_report_num(bootstrap_report$`CI lower`), 3),
  " to ",
  format_num(as_report_num(bootstrap_report$`CI upper`), 3)
)
bootstrap_report <- bootstrap_report[, c("Metric", "Estimate", "95% interval"), drop = FALSE]

section_highlights_report <- section_highlights
section_highlights_report$Section <- short_section_label(section_highlights_report$Section)
section_highlights_report$Course <- pretty_course(section_highlights_report$Course)
section_highlights_report$`Adjusted signal` <- signed_text(section_highlights_report$`Adjusted signal`, 2)
section_highlights_report$Category <- c(
  "Within expected range" = "In range",
  "Above expected" = "Above",
  "Below expected" = "Below",
  "Small group" = "Small n"
)[section_highlights_report$Category]
section_highlights_report <- section_highlights_report[
  ,
  c(
    "Section", "Teacher", "Course", "N", "Raw gain",
    "Expected gain", "Adjusted signal", "Category"
  ),
  drop = FALSE
]
names(section_highlights_report) <- c(
  "Section", "Teacher", "Course", "N", "Raw", "Expected", "Signal", "Result"
)
if (nrow(section_highlights_report) > 8) {
  section_highlights_report <- rbind(
    head(section_highlights_report, 4),
    tail(section_highlights_report, 4)
  )
}

teacher_summary_report <- top_n(teacher_summary, 10)
teacher_summary_report$`Adjusted signal` <- signed_text(teacher_summary_report$`Adjusted signal`, 2)
teacher_summary_report <- teacher_summary_report[
  ,
  c("Teacher", "Sections", "Records", "Raw gain", "Expected gain", "Adjusted signal"),
  drop = FALSE
]
names(teacher_summary_report) <- c("Teacher", "Sections", "Records", "Raw", "Expected", "Signal")

course_summary_report <- top_n(course_summary, 10)
course_summary_report$Course <- pretty_course(course_summary_report$Course)
course_summary_report$`Adjusted signal` <- signed_text(course_summary_report$`Adjusted signal`, 2)
course_summary_report <- course_summary_report[
  ,
  c("Course", "Sections", "Records", "Raw gain", "Expected gain", "Adjusted signal"),
  drop = FALSE
]
names(course_summary_report) <- c("Course", "Sections", "Records", "Raw", "Expected", "Signal")

raw_improvement_report <- top_n(section_ttests, 8)
raw_improvement_report$Section <- short_section_label(raw_improvement_report$Section)
raw_improvement_report$Course <- pretty_course(raw_improvement_report$Course)
raw_improvement_report <- raw_improvement_report[
  ,
  c("Section", "Course", "N", "BOY", "EOY", "Gain", "95% CI", "p-value"),
  drop = FALSE
]

diagnostics_report <- diagnostics[
  diagnostics$Diagnostic %in% c(
    "Latest-year expected-gain RMSE",
    "Latest-year expected-gain R-squared",
    "Latest-year EOY R-squared",
    "Latest-year residual mean",
    "Latest-year residual SD"
  ),
  ,
  drop = FALSE
]

sensitivity_report <- sensitivity[
  sensitivity$Measure %in% c(
    "Training paired records",
    "Latest-year paired records",
    "Latest-year section-year groups",
    "Latest-year mean raw BOY/EOY gain",
    "Latest-year raw-vs-adjusted rank correlation",
    "Latest-year top-10 overlap, raw vs adjusted ranking"
  ),
  ,
  drop = FALSE
]

appendix_metric_names <- c(
  "Selected model",
  "Selected target strategy",
  "Selected method",
  "Selected family",
  "Selected tuned parameters",
  "Selection rule",
  "Training paired records",
  "Latest-year action paired records",
  "Training years",
  "Action year",
  "Candidate models tested",
  "Operational candidates tested",
  "Excluded leakage benchmarks",
  "Repeated CV folds",
  "Repeated CV repeats",
  "Temporal expected-gain RMSE",
  "Temporal expected-gain MAE",
  "Temporal expected-gain R-squared",
  "Temporal expected-gain RMSE SD",
  "Temporal EOY R-squared",
  "Latest-year expected-gain RMSE",
  "Latest-year expected-gain MAE",
  "Latest-year expected-gain R-squared",
  "Latest-year EOY R-squared"
)
appendix_metrics <- final_metrics[
  match(appendix_metric_names, final_metrics$Metric),
  ,
  drop = FALSE
]
appendix_metrics <- appendix_metrics[!is.na(appendix_metrics$Metric), , drop = FALSE]
appendix_metrics$Metric[appendix_metrics$Metric == "Excluded leakage benchmarks"] <- "Excluded ID benchmarks"

dependency_report <- dependency_status
dependency_report$Installed <- ifelse(dependency_report$Installed == "TRUE", "Available", "Not installed")

selection_delta <- if (nrow(selected_row) > 0) {
  selected_delta <- as_report_num(selected_row$`Temporal RMSE`) -
    as_report_num(best_temporal_row$`Temporal RMSE`)
  format_num(selected_delta, 3)
} else {
  ""
}

if (nrow(best_overall_row) > 0 &&
    best_overall_row$Model != best_temporal_row$Model &&
    best_overall_row$Eligible != "Yes") {
  overall_context <- paste0(
    "The lowest overall temporal RMSE was **", best_overall_row$`Temporal RMSE`,
    "** from **", best_overall_row$Model,
    "**, but that row is reported as a benchmark rather than an operating baseline because it is not an eligible direct-growth candidate."
  )
} else {
  overall_context <- ""
}

selection_result_text <- if (nrow(selected_row) > 0 &&
                             selected_row$Model == best_temporal_row$Model) {
  paste0(
    "The best eligible direct-growth rolling-origin RMSE was **", best_temporal_row$`Temporal RMSE`,
    "** from **", best_temporal_row$Model,
    "**, so it is the operating baseline. Repeated-CV RMSE remains a stability check for candidates that are practically tied on rolling-origin RMSE."
  )
} else {
  paste0(
    "The best eligible direct-growth rolling-origin RMSE was **", best_temporal_row$`Temporal RMSE`,
    "** from **", best_temporal_row$Model, "**. ",
    "The selected model's temporal RMSE was **", selected_row$`Temporal RMSE`,
    "**, a difference of ", selection_delta,
    " points. Because that difference is below the 0.01-point practical tolerance, the selected model is the operating baseline because it has the strongest repeated-CV RMSE among the temporally tied direct-growth candidates."
  )
}

report_lines <- c(
  "# Assessment Growth and Section Performance Analytics in R",
  "",
  "## Recommendation",
  "",
  paste0(
    "Use prior completed assessment years to build and validate an expected-growth baseline, then apply that baseline to the latest completed year, **", action_year,
    "**, to identify teacher, course, and section patterns that may deserve review before the next cycle. ",
    "The stakeholder metric is **BOY/EOY score gain**: end-of-year score minus beginning-of-year score for the same student record."
  ),
  "",
  paste0(
    "Historical years establish expected growth. The latest completed year is scored against that expectation to produce current review priorities."
  ),
  "",
  "## How To Read The Model Results",
  "",
  paste0(
    "The model is designed for **group-level review**, not individual student forecasting. ",
    "Individual growth varies because similar students can improve by different amounts for reasons not fully captured in the extract. ",
    "For that reason, the latest-year individual gain R-squared of **", latest_gain_r2,
    "** is a supporting model-quality measure, not the primary decision measure."
  ),
  "",
  paste0(
    "The decision question is group-level: after adjusting for starting score, readiness, attendance, prior history, course track, grade level, and section composition, ",
    "did a teacher, course, or section produce more or less average growth than expected? ",
    "That comparison is more stable because student-level noise partly averages out across groups."
  ),
  "",
  paste0(
    "The EOY R-squared of **", latest_eoy_r2,
    "** is reported only to show that final score is more directly related to BOY score. ",
    "It should not be read as evidence that the model precisely predicts improvement. ",
    "The relevant evidence is out-of-sample lift versus a naive baseline, aggregate fit, residual calibration, uncertainty intervals, and flag stability."
  ),
  "",
  paste0(
    "The baseline selected for operations is **", selected_model, "**. ",
    "It predicts **score gain directly** using a ", selected_family,
    " specification. The selected tuning choice is ", selected_tuned_text, ". ",
    "Against a naive prior-year mean-growth baseline, the selected model improves temporal RMSE by **",
    temporal_rmse_improvement, "** and latest-year RMSE by **", latest_rmse_improvement, "**."
  ),
  "",
  paste0(
    "Under the validation framework, this model is best described as **",
    decision_grade_status,
    "** evidence: ", primary_pass_count, " of ", primary_total_count,
    " primary gates passed. The model is useful for structured review and prioritization, while the final interpretation should remain a review process rather than a stand-alone score."
  ),
  "",
  paste0(
    "Because decisions are made at aggregate review levels, the planning-level fit is more relevant than the individual gain R-squared: latest-year gain R-squared is **",
    section_mean_r2, "** for section means, **", course_mean_r2,
    "** for course means, and **", teacher_mean_r2, "** for teacher means."
  ),
  "",
  "The workflow uses the direct-growth model to create a fair expected-growth baseline, then identifies aggregate teacher, course, and section residuals with bootstrap uncertainty checks.",
  "",
  markdown_table(decision_counts),
  "",
  markdown_table(front_priority_report),
  "",
  paste0(
    "Bright spots, watch-list rows, and the full decision table are generated as ",
    artifact_ref("reports/intervention_targets.csv"), "."
  ),
  "",
  "## Plain-English Method",
  "",
  "1. Build a paired BOY/EOY growth extract from public-safe assessment records.",
  "2. Define the business outcome as score gain: EOY score minus BOY score.",
  "3. Use prior completed years to engineer pre-outcome predictors, compare candidate models, and select the expected-growth baseline.",
  "4. Hold out the latest completed year as the action-year review period.",
  "5. Score latest-year records against the prior-year baseline.",
  "6. Aggregate observed-minus-expected growth by teacher, course, and section.",
  "7. Flag review targets when the gap is large enough to matter and the uncertainty check supports follow-up.",
  "",
  paste0(
    "This design separates the prediction problem from the decision problem. ",
    "The prediction model estimates what growth would be expected for a similar starting profile; the review layer asks where actual growth departed from that expectation."
  ),
  "",
  "## Direct Answers",
  "",
  paste0("1. The analysis covers ", included_pairs, " paired BOY/EOY records across ", section_groups, " section-year groups and ", teachers, " teacher identifiers."),
  paste0("2. The training window is ", training_years, "; the action year is ", action_year, "."),
  paste0("3. The average raw gain across the full extract is ", mean_gain, " points; the latest-year raw gain is ", latest_gain, " points."),
  paste0("4. The model search tested ", candidate_count, " candidate baselines across parametric, nonlinear, ensemble, and excluded ID-benchmark families."),
  paste0("5. The selected direct-growth baseline has temporal expected-gain RMSE ", temporal_gain_rmse, ", temporal MAE ", temporal_gain_mae, ", latest-year RMSE ", latest_gain_rmse, ", and latest-year MAE ", latest_gain_mae, "."),
  "6. The individual gain R-squared is a supporting model-quality measure; the review decision is based on group-level observed-minus-expected growth.",
  "7. Teacher, course, and section flags are review priorities for planning and follow-up.",
  "",
  "## Data Audit",
  "",
  "A record enters the growth model only when the same public-safe student has valid BOY and EOY scores in the same section and teacher context. This keeps improvement tied to one instructional experience instead of mixing students across sections.",
  "",
  markdown_table(profile),
  "",
  "## Model Selection",
  "",
  paste0(
    "The model discovery system used ", training_records, " prior-year pairs and held out ",
    action_records, " latest-year pairs for action-year evaluation. ",
    "The primary selection metric is rolling-origin temporal expected-gain RMSE, not latest-year performance, so each validation year is treated like the future."
  ),
  "",
  selection_result_text,
  "",
  overall_context,
  "",
  "The model-search guardrails were:",
  "",
  "- Use direct BOY/EOY score gain as the operating target because that is the stakeholder performance metric.",
  "- Select by rolling-origin temporal RMSE so the baseline is judged on future-facing generalization.",
  "- Use repeated-CV RMSE as the tie-breaker when rolling-origin RMSE differs by less than 0.01 points.",
  "- Keep teacher, course, and section identifiers out of the operating baseline because those are the groups being reviewed.",
  "- Use feature engineering only when the feature is available at BOY or from prior completed years.",
  "- Refit the selected production model on all completed years only after model selection.",
  "- Report individual gain R-squared as a supporting model-quality measure, not as the primary decision measure.",
  "- Report EOY R-squared only as context because final score is more directly related to starting score than growth is.",
  "",
  "The validation targets below are conservative. They keep the interpretation aligned with the strength of the evidence.",
  "",
  markdown_table(validity_report),
  "",
  "The first strength check is whether the selected model beats a naive baseline that predicts the training-year mean gain for every record. This is the minimum bar for using a model as an expected-growth baseline.",
  "",
  markdown_table(model_strength_report),
  "",
  "<!-- PDF_PAGE_BREAK -->",
  "",
  "The table below shows the strongest candidate baselines tested. The selected model was chosen by rolling-origin validation, not by whichever model looked best on the latest year. The excluded ID benchmark row is shown for transparency but is not eligible because it includes teacher/course identifiers that are part of the review layer.",
  "",
  markdown_table(model_comparison_report),
  "",
  paste0(
    "Full model artifacts: ",
    artifact_ref("reports/growth_model_comparison_display.csv"),
    ", ",
    artifact_ref("reports/growth_model_search_grid.csv"),
    ", ",
    artifact_ref("reports/growth_model_strength.csv"),
    ", ",
    artifact_ref("reports/growth_model_family_summary.csv"),
    ", ",
    artifact_ref("reports/growth_model_selection_rationale.csv"),
    ", ",
    artifact_ref("reports/model_temporal_validation.csv"),
    ", ",
    artifact_ref("reports/rolling_origin_validation.csv"),
    ", ",
    artifact_ref("reports/process_validation.csv"),
    ", ",
    artifact_ref("reports/locked_holdout_validation.csv"),
    ", ",
    artifact_ref("reports/model_validity_targets.csv"),
    ", and ",
    artifact_ref("reports/model_bootstrap_validation.csv"), "."
  ),
  "",
  "## Feature Discovery",
  "",
  "The model search includes time-appropriate feature engineering: multi-year prior student growth, prior trend and volatility, BOY score bands, section composition, attendance mix, nonlinear basis terms, and selected interactions. The table below shows which features mattered most when permuted in the locked action-year data.",
  "",
  markdown_table(feature_importance_report),
  "",
  "Feature stability asks whether the same predictors continue to matter across repeated perturbations.",
  "",
  markdown_table(feature_stability_report),
  "",
  paste0(
    "Feature artifacts: ",
    artifact_ref("reports/feature_importance.csv"),
    " and ",
    artifact_ref("reports/feature_stability.csv"), "."
  ),
  "",
  "![Model search by family and tuned candidate](../figures/growth_model_search.png)",
  "",
  "![Expected-growth model comparison](../figures/growth_model_comparison.png)",
  "",
  "<!-- PDF_PAGE_BREAK -->",
  "",
  "## Latest-Year Review Targets",
  "",
  paste0(
    "The latest-year review layer compares observed gain with expected gain for ",
    latest_section_groups, " section groups. ",
    "The decision labels use a practical review threshold: material gap, bootstrap interval direction, and BH-adjusted q-value for multiple-review control."
  ),
  "",
  "**Teacher review**",
  "",
  markdown_table(teacher_priority),
  "",
  "**Course review**",
  "",
  markdown_table(course_priority),
  "",
  "**Section evidence**",
  "",
  markdown_table(section_priority),
  "",
  paste0(
    "Full review tables: ",
    artifact_ref("reports/latest_teacher_review.csv"),
    ", ",
    artifact_ref("reports/latest_course_review.csv"),
    ", and ",
    artifact_ref("reports/latest_section_review.csv"), "."
  ),
  "",
  "A second review layer fits a mixed-effects shrinkage model on the latest-year residuals. It estimates teacher, course, and section effects at the same time and pulls noisier small-group estimates toward zero, so the strongest flags are less likely to be one-off small-section artifacts.",
  "",
  markdown_table(shrinkage_report),
  "",
  "Flag stability estimates how often a slice remains beyond the practical one-point gap threshold under bootstrap resampling. Directional rows should be reviewed with context; stable rows have stronger evidence for action.",
  "",
  markdown_table(flag_stability_report),
  "",
  paste0(
    "Shrinkage artifacts: ",
    artifact_ref("reports/shrinkage_status.csv"),
    " and ",
    artifact_ref("reports/shrinkage_review.csv"),
    ". Flag-stability artifacts: ",
    artifact_ref("reports/flag_stability.csv"), "."
  ),
  "",
  "<!-- PDF_PAGE_BREAK -->",
  "",
  "## Section Evidence",
  "",
  "Raw section improvement is useful for communication, but it is not the final comparison. A section can show positive raw gain and still fall below expected growth if its starting profile suggested a larger increase.",
  "",
  markdown_table(raw_improvement_report),
  "",
  "![Distribution of BOY/EOY improvement](../figures/growth_distribution.png)",
  "",
  "<!-- PDF_PAGE_BREAK -->",
  "",
  "The adjusted section signal is observed gain minus expected gain, reliability-weighted toward zero for smaller sections.",
  "",
  markdown_table(section_highlights_report),
  "",
  "![Sections above or below expected growth](../figures/section_adjusted_signals.png)",
  "",
  paste0(
    "The full section signal table is generated as ",
    artifact_ref("reports/section_adjusted_signals.csv"), "."
  ),
  "",
  "<!-- PDF_PAGE_BREAK -->",
  "",
  "## Teacher and Course Summaries",
  "",
  "These summaries aggregate the latest-year evidence into planning views. They support review conversations about pacing, curriculum alignment, attendance mix, and transferable practices.",
  "",
  markdown_table(teacher_summary_report),
  "",
  markdown_table(course_summary_report),
  "",
  "![Teacher and course growth summaries](../figures/teacher_course_summary.png)",
  "",
  "<!-- PDF_PAGE_BREAK -->",
  "",
  "## Diagnostics and Sensitivity",
  "",
  paste0(
    "The baseline is strong for final-score expectation and weaker for individual gain variation. ",
    "That pattern is expected: BOY score explains much of EOY score, while individual improvement contains more unobserved classroom, attendance, motivation, and assessment variation. ",
    "For review decisions, the model is used to build expected growth and then aggregate residuals by teacher, course, and section."
  ),
  "",
  markdown_table(diagnostics_report),
  "",
  markdown_table(bootstrap_report),
  "",
  markdown_table(holdout_report),
  "",
  markdown_table(signal_ceiling_report),
  "",
  markdown_table(sensitivity_report),
  "",
  "![Growth model diagnostics](../figures/growth_diagnostics.png)",
  "",
  "## Technical Appendix",
  "",
  "The operating model excludes teacher IDs, course IDs, and section IDs. An excluded ID benchmark is reported only to show what would happen if persistent IDs were included in the baseline; it is not used for review because it would absorb the same teacher/course patterns the decision layer is designed to examine.",
  "",
  markdown_table(dependency_report),
  "",
  markdown_table(appendix_metrics),
  "",
  paste0(
    "The full selected-model metrics table is generated as ",
    artifact_ref("reports/growth_final_metrics.csv"), "."
  ),
  "",
  "## Conclusion",
  "",
  "The project should be read as a statistical decision-support system. The strongest business value is the workflow: choose a validated expected-growth baseline, compare latest actual growth to that baseline at the group level, quantify uncertainty by slice, and translate the evidence into review priorities.",
  "",
  "The recommended stakeholder action is to review the flagged teacher, course, and section patterns before the next assessment cycle. Priority targets deserve support or investigation; positive anomalies deserve study for transferable practices; watch-list rows deserve context review before escalation.",
  "",
  "The important limitation is that the data are public-safe and generalized from an assessment workflow. The outputs demonstrate the analysis pattern and should be interpreted as portfolio evidence rather than operational decisions about real students or staff.",
  "",
  "## Reproducibility",
  "",
  "Rebuild the full evidence packet with `make all`. The pipeline uses the included public-safe extract and no credentials, private files, or network access.",
  "",
  "## Public-Safety Statement",
  "",
  "This report is an original public-safe portfolio artifact. It excludes private coursework prompts, exams, rubrics, syllabi, lecture transcripts, source datasets, personal data, real student-identifiable records, real personnel records, credentials, and copyrighted source documents."
)

writeLines(report_lines, file.path("reports", "assessment_growth_section_performance_report.md"))

executive_lines <- c(
  "# Executive Brief: Assessment Growth and Section Performance",
  "",
  paste0(
    "**Purpose:** use prior completed assessment years to build and validate an expected-growth baseline, then apply it to the latest completed year for teacher, course, and section review before the next cycle."
  ),
  "",
  paste0(
    "**Action year:** ", action_year,
    "; latest-year paired records: ", action_records,
    "; latest-year raw gain: ", latest_gain, " points."
  ),
  "",
  paste0(
    "**Baseline:** ", selected_model,
    " selected from ", candidate_count,
    " candidates using direct-growth temporal validation. It improves temporal RMSE by ",
    temporal_rmse_improvement,
    " and latest-year RMSE by ", latest_rmse_improvement,
    " versus a naive mean-growth baseline."
  ),
  "",
  paste0(
    "**How to read performance:** the model is designed for group-level review rather than individual student forecasting. ",
    "Individual gain R-squared is ", latest_gain_r2,
    ", while aggregate fit is stronger for teacher and course means. ",
    "Use the baseline to compare group-level actual growth with expected growth."
  ),
  "",
  paste0(
    "**Decision logic:** observed gain minus expected gain, reviewed by teacher, course, and section with bootstrap intervals and BH-adjusted q-values."
  ),
  "",
  markdown_table(priority_target_report),
  "",
  "**Appropriate use:** the outputs are review priorities for planning and follow-up."
)

writeLines(executive_lines, file.path("reports", "executive_brief.md"))

model_card_lines <- c(
  "# Model Card",
  "",
  "## Intended Use",
  "",
  "Estimate an expected BOY/EOY assessment-growth baseline from prior completed years and identify latest-year teacher, course, and section patterns that deserve future instructional review.",
  "",
  "## Not Intended For",
  "",
  "Teacher evaluation, compensation, discipline, student placement, grading, employment, admissions, clinical decisions, or automated decisions with real student or personnel data.",
  "",
  "## Data",
  "",
  paste0(
    "Public-safe paired BOY/EOY assessment records with ", included_pairs,
    " modeled pairs. The action-year review uses ", action_records,
    " latest-year pairs. Identifiers are simulated and generalized; no real student-identifiable or personnel records are included."
  ),
  "",
  "## Model",
  "",
  paste0(
    "Selected baseline: ", selected_model,
    ". The operating target is direct BOY/EOY score gain. Candidate families include a naive mean-growth benchmark, linear baselines, lagged-history and section-composition parametric models, polynomial terms, interaction surfaces, cyclic terms, GAM smooths, regularized regression, regression trees, random forests, gradient boosting, hand-weighted ensembles, stacked ensembles, EOY-derived benchmarks, and an excluded teacher/course ID benchmark."
  ),
  "",
  "## Validation",
  "",
  markdown_table(model_strength_report),
  "",
  markdown_table(appendix_metrics),
  "",
  markdown_table(bootstrap_report),
  "",
  "## Decision Layer",
  "",
  "Latest-year teacher, course, and section residuals are summarized with bootstrap intervals, p-values, BH-adjusted q-values, reliability weighting, mixed-effects shrinkage review, and decision labels. The labels are review priorities for planning and follow-up.",
  "",
  "## Monitoring Recommendations",
  "",
  "- Track BOY/EOY pairing rates and missing EOY assessments.",
  "- Monitor section sizes before ranking or escalating signals.",
  "- Refit the model when course mix, assessment design, or attendance patterns change.",
  "- Keep teacher, course, and section IDs out of the operating baseline when the goal is to surface those patterns for review.",
  "- Compare raw and adjusted growth before communicating findings.",
  "",
  "## Public-Safety Boundary",
  "",
  "No private coursework prompts, raw private source datasets, credentials, real student records, real personnel records, patient records, or customer records are included."
)

writeLines(model_card_lines, file.path("docs", "model-card.md"))
message("Wrote reports/assessment_growth_section_performance_report.md")
message("Wrote reports/executive_brief.md")
message("Wrote docs/model-card.md")
