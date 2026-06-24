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

make_spec <- function(name, target, method, formula, role = "Operational candidate",
                      parameters = NA_integer_, fit_args = list()) {
  list(
    name = name,
    target = target,
    method = method,
    formula = formula,
    role = role,
    parameters = parameters,
    fit_args = fit_args
  )
}

target_label <- function(target) {
  ifelse(target == "eoy_score", "Predicted EOY", "Predicted gain")
}

method_label <- function(method) {
  labels <- c(
    lm = "Linear model",
    gam = "GAM",
    rf = "Random forest",
    gbm = "Gradient boosting",
    ensemble = "Ensemble"
  )
  labels[[method]]
}

fit_candidate <- function(spec, data, seed = 20260623) {
  set.seed(seed)
  if (spec$method == "lm") {
    return(lm(spec$formula, data = data))
  }
  if (spec$method == "gam") {
    return(mgcv::gam(spec$formula, data = data, method = "REML"))
  }
  if (spec$method == "rf") {
    return(randomForest::randomForest(
      spec$formula,
      data = data,
      ntree = spec$fit_args$ntree,
      nodesize = spec$fit_args$nodesize,
      importance = FALSE
    ))
  }
  if (spec$method == "gbm") {
    return(gbm::gbm(
      spec$formula,
      data = data,
      distribution = "gaussian",
      n.trees = spec$fit_args$n_trees,
      interaction.depth = spec$fit_args$interaction_depth,
      shrinkage = spec$fit_args$shrinkage,
      bag.fraction = spec$fit_args$bag_fraction,
      n.minobsinnode = spec$fit_args$n_minobsinnode,
      train.fraction = 1,
      verbose = FALSE
    ))
  }
  stop("Unsupported model method: ", spec$method)
}

predict_target_value <- function(fit, spec, newdata) {
  if (spec$method == "gbm") {
    return(as.numeric(predict(
      fit,
      newdata = newdata,
      n.trees = spec$fit_args$n_trees
    )))
  }
  as.numeric(predict(fit, newdata = newdata))
}

predict_expected_gain <- function(fit, spec, newdata) {
  target_prediction <- predict_target_value(fit, spec, newdata)
  if (spec$target == "eoy_score") {
    return(target_prediction - newdata$boy_score)
  }
  target_prediction
}

predict_expected_eoy <- function(fit, spec, newdata) {
  if (spec$target == "eoy_score") {
    return(predict_target_value(fit, spec, newdata))
  }
  newdata$boy_score + predict_target_value(fit, spec, newdata)
}

evaluate_expected_gain <- function(data, expected_gain) {
  gain_metrics <- evaluate_regression(data$score_gain, expected_gain)
  eoy_metrics <- evaluate_regression(data$eoy_score, data$boy_score + expected_gain)
  data.frame(
    Gain_RMSE = gain_metrics$RMSE,
    Gain_MAE = gain_metrics$MAE,
    Gain_R2 = gain_metrics$R2,
    EOY_RMSE = eoy_metrics$RMSE,
    EOY_R2 = eoy_metrics$R2,
    stringsAsFactors = FALSE
  )
}

run_repeated_model_cv <- function(data, specs, k = 5, repeats = 3,
                                  seed = 20260623) {
  results <- list()
  counter <- 1
  set.seed(seed)

  for (repeat_id in seq_len(repeats)) {
    folds <- make_random_folds(nrow(data), k)
    for (spec in specs) {
      predictions <- rep(NA_real_, nrow(data))
      for (fold_id in seq_len(k)) {
        train_data <- data[folds != fold_id, , drop = FALSE]
        test_data <- data[folds == fold_id, , drop = FALSE]
        fit <- fit_candidate(
          spec,
          train_data,
          seed = seed + repeat_id * 100 + fold_id
        )
        predictions[folds == fold_id] <- predict_expected_gain(fit, spec, test_data)
      }
      metrics <- evaluate_expected_gain(data, predictions)
      results[[counter]] <- data.frame(
        Model = spec$name,
        Target = target_label(spec$target),
        Method = method_label(spec$method),
        Role = spec$role,
        Repeat = repeat_id,
        RMSE = metrics$Gain_RMSE,
        MAE = metrics$Gain_MAE,
        R2 = metrics$Gain_R2,
        EOY_RMSE = metrics$EOY_RMSE,
        EOY_R2 = metrics$EOY_R2,
        stringsAsFactors = FALSE
      )
      counter <- counter + 1
    }
  }

  do.call(rbind, results)
}

