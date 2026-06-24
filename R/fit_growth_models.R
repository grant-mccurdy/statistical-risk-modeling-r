source(file.path("R", "model_utils.R"))

ensure_project_dirs()

data_path <- file.path("data", "processed", "education_section_growth.csv")
if (!file.exists(data_path)) {
  source(file.path("R", "generate_synthetic_data.R"))
}

growth <- read.csv(data_path, stringsAsFactors = FALSE)

growth$grade_level <- factor(growth$grade_level, levels = sort(unique(growth$grade_level)))
growth$course_track <- factor(
  growth$course_track,
  levels = c("regular", "honors", "ap", "beyond_core")
)
growth$attendance_category <- factor(
  growth$attendance_category,
  levels = c("normal", "high", "at_risk")
)
growth$course_id <- factor(growth$course_id)
growth$teacher_id <- factor(growth$teacher_id)
growth$section_id <- factor(growth$section_id)

rmse <- function(y, p) {
  sqrt(mean((as.numeric(y) - as.numeric(p))^2))
}

mae <- function(y, p) {
  mean(abs(as.numeric(y) - as.numeric(p)))
}

r_squared <- function(y, p) {
  y <- as.numeric(y)
  p <- as.numeric(p)
  1 - sum((y - p)^2) / sum((y - mean(y))^2)
}

evaluate_regression <- function(y, p) {
  data.frame(
    RMSE = rmse(y, p),
    MAE = mae(y, p),
    R2 = r_squared(y, p),
    stringsAsFactors = FALSE
  )
}

make_random_folds <- function(n, k) {
  sample(rep(seq_len(k), length.out = n))
}

run_repeated_lm_cv <- function(data, formulas, outcome, k = 5, repeats = 6,
                               seed = 20260623) {
  results <- list()
  counter <- 1
  set.seed(seed)

  for (repeat_id in seq_len(repeats)) {
    folds <- make_random_folds(nrow(data), k)
    for (model_name in names(formulas)) {
      predictions <- rep(NA_real_, nrow(data))
      for (fold_id in seq_len(k)) {
        train_data <- data[folds != fold_id, , drop = FALSE]
        test_data <- data[folds == fold_id, , drop = FALSE]
        fit <- lm(formulas[[model_name]], data = train_data)
        predictions[folds == fold_id] <- as.numeric(predict(fit, newdata = test_data))
      }
      metrics <- evaluate_regression(data[[outcome]], predictions)
      results[[counter]] <- data.frame(
        Model = model_name,
        Repeat = repeat_id,
        RMSE = metrics$RMSE,
        MAE = metrics$MAE,
        R2 = metrics$R2,
        stringsAsFactors = FALSE
      )
      counter <- counter + 1
    }
  }

  do.call(rbind, results)
}

summarize_regression_cv <- function(cv_results) {
  means <- aggregate(cbind(RMSE, MAE, R2) ~ Model, cv_results, mean)
  sds <- aggregate(cbind(RMSE, MAE, R2) ~ Model, cv_results, sd)
  names(means) <- c("Model", "CV_RMSE", "CV_MAE", "CV_R2")
  names(sds) <- c("Model", "CV_RMSE_SD", "CV_MAE_SD", "CV_R2_SD")
  summary <- merge(means, sds, by = "Model")
  summary[order(summary$CV_RMSE), ]
}

section_key <- paste(growth$section_id, growth$school_year, sep = " | ")
growth$section_year_id <- section_key

set.seed(20260623)
train_idx <- sort(sample(seq_len(nrow(growth)), size = floor(0.80 * nrow(growth))))
train_data <- growth[train_idx, , drop = FALSE]
holdout_data <- growth[-train_idx, , drop = FALSE]

outcome <- "score_gain"
candidate_formulas <- list(
  "Context baseline" = score_gain ~ grade_level + course_track +
    attendance_category + school_year_offset,
  "Linear BOY score" = score_gain ~ grade_level + course_track +
    attendance_category + attendance_probability + boy_score +
    school_year_offset,
  "Quadratic BOY score" = score_gain ~ grade_level + course_track +
    attendance_category + attendance_probability + boy_score_z +
    I(boy_score_z^2) + school_year_offset,
  "Piecewise BOY score" = score_gain ~ grade_level + course_track +
    attendance_category + attendance_probability + boy_below_45 +
    boy_45_to_60 + boy_above_60 + school_year_offset,
  "Readiness-augmented" = score_gain ~ grade_level + course_track +
    attendance_category + attendance_probability + boy_score +
    boy_readiness + school_year_offset,
  "Spline BOY score benchmark" = score_gain ~ grade_level + course_track +
    attendance_category + attendance_probability +
    splines::ns(boy_score, df = 4) + school_year_offset
)

