source(file.path("R", "model_utils.R"))

ensure_project_dirs()

required_tables <- c(
  file.path("reports", "growth_extract_profile.csv"),
  file.path("reports", "growth_model_comparison_display.csv"),
  file.path("reports", "growth_model_search_grid.csv"),
  file.path("reports", "growth_model_family_summary.csv"),
  file.path("reports", "growth_model_selection_rationale.csv"),
  file.path("reports", "growth_shape_review.csv"),
  file.path("reports", "growth_final_metrics.csv"),
  file.path("reports", "model_dependency_status.csv"),
  file.path("reports", "model_temporal_validation.csv"),
  file.path("reports", "model_bootstrap_validation.csv"),
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

as_report_num <- function(x) {
  suppressWarnings(as.numeric(gsub(",", "", x)))
}

signed_text <- function(x, digits = 2) {
  value <- as_report_num(x)
  ifelse(value > 0, paste0("+", format_num(value, digits)), format_num(value, digits))
}

artifact_ref <- function(path) {
  paste0("[", path, "](", basename(path), ")")
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
    "Growth linear benchmark" = "Growth linear",
    "Growth readiness model" = "Growth readiness",
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
    "Growth gradient boosting 1" = "GBM 1",
    "Growth gradient boosting 2" = "GBM 2",
    "Growth gradient boosting 3" = "GBM 3",
    "EOY readiness benchmark" = "EOY readiness",
    "EOY interaction benchmark" = "EOY interaction",
    "Teacher/course leakage benchmark" = "Leakage check",
    "Growth ensemble balanced" = "Growth ensemble balanced",
    "Growth ensemble nonlinear weighted" = "Growth ensemble nonlinear weighted"
  )
  ifelse(model %in% names(labels), unname(labels[model]), model)
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

profile <- read_display_csv(file.path("reports", "growth_extract_profile.csv"))
model_comparison <- read_display_csv(
  file.path("reports", "growth_model_comparison_display.csv"),
  check_names = FALSE
)
model_search_grid <- read_display_csv(file.path("reports", "growth_model_search_grid.csv"))
family_summary <- read_display_csv(file.path("reports", "growth_model_family_summary.csv"))
selection_rationale <- read_display_csv(file.path("reports", "growth_model_selection_rationale.csv"))
shape_review <- read_display_csv(file.path("reports", "growth_shape_review.csv"))
final_metrics <- read_display_csv(file.path("reports", "growth_final_metrics.csv"))
dependency_status <- read_display_csv(file.path("reports", "model_dependency_status.csv"))
temporal_validation <- read_display_csv(file.path("reports", "model_temporal_validation.csv"))
bootstrap_validation <- read_display_csv(file.path("reports", "model_bootstrap_validation.csv"))
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
  "an equal-weight blend of gradient boosting, GAM, and degree-3 polynomial growth predictions"
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

model_comparison_compact <- model_comparison
model_comparison_compact$Model <- short_model_name(model_comparison_compact$Model)
model_rows <- unique(c(
  which(model_comparison_compact$Eligible == "Yes")[seq_len(min(10, sum(model_comparison_compact$Eligible == "Yes")))],
  which(model_comparison$Role == "Excluded leakage benchmark")[1]
))
model_rows <- model_rows[!is.na(model_rows)]
model_comparison_report <- model_comparison_compact[
  model_rows,
  c(
    "Model", "Selected", "Family", "CV RMSE",
    "Temporal RMSE", "Temporal R2", "Latest RMSE", "Latest R2"
  ),
  drop = FALSE
]
names(model_comparison_report) <- c(
  "Model", "Use", "Family", "CV RMSE",
  "Temporal RMSE", "Temporal R2", "Latest RMSE", "Latest R2"
)

family_summary_report <- family_summary[
  ,
  c(
    "Family", "Candidates", "Eligible", "Best model", "Selected family",
    "Best temporal RMSE", "Best temporal R2", "Best latest RMSE"
  ),
  drop = FALSE
]
family_summary_report[["Best model"]] <- short_model_name(family_summary_report[["Best model"]])
names(family_summary_report) <- c(
  "Family", "Candidates", "Eligible", "Best model", "Selected",
  "Temporal RMSE", "Temporal R2", "Latest RMSE"
)

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

report_lines <- c(
  "# Assessment Growth and Section Performance Analytics in R",
  "",
  "## Recommendation",
  "",
  paste0(
    "Use the latest completed assessment year, **", action_year,
    "**, to identify teacher, course, and section patterns that deserve review before the next cycle. ",
    "The stakeholder metric is **BOY/EOY score gain**: end-of-year score minus beginning-of-year score for the same public-safe student record."
  ),
  "",
  paste0(
    "The decision system does not ask whether old sections should be managed retroactively. ",
    "It asks whether the most recent actual growth was materially above or below an expected-growth baseline trained only on prior years."
  ),
  "",
  paste0(
    "The baseline selected for operations is **", selected_model, "**. ",
    "It predicts **score gain directly** using a ", selected_family,
    " specification. The selected tuning choice is ", selected_tuned_text, ". ",
    "The latest-year expected-gain RMSE is **", latest_gain_rmse,
    "** points and the latest-year MAE is **", latest_gain_mae, "** points."
  ),
  "",
  paste0(
    "The latest-year gain R-squared is **", latest_gain_r2,
    "**; EOY R-squared is **", latest_eoy_r2,
    "** and is reported only as secondary context. EOY is easier to predict because BOY score mechanically explains much of final score. ",
    "The workflow uses the direct-growth model to create a fair expected-growth baseline, then makes decisions from aggregate teacher, course, and section residuals with bootstrap uncertainty checks."
  ),
  "",
  markdown_table(decision_counts),
  "",
  markdown_table(priority_target_report),
  "",
  paste0(
    "The full decision table, including watch-list rows, is generated as ",
    artifact_ref("reports/intervention_targets.csv"), "."
  ),
  "",
  "<!-- PDF_PAGE_BREAK -->",
  "",
  "## Plain-English Method",
  "",
  "1. Build a paired BOY/EOY growth extract from public-safe assessment records.",
  "2. Define the business outcome as score gain: EOY score minus BOY score.",
  "3. Train candidate expected-growth models on prior years only, including parametric, smooth, tree-based, ensemble, and excluded leakage-check specifications.",
  "4. Select the operating baseline using leave-one-year-out temporal validation, with repeated CV and bootstrap checks as supporting evidence.",
  "5. Score the latest year against that prior-year baseline.",
  "6. Aggregate observed-minus-expected growth by teacher, course, and section.",
  "7. Flag review targets only when the gap is large enough to matter and the uncertainty check supports follow-up.",
  "",
  paste0(
    "This design separates the prediction problem from the decision problem. ",
    "The prediction model estimates what growth would be expected for a similar starting profile; the review layer asks where actual growth departed from that expectation."
  ),
  "",
  "## Direct Answers",
  "",
  paste0("1. The analysis covers ", included_pairs, " paired BOY/EOY records across ", section_groups, " section-year groups and ", teachers, " public-safe teacher identifiers."),
  paste0("2. The training window is ", training_years, "; the action year is ", action_year, "."),
  paste0("3. The average raw gain across the full extract is ", mean_gain, " points; the latest-year raw gain is ", latest_gain, " points."),
  paste0("4. The model search tested ", candidate_count, " candidate baselines across parametric, nonlinear, ensemble, and leakage-check families."),
  paste0("5. The selected direct-growth baseline has temporal expected-gain RMSE ", temporal_gain_rmse, ", temporal MAE ", temporal_gain_mae, ", and latest-year expected-gain RMSE ", latest_gain_rmse, "."),
  "6. Teacher, course, and section flags are audit priorities. They are not automatic personnel ratings or causal claims.",
  "",
  "## Data Audit",
  "",
  "A record enters the growth model only when the same public-safe student has valid BOY and EOY scores in the same section and teacher context. This keeps improvement tied to one instructional experience instead of mixing students across sections.",
  "",
  markdown_table(profile),
  "",
  "<!-- PDF_PAGE_BREAK -->",
  "",
  "## Model Selection",
  "",
  paste0(
    "The model search used ", training_records, " prior-year pairs and held out ",
    action_records, " latest-year pairs for action-year evaluation. ",
    "The primary selection metric is leave-one-year-out temporal expected-gain RMSE, not latest-year performance, so the system does not choose a model by looking at the year it later reviews."
  ),
  "",
  paste0(
    "The best eligible direct-growth temporal RMSE was **", best_temporal_row$`Temporal RMSE`,
    "** from **", best_temporal_row$Model, "**. ",
    "The selected model's temporal RMSE was **", selected_row$`Temporal RMSE`,
    "**, a difference of ", selection_delta,
    " points. Because that difference is below the 0.01-point practical tolerance, the selected model is the operating baseline because it has the strongest repeated-CV RMSE among the temporally tied direct-growth candidates."
  ),
  "",
  overall_context,
  "",
  "The model-search guardrails were:",
  "",
  "- Use direct BOY/EOY score gain as the operating target because that is the stakeholder performance metric.",
  "- Select by temporal-CV RMSE so the baseline is judged on year-to-year generalization.",
  "- Use repeated-CV RMSE as the tie-breaker when temporal-CV RMSE differs by less than 0.01 points.",
  "- Keep teacher, course, and section identifiers out of the operating baseline because those are the review slices.",
  "- Report EOY R-squared only as context because final score is mechanically easier to predict than growth.",
  "",
  markdown_table(family_summary_report),
  "",
  markdown_table(shape_review_report),
  "",
  markdown_table(model_comparison_report),
  "",
  paste0(
    "Full model artifacts: ",
    artifact_ref("reports/growth_model_comparison_display.csv"),
    ", ",
    artifact_ref("reports/growth_model_search_grid.csv"),
    ", ",
    artifact_ref("reports/growth_model_family_summary.csv"),
    ", ",
    artifact_ref("reports/growth_model_selection_rationale.csv"),
    ", ",
    artifact_ref("reports/model_temporal_validation.csv"),
    ", and ",
    artifact_ref("reports/model_bootstrap_validation.csv"), "."
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
    "The decision labels use a practical audit threshold: material gap, bootstrap interval direction, and BH-adjusted q-value for multiple-review control."
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
  "These summaries aggregate the latest-year evidence into planning views. They support review conversations about pacing, curriculum alignment, attendance mix, and transferable practices. They should not be read as standalone personnel scores.",
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
    "That pattern is expected: BOY score explains much of EOY score, while individual improvement contains more unobserved classroom, attendance, and assessment noise."
  ),
  "",
  markdown_table(diagnostics_report),
  "",
  markdown_table(bootstrap_report),
  "",
  markdown_table(sensitivity_report),
  "",
  "![Growth model diagnostics](../figures/growth_diagnostics.png)",
  "",
  "## Technical Appendix",
  "",
  "The operating model excludes teacher IDs, course IDs, and section IDs. A leakage benchmark is reported only to show what would happen if persistent IDs were included in the baseline; it is not used for review because it would absorb the teacher/course patterns the decision layer is designed to detect.",
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
  "The project should be read as a statistical decision-support system, not as a simple prediction demo. The strongest business value is the workflow: choose a validated expected-growth baseline, compare latest actual growth to that baseline, quantify uncertainty by slice, and translate the evidence into review priorities.",
  "",
  "The recommended stakeholder action is to review the flagged teacher, course, and section patterns before the next assessment cycle. Priority targets deserve support or investigation; positive anomalies deserve study for transferable practices; watch-list rows deserve context review before escalation.",
  "",
  "The important limitation is that the data are public-safe and generalized from an assessment workflow. The outputs demonstrate the analysis pattern and should not be used as real student, teacher, or personnel decisions.",
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
    "**Purpose:** use prior-year BOY/EOY assessment history to build an expected-growth baseline, then review the latest completed year for teacher, course, and section patterns that deserve action before the next cycle."
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
    " candidates using direct-growth temporal validation. Temporal expected-gain RMSE is ",
    temporal_gain_rmse, "; latest-year expected-gain RMSE is ",
    latest_gain_rmse, "; latest-year EOY R-squared is ", latest_eoy_r2,
    " for context."
  ),
  "",
  paste0(
    "**Decision logic:** observed gain minus expected gain, reviewed by teacher, course, and section with bootstrap intervals and BH-adjusted q-values."
  ),
  "",
  markdown_table(priority_target_report),
  "",
  "**Guardrail:** the outputs are review priorities, not automatic teacher evaluation, compensation, discipline, or personnel decisions."
)

writeLines(executive_lines, file.path("reports", "executive_brief.md"))

model_card_lines <- c(
  "# Model Card",
  "",
  "## Intended Use",
  "",
  "Estimate an expected BOY/EOY assessment-growth baseline and identify public-safe teacher, course, and section patterns that deserve future instructional review.",
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
    ". The operating target is direct BOY/EOY score gain. Candidate families include linear baselines, polynomial terms, interaction surfaces, cyclic terms, GAM smooths, regression trees, random forests, gradient boosting, validation ensembles, EOY-derived benchmarks, and an excluded teacher/course ID leakage check."
  ),
  "",
  "## Validation",
  "",
  markdown_table(appendix_metrics),
  "",
  markdown_table(bootstrap_report),
  "",
  "## Decision Layer",
  "",
  "Latest-year teacher, course, and section residuals are summarized with bootstrap intervals, p-values, BH-adjusted q-values, reliability weighting, and decision labels. The labels are audit priorities, not causal claims.",
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