summarize_regression_cv <- function(cv_results) {
  means <- aggregate(
    cbind(RMSE, MAE, R2, EOY_RMSE, EOY_R2) ~ Model + Target + Method + Role,
    cv_results,
    mean
  )
  sds <- aggregate(
    cbind(RMSE, MAE, R2) ~ Model + Target + Method + Role,
    cv_results,
    sd
  )
  names(means) <- c(
    "Model", "Target", "Method", "Role", "CV_RMSE", "CV_MAE", "CV_R2",
    "CV_EOY_RMSE", "CV_EOY_R2"
  )
  names(sds) <- c(
    "Model", "Target", "Method", "Role", "CV_RMSE_SD", "CV_MAE_SD",
    "CV_R2_SD"
  )
  summary <- merge(means, sds, by = c("Model", "Target", "Method", "Role"))
  summary[order(summary$CV_RMSE), ]
}

section_key <- paste(growth$section_id, growth$school_year, sep = " | ")
growth$section_year_id <- section_key

set.seed(20260623)
train_idx <- sort(sample(seq_len(nrow(growth)), size = floor(0.80 * nrow(growth))))
train_data <- growth[train_idx, , drop = FALSE]
holdout_data <- growth[-train_idx, , drop = FALSE]

candidate_specs <- list(
  make_spec(
    "Gain linear benchmark",
    "score_gain",
    "lm",
    score_gain ~ grade_level + course_track + attendance_category +
      attendance_probability + boy_score + school_year_offset + annual_sin +
      annual_cos,
    parameters = 12
  ),
  make_spec(
    "Gain readiness model",
    "score_gain",
    "lm",
    score_gain ~ grade_level + course_track + attendance_category +
      attendance_probability + boy_score + boy_readiness + school_year_offset +
      annual_sin + annual_cos,
    parameters = 13
  ),
  make_spec(
    "Gain interaction model",
    "score_gain",
    "lm",
    score_gain ~ grade_level + course_track + attendance_category +
      attendance_probability + boy_score_z + I(boy_score_z^2) +
      boy_readiness_z + boy_score_z:course_track +
      boy_readiness_z:attendance_category + school_year_offset + annual_sin +
      annual_cos,
    parameters = 19
  ),
  make_spec(
    "EOY linear benchmark",
    "eoy_score",
    "lm",
    eoy_score ~ grade_level + course_track + attendance_category +
      attendance_probability + boy_score + school_year_offset + annual_sin +
      annual_cos,
    parameters = 12
  ),
  make_spec(
    "EOY readiness model",
    "eoy_score",
    "lm",
    eoy_score ~ grade_level + course_track + attendance_category +
      attendance_probability + boy_score + boy_readiness + school_year_offset +
      annual_sin + annual_cos,
    parameters = 13
  ),
  make_spec(
    "EOY interaction model",
    "eoy_score",
    "lm",
    eoy_score ~ grade_level + course_track + attendance_category +
      attendance_probability + boy_score_z + I(boy_score_z^2) +
      boy_readiness_z + boy_score_z:course_track +
      boy_readiness_z:attendance_category + school_year_offset + annual_sin +
      annual_cos,
    parameters = 19
  )
)

dependency_status <- data.frame(
  Package = c("mgcv", "randomForest", "gbm"),
  Installed = c(
    requireNamespace("mgcv", quietly = TRUE),
    requireNamespace("randomForest", quietly = TRUE),
    requireNamespace("gbm", quietly = TRUE)
  ),
  stringsAsFactors = FALSE
)