benchmark_models <- c("Spline BOY score benchmark")
cv_folds <- 5
cv_repeats <- 6

cv_results <- run_repeated_lm_cv(
  data = train_data,
  formulas = candidate_formulas,
  outcome = outcome,
  k = cv_folds,
  repeats = cv_repeats
)

cv_summary <- summarize_regression_cv(cv_results)
candidate_fits <- lapply(candidate_formulas, function(model_formula) {
  lm(model_formula, data = train_data)
})

holdout_metrics <- do.call(rbind, lapply(names(candidate_fits), function(model_name) {
  predictions <- as.numeric(predict(candidate_fits[[model_name]], newdata = holdout_data))
  metrics <- evaluate_regression(holdout_data[[outcome]], predictions)
  data.frame(
    Model = model_name,
    Holdout_RMSE = metrics$RMSE,
    Holdout_MAE = metrics$MAE,
    Holdout_R2 = metrics$R2,
    AIC = AIC(candidate_fits[[model_name]]),
    Parameters = count_model_parameters(candidate_fits[[model_name]]),
    stringsAsFactors = FALSE
  )
}))

model_comparison <- merge(cv_summary, holdout_metrics, by = "Model")
model_comparison <- model_comparison[order(model_comparison$CV_RMSE), ]

selection_candidates <- model_comparison[
  !(model_comparison$Model %in% benchmark_models),
]
best_row <- selection_candidates[which.min(selection_candidates$CV_RMSE), ]
best_rmse_limit <- best_row$CV_RMSE + best_row$CV_RMSE_SD / sqrt(cv_repeats)
eligible <- selection_candidates[
  selection_candidates$CV_RMSE <= best_rmse_limit,
]
eligible <- eligible[order(eligible$Parameters, eligible$CV_RMSE), ]
selected_model_name <- eligible$Model[1]

model_comparison$Selected <- model_comparison$Model == selected_model_name
model_comparison$Delta_CV_RMSE <- model_comparison$CV_RMSE -
  min(model_comparison$CV_RMSE)
model_comparison <- model_comparison[
  order(model_comparison$CV_RMSE),
  c(
    "Model", "Selected", "Parameters", "CV_RMSE", "CV_RMSE_SD",
    "CV_MAE", "CV_R2", "Holdout_RMSE", "Holdout_MAE", "Holdout_R2",
    "AIC", "Delta_CV_RMSE"
  )
]

selected_formula <- candidate_formulas[[selected_model_name]]
final_model_train <- candidate_fits[[selected_model_name]]
holdout_predictions <- as.numeric(predict(final_model_train, newdata = holdout_data))
train_predictions <- as.numeric(predict(final_model_train, newdata = train_data))
holdout_final_metrics <- evaluate_regression(holdout_data[[outcome]], holdout_predictions)
train_final_metrics <- evaluate_regression(train_data[[outcome]], train_predictions)

final_model <- lm(selected_formula, data = growth)
growth$expected_gain <- as.numeric(predict(final_model, newdata = growth))
growth$adjusted_growth_residual <- growth$score_gain - growth$expected_gain

