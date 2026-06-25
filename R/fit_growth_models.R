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
                      family = method_label(method), complexity = "Baseline",
                      parameters = NA_integer_, tuned_parameters = "",
                      selection_eligible = TRUE, leakage_status = "Public-safe",
                      fit_args = list()) {
  list(
    name = name,
    target = target,
    method = method,
    formula = formula,
    role = role,
    family = family,
    complexity = complexity,
    parameters = parameters,
    tuned_parameters = tuned_parameters,
    selection_eligible = selection_eligible,
    leakage_status = leakage_status,
    fit_args = fit_args
  )
}

target_label <- function(target) {
  ifelse(target == "eoy_score", "EOY-derived gain", "Direct growth")
}

method_label <- function(method) {
  labels <- c(
    lm = "Linear model",
    gam = "GAM",
    rf = "Random forest",
    gbm = "Gradient boosting",
    rpart = "Regression tree",
    ensemble = "Ensemble"
  )
  labels[[method]]
}

fit_candidate <- function(spec, data, seed = 20260623) {
  set.seed(seed)
  if (spec$method == "ensemble") {
    member_fits <- lapply(seq_along(spec$fit_args$members), function(i) {
      fit_candidate(
        spec$fit_args$members[[i]],
        data,
        seed = seed + i * 17
      )
    })
    return(list(
      member_fits = member_fits,
      member_specs = spec$fit_args$members,
      weights = spec$fit_args$weights
    ))
  }
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
      mtry = spec$fit_args$mtry,
      importance = FALSE
    ))
  }
  if (spec$method == "rpart") {
    return(rpart::rpart(
      spec$formula,
      data = data,
      method = "anova",
      control = rpart::rpart.control(
        cp = spec$fit_args$cp,
        minbucket = spec$fit_args$minbucket,
        maxdepth = spec$fit_args$maxdepth
      )
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
    return(as.numeric(suppressWarnings(predict(
      fit,
      newdata = newdata,
      n.trees = spec$fit_args$n_trees
    ))))
  }
  as.numeric(suppressWarnings(predict(fit, newdata = newdata)))
}

predict_expected_gain <- function(fit, spec, newdata) {
  if (spec$method == "ensemble") {
    member_predictions <- mapply(
      function(member_fit, member_spec) {
        predict_expected_gain(member_fit, member_spec, newdata)
      },
      fit$member_fits,
      fit$member_specs
    )
    if (is.null(dim(member_predictions))) {
      member_predictions <- matrix(member_predictions, ncol = length(fit$member_specs))
    }
    weights <- fit$weights / sum(fit$weights)
    return(as.numeric(member_predictions %*% weights))
  }
  target_prediction <- predict_target_value(fit, spec, newdata)
  if (spec$target == "eoy_score") {
    return(target_prediction - newdata$boy_score)
  }
  target_prediction
}

predict_expected_eoy <- function(fit, spec, newdata) {
  if (spec$method == "ensemble") {
    return(newdata$boy_score + predict_expected_gain(fit, spec, newdata))
  }
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

run_temporal_validation <- function(data, specs, years, seed = 20260623) {
  results <- list()
  counter <- 1

  for (validation_year in years) {
    train_data <- data[data$school_year != validation_year, , drop = FALSE]
    test_data <- data[data$school_year == validation_year, , drop = FALSE]
    for (spec in specs) {
      fit <- fit_candidate(
        spec,
        train_data,
        seed = seed + match(validation_year, years)
      )
      expected_gain <- predict_expected_gain(fit, spec, test_data)
      metrics <- evaluate_expected_gain(test_data, expected_gain)
      results[[counter]] <- data.frame(
        Model = spec$name,
        Target = target_label(spec$target),
        Method = method_label(spec$method),
        Role = spec$role,
        ValidationYear = validation_year,
        N = nrow(test_data),
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

summarize_temporal_validation <- function(temporal_results) {
  means <- aggregate(
    cbind(RMSE, MAE, R2, EOY_RMSE, EOY_R2) ~ Model + Target + Method + Role,
    temporal_results,
    mean
  )
  sds <- aggregate(
    cbind(RMSE, MAE, R2) ~ Model + Target + Method + Role,
    temporal_results,
    sd
  )
  names(means) <- c(
    "Model", "Target", "Method", "Role", "Temporal_RMSE",
    "Temporal_MAE", "Temporal_R2", "Temporal_EOY_RMSE", "Temporal_EOY_R2"
  )
  names(sds) <- c(
    "Model", "Target", "Method", "Role", "Temporal_RMSE_SD",
    "Temporal_MAE_SD", "Temporal_R2_SD"
  )
  summary <- merge(means, sds, by = c("Model", "Target", "Method", "Role"))
  summary[order(summary$Temporal_RMSE), ]
}

bootstrap_model_validation <- function(data, expected_gain, reps = 300,
                                       seed = 20260623) {
  set.seed(seed)
  metric_rows <- replicate(reps, {
    idx <- sample(seq_len(nrow(data)), size = nrow(data), replace = TRUE)
    metrics <- evaluate_expected_gain(data[idx, , drop = FALSE], expected_gain[idx])
    c(
      Gain_RMSE = metrics$Gain_RMSE,
      Gain_MAE = metrics$Gain_MAE,
      Gain_R2 = metrics$Gain_R2,
      EOY_RMSE = metrics$EOY_RMSE,
      EOY_R2 = metrics$EOY_R2
    )
  })
  metric_rows <- t(metric_rows)
  estimates <- evaluate_expected_gain(data, expected_gain)
  data.frame(
    Metric = c(
      "Expected-gain RMSE", "Expected-gain MAE", "Expected-gain R-squared",
      "EOY RMSE", "EOY R-squared"
    ),
    Estimate = c(
      estimates$Gain_RMSE, estimates$Gain_MAE, estimates$Gain_R2,
      estimates$EOY_RMSE, estimates$EOY_R2
    ),
    CI_Lower = apply(metric_rows, 2, quantile, probs = 0.025, na.rm = TRUE),
    CI_Upper = apply(metric_rows, 2, quantile, probs = 0.975, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}

bootstrap_gap_summary <- function(values, reps = 300, seed = 20260623) {
  set.seed(seed)
  n <- length(values)
  observed <- mean(values)
  if (n <= 1 || is.na(observed)) {
    return(c(
      Gap = observed, CI_Lower = NA_real_, CI_Upper = NA_real_,
      P_Value = NA_real_
    ))
  }
  boots <- replicate(reps, mean(sample(values, size = n, replace = TRUE)))
  p_value <- 2 * min(mean(boots <= 0), mean(boots >= 0))
  p_value <- min(max(p_value, 1 / (reps + 1)), 1)
  c(
    Gap = observed,
    CI_Lower = as.numeric(quantile(boots, probs = 0.025, na.rm = TRUE)),
    CI_Upper = as.numeric(quantile(boots, probs = 0.975, na.rm = TRUE)),
    P_Value = p_value
  )
}

decision_flag <- function(gap, lower, upper, q_value, n, min_n,
                          effect_threshold = 0.75,
                          q_threshold = 0.20) {
  if (is.na(n) || n < min_n) {
    return("Insufficient sample")
  }
  if (!is.na(q_value) && !is.na(lower) && !is.na(upper) &&
      gap <= -effect_threshold && upper < 0 && q_value <= q_threshold) {
    return("Intervention target")
  }
  if (!is.na(q_value) && !is.na(lower) && !is.na(upper) &&
      gap >= effect_threshold && lower > 0 && q_value <= q_threshold) {
    return("Positive anomaly")
  }
  if (!is.na(gap) && abs(gap) >= effect_threshold) {
    return("Watch list")
  }
  "In range"
}

make_latest_review <- function(data, group_vars, level, min_n, reps = 300,
                               seed = 20260623) {
  group_key <- do.call(paste, c(data[group_vars], sep = " | "))
  split_data <- split(data, group_key)
  median_n <- median(vapply(split_data, nrow, integer(1)))

  rows <- lapply(seq_along(split_data), function(i) {
    df <- split_data[[i]]
    gap_stats <- bootstrap_gap_summary(
      df$adjusted_growth_residual,
      reps = reps,
      seed = seed + i
    )
    n <- nrow(df)
    reliability_weight <- n / (n + median_n)
    base <- data.frame(
      Level = level,
      Target = names(split_data)[i],
      N = n,
      RawGain = mean(df$score_gain),
      ExpectedGain = mean(df$expected_gain),
      AdjustedGap = gap_stats[["Gap"]],
      ReliabilityWeight = reliability_weight,
      ReviewSignal = gap_stats[["Gap"]] * reliability_weight,
      CI_Lower = gap_stats[["CI_Lower"]],
      CI_Upper = gap_stats[["CI_Upper"]],
      P_Value = gap_stats[["P_Value"]],
      stringsAsFactors = FALSE
    )
    for (var in group_vars) {
      base[[var]] <- as.character(df[[var]][1])
    }
    base
  })

  review <- do.call(rbind, rows)
  review$Q_Value <- p.adjust(review$P_Value, method = "BH")
  review$Decision <- mapply(
    decision_flag,
    review$AdjustedGap,
    review$CI_Lower,
    review$CI_Upper,
    review$Q_Value,
    review$N,
    MoreArgs = list(min_n = min_n),
    USE.NAMES = FALSE
  )
  review[order(review$ReviewSignal), ]
}

format_review_table <- function(review, id_cols) {
  target <- if ("Target" %in% names(review)) {
    review$Target
  } else {
    review$DisplayTarget
  }
  output <- data.frame(
    Level = review$Level,
    Target = target,
    N = review$N,
    Raw_gain = format_num(review$RawGain, 2),
    Expected_gain = format_num(review$ExpectedGain, 2),
    Adjusted_gap = format_num(review$AdjustedGap, 2),
    CI_95 = paste0(
      format_num(review$CI_Lower, 2),
      " to ",
      format_num(review$CI_Upper, 2)
    ),
    P_value = format_p(review$P_Value),
    Q_value = format_p(review$Q_Value),
    Decision = review$Decision,
    stringsAsFactors = FALSE
  )
  for (col in rev(id_cols)) {
    output <- cbind(setNames(data.frame(review[[col]], stringsAsFactors = FALSE), col), output)
  }
  output
}

section_key <- paste(growth$section_id, growth$school_year, sep = " | ")
growth$section_year_id <- section_key

school_years <- sort(unique(growth$school_year))
action_year <- tail(school_years, 1)
training_years <- setdiff(school_years, action_year)
train_data <- growth[growth$school_year %in% training_years, , drop = FALSE]
action_data <- growth[growth$school_year == action_year, , drop = FALSE]

candidate_specs <- list(
  make_spec(
    "Growth linear benchmark",
    "score_gain",
    "lm",
    score_gain ~ grade_level + course_track + attendance_category +
      attendance_probability + boy_score + school_year_offset + annual_sin +
      annual_cos,
    family = "Parametric linear",
    complexity = "Baseline",
    parameters = 12,
    tuned_parameters = "linear terms"
  ),
  make_spec(
    "Growth readiness model",
    "score_gain",
    "lm",
    score_gain ~ grade_level + course_track + attendance_category +
      attendance_probability + boy_score + boy_readiness + school_year_offset +
      annual_sin + annual_cos,
    family = "Parametric linear",
    complexity = "Readiness adjusted",
    parameters = 13,
    tuned_parameters = "adds BOY readiness"
  ),
  make_spec(
    "Growth polynomial degree 2",
    "score_gain",
    "lm",
    score_gain ~ grade_level + course_track + attendance_category +
      attendance_probability + boy_score_z + I(boy_score_z^2) +
      boy_readiness_z + I(boy_readiness_z^2) + school_year_offset +
      annual_sin + annual_cos,
    family = "Parametric polynomial",
    complexity = "Degree 2",
    parameters = 15,
    tuned_parameters = "degree=2"
  ),
  make_spec(
    "Growth polynomial degree 3",
    "score_gain",
    "lm",
    score_gain ~ grade_level + course_track + attendance_category +
      attendance_probability + boy_score_z + I(boy_score_z^2) +
      I(boy_score_z^3) + boy_readiness_z + I(boy_readiness_z^2) +
      I(boy_readiness_z^3) + school_year_offset + annual_sin + annual_cos,
    family = "Parametric polynomial",
    complexity = "Degree 3",
    parameters = 17,
    tuned_parameters = "degree=3"
  ),
  make_spec(
    "Growth interaction model",
    "score_gain",
    "lm",
    score_gain ~ grade_level + course_track + attendance_category +
      attendance_probability + boy_score_z + I(boy_score_z^2) +
      boy_readiness_z + boy_score_z:course_track +
      boy_readiness_z:attendance_category + attendance_probability:course_track +
      school_year_offset + annual_sin + annual_cos,
    family = "Parametric interactions",
    complexity = "Targeted interactions",
    parameters = 22,
    tuned_parameters = "track/readiness/attendance interactions"
  ),
  make_spec(
    "Growth cyclic interaction model",
    "score_gain",
    "lm",
    score_gain ~ grade_level + course_track + attendance_category +
      attendance_probability + boy_score_z + I(boy_score_z^2) +
      boy_readiness_z + boy_score_z:course_track +
      boy_readiness_z:attendance_category + annual_sin:course_track +
      annual_cos:course_track + school_year_offset,
    family = "Parametric cyclic",
    complexity = "Cyclic interactions",
    parameters = 25,
    tuned_parameters = "track-specific sine/cosine terms"
  ),
  make_spec(
    "EOY readiness benchmark",
    "eoy_score",
    "lm",
    eoy_score ~ grade_level + course_track + attendance_category +
      attendance_probability + boy_score + boy_readiness + school_year_offset +
      annual_sin + annual_cos,
    role = "EOY-derived benchmark",
    family = "EOY-derived benchmark",
    complexity = "Readiness adjusted",
    parameters = 13,
    tuned_parameters = "predicts EOY then subtracts BOY",
    selection_eligible = FALSE
  ),
  make_spec(
    "EOY interaction benchmark",
    "eoy_score",
    "lm",
    eoy_score ~ grade_level + course_track + attendance_category +
      attendance_probability + boy_score_z + I(boy_score_z^2) +
      boy_readiness_z + boy_score_z:course_track +
      boy_readiness_z:attendance_category + school_year_offset + annual_sin +
      annual_cos,
    role = "EOY-derived benchmark",
    family = "EOY-derived benchmark",
    complexity = "Interaction benchmark",
    parameters = 19,
    tuned_parameters = "predicts EOY then subtracts BOY",
    selection_eligible = FALSE
  )
)

dependency_status <- data.frame(
  Package = c("mgcv", "randomForest", "gbm", "rpart"),
  Installed = c(
    requireNamespace("mgcv", quietly = TRUE),
    requireNamespace("randomForest", quietly = TRUE),
    requireNamespace("gbm", quietly = TRUE),
    requireNamespace("rpart", quietly = TRUE)
  ),
  stringsAsFactors = FALSE
)

if (dependency_status$Installed[dependency_status$Package == "mgcv"]) {
  s <- mgcv::s
  gam_ks <- c(4, 8)
  candidate_specs <- c(
    candidate_specs,
    lapply(gam_ks, function(k) {
      make_spec(
        paste0("Growth GAM k", k),
        "score_gain",
        "gam",
        as.formula(paste0(
          "score_gain ~ grade_level + course_track + attendance_category + ",
          "s(boy_score, k = ", k, ") + ",
          "s(boy_readiness, k = ", k, ") + ",
          "s(attendance_probability, k = 4) + ",
          "s(school_year_offset, k = 5) + annual_sin + annual_cos"
        )),
        family = "Semi-parametric GAM",
        complexity = paste0("Smooth k=", k),
        parameters = 3 * k + 9,
        tuned_parameters = paste0("k=", k)
      )
    })
  )
}

tree_formula_gain <- score_gain ~ grade_level + course_track +
  attendance_category + attendance_probability + boy_score + boy_readiness +
  boy_below_45 + boy_45_to_60 + boy_above_60 + school_year_offset +
  annual_sin + annual_cos

tree_grid <- list(
  list(cp = 0.010, minbucket = 8, maxdepth = 5),
  list(cp = 0.003, minbucket = 5, maxdepth = 7)
)

if (dependency_status$Installed[dependency_status$Package == "rpart"]) {
  candidate_specs <- c(
    candidate_specs,
    lapply(seq_along(tree_grid), function(i) {
      args <- tree_grid[[i]]
      make_spec(
        paste0("Growth regression tree ", i),
        "score_gain",
        "rpart",
        tree_formula_gain,
        family = "Non-parametric tree",
        complexity = paste0("Tree grid ", i),
        parameters = NA_integer_,
        tuned_parameters = paste0(
          "cp=", args$cp,
          "; minbucket=", args$minbucket,
          "; maxdepth=", args$maxdepth
        ),
        fit_args = args
      )
    })
  )
}

if (dependency_status$Installed[dependency_status$Package == "randomForest"]) {
  rf_grid <- list(
    list(ntree = 200, nodesize = 10, mtry = 4),
    list(ntree = 300, nodesize = 5, mtry = 7)
  )
  candidate_specs <- c(
    candidate_specs,
    lapply(seq_along(rf_grid), function(i) {
      args <- rf_grid[[i]]
      make_spec(
        paste0("Growth random forest ", i),
        "score_gain",
        "rf",
        tree_formula_gain,
        family = "Non-parametric random forest",
        complexity = paste0("RF grid ", i),
        parameters = args$ntree,
        tuned_parameters = paste0(
          "ntree=", args$ntree,
          "; mtry=", args$mtry,
          "; nodesize=", args$nodesize
        ),
        fit_args = args
      )
    })
  )
}

if (dependency_status$Installed[dependency_status$Package == "gbm"]) {
  gbm_grid <- list(
    list(n_trees = 300, interaction_depth = 2, shrinkage = 0.040, bag_fraction = 0.75, n_minobsinnode = 10),
    list(n_trees = 600, interaction_depth = 3, shrinkage = 0.025, bag_fraction = 0.75, n_minobsinnode = 8)
  )
  candidate_specs <- c(
    candidate_specs,
    lapply(seq_along(gbm_grid), function(i) {
      args <- gbm_grid[[i]]
      make_spec(
        paste0("Growth gradient boosting ", i),
        "score_gain",
        "gbm",
        tree_formula_gain,
        family = "Non-parametric boosting",
        complexity = paste0("GBM grid ", i),
        parameters = args$n_trees,
        tuned_parameters = paste0(
          "trees=", args$n_trees,
          "; depth=", args$interaction_depth,
          "; shrinkage=", args$shrinkage,
          "; minobs=", args$n_minobsinnode
        ),
        fit_args = args
      )
    })
  )
}

add_ensemble_candidate <- function(specs, name, member_names, weights, complexity) {
  spec_names <- vapply(specs, `[[`, character(1), "name")
  keep <- member_names %in% spec_names
  member_names <- member_names[keep]
  weights <- weights[keep]
  if (length(member_names) < 2) {
    return(specs)
  }
  members <- lapply(member_names, function(member_name) {
    specs[[match(member_name, spec_names)]]
  })
  parameters <- sum(vapply(members, function(member) {
    ifelse(is.na(member$parameters), 1, member$parameters)
  }, numeric(1)))
  c(
    specs,
    list(make_spec(
      name,
      "score_gain",
      "ensemble",
      score_gain ~ 1,
      family = "Validation ensemble",
      complexity = complexity,
      parameters = parameters,
      tuned_parameters = paste0(
        paste(member_names, weights, sep = " weight=", collapse = "; ")
      ),
      fit_args = list(members = members, weights = weights)
    ))
  )
}

candidate_specs <- add_ensemble_candidate(
  candidate_specs,
  "Growth ensemble balanced",
  c("Growth gradient boosting 1", "Growth GAM k4", "Growth polynomial degree 3"),
  c(1, 1, 1),
  "Equal-weight GBM/GAM/polynomial blend"
)

candidate_specs <- add_ensemble_candidate(
  candidate_specs,
  "Growth ensemble nonlinear weighted",
  c("Growth gradient boosting 1", "Growth GAM k4", "Growth polynomial degree 3"),
  c(2, 1, 1),
  "GBM-weighted nonlinear blend"
)

candidate_specs <- c(
  candidate_specs,
  list(
    make_spec(
      "Teacher/course leakage benchmark",
      "score_gain",
      "lm",
      score_gain ~ grade_level + course_track + attendance_category +
        attendance_probability + boy_score + boy_readiness + school_year_offset +
        annual_sin + annual_cos + teacher_id + course_id,
      role = "Excluded leakage benchmark",
      family = "Leakage benchmark",
      complexity = "Teacher/course IDs",
      parameters = 26,
      tuned_parameters = "includes persistent IDs",
      selection_eligible = FALSE,
      leakage_status = "Excluded: absorbs review signals"
    )
  )
)

cv_folds <- 5
cv_repeats <- 2

cv_results <- run_repeated_model_cv(
  data = train_data,
  specs = candidate_specs,
  k = cv_folds,
  repeats = cv_repeats
)

cv_summary <- summarize_regression_cv(cv_results)
temporal_results <- run_temporal_validation(
  data = train_data,
  specs = candidate_specs,
  years = training_years
)
temporal_summary <- summarize_temporal_validation(temporal_results)
names(candidate_specs) <- vapply(candidate_specs, `[[`, character(1), "name")
candidate_fits <- lapply(candidate_specs, function(spec) {
  fit_candidate(spec, train_data)
})

spec_metadata <- do.call(rbind, lapply(names(candidate_specs), function(model_name) {
  spec <- candidate_specs[[model_name]]
  data.frame(
    Model = model_name,
    Family = spec$family,
    Complexity = spec$complexity,
    TunedParameters = spec$tuned_parameters,
    SelectionEligible = spec$selection_eligible,
    LeakageStatus = spec$leakage_status,
    stringsAsFactors = FALSE
  )
}))

action_metrics <- do.call(rbind, lapply(names(candidate_specs), function(model_name) {
  spec <- candidate_specs[[model_name]]
  fit <- candidate_fits[[model_name]]
  expected_gain <- predict_expected_gain(fit, spec, action_data)
  train_expected_gain <- predict_expected_gain(fit, spec, train_data)
  metrics <- evaluate_expected_gain(action_data, expected_gain)
  train_metrics <- evaluate_expected_gain(train_data, train_expected_gain)
  data.frame(
    Model = model_name,
    Train_RMSE = train_metrics$Gain_RMSE,
    Train_MAE = train_metrics$Gain_MAE,
    Train_R2 = train_metrics$Gain_R2,
    Action_RMSE = metrics$Gain_RMSE,
    Action_MAE = metrics$Gain_MAE,
    Action_R2 = metrics$Gain_R2,
    Action_EOY_RMSE = metrics$EOY_RMSE,
    Action_EOY_R2 = metrics$EOY_R2,
    AIC = ifelse(spec$method %in% c("lm", "gam"), AIC(fit), NA_real_),
    BIC = ifelse(spec$method %in% c("lm", "gam"), BIC(fit), NA_real_),
    Adj_R2 = ifelse(spec$method == "lm", summary(fit)$adj.r.squared, NA_real_),
    Parameters = spec$parameters,
    stringsAsFactors = FALSE
  )
}))

model_comparison <- merge(cv_summary, temporal_summary, by = c("Model", "Target", "Method", "Role"))
model_comparison <- merge(model_comparison, action_metrics, by = "Model")
model_comparison <- merge(model_comparison, spec_metadata, by = "Model")
model_comparison <- model_comparison[order(model_comparison$Temporal_RMSE), ]

selection_candidates <- model_comparison[
  model_comparison$SelectionEligible &
    model_comparison$Role == "Operational candidate" &
    model_comparison$Target == "Direct growth",
  ,
  drop = FALSE
]
best_temporal_rmse <- min(selection_candidates$Temporal_RMSE)
temporal_tolerance <- 0.01
selection_candidates <- selection_candidates[
  selection_candidates$Temporal_RMSE <= best_temporal_rmse + temporal_tolerance,
  ,
  drop = FALSE
]
selection_candidates <- selection_candidates[
  order(
    selection_candidates$CV_RMSE,
    selection_candidates$Temporal_RMSE,
    -selection_candidates$Temporal_R2
  ),
  ,
  drop = FALSE
]
selected_model_name <- selection_candidates$Model[1]

model_comparison$Selected <- model_comparison$Model == selected_model_name
model_comparison$Delta_Temporal_RMSE <- model_comparison$Temporal_RMSE -
  best_temporal_rmse
model_comparison <- model_comparison[
  order(model_comparison$Temporal_RMSE),
  c(
    "Model", "Selected", "Role", "Target", "Method", "Family",
    "Complexity", "TunedParameters", "SelectionEligible", "LeakageStatus",
    "Parameters", "CV_RMSE", "CV_RMSE_SD", "CV_MAE", "CV_R2", "CV_EOY_RMSE",
    "CV_EOY_R2", "Temporal_RMSE", "Temporal_RMSE_SD", "Temporal_MAE",
    "Temporal_R2", "Temporal_EOY_RMSE", "Temporal_EOY_R2",
    "Action_RMSE", "Action_MAE", "Action_R2", "Action_EOY_RMSE",
    "Action_EOY_R2", "Train_RMSE", "Train_MAE", "Train_R2",
    "Adj_R2", "AIC", "BIC", "Delta_Temporal_RMSE"
  )
]

selected_spec <- candidate_specs[[selected_model_name]]
selected_formula <- selected_spec$formula
final_model <- candidate_fits[[selected_model_name]]
action_predictions <- predict_expected_gain(final_model, selected_spec, action_data)
train_predictions <- predict_expected_gain(final_model, selected_spec, train_data)
action_final_metrics <- evaluate_expected_gain(action_data, action_predictions)
train_final_metrics <- evaluate_expected_gain(train_data, train_predictions)
model_bootstrap_validation <- bootstrap_model_validation(
  action_data,
  action_predictions,
  reps = 300
)

growth$expected_gain <- predict_expected_gain(final_model, selected_spec, growth)
growth$expected_eoy <- growth$boy_score + growth$expected_gain
growth$adjusted_growth_residual <- growth$score_gain - growth$expected_gain
train_scored <- growth[growth$school_year %in% training_years, , drop = FALSE]
action_scored <- growth[growth$school_year == action_year, , drop = FALSE]

section_split <- split(action_scored, action_scored$section_year_id)
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

teacher_split <- split(action_scored, action_scored$teacher_id)
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

course_split <- split(action_scored, action_scored$course_id)
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

latest_teacher_review <- make_latest_review(
  action_scored,
  group_vars = c("teacher_id"),
  level = "Teacher",
  min_n = 20
)
latest_course_review <- make_latest_review(
  action_scored,
  group_vars = c("course_id"),
  level = "Course",
  min_n = 20
)
latest_section_review <- make_latest_review(
  action_scored,
  group_vars = c("section_id", "teacher_id", "course_id"),
  level = "Section",
  min_n = 5
)

latest_teacher_review$DisplayTarget <- latest_teacher_review$teacher_id
latest_teacher_review$section_id <- ""
latest_teacher_review$course_id <- ""
latest_course_review$DisplayTarget <- latest_course_review$course_id
latest_course_review$section_id <- ""
latest_course_review$teacher_id <- ""
latest_section_review$DisplayTarget <- paste(
  latest_section_review$section_id,
  latest_section_review$course_id,
  latest_section_review$teacher_id,
  sep = " / "
)

target_cols <- c(
  "Level", "DisplayTarget", "section_id", "teacher_id", "course_id", "N",
  "RawGain", "ExpectedGain", "AdjustedGap", "ReliabilityWeight",
  "ReviewSignal", "CI_Lower", "CI_Upper", "P_Value", "Q_Value", "Decision"
)
review_targets <- rbind(
  latest_teacher_review[
    latest_teacher_review$Decision != "In range" &
      latest_teacher_review$Decision != "Insufficient sample",
    target_cols
  ],
  latest_course_review[
    latest_course_review$Decision != "In range" &
      latest_course_review$Decision != "Insufficient sample",
    target_cols
  ],
  latest_section_review[
    latest_section_review$Decision != "In range" &
      latest_section_review$Decision != "Insufficient sample",
    target_cols
  ]
)
if (nrow(review_targets) == 0) {
  review_targets <- rbind(
    head(latest_section_review[order(latest_section_review$ReviewSignal), target_cols], 3),
    head(latest_section_review[order(latest_section_review$ReviewSignal, decreasing = TRUE), target_cols], 3)
  )
}
decision_order <- c(
  "Intervention target" = 1,
  "Positive anomaly" = 2,
  "Watch list" = 3,
  "Insufficient sample" = 4,
  "In range" = 5
)
review_targets$DecisionOrder <- decision_order[review_targets$Decision]
review_targets$DecisionOrder[is.na(review_targets$DecisionOrder)] <- 9
intervention_targets <- review_targets[
  order(review_targets$DecisionOrder, review_targets$ReviewSignal),
]

recommended_follow_up <- function(level, decision, target) {
  if (decision == "Intervention target") {
    return(paste0("Review ", tolower(level), " ", target, " for support before the next cycle."))
  }
  if (decision == "Positive anomaly") {
    return(paste0("Study ", tolower(level), " ", target, " for transferable practices."))
  }
  paste0("Monitor ", tolower(level), " ", target, " and review context before escalation.")
}

future_priorities <- data.frame(
  Priority = intervention_targets$Decision,
  Target = intervention_targets$DisplayTarget,
  Mean_adjusted_gap = format_num(intervention_targets$AdjustedGap, 2),
  Review_signal = format_num(intervention_targets$ReviewSignal, 2),
  Evidence = paste0(
    intervention_targets$N,
    " latest-year paired records; 95% CI ",
    format_num(intervention_targets$CI_Lower, 2),
    " to ",
    format_num(intervention_targets$CI_Upper, 2),
    "; q=",
    format_p(intervention_targets$Q_Value),
    "."
  ),
  Recommended_follow_up = mapply(
    recommended_follow_up,
    intervention_targets$Level,
    intervention_targets$Decision,
    intervention_targets$DisplayTarget,
    USE.NAMES = FALSE
  ),
  stringsAsFactors = FALSE
)

historical_section_evidence <- data.frame(
  Priority = intervention_targets$Decision,
  Target = intervention_targets$DisplayTarget,
  Section = ifelse("section_id" %in% names(intervention_targets), intervention_targets$section_id, ""),
  Teacher = ifelse("teacher_id" %in% names(intervention_targets), intervention_targets$teacher_id, ""),
  Course = ifelse("course_id" %in% names(intervention_targets), intervention_targets$course_id, ""),
  Year = action_year,
  N = intervention_targets$N,
  Raw_gain = format_num(intervention_targets$RawGain, 2),
  Expected_gain = format_num(intervention_targets$ExpectedGain, 2),
  Adjusted_signal = format_num(intervention_targets$ReviewSignal, 2),
  stringsAsFactors = FALSE
)

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
    "Training paired records",
    "Latest-year paired records",
    "Latest-year section-year groups",
    "Latest-year groups with at least 5 paired records",
    "Latest-year groups with at least 8 paired records",
    "Latest-year mean raw BOY/EOY gain",
    "Latest-year raw-vs-adjusted rank correlation",
    "Latest-year top-10 overlap, raw vs adjusted ranking"
  ),
  Value = c(
    format(nrow(train_data), big.mark = ","),
    format(nrow(action_scored), big.mark = ","),
    format(nrow(section_summary), big.mark = ","),
    format(sum(section_summary$N >= 5), big.mark = ","),
    format(sum(section_summary$N >= 8), big.mark = ","),
    format_num(mean(action_scored$score_gain), 2),
    format_num(rank_correlation, 3),
    format_pct(top_overlap)
  ),
  stringsAsFactors = FALSE
)

diagnostics <- data.frame(
  Diagnostic = c(
    "Latest-year expected-gain RMSE",
    "Latest-year expected-gain MAE",
    "Latest-year expected-gain R-squared",
    "Latest-year EOY RMSE",
    "Latest-year EOY R-squared",
    "Latest-year residual mean",
    "Latest-year residual SD"
  ),
  Estimate = c(
    format_num(action_final_metrics$Gain_RMSE, 3),
    format_num(action_final_metrics$Gain_MAE, 3),
    format_num(action_final_metrics$Gain_R2, 3),
    format_num(action_final_metrics$EOY_RMSE, 3),
    format_num(action_final_metrics$EOY_R2, 3),
    format_num(mean(action_scored$adjusted_growth_residual), 3),
    format_num(sd(action_scored$adjusted_growth_residual), 3)
  ),
  Interpretation = c(
    "Typical out-of-sample prediction error on latest-year BOY/EOY gain",
    "Average absolute out-of-sample prediction error",
    "Share of latest-year gain variation explained by the expected-growth model",
    "Typical out-of-sample prediction error on latest-year EOY score",
    "Share of latest-year EOY score variation explained by the baseline",
    "Near 0 means expected gain is centered in the action year",
    "Latest-year residual spread used for slice uncertainty"
  ),
  stringsAsFactors = FALSE
)

model_comparison_display <- data.frame(
  Model = model_comparison$Model,
  Selected = ifelse(model_comparison$Selected, "Yes", ""),
  Role = model_comparison$Role,
  Target = model_comparison$Target,
  Method = model_comparison$Method,
  Family = model_comparison$Family,
  Complexity = model_comparison$Complexity,
  Tuned = model_comparison$TunedParameters,
  Eligible = ifelse(model_comparison$SelectionEligible, "Yes", "No"),
  Params = model_comparison$Parameters,
  CV_RMSE = format_num(model_comparison$CV_RMSE, 3),
  CV_SD = format_num(model_comparison$CV_RMSE_SD, 3),
  CV_MAE = format_num(model_comparison$CV_MAE, 3),
  CV_R2 = format_num(model_comparison$CV_R2, 3),
  CV_EOY_R2 = format_num(model_comparison$CV_EOY_R2, 3),
  Temporal_RMSE = format_num(model_comparison$Temporal_RMSE, 3),
  Temporal_SD = format_num(model_comparison$Temporal_RMSE_SD, 3),
  Temporal_R2 = format_num(model_comparison$Temporal_R2, 3),
  Temporal_EOY_R2 = format_num(model_comparison$Temporal_EOY_R2, 3),
  Action_RMSE = format_num(model_comparison$Action_RMSE, 3),
  Action_MAE = format_num(model_comparison$Action_MAE, 3),
  Action_R2 = format_num(model_comparison$Action_R2, 3),
  Action_EOY_R2 = format_num(model_comparison$Action_EOY_R2, 3),
  Train_R2 = format_num(model_comparison$Train_R2, 3),
  Adj_R2 = format_num(model_comparison$Adj_R2, 3),
  AIC = format_num(model_comparison$AIC, 1),
  BIC = format_num(model_comparison$BIC, 1),
  Delta = format_num(model_comparison$Delta_Temporal_RMSE, 3),
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
    "CV expected-gain RMSE",
    "CV expected-gain MAE",
    "CV expected-gain R-squared",
    "CV expected-gain RMSE SD",
    "CV EOY R-squared",
    "Temporal expected-gain RMSE",
    "Temporal expected-gain MAE",
    "Temporal expected-gain R-squared",
    "Temporal expected-gain RMSE SD",
    "Temporal EOY R-squared",
    "Latest-year expected-gain RMSE",
    "Latest-year expected-gain MAE",
    "Latest-year expected-gain R-squared",
    "Latest-year EOY RMSE",
    "Latest-year EOY R-squared",
    "Mean BOY score",
    "Mean EOY score",
    "Mean raw BOY/EOY gain",
    "Latest-year section groups"
  ),
  Value = c(
    selected_model_name,
    selected_comparison$Target,
    selected_comparison$Method,
    selected_comparison$Family,
    selected_comparison$TunedParameters,
    "Lowest repeated-CV RMSE among direct-growth candidates within 0.01 points of the best temporal-CV RMSE",
    format(nrow(train_data), big.mark = ","),
    format(nrow(action_data), big.mark = ","),
    paste(training_years, collapse = ", "),
    action_year,
    length(candidate_specs),
    sum(model_comparison$Role == "Operational candidate"),
    sum(model_comparison$Role != "Operational candidate"),
    cv_folds,
    cv_repeats,
    format_num(selected_comparison$CV_RMSE, 3),
    format_num(selected_comparison$CV_MAE, 3),
    format_num(selected_comparison$CV_R2, 3),
    format_num(selected_comparison$CV_RMSE_SD, 3),
    format_num(selected_comparison$CV_EOY_R2, 3),
    format_num(selected_comparison$Temporal_RMSE, 3),
    format_num(selected_comparison$Temporal_MAE, 3),
    format_num(selected_comparison$Temporal_R2, 3),
    format_num(selected_comparison$Temporal_RMSE_SD, 3),
    format_num(selected_comparison$Temporal_EOY_R2, 3),
    format_num(action_final_metrics$Gain_RMSE, 3),
    format_num(action_final_metrics$Gain_MAE, 3),
    format_num(action_final_metrics$Gain_R2, 3),
    format_num(action_final_metrics$EOY_RMSE, 3),
    format_num(action_final_metrics$EOY_R2, 3),
    format_num(mean(growth$boy_score), 1),
    format_num(mean(growth$eoy_score), 1),
    format_num(mean(growth$score_gain), 2),
    format(nrow(section_summary), big.mark = ",")
  ),
  stringsAsFactors = FALSE
)

family_review_spec <- data.frame(
  Family = c(
    "Direct growth linear baselines",
    "Direct growth polynomial terms",
    "Direct growth interaction surfaces",
    "GAM smooths",
    "Regression trees",
    "Random forests",
    "Gradient boosting",
    "Validation ensembles",
    "EOY-derived benchmarks",
    "Teacher/course ID leakage check"
  ),
  Pattern = c(
    "^Growth (linear benchmark|readiness model)$",
    "^Growth polynomial",
    "^Growth (interaction|cyclic)",
    "^Growth GAM",
    "^Growth regression tree",
    "^Growth random forest",
    "^Growth gradient boosting",
    "^Growth ensemble",
    "^EOY .*benchmark$",
    "Teacher/course leakage benchmark$"
  ),
  Why_tested = c(
    "Directly predicts BOY/EOY score gain from starting profile and context.",
    "Tests whether increasing parametric curvature improves validated growth prediction.",
    "Tests whether baseline score, readiness, track, attendance, and year effects vary together.",
    "Uses smooth nonlinear functions for baseline, readiness, attendance, and year effects.",
    "Tests simple non-parametric threshold rules.",
    "Tests a flexible non-parametric tree ensemble without teacher, course ID, or section ID effects.",
    "Tests boosted trees for nonlinear interactions without persistent ID effects.",
    "Tests whether averaging the best nonlinear and parametric growth shapes stabilizes future-year prediction.",
    "Predicts final EOY score first, then converts it to expected gain; benchmark only because growth is the business target.",
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
      Temporal_RMSE = "",
      Action_RMSE = "",
      stringsAsFactors = FALSE
    ))
  }
  if (any(rows$Selected)) {
    best_row <- rows[rows$Selected, , drop = FALSE][1, , drop = FALSE]
  } else {
    best_row <- rows[which.min(rows$Temporal_RMSE), , drop = FALSE]
  }
  decision <- if (best_row$Role == "Excluded leakage benchmark") {
    "Excluded from operating selection; persistent IDs would contaminate future review signals."
  } else if (any(rows$Selected)) {
    "Selected operating family."
  } else {
    "Compared; not selected by temporal expected-gain RMSE."
  }
  data.frame(
    Family = family_review_spec$Family[i],
    Representative_model = best_row$Model,
    Why_tested = family_review_spec$Why_tested[i],
    Decision = decision,
    Temporal_RMSE = format_num(best_row$Temporal_RMSE, 3),
    Action_RMSE = format_num(best_row$Action_RMSE, 3),
    stringsAsFactors = FALSE
  )
}))

model_search_grid <- data.frame(
  Model = model_comparison$Model,
  Selected = ifelse(model_comparison$Selected, "Yes", ""),
  Family = model_comparison$Family,
  Target = model_comparison$Target,
  Method = model_comparison$Method,
  Complexity = model_comparison$Complexity,
  Tuned_parameters = model_comparison$TunedParameters,
  Selection_eligible = model_comparison$SelectionEligible,
  Temporal_RMSE = format_num(model_comparison$Temporal_RMSE, 3),
  Delta_temporal_RMSE = format_num(model_comparison$Delta_Temporal_RMSE, 3),
  Temporal_MAE = format_num(model_comparison$Temporal_MAE, 3),
  Temporal_R2 = format_num(model_comparison$Temporal_R2, 3),
  CV_RMSE = format_num(model_comparison$CV_RMSE, 3),
  CV_RMSE_SD = format_num(model_comparison$CV_RMSE_SD, 3),
  CV_MAE = format_num(model_comparison$CV_MAE, 3),
  CV_R2 = format_num(model_comparison$CV_R2, 3),
  Latest_RMSE = format_num(model_comparison$Action_RMSE, 3),
  Latest_MAE = format_num(model_comparison$Action_MAE, 3),
  Latest_R2 = format_num(model_comparison$Action_R2, 3),
  Train_R2 = format_num(model_comparison$Train_R2, 3),
  Adjusted_R2 = format_num(model_comparison$Adj_R2, 3),
  AIC = format_num(model_comparison$AIC, 1),
  BIC = format_num(model_comparison$BIC, 1),
  Leakage_status = model_comparison$LeakageStatus,
  stringsAsFactors = FALSE
)

family_summary <- do.call(rbind, lapply(split(model_comparison, model_comparison$Family), function(rows) {
  best <- if (any(rows$Selected)) {
    rows[rows$Selected, , drop = FALSE][1, , drop = FALSE]
  } else {
    rows[which.min(rows$Temporal_RMSE), , drop = FALSE]
  }
  data.frame(
    Family = best$Family,
    Candidates = nrow(rows),
    Eligible_candidates = sum(rows$SelectionEligible),
    Best_model = best$Model,
    Selected_family = ifelse(any(rows$Selected), "Yes", ""),
    Best_temporal_RMSE = format_num(best$Temporal_RMSE, 3),
    Best_delta_RMSE = format_num(best$Delta_Temporal_RMSE, 3),
    Best_temporal_MAE = format_num(best$Temporal_MAE, 3),
    Best_temporal_R2 = format_num(best$Temporal_R2, 3),
    Best_latest_RMSE = format_num(best$Action_RMSE, 3),
    Best_latest_R2 = format_num(best$Action_R2, 3),
    Best_tuned_parameters = best$TunedParameters,
    stringsAsFactors = FALSE
  )
}))
family_summary <- family_summary[
  order(as.numeric(family_summary$Best_temporal_RMSE)),
  ,
  drop = FALSE
]

selection_rationale <- data.frame(
  Decision = c(
    "Primary target",
    "Primary validation metric",
    "Stability tie-breaker",
    "Selected operating model",
    "Selected family",
    "Selected tuned parameters",
    "Temporal CV RMSE",
    "Temporal CV MAE",
    "Temporal CV R-squared",
    "Repeated-CV RMSE SD",
    "Latest-year RMSE",
    "Latest-year MAE",
    "Latest-year R-squared",
    "EOY R-squared role",
    "Leakage rule"
  ),
  Rationale = c(
    "Directly predict BOY/EOY score gain because growth is the performance metric used to evaluate actual class outcomes.",
    "Leave-one-year-out temporal-CV RMSE tests whether prior years generalize to a future year.",
    "When candidates are within 0.01 points of the best temporal-CV RMSE, repeated-CV RMSE chooses the more stable baseline without looking at the latest action year.",
    selected_model_name,
    selected_comparison$Family,
    selected_comparison$TunedParameters,
    format_num(selected_comparison$Temporal_RMSE, 3),
    format_num(selected_comparison$Temporal_MAE, 3),
    format_num(selected_comparison$Temporal_R2, 3),
    format_num(selected_comparison$CV_RMSE_SD, 3),
    format_num(action_final_metrics$Gain_RMSE, 3),
    format_num(action_final_metrics$Gain_MAE, 3),
    format_num(action_final_metrics$Gain_R2, 3),
    "Reported as secondary context only; EOY is easier to predict because BOY score mechanically explains much of final score.",
    "Teacher, course, and section IDs are excluded from the operating baseline because they are review targets, not neutral adjustment fields."
  ),
  stringsAsFactors = FALSE
)

write.csv(model_comparison, file.path("reports", "growth_model_comparison.csv"), row.names = FALSE)
write.csv(model_comparison_display, file.path("reports", "growth_model_comparison_display.csv"), row.names = FALSE)
write.csv(model_search_grid, file.path("reports", "growth_model_search_grid.csv"), row.names = FALSE)
write.csv(family_summary, file.path("reports", "growth_model_family_summary.csv"), row.names = FALSE)
write.csv(selection_rationale, file.path("reports", "growth_model_selection_rationale.csv"), row.names = FALSE)
write.csv(final_metrics, file.path("reports", "growth_final_metrics.csv"), row.names = FALSE)
write.csv(shape_review, file.path("reports", "growth_shape_review.csv"), row.names = FALSE)
write.csv(dependency_status, file.path("reports", "model_dependency_status.csv"), row.names = FALSE)
write.csv(temporal_summary, file.path("reports", "model_temporal_validation.csv"), row.names = FALSE)
write.csv(model_bootstrap_validation, file.path("reports", "model_bootstrap_validation.csv"), row.names = FALSE)
write.csv(section_ttests_display, file.path("reports", "section_ttests.csv"), row.names = FALSE)
write.csv(section_signals_display, file.path("reports", "section_adjusted_signals.csv"), row.names = FALSE)
write.csv(section_highlights_display, file.path("reports", "section_signal_highlights.csv"), row.names = FALSE)
write.csv(teacher_display, file.path("reports", "teacher_growth_summary.csv"), row.names = FALSE)
write.csv(course_display, file.path("reports", "course_growth_summary.csv"), row.names = FALSE)
write.csv(future_priorities, file.path("reports", "future_review_priorities.csv"), row.names = FALSE)
write.csv(historical_section_evidence, file.path("reports", "historical_section_evidence.csv"), row.names = FALSE)
write.csv(format_review_table(latest_teacher_review, c("teacher_id")), file.path("reports", "latest_teacher_review.csv"), row.names = FALSE)
write.csv(format_review_table(latest_course_review, c("course_id")), file.path("reports", "latest_course_review.csv"), row.names = FALSE)
write.csv(format_review_table(latest_section_review, c("section_id", "teacher_id", "course_id")), file.path("reports", "latest_section_review.csv"), row.names = FALSE)
write.csv(format_review_table(intervention_targets, c("section_id", "teacher_id", "course_id")), file.path("reports", "intervention_targets.csv"), row.names = FALSE)
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
    model_search_grid = model_search_grid,
    family_summary = family_summary,
    selection_rationale = selection_rationale,
    section_summary = section_summary,
    teacher_summary = teacher_summary,
    course_summary = course_summary,
    future_priorities = future_priorities,
    historical_section_evidence = historical_section_evidence,
    temporal_summary = temporal_summary,
    model_bootstrap_validation = model_bootstrap_validation,
    latest_teacher_review = latest_teacher_review,
    latest_course_review = latest_course_review,
    latest_section_review = latest_section_review,
    intervention_targets = intervention_targets,
    growth = growth,
    training_years = training_years,
    action_year = action_year,
    train_rows = nrow(train_data),
    action_rows = nrow(action_data)
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
  "Growth readiness model",
  "Growth polynomial degree 3",
  "Growth interaction model",
  "Growth GAM k8",
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
ordered_models <- model_comparison[order(model_comparison$Temporal_RMSE, decreasing = TRUE), ]
y_pos <- seq_len(nrow(ordered_models))
x_min <- min(ordered_models$Temporal_RMSE - ordered_models$Temporal_RMSE_SD) - 0.05
x_max <- max(ordered_models$Temporal_RMSE + ordered_models$Temporal_RMSE_SD) + 0.05
par(mar = c(5, 15, 4, 2))
plot(
  ordered_models$Temporal_RMSE,
  y_pos,
  xlim = c(x_min, x_max),
  yaxt = "n",
  xlab = "Leave-one-year-out RMSE",
  ylab = "",
  pch = 19,
  col = ifelse(ordered_models$Selected, "#1B6CA8", "#555555"),
  main = "Expected-Growth Model Comparison"
)
segments(
  ordered_models$Temporal_RMSE - ordered_models$Temporal_RMSE_SD,
  y_pos,
  ordered_models$Temporal_RMSE + ordered_models$Temporal_RMSE_SD,
  y_pos,
  col = "#888888"
)
axis(2, at = y_pos, labels = ordered_models$Model, las = 1)
abline(v = selected_comparison$Temporal_RMSE, lty = 2, col = "#8C2D19")
legend(
  "bottomright",
  legend = c("Selected model", "Other candidate", "Selected temporal RMSE"),
  pch = c(19, 19, NA),
  lty = c(NA, NA, 2),
  col = c("#1B6CA8", "#555555", "#8C2D19"),
  bty = "n"
)
dev.off()

png(file.path("figures", "growth_model_search.png"), width = 1300, height = 700, res = 150)
par(mfrow = c(1, 2), mar = c(5, 12, 4, 2))
family_plot <- family_summary[order(as.numeric(family_summary$Best_temporal_RMSE), decreasing = TRUE), ]
family_rmse <- as.numeric(family_plot$Best_temporal_RMSE)
family_r2 <- as.numeric(family_plot$Best_temporal_R2)
family_cols <- ifelse(family_plot$Selected_family == "Yes", "#1B6CA8", "#555555")
family_y <- seq_len(nrow(family_plot))
plot(
  family_rmse,
  family_y,
  xlim = range(family_rmse) + c(-0.015, 0.015),
  yaxt = "n",
  pch = 19,
  cex = 1.2,
  col = family_cols,
  xlab = "Temporal-CV RMSE",
  ylab = "",
  main = "Best Candidate by Family"
)
segments(min(family_rmse) - 0.015, family_y, family_rmse, family_y, col = "#D0D0D0")
axis(2, at = family_y, labels = family_plot$Family, las = 1, cex.axis = 0.85)
abline(v = as.numeric(selected_comparison$Temporal_RMSE), lty = 2, col = "#8C2D19", lwd = 1.5)
grid(col = "#E0E0E0")

eligible_plot <- model_comparison[
  model_comparison$SelectionEligible & model_comparison$Target == "Direct growth",
  ,
  drop = FALSE
]
eligible_plot <- eligible_plot[order(eligible_plot$Temporal_RMSE), , drop = FALSE]
eligible_plot <- head(eligible_plot, 12)
eligible_plot <- eligible_plot[order(eligible_plot$Temporal_R2), , drop = FALSE]
model_label <- function(model_name) {
  labels <- c(
    "Growth ensemble nonlinear weighted" = "Ensemble weighted",
    "Growth ensemble balanced" = "Ensemble balanced",
    "Growth gradient boosting 1" = "GBM 1",
    "Growth gradient boosting 2" = "GBM 2",
    "Growth GAM k4" = "GAM k4",
    "Growth GAM k8" = "GAM k8",
    "Growth polynomial degree 3" = "Polynomial d3",
    "Growth polynomial degree 2" = "Polynomial d2",
    "Growth readiness model" = "Readiness LM",
    "Growth linear benchmark" = "Linear LM",
    "Growth interaction model" = "Interaction LM",
    "Growth random forest 1" = "Random forest 1"
  )
  ifelse(model_name %in% names(labels), labels[model_name], model_name)
}
par(mar = c(5, 11, 4, 2))
y_pos <- seq_len(nrow(eligible_plot))
plot(
  eligible_plot$Temporal_R2,
  y_pos,
  type = "p",
  pch = 19,
  col = "#1B6CA8",
  yaxt = "n",
  xlab = "Temporal-CV growth R-squared",
  ylab = "",
  main = "Top Growth Models"
)
segments(0, y_pos, eligible_plot$Temporal_R2, y_pos, col = "#D0D0D0")
axis(
  2,
  at = y_pos,
  labels = model_label(eligible_plot$Model),
  las = 1,
  cex.axis = 0.85
)
grid(col = "#E0E0E0")
points(
  eligible_plot$Temporal_R2[eligible_plot$Selected],
  y_pos[eligible_plot$Selected],
  pch = 19,
  cex = 1.5,
  col = "#8C2D19"
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
  action_predictions,
  action_data$score_gain,
  pch = 19,
  col = "#1B6CA880",
  xlab = "Predicted BOY/EOY gain",
  ylab = "Observed BOY/EOY gain",
  main = "Latest-Year Predictions"
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