if (dependency_status$Installed[dependency_status$Package == "mgcv"]) {
  s <- mgcv::s
  candidate_specs <- c(
    candidate_specs,
    list(
      make_spec(
        "Gain GAM",
        "score_gain",
        "gam",
        score_gain ~ grade_level + course_track + attendance_category +
          s(boy_score, k = 8) + s(boy_readiness, k = 8) +
          s(attendance_probability, k = 4) + s(school_year_offset, k = 5) +
          annual_sin + annual_cos,
        parameters = 24
      ),
      make_spec(
        "EOY GAM",
        "eoy_score",
        "gam",
        eoy_score ~ grade_level + course_track + attendance_category +
          s(boy_score, k = 8) + s(boy_readiness, k = 8) +
          s(attendance_probability, k = 4) + s(school_year_offset, k = 5) +
          annual_sin + annual_cos,
        parameters = 24
      )
    )
  )
}

tree_formula_gain <- score_gain ~ grade_level + course_track +
  attendance_category + attendance_probability + boy_score + boy_readiness +
  boy_below_45 + boy_45_to_60 + boy_above_60 + school_year_offset +
  annual_sin + annual_cos
tree_formula_eoy <- eoy_score ~ grade_level + course_track +
  attendance_category + attendance_probability + boy_score + boy_readiness +
  boy_below_45 + boy_45_to_60 + boy_above_60 + school_year_offset +
  annual_sin + annual_cos

if (dependency_status$Installed[dependency_status$Package == "randomForest"]) {
  candidate_specs <- c(
    candidate_specs,
    list(
      make_spec(
        "Gain random forest",
        "score_gain",
        "rf",
        tree_formula_gain,
        parameters = 250,
        fit_args = list(ntree = 250, nodesize = 10)
      ),
      make_spec(
        "EOY random forest",
        "eoy_score",
        "rf",
        tree_formula_eoy,
        parameters = 250,
        fit_args = list(ntree = 250, nodesize = 10)
      )
    )
  )
}

if (dependency_status$Installed[dependency_status$Package == "gbm"]) {
  gbm_args <- list(
    n_trees = 600,
    interaction_depth = 3,
    shrinkage = 0.03,
    bag_fraction = 0.75,
    n_minobsinnode = 10
  )
  candidate_specs <- c(
    candidate_specs,
    list(
      make_spec(
        "Gain gradient boosting",
        "score_gain",
        "gbm",
        tree_formula_gain,
        parameters = gbm_args$n_trees,
        fit_args = gbm_args
      ),
      make_spec(
        "EOY gradient boosting",
        "eoy_score",
        "gbm",
        tree_formula_eoy,
        parameters = gbm_args$n_trees,
        fit_args = gbm_args
      )
    )
  )
}

candidate_specs <- c(
  candidate_specs,
  list(
    make_spec(
      "Teacher/course leakage benchmark",
      "eoy_score",
      "lm",
      eoy_score ~ grade_level + course_track + attendance_category +
        attendance_probability + boy_score + boy_readiness + school_year_offset +
        annual_sin + annual_cos + teacher_id + course_id,
      role = "Excluded leakage benchmark",
      parameters = 26
    )
  )
)

cv_folds <- 5
cv_repeats <- 3

cv_results <- run_repeated_model_cv(
  data = train_data,
  specs = candidate_specs,
  k = cv_folds,
  repeats = cv_repeats
)

cv_summary <- summarize_regression_cv(cv_results)
names(candidate_specs) <- vapply(candidate_specs, `[[`, character(1), "name")
candidate_fits <- lapply(candidate_specs, function(spec) {
  fit_candidate(spec, train_data)
})