section_split <- split(growth, growth$section_year_id)
section_rows <- lapply(section_split, function(df) {
  n <- nrow(df)
  mean_gain <- mean(df$score_gain)
  sd_gain <- sd(df$score_gain)
  se_gain <- sd_gain / sqrt(n)
  t_stat <- ifelse(is.na(se_gain) || se_gain == 0, NA_real_, mean_gain / se_gain)
  p_value <- ifelse(is.na(t_stat), NA_real_, 2 * pt(-abs(t_stat), df = n - 1))
  ci_mult <- qt(0.975, df = n - 1)
  mean_residual <- mean(df$adjusted_growth_residual)
  sd_residual <- sd(df$adjusted_growth_residual)
  se_residual <- sd_residual / sqrt(n)
  data.frame(
    SectionYear = df$section_year_id[1],
    Section = df$section_id[1],
    SectionLabel = df$section_label[1],
    Teacher = df$teacher_id[1],
    TeacherLabel = df$teacher_label[1],
    Course = df$course_id[1],
    CourseTrack = df$course_track[1],
    SchoolYear = df$school_year[1],
    N = n,
    BOYMean = mean(df$boy_score),
    EOYMean = mean(df$eoy_score),
    MeanGain = mean_gain,
    GainSD = sd_gain,
    GainSE = se_gain,
    GainCILower = mean_gain - ci_mult * se_gain,
    GainCIUpper = mean_gain + ci_mult * se_gain,
    TStatistic = t_stat,
    PValue = p_value,
    ExpectedGain = mean(df$expected_gain),
    AdjustedResidual = mean_residual,
    ResidualSE = se_residual,
    ResidualCILower = mean_residual - ci_mult * se_residual,
    ResidualCIUpper = mean_residual + ci_mult * se_residual,
    stringsAsFactors = FALSE
  )
})
section_summary <- do.call(rbind, section_rows)
section_summary$QValue <- p.adjust(section_summary$PValue, method = "BH")
median_section_n <- median(section_summary$N)
section_summary$ReliabilityWeight <- section_summary$N /
  (section_summary$N + median_section_n)
section_summary$AdjustedGrowthSignal <- section_summary$AdjustedResidual *
  section_summary$ReliabilityWeight
section_summary$SignalCategory <- ifelse(
  section_summary$N < 5,
  "Small group",
  ifelse(
    section_summary$ResidualCILower > 0,
    "Above expected",
    ifelse(section_summary$ResidualCIUpper < 0, "Below expected", "Within expected range")
  )
)

section_summary <- section_summary[order(section_summary$AdjustedGrowthSignal, decreasing = TRUE), ]
eligible_sections <- section_summary[section_summary$N >= 5, , drop = FALSE]
top_sections <- head(eligible_sections[order(eligible_sections$AdjustedGrowthSignal, decreasing = TRUE), ], 8)
bottom_sections <- head(eligible_sections[order(eligible_sections$AdjustedGrowthSignal), ], 8)
section_highlights <- rbind(top_sections, bottom_sections)
section_highlights <- section_highlights[!duplicated(section_highlights$SectionYear), ]

teacher_split <- split(growth, growth$teacher_id)
teacher_summary <- do.call(rbind, lapply(teacher_split, function(df) {
  data.frame(
    Teacher = df$teacher_id[1],
    TeacherLabel = df$teacher_label[1],
    Sections = length(unique(df$section_year_id)),
    PairedRecords = nrow(df),
    MeanBOY = mean(df$boy_score),
    MeanEOY = mean(df$eoy_score),
    MeanGain = mean(df$score_gain),
    ExpectedGain = mean(df$expected_gain),
    AdjustedResidual = mean(df$adjusted_growth_residual),
    stringsAsFactors = FALSE
  )
}))
teacher_summary <- teacher_summary[order(teacher_summary$AdjustedResidual, decreasing = TRUE), ]

course_split <- split(growth, growth$course_id)
course_summary <- do.call(rbind, lapply(course_split, function(df) {
  data.frame(
    Course = df$course_id[1],
    Track = df$course_track[1],
    Sections = length(unique(df$section_year_id)),
    PairedRecords = nrow(df),
    MeanBOY = mean(df$boy_score),
    MeanEOY = mean(df$eoy_score),
    MeanGain = mean(df$score_gain),
    ExpectedGain = mean(df$expected_gain),
    AdjustedResidual = mean(df$adjusted_growth_residual),
    stringsAsFactors = FALSE
  )
}))
course_summary <- course_summary[order(course_summary$AdjustedResidual, decreasing = TRUE), ]

raw_rank <- eligible_sections[order(eligible_sections$MeanGain, decreasing = TRUE), "SectionYear"]
adjusted_rank <- eligible_sections[
  order(eligible_sections$AdjustedGrowthSignal, decreasing = TRUE),
  "SectionYear"
]
top_n <- min(10, length(raw_rank), length(adjusted_rank))
top_overlap <- length(intersect(raw_rank[seq_len(top_n)], adjusted_rank[seq_len(top_n)])) / top_n
rank_correlation <- suppressWarnings(cor(
  eligible_sections$MeanGain,
  eligible_sections$AdjustedGrowthSignal,
  method = "spearman"
))

sensitivity <- data.frame(
  Measure = c(
    "Included paired records",
    "Section-year groups",
    "Groups with at least 5 paired records",
    "Groups with at least 8 paired records",
    "Mean raw BOY/EOY gain",
    "Raw-vs-adjusted rank correlation",
    "Top-10 overlap, raw vs adjusted ranking"
  ),
  Value = c(
    format(nrow(growth), big.mark = ","),
    format(nrow(section_summary), big.mark = ","),
    format(sum(section_summary$N >= 5), big.mark = ","),
    format(sum(section_summary$N >= 8), big.mark = ","),
    format_num(mean(growth$score_gain), 2),
    format_num(rank_correlation, 3),
    format_pct(top_overlap)
  ),
  stringsAsFactors = FALSE
)

diagnostics <- data.frame(
  Diagnostic = c(
    "Holdout RMSE",
    "Holdout MAE",
    "Holdout R-squared",
    "Residual mean, all pairs",
    "Residual SD, all pairs"
  ),
  Estimate = c(
    format_num(holdout_final_metrics$RMSE, 3),
    format_num(holdout_final_metrics$MAE, 3),
    format_num(holdout_final_metrics$R2, 3),
    format_num(mean(growth$adjusted_growth_residual), 3),
    format_num(sd(growth$adjusted_growth_residual), 3)
  ),
  Interpretation = c(
    "Typical holdout prediction error on BOY/EOY gain",
    "Average absolute holdout prediction error",
    "Share of holdout gain variation explained by the model",
    "Near 0 means expected gain is centered overall",
    "Residual spread used to judge section signal uncertainty"
  ),
  stringsAsFactors = FALSE
)

model_comparison_display <- data.frame(
  Model = model_comparison$Model,
  Selected = ifelse(model_comparison$Selected, "Yes", ""),
  Role = ifelse(model_comparison$Model %in% benchmark_models, "Benchmark", "Selection candidate"),
  Params = model_comparison$Parameters,
  CV_RMSE = format_num(model_comparison$CV_RMSE, 3),
  CV_SD = format_num(model_comparison$CV_RMSE_SD, 3),
  CV_MAE = format_num(model_comparison$CV_MAE, 3),
  CV_R2 = format_num(model_comparison$CV_R2, 3),
  Holdout_RMSE = format_num(model_comparison$Holdout_RMSE, 3),
  Holdout_R2 = format_num(model_comparison$Holdout_R2, 3),
  Delta = format_num(model_comparison$Delta_CV_RMSE, 3),
  stringsAsFactors = FALSE
)

section_ttests_display <- data.frame(
  Section = section_summary$Section,
  Teacher = section_summary$Teacher,
  Course = section_summary$Course,
  Year = section_summary$SchoolYear,
  N = section_summary$N,
  BOY = format_num(section_summary$BOYMean, 1),
  EOY = format_num(section_summary$EOYMean, 1),
  Gain = format_num(section_summary$MeanGain, 2),
  CI_95 = paste0(
    format_num(section_summary$GainCILower, 2),
    " to ",
    format_num(section_summary$GainCIUpper, 2)
  ),
  P_value = format_p(section_summary$PValue),
  Q_value = format_p(section_summary$QValue),
  stringsAsFactors = FALSE
)

section_signals_display <- data.frame(
  Section = section_summary$Section,
  Teacher = section_summary$Teacher,
  Course = section_summary$Course,
  Year = section_summary$SchoolYear,
  N = section_summary$N,
  Raw_gain = format_num(section_summary$MeanGain, 2),
  Expected_gain = format_num(section_summary$ExpectedGain, 2),
  Adjusted_signal = format_num(section_summary$AdjustedGrowthSignal, 2),
  Residual_CI = paste0(
    format_num(section_summary$ResidualCILower, 2),
    " to ",
    format_num(section_summary$ResidualCIUpper, 2)
  ),
  Category = section_summary$SignalCategory,
  stringsAsFactors = FALSE
)

section_highlights_display <- data.frame(
  Section = section_highlights$Section,
  Teacher = section_highlights$Teacher,
  Course = section_highlights$Course,
  Year = section_highlights$SchoolYear,
  N = section_highlights$N,
  Raw_gain = format_num(section_highlights$MeanGain, 2),
  Expected_gain = format_num(section_highlights$ExpectedGain, 2),
  Adjusted_signal = format_num(section_highlights$AdjustedGrowthSignal, 2),
  Category = section_highlights$SignalCategory,
  stringsAsFactors = FALSE
)