holdout_metrics <- do.call(rbind, lapply(names(candidate_specs), function(model_name) {
  spec <- candidate_specs[[model_name]]
  expected_gain <- predict_expected_gain(candidate_fits[[model_name]], spec, holdout_data)
  metrics <- evaluate_expected_gain(holdout_data, expected_gain)
  data.frame(
    Model = model_name,
    Holdout_RMSE = metrics$Gain_RMSE,
    Holdout_MAE = metrics$Gain_MAE,
    Holdout_R2 = metrics$Gain_R2,
    Holdout_EOY_RMSE = metrics$EOY_RMSE,
    Holdout_EOY_R2 = metrics$EOY_R2,
    AIC = ifelse(spec$method %in% c("lm", "gam"), AIC(candidate_fits[[model_name]]), NA_real_),
    Parameters = spec$parameters,
    stringsAsFactors = FALSE
  )
}))

model_comparison <- merge(cv_summary, holdout_metrics, by = "Model")
model_comparison <- model_comparison[order(model_comparison$CV_RMSE), ]

selection_candidates <- model_comparison[
  model_comparison$Role == "Operational candidate",
  ,
  drop = FALSE
]
selected_model_name <- selection_candidates$Model[
  which.min(selection_candidates$CV_RMSE)
]

model_comparison$Selected <- model_comparison$Model == selected_model_name
model_comparison$Delta_CV_RMSE <- model_comparison$CV_RMSE -
  min(selection_candidates$CV_RMSE)
model_comparison <- model_comparison[
  order(model_comparison$CV_RMSE),
  c(
    "Model", "Selected", "Role", "Target", "Method", "Parameters",
    "CV_RMSE", "CV_RMSE_SD", "CV_MAE", "CV_R2", "CV_EOY_RMSE",
    "CV_EOY_R2", "Holdout_RMSE", "Holdout_MAE", "Holdout_R2",
    "Holdout_EOY_RMSE", "Holdout_EOY_R2", "AIC", "Delta_CV_RMSE"
  )
]

selected_spec <- candidate_specs[[selected_model_name]]
selected_formula <- selected_spec$formula
final_model_train <- candidate_fits[[selected_model_name]]
holdout_predictions <- predict_expected_gain(final_model_train, selected_spec, holdout_data)
train_predictions <- predict_expected_gain(final_model_train, selected_spec, train_data)
holdout_final_metrics <- evaluate_expected_gain(holdout_data, holdout_predictions)
train_final_metrics <- evaluate_expected_gain(train_data, train_predictions)

final_model <- fit_candidate(selected_spec, growth)
growth$expected_gain <- predict_expected_gain(final_model, selected_spec, growth)
growth$expected_eoy <- growth$boy_score + growth$expected_gain
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
median_teacher_records <- median(teacher_summary$PairedRecords)
teacher_summary$ReliabilityWeight <- teacher_summary$PairedRecords /
  (teacher_summary$PairedRecords + median_teacher_records)
teacher_summary$AdjustedGrowthSignal <- teacher_summary$AdjustedResidual *
  teacher_summary$ReliabilityWeight
teacher_summary <- teacher_summary[
  order(teacher_summary$AdjustedGrowthSignal, decreasing = TRUE),
]

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
median_course_records <- median(course_summary$PairedRecords)
course_summary$ReliabilityWeight <- course_summary$PairedRecords /
  (course_summary$PairedRecords + median_course_records)
course_summary$AdjustedGrowthSignal <- course_summary$AdjustedResidual *
  course_summary$ReliabilityWeight
course_summary <- course_summary[
  order(course_summary$AdjustedGrowthSignal, decreasing = TRUE),
]

teacher_support <- teacher_summary[which.min(teacher_summary$AdjustedGrowthSignal), ]
teacher_bright <- teacher_summary[which.max(teacher_summary$AdjustedGrowthSignal), ]
course_support <- course_summary[which.min(course_summary$AdjustedGrowthSignal), ]
course_bright <- course_summary[which.max(course_summary$AdjustedGrowthSignal), ]

priority_rows <- list(
  data.frame(
    Priority = "Teacher support review",
    Target = teacher_support$Teacher,
    Mean_adjusted_gap = format_num(teacher_support$AdjustedResidual, 2),
    Review_signal = format_num(teacher_support$AdjustedGrowthSignal, 2),
    Evidence = paste0(
      teacher_support$Sections, " historical sections and ",
      teacher_support$PairedRecords, " paired records."
    ),
    Recommended_follow_up = paste0(
      "Review upcoming sections for ", teacher_support$Teacher,
      " before the next assessment cycle; focus on pacing, attendance mix, ",
      "starting readiness, and support routines."
    ),
    stringsAsFactors = FALSE
  ),
  data.frame(
    Priority = "Teacher bright spot review",
    Target = teacher_bright$Teacher,
    Mean_adjusted_gap = format_num(teacher_bright$AdjustedResidual, 2),
    Review_signal = paste0("+", format_num(abs(teacher_bright$AdjustedGrowthSignal), 2)),
    Evidence = paste0(
      teacher_bright$Sections, " historical sections and ",
      teacher_bright$PairedRecords, " paired records."
    ),
    Recommended_follow_up = paste0(
      "Identify practices from ", teacher_bright$Teacher,
      " that may transfer to similar course and readiness contexts."
    ),
    stringsAsFactors = FALSE
  ),
  data.frame(
    Priority = "Course support review",
    Target = as.character(course_support$Course),
    Mean_adjusted_gap = format_num(course_support$AdjustedResidual, 2),
    Review_signal = format_num(course_support$AdjustedGrowthSignal, 2),
    Evidence = paste0(
      course_support$Sections, " historical sections and ",
      course_support$PairedRecords, " paired records."
    ),
    Recommended_follow_up = paste0(
      "Review curriculum sequence, assessment alignment, and prerequisite ",
      "readiness for ", course_support$Course, "."
    ),
    stringsAsFactors = FALSE
  ),
  data.frame(
    Priority = "Course bright spot review",
    Target = as.character(course_bright$Course),
    Mean_adjusted_gap = paste0("+", format_num(abs(course_bright$AdjustedResidual), 2)),
    Review_signal = paste0("+", format_num(abs(course_bright$AdjustedGrowthSignal), 2)),
    Evidence = paste0(
      course_bright$Sections, " historical sections and ",
      course_bright$PairedRecords, " paired records."
    ),
    Recommended_follow_up = paste0(
      "Use ", course_bright$Course,
      " as a reference pattern when reviewing similar course pathways."
    ),
    stringsAsFactors = FALSE
  )
)
future_priorities <- do.call(rbind, priority_rows)

section_evidence_for_priority <- function(priority, target, target_type, direction, n = 2) {
  if (target_type == "teacher") {
    rows <- eligible_sections[eligible_sections$Teacher == target, , drop = FALSE]
  } else {
    rows <- eligible_sections[eligible_sections$Course == target, , drop = FALSE]
  }
  if (nrow(rows) == 0) {
    return(data.frame())
  }
  rows <- rows[order(rows$AdjustedGrowthSignal, decreasing = direction == "high"), ]
  rows <- head(rows, n)
  data.frame(
    Priority = priority,
    Target = target,
    Section = rows$Section,
    Teacher = rows$Teacher,
    Course = rows$Course,
    Year = rows$SchoolYear,
    N = rows$N,
    Raw_gain = format_num(rows$MeanGain, 2),
    Expected_gain = format_num(rows$ExpectedGain, 2),
    Adjusted_signal = format_num(rows$AdjustedGrowthSignal, 2),
    stringsAsFactors = FALSE
  )
}