teacher_display <- data.frame(
  Teacher = teacher_summary$Teacher,
  Sections = teacher_summary$Sections,
  Records = teacher_summary$PairedRecords,
  BOY = format_num(teacher_summary$MeanBOY, 1),
  EOY = format_num(teacher_summary$MeanEOY, 1),
  Raw_gain = format_num(teacher_summary$MeanGain, 2),
  Expected_gain = format_num(teacher_summary$ExpectedGain, 2),
  Adjusted_signal = format_num(teacher_summary$AdjustedResidual, 2),
  stringsAsFactors = FALSE
)

course_display <- data.frame(
  Course = course_summary$Course,
  Track = course_summary$Track,
  Sections = course_summary$Sections,
  Records = course_summary$PairedRecords,
  BOY = format_num(course_summary$MeanBOY, 1),
  EOY = format_num(course_summary$MeanEOY, 1),
  Raw_gain = format_num(course_summary$MeanGain, 2),
  Expected_gain = format_num(course_summary$ExpectedGain, 2),
  Adjusted_signal = format_num(course_summary$AdjustedResidual, 2),
  stringsAsFactors = FALSE
)

final_metrics <- data.frame(
  Metric = c(
    "Selected model",
    "Selection rule",
    "Training paired records",
    "Holdout paired records",
    "Repeated CV folds",
    "Repeated CV repeats",
    "CV RMSE",
    "CV MAE",
    "CV R-squared",
    "Holdout RMSE",
    "Holdout MAE",
    "Holdout R-squared",
    "Mean BOY score",
    "Mean EOY score",
    "Mean raw BOY/EOY gain",
    "Section-year groups"
  ),
  Value = c(
    selected_model_name,
    "Simplest non-benchmark model within one standard error of best repeated-CV RMSE",
    format(nrow(train_data), big.mark = ","),
    format(nrow(holdout_data), big.mark = ","),
    cv_folds,
    cv_repeats,
    format_num(model_comparison$CV_RMSE[model_comparison$Selected], 3),
    format_num(model_comparison$CV_MAE[model_comparison$Selected], 3),
    format_num(model_comparison$CV_R2[model_comparison$Selected], 3),
    format_num(holdout_final_metrics$RMSE, 3),
    format_num(holdout_final_metrics$MAE, 3),
    format_num(holdout_final_metrics$R2, 3),
    format_num(mean(growth$boy_score), 1),
    format_num(mean(growth$eoy_score), 1),
    format_num(mean(growth$score_gain), 2),
    format(nrow(section_summary), big.mark = ",")
  ),
  stringsAsFactors = FALSE
)

shape_review <- data.frame(
  Family = c(
    "Context baseline",
    "Linear BOY score",
    "Quadratic BOY score",
    "Piecewise BOY score",
    "Readiness-augmented",
    "Spline BOY score benchmark"
  ),
  Why_tested = c(
    "Tests whether grade, course, attendance, and year context are enough.",
    "Adds the main baseline achievement signal.",
    "Tests whether gain changes nonlinearly for very low or high BOY scores.",
    "Uses interpretable score regions to handle floor and ceiling effects.",
    "Checks whether readiness adds signal beyond the observed BOY score.",
    "Flexible benchmark for the baseline-score curve."
  ),
  Decision = c(
    "Baseline comparator.",
    ifelse(selected_model_name == "Linear BOY score", "Selected operating model.", "Useful simple challenger."),
    ifelse(selected_model_name == "Quadratic BOY score", "Selected operating model.", "Compared for nonlinear gain shape."),
    ifelse(selected_model_name == "Piecewise BOY score", "Selected operating model.", "Interpretable nonlinear challenger."),
    ifelse(selected_model_name == "Readiness-augmented", "Selected operating model.", "Checked for added readiness value."),
    "Benchmark only; not selected unless it materially improves validation."
  ),
  CV_RMSE = model_comparison_display$CV_RMSE[
    match(
      c(
        "Context baseline", "Linear BOY score", "Quadratic BOY score",
        "Piecewise BOY score", "Readiness-augmented", "Spline BOY score benchmark"
      ),
      model_comparison_display$Model
    )
  ],
  Holdout_RMSE = model_comparison_display$Holdout_RMSE[
    match(
      c(
        "Context baseline", "Linear BOY score", "Quadratic BOY score",
        "Piecewise BOY score", "Readiness-augmented", "Spline BOY score benchmark"
      ),
      model_comparison_display$Model
    )
  ],
  stringsAsFactors = FALSE
)