historical_section_evidence <- do.call(rbind, list(
  section_evidence_for_priority(
    "Teacher support review", teacher_support$Teacher, "teacher", "low"
  ),
  section_evidence_for_priority(
    "Teacher bright spot review", teacher_bright$Teacher, "teacher", "high"
  ),
  section_evidence_for_priority(
    "Course support review", course_support$Course, "course", "low"
  ),
  section_evidence_for_priority(
    "Course bright spot review", course_bright$Course, "course", "high"
  )
))

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
    "Holdout expected-gain RMSE",
    "Holdout expected-gain MAE",
    "Holdout expected-gain R-squared",
    "Holdout EOY RMSE",
    "Holdout EOY R-squared",
    "Residual mean, all pairs",
    "Residual SD, all pairs"
  ),
  Estimate = c(
    format_num(holdout_final_metrics$Gain_RMSE, 3),
    format_num(holdout_final_metrics$Gain_MAE, 3),
    format_num(holdout_final_metrics$Gain_R2, 3),
    format_num(holdout_final_metrics$EOY_RMSE, 3),
    format_num(holdout_final_metrics$EOY_R2, 3),
    format_num(mean(growth$adjusted_growth_residual), 3),
    format_num(sd(growth$adjusted_growth_residual), 3)
  ),
  Interpretation = c(
    "Typical holdout prediction error on BOY/EOY gain",
    "Average absolute holdout prediction error",
    "Share of holdout gain variation explained by the expected-growth model",
    "Typical holdout prediction error on final EOY score",
    "Share of holdout EOY score variation explained by the baseline",
    "Near 0 means expected gain is centered overall",
    "Residual spread used to judge section signal uncertainty"
  ),
  stringsAsFactors = FALSE
)

model_comparison_display <- data.frame(
  Model = model_comparison$Model,
  Selected = ifelse(model_comparison$Selected, "Yes", ""),
  Role = model_comparison$Role,
  Target = model_comparison$Target,
  Method = model_comparison$Method,
  Params = model_comparison$Parameters,
  CV_RMSE = format_num(model_comparison$CV_RMSE, 3),
  CV_SD = format_num(model_comparison$CV_RMSE_SD, 3),
  CV_MAE = format_num(model_comparison$CV_MAE, 3),
  CV_R2 = format_num(model_comparison$CV_R2, 3),
  CV_EOY_R2 = format_num(model_comparison$CV_EOY_R2, 3),
  Holdout_RMSE = format_num(model_comparison$Holdout_RMSE, 3),
  Holdout_R2 = format_num(model_comparison$Holdout_R2, 3),
  Holdout_EOY_R2 = format_num(model_comparison$Holdout_EOY_R2, 3),
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
  Adjusted_signal = format_num(teacher_summary$AdjustedGrowthSignal, 2),
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
  Adjusted_signal = format_num(course_summary$AdjustedGrowthSignal, 2),
  stringsAsFactors = FALSE
)

selected_comparison <- model_comparison[model_comparison$Selected, , drop = FALSE]

final_metrics <- data.frame(
  Metric = c(
    "Selected model",
    "Selected target strategy",
    "Selected method",
    "Selection rule",
    "Training paired records",
    "Holdout paired records",
    "Candidate models tested",
    "Operational candidates tested",
    "Excluded leakage benchmarks",
    "Repeated CV folds",
    "Repeated CV repeats",
    "CV expected-gain RMSE",
    "CV expected-gain MAE",
    "CV expected-gain R-squared",
    "CV EOY R-squared",
    "Holdout expected-gain RMSE",
    "Holdout expected-gain MAE",
    "Holdout expected-gain R-squared",
    "Holdout EOY RMSE",
    "Holdout EOY R-squared",
    "Mean BOY score",
    "Mean EOY score",
    "Mean raw BOY/EOY gain",
    "Section-year groups"
  ),
  Value = c(
    selected_model_name,
    selected_comparison$Target,
    selected_comparison$Method,
    "Lowest repeated-CV expected-gain RMSE among operational candidates; teacher/course ID leakage benchmark excluded",
    format(nrow(train_data), big.mark = ","),
    format(nrow(holdout_data), big.mark = ","),
    length(candidate_specs),
    sum(model_comparison$Role == "Operational candidate"),
    sum(model_comparison$Role != "Operational candidate"),
    cv_folds,
    cv_repeats,
    format_num(selected_comparison$CV_RMSE, 3),
    format_num(selected_comparison$CV_MAE, 3),
    format_num(selected_comparison$CV_R2, 3),
    format_num(selected_comparison$CV_EOY_R2, 3),
    format_num(holdout_final_metrics$Gain_RMSE, 3),
    format_num(holdout_final_metrics$Gain_MAE, 3),
    format_num(holdout_final_metrics$Gain_R2, 3),
    format_num(holdout_final_metrics$EOY_RMSE, 3),
    format_num(holdout_final_metrics$EOY_R2, 3),
    format_num(mean(growth$boy_score), 1),
    format_num(mean(growth$eoy_score), 1),
    format_num(mean(growth$score_gain), 2),
    format(nrow(section_summary), big.mark = ",")
  ),
  stringsAsFactors = FALSE
)

family_review_spec <- data.frame(
  Family = c(
    "Direct gain baseline",
    "Predicted EOY baseline",
    "Interaction surface",
    "GAM smooths",
    "Random forest",
    "Gradient boosting",
    "Teacher/course ID leakage check"
  ),
  Pattern = c(
    "^Gain (linear benchmark|readiness model)$",
    "^EOY (linear benchmark|readiness model)$",
    "interaction model$",
    "GAM$",
    "random forest$",
    "gradient boosting$",
    "Teacher/course leakage benchmark$"
  ),
  Why_tested = c(
    "Directly predicts score gain from starting profile and context.",
    "Predicts final EOY score first, then converts it to expected gain.",
    "Tests whether baseline score and readiness effects vary by track and attendance.",
    "Uses smooth nonlinear functions for baseline, readiness, attendance, and year effects.",
    "Tests a flexible tree ensemble without teacher, course ID, or section ID effects.",
    "Tests boosted trees for nonlinear interactions without persistent ID effects.",
    "Shows what happens when teacher and course IDs are included; excluded from operations because it would absorb the review signals."
  ),
  stringsAsFactors = FALSE
)
shape_review <- do.call(rbind, lapply(seq_len(nrow(family_review_spec)), function(i) {
  rows <- model_comparison[
    grepl(family_review_spec$Pattern[i], model_comparison$Model),
    ,
    drop = FALSE
  ]
  if (nrow(rows) == 0) {
    return(data.frame(
      Family = family_review_spec$Family[i],
      Representative_model = "Not run",
      Why_tested = family_review_spec$Why_tested[i],
      Decision = "Skipped because the optional package was not available.",
      CV_RMSE = "",
      Holdout_RMSE = "",
      stringsAsFactors = FALSE
    ))
  }
  best_row <- rows[which.min(rows$CV_RMSE), , drop = FALSE]
  decision <- if (best_row$Role == "Excluded leakage benchmark") {
    "Excluded from operating selection; persistent IDs would contaminate future review signals."
  } else if (any(rows$Selected)) {
    "Selected operating family."
  } else {
    "Compared; not selected by repeated-CV expected-gain RMSE."
  }
  data.frame(
    Family = family_review_spec$Family[i],
    Representative_model = best_row$Model,
    Why_tested = family_review_spec$Why_tested[i],
    Decision = decision,
    CV_RMSE = format_num(best_row$CV_RMSE, 3),
    Holdout_RMSE = format_num(best_row$Holdout_RMSE, 3),
    stringsAsFactors = FALSE
  )
}))