write.csv(model_comparison, file.path("reports", "growth_model_comparison.csv"), row.names = FALSE)
write.csv(model_comparison_display, file.path("reports", "growth_model_comparison_display.csv"), row.names = FALSE)
write.csv(final_metrics, file.path("reports", "growth_final_metrics.csv"), row.names = FALSE)
write.csv(shape_review, file.path("reports", "growth_shape_review.csv"), row.names = FALSE)
write.csv(section_ttests_display, file.path("reports", "section_ttests.csv"), row.names = FALSE)
write.csv(section_signals_display, file.path("reports", "section_adjusted_signals.csv"), row.names = FALSE)
write.csv(section_highlights_display, file.path("reports", "section_signal_highlights.csv"), row.names = FALSE)
write.csv(teacher_display, file.path("reports", "teacher_growth_summary.csv"), row.names = FALSE)
write.csv(course_display, file.path("reports", "course_growth_summary.csv"), row.names = FALSE)
write.csv(diagnostics, file.path("reports", "growth_diagnostics.csv"), row.names = FALSE)
write.csv(sensitivity, file.path("reports", "growth_sensitivity.csv"), row.names = FALSE)
write.csv(growth, file.path("reports", "growth_scored_pairs.csv"), row.names = FALSE)

saveRDS(
  list(
    selected_model_name = selected_model_name,
    selected_formula = selected_formula,
    final_model = final_model,
    model_comparison = model_comparison,
    section_summary = section_summary,
    teacher_summary = teacher_summary,
    course_summary = course_summary,
    growth = growth,
    train_rows = nrow(train_data),
    holdout_rows = nrow(holdout_data)
  ),
  file.path("reports", "model_artifacts.rds")
)

short_course_label <- function(course) {
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
  ifelse(key %in% names(labels), labels[key], gsub("-", " ", key))
}

short_section_code <- function(section) {
  section <- sub("^Y[0-9]+-", "", section)
  section_num <- suppressWarnings(as.integer(sub("^SEC-", "", section)))
  ifelse(is.na(section_num), section, sprintf("S%02d", section_num))
}

short_school_year <- function(year) {
  paste0(substr(year, 3, 4), "-", substr(year, 8, 9))
}