write.csv(model_comparison, file.path("reports", "growth_model_comparison.csv"), row.names = FALSE)
write.csv(model_comparison_display, file.path("reports", "growth_model_comparison_display.csv"), row.names = FALSE)
write.csv(final_metrics, file.path("reports", "growth_final_metrics.csv"), row.names = FALSE)
write.csv(shape_review, file.path("reports", "growth_shape_review.csv"), row.names = FALSE)
write.csv(dependency_status, file.path("reports", "model_dependency_status.csv"), row.names = FALSE)
write.csv(section_ttests_display, file.path("reports", "section_ttests.csv"), row.names = FALSE)
write.csv(section_signals_display, file.path("reports", "section_adjusted_signals.csv"), row.names = FALSE)
write.csv(section_highlights_display, file.path("reports", "section_signal_highlights.csv"), row.names = FALSE)
write.csv(teacher_display, file.path("reports", "teacher_growth_summary.csv"), row.names = FALSE)
write.csv(course_display, file.path("reports", "course_growth_summary.csv"), row.names = FALSE)
write.csv(future_priorities, file.path("reports", "future_review_priorities.csv"), row.names = FALSE)
write.csv(historical_section_evidence, file.path("reports", "historical_section_evidence.csv"), row.names = FALSE)
write.csv(diagnostics, file.path("reports", "growth_diagnostics.csv"), row.names = FALSE)
write.csv(sensitivity, file.path("reports", "growth_sensitivity.csv"), row.names = FALSE)
write.csv(growth, file.path("reports", "growth_scored_pairs.csv"), row.names = FALSE)

saveRDS(
  list(
    selected_model_name = selected_model_name,
    selected_formula = selected_formula,
    selected_spec = selected_spec,
    candidate_specs = candidate_specs,
    final_model = final_model,
    dependency_status = dependency_status,
    model_comparison = model_comparison,
    section_summary = section_summary,
    teacher_summary = teacher_summary,
    course_summary = course_summary,
    future_priorities = future_priorities,
    historical_section_evidence = historical_section_evidence,
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
curve_models <- unique(c(
  "Gain readiness model",
  "EOY readiness model",
  "EOY interaction model",
  selected_model_name
))
curve_models <- curve_models[curve_models %in% names(candidate_fits)]
curve_predictions <- lapply(curve_models, function(model_name) {
  predict_expected_gain(
    candidate_fits[[model_name]],
    candidate_specs[[model_name]],
    curve_data
  )
})
curve_ylim <- range(c(growth$score_gain, unlist(curve_predictions)), na.rm = TRUE)
plot(
  range(score_grid),
  curve_ylim,
  type = "n",
  xlab = "BOY score",
  ylab = "Predicted BOY/EOY gain",
  main = "Expected-Gain Shape Search"
)
curve_cols <- c("#555555", "#8C2D19", "#1B6CA8", "#2D7D46", "#6B4E9B")
for (i in seq_along(curve_models)) {
  model_name <- curve_models[i]
  lines(
    score_grid,
    curve_predictions[[i]],
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
abline(v = selected_comparison$CV_RMSE, lty = 2, col = "#8C2D19")
legend(
  "bottomright",
  legend = c("Selected model", "Other candidate", "Selected mean CV RMSE"),
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
teacher_plot <- teacher_summary[order(teacher_summary$AdjustedGrowthSignal), ]
barplot(
  teacher_plot$AdjustedGrowthSignal,
  names.arg = teacher_plot$Teacher,
  las = 2,
  col = ifelse(teacher_plot$AdjustedGrowthSignal >= 0, "#1B6CA8", "#8C2D19"),
  border = NA,
  ylab = "Reliability-weighted adjusted signal",
  main = "Teacher-Level Future Signal"
)
abline(h = 0, lwd = 1.5, col = "#333333")
course_plot <- head(course_summary[order(abs(course_summary$AdjustedGrowthSignal), decreasing = TRUE), ], 8)
course_plot <- course_plot[order(course_plot$AdjustedGrowthSignal), ]
barplot(
  course_plot$AdjustedGrowthSignal,
  names.arg = short_course_label(course_plot$Course),
  las = 2,
  col = ifelse(course_plot$AdjustedGrowthSignal >= 0, "#1B6CA8", "#8C2D19"),
  border = NA,
  ylab = "Reliability-weighted adjusted signal",
  main = "Course-Level Future Signal"
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