png(file.path("figures", "growth_distribution.png"), width = 1200, height = 620, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
hist(
  growth$score_gain,
  breaks = 30,
  col = "#7BA7C7",
  border = "white",
  xlab = "EOY score minus BOY score",
  main = "BOY/EOY Gain Distribution"
)
abline(v = mean(growth$score_gain), col = "#8C2D19", lwd = 2)

track_split <- split(growth$score_gain, growth$course_track)
track_summary <- data.frame(
  Track = names(track_split),
  N = vapply(track_split, length, integer(1)),
  Mean = vapply(track_split, mean, numeric(1)),
  SD = vapply(track_split, sd, numeric(1)),
  stringsAsFactors = FALSE
)
track_summary$SE <- track_summary$SD / sqrt(track_summary$N)
track_summary$Lower <- track_summary$Mean - 1.96 * track_summary$SE
track_summary$Upper <- track_summary$Mean + 1.96 * track_summary$SE
track_summary$Label <- c(
  "ap" = "AP",
  "beyond_core" = "Beyond core",
  "honors" = "Honors",
  "regular" = "Regular"
)[track_summary$Track]
track_summary <- track_summary[order(track_summary$Mean), ]
track_summary$AxisLabel <- paste0(track_summary$Label, " (n=", track_summary$N, ")")
y_pos <- seq_len(nrow(track_summary))
par(mar = c(5, 10, 4, 2))
plot(
  track_summary$Mean,
  y_pos,
  xlim = c(
    min(0, track_summary$Lower) - 0.5,
    max(track_summary$Upper) + 0.7
  ),
  ylim = range(y_pos) + c(-0.5, 0.5),
  yaxt = "n",
  pch = 19,
  cex = 1.2,
  col = "#1B6CA8",
  xlab = "Mean BOY/EOY score gain",
  ylab = "",
  main = "Average Gain by Track"
)
segments(track_summary$Lower, y_pos, track_summary$Upper, y_pos, col = "#555555", lwd = 2)
points(track_summary$Mean, y_pos, pch = 19, cex = 1.2, col = "#1B6CA8")
axis(2, at = y_pos, labels = track_summary$AxisLabel, las = 1)
abline(v = 0, lty = 2, col = "#888888")
abline(v = mean(growth$score_gain), lty = 3, col = "#8C2D19", lwd = 1.5)
mtext("Points show means; bars show 95% CIs", side = 3, line = 0.3, cex = 0.8)
dev.off()

png(file.path("figures", "baseline_growth_shape.png"), width = 1300, height = 700, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
rank_groups <- cut(
  rank(train_data$boy_score, ties.method = "first"),
  breaks = seq(0, nrow(train_data), length.out = 13),
  include.lowest = TRUE,
  labels = seq_len(12)
)
binned <- aggregate(cbind(score_gain, boy_score) ~ rank_groups, train_data, mean)
plot(
  binned$boy_score,
  binned$score_gain,
  pch = 19,
  col = "#1B6CA8",
  xlab = "BOY score",
  ylab = "Observed BOY/EOY gain",
  main = "Nonparametric Growth Shape"
)
score_grid <- seq(floor(min(growth$boy_score)), ceiling(max(growth$boy_score)), length.out = 120)
for (bandwidth in c(4, 8, 12)) {
  smooth <- ksmooth(
    train_data$boy_score,
    train_data$score_gain,
    kernel = "normal",
    bandwidth = bandwidth,
    x.points = score_grid
  )
  lines(smooth$x, smooth$y, lwd = 2)
}
abline(h = 0, lty = 2, col = "#666666")
grid(col = "#E0E0E0")
legend(
  "topright",
  legend = c("Binned gain", "h = 4", "h = 8", "h = 12"),
  pch = c(19, NA, NA, NA),
  lty = c(NA, 1, 1, 1),
  lwd = c(NA, 2, 2, 2),
  col = c("#1B6CA8", "#000000", "#666666", "#999999"),
  bty = "n"
)

typical <- growth[which.min(abs(growth$boy_score - median(growth$boy_score))), ]
curve_data <- typical[rep(1, length(score_grid)), ]
curve_data$boy_score <- score_grid
curve_data$boy_score_z <- (score_grid - mean(growth$boy_score)) / sd(growth$boy_score)
curve_data$boy_below_45 <- pmax(45 - score_grid, 0)
curve_data$boy_45_to_60 <- pmin(pmax(score_grid - 45, 0), 15)
curve_data$boy_above_60 <- pmax(score_grid - 60, 0)
curve_data$boy_readiness <- typical$boy_readiness + (score_grid - typical$boy_score)
curve_data$boy_readiness_z <- (
  curve_data$boy_readiness - mean(growth$boy_readiness)
) / sd(growth$boy_readiness)
curve_models <- c(
  "Linear BOY score",
  "Quadratic BOY score",
  "Piecewise BOY score",
  "Spline BOY score benchmark"
)
plot(
  range(score_grid),
  range(growth$score_gain),
  type = "n",
  xlab = "BOY score",
  ylab = "Predicted BOY/EOY gain",
  main = "Parametric Family Search"
)
curve_cols <- c("#555555", "#8C2D19", "#1B6CA8", "#2D7D46")
for (i in seq_along(curve_models)) {
  model_name <- curve_models[i]
  lines(
    score_grid,
    as.numeric(predict(candidate_fits[[model_name]], newdata = curve_data)),
    lwd = ifelse(model_name == selected_model_name, 3, 2),
    col = curve_cols[i]
  )
}
abline(h = 0, lty = 2, col = "#666666")
grid(col = "#E0E0E0")
legend(
  "topright",
  legend = curve_models,
  col = curve_cols,
  lwd = ifelse(curve_models == selected_model_name, 3, 2),
  bty = "n"
)
dev.off()

png(file.path("figures", "growth_model_comparison.png"), width = 1200, height = 760, res = 150)
ordered_models <- model_comparison[order(model_comparison$CV_RMSE, decreasing = TRUE), ]
y_pos <- seq_len(nrow(ordered_models))
x_min <- min(ordered_models$CV_RMSE - ordered_models$CV_RMSE_SD) - 0.05
x_max <- max(ordered_models$CV_RMSE + ordered_models$CV_RMSE_SD) + 0.05
par(mar = c(5, 15, 4, 2))
plot(
  ordered_models$CV_RMSE,
  y_pos,
  xlim = c(x_min, x_max),
  yaxt = "n",
  xlab = "Repeated-CV RMSE",
  ylab = "",
  pch = 19,
  col = ifelse(ordered_models$Selected, "#1B6CA8", "#555555"),
  main = "Expected-Growth Model Comparison"
)
segments(
  ordered_models$CV_RMSE - ordered_models$CV_RMSE_SD,
  y_pos,
  ordered_models$CV_RMSE + ordered_models$CV_RMSE_SD,
  y_pos,
  col = "#888888"
)
axis(2, at = y_pos, labels = ordered_models$Model, las = 1)
abline(v = min(model_comparison$CV_RMSE), lty = 2, col = "#8C2D19")
legend(
  "bottomright",
  legend = c("Selected model", "Other candidate", "Best mean CV RMSE"),
  pch = c(19, 19, NA),
  lty = c(NA, NA, 2),
  col = c("#1B6CA8", "#555555", "#8C2D19"),
  bty = "n"
)
dev.off()

png(file.path("figures", "section_adjusted_signals.png"), width = 1250, height = 760, res = 150)
plot_sections <- section_highlights[
  order(section_highlights$AdjustedGrowthSignal),
]
labels <- paste(
  short_school_year(plot_sections$SchoolYear),
  short_section_code(plot_sections$Section),
  "/",
  short_course_label(plot_sections$Course)
)
bar_cols <- ifelse(plot_sections$AdjustedGrowthSignal >= 0, "#1B6CA8", "#8C2D19")
par(mar = c(5, 12, 4, 2))
barplot(
  plot_sections$AdjustedGrowthSignal,
  names.arg = labels,
  horiz = TRUE,
  las = 1,
  col = bar_cols,
  border = NA,
  xlab = "Reliability-weighted adjusted growth signal",
  main = "Sections Farthest Above or Below Expected Growth"
)
abline(v = 0, lwd = 1.5, col = "#333333")
dev.off()

png(file.path("figures", "teacher_course_summary.png"), width = 1250, height = 700, res = 150)
par(mfrow = c(1, 2), mar = c(7, 5, 4, 2))
teacher_plot <- teacher_summary[order(teacher_summary$AdjustedResidual), ]
barplot(
  teacher_plot$AdjustedResidual,
  names.arg = teacher_plot$Teacher,
  las = 2,
  col = ifelse(teacher_plot$AdjustedResidual >= 0, "#1B6CA8", "#8C2D19"),
  border = NA,
  ylab = "Mean adjusted growth residual",
  main = "Teacher-Level Summary"
)
abline(h = 0, lwd = 1.5, col = "#333333")
course_plot <- head(course_summary[order(abs(course_summary$AdjustedResidual), decreasing = TRUE), ], 8)
course_plot <- course_plot[order(course_plot$AdjustedResidual), ]
barplot(
  course_plot$AdjustedResidual,
  names.arg = short_course_label(course_plot$Course),
  las = 2,
  col = ifelse(course_plot$AdjustedResidual >= 0, "#1B6CA8", "#8C2D19"),
  border = NA,
  ylab = "Mean adjusted growth residual",
  main = "Course-Level Summary"
)
abline(h = 0, lwd = 1.5, col = "#333333")
dev.off()

png(file.path("figures", "growth_diagnostics.png"), width = 1200, height = 620, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
plot(
  holdout_predictions,
  holdout_data$score_gain,
  pch = 19,
  col = "#1B6CA880",
  xlab = "Predicted BOY/EOY gain",
  ylab = "Observed BOY/EOY gain",
  main = "Holdout Predictions"
)
abline(0, 1, col = "#8C2D19", lwd = 2)
grid(col = "#E0E0E0")
plot(
  growth$expected_gain,
  growth$adjusted_growth_residual,
  pch = 19,
  col = "#1B6CA880",
  xlab = "Expected BOY/EOY gain",
  ylab = "Adjusted residual",
  main = "Residual Check"
)
abline(h = 0, col = "#8C2D19", lwd = 2)
grid(col = "#E0E0E0")
dev.off()

message("Wrote growth model artifacts, report tables, and figures.")
message("Selected model: ", selected_model_name)
