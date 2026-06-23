ensure_project_dirs <- function() {
  dirs <- c("data/processed", "reports", "figures")
  for (dir in dirs) {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE)
    }
  }
}

clip_probability <- function(p, eps = 1e-15) {
  pmin(pmax(as.numeric(p), eps), 1 - eps)
}

log_loss <- function(y, p) {
  y <- as.integer(y)
  p <- clip_probability(p)
  -mean(y * log(p) + (1 - y) * log(1 - p))
}

brier_score <- function(y, p) {
  y <- as.integer(y)
  mean((y - as.numeric(p))^2)
}

auc_score <- function(y, p) {
  y <- as.integer(y)
  p <- as.numeric(p)
  n_pos <- sum(y == 1)
  n_neg <- sum(y == 0)
  if (n_pos == 0 || n_neg == 0) {
    return(NA_real_)
  }
  ranks <- rank(p, ties.method = "average")
  (sum(ranks[y == 1]) - n_pos * (n_pos + 1) / 2) / (n_pos * n_neg)
}

format_num <- function(x, digits = 3) {
  ifelse(
    is.na(x),
    "",
    formatC(as.numeric(x), digits = digits, format = "f")
  )
}

format_pct <- function(x, digits = 1) {
  ifelse(
    is.na(x),
    "",
    paste0(formatC(100 * as.numeric(x), digits = digits, format = "f"), "%")
  )
}

format_p <- function(p) {
  ifelse(
    is.na(p),
    "",
    ifelse(p < 0.001, "<0.001", formatC(p, digits = 3, format = "f"))
  )
}

markdown_table <- function(df) {
  if (nrow(df) == 0) {
    return("")
  }
  df[] <- lapply(df, as.character)
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  divider <- paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |")
  rows <- apply(df, 1, function(row) {
    row <- gsub("\\|", "/", row)
    paste0("| ", paste(row, collapse = " | "), " |")
  })
  paste(c(header, divider, rows), collapse = "\n")
}

make_stratified_folds <- function(y, k) {
  y <- as.integer(y)
  folds <- integer(length(y))
  for (class_value in sort(unique(y))) {
    idx <- sample(which(y == class_value))
    folds[idx] <- rep(seq_len(k), length.out = length(idx))
  }
  folds
}

make_stratified_split <- function(y, train_prop = 0.8, seed = 20260623) {
  set.seed(seed)
  y <- as.integer(y)
  train_idx <- integer()
  for (class_value in sort(unique(y))) {
    idx <- sample(which(y == class_value))
    n_train <- floor(length(idx) * train_prop)
    train_idx <- c(train_idx, idx[seq_len(n_train)])
  }
  sort(train_idx)
}

safe_predict_glm <- function(model, newdata) {
  as.numeric(predict(model, newdata = newdata, type = "response"))
}

evaluate_predictions <- function(y, p) {
  data.frame(
    LogLoss = log_loss(y, p),
    Brier = brier_score(y, p),
    AUC = auc_score(y, p),
    stringsAsFactors = FALSE
  )
}

bootstrap_metric_ci <- function(y, p, reps = 500, seed = 20260623) {
  set.seed(seed)
  n <- length(y)
  rows <- replicate(reps, {
    idx <- sample(seq_len(n), size = n, replace = TRUE)
    c(
      LogLoss = log_loss(y[idx], p[idx]),
      Brier = brier_score(y[idx], p[idx]),
      AUC = auc_score(y[idx], p[idx])
    )
  })
  rows <- t(rows)
  data.frame(
    Metric = colnames(rows),
    Estimate = c(log_loss(y, p), brier_score(y, p), auc_score(y, p)),
    CI_Lower = apply(rows, 2, quantile, probs = 0.025, na.rm = TRUE),
    CI_Upper = apply(rows, 2, quantile, probs = 0.975, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}

make_calibration_diagnostics <- function(y, p) {
  y <- as.integer(y)
  clipped <- clip_probability(p)
  logit_p <- qlogis(clipped)
  intercept_model <- suppressWarnings(glm(y ~ offset(logit_p), family = binomial()))
  slope_model <- suppressWarnings(glm(y ~ logit_p, family = binomial()))
  data.frame(
    Diagnostic = c("Calibration intercept", "Calibration slope"),
    Estimate = c(coef(intercept_model)[["(Intercept)"]], coef(slope_model)[["logit_p"]]),
    Interpretation = c(
      "Near 0 means predicted risk is not systematically high or low",
      "Near 1 means predicted probabilities are not overly extreme or compressed"
    ),
    stringsAsFactors = FALSE
  )
}

run_repeated_cv <- function(data, formulas, outcome, k = 5, repeats = 5,
                            seed = 20260623) {
  results <- list()
  counter <- 1
  set.seed(seed)

  for (repeat_id in seq_len(repeats)) {
    folds <- make_stratified_folds(data[[outcome]], k)
    for (model_name in names(formulas)) {
      predictions <- rep(NA_real_, nrow(data))
      for (fold_id in seq_len(k)) {
        train_data <- data[folds != fold_id, , drop = FALSE]
        test_data <- data[folds == fold_id, , drop = FALSE]
        fit <- suppressWarnings(glm(formulas[[model_name]],
          data = train_data,
          family = binomial()
        ))
        predictions[folds == fold_id] <- safe_predict_glm(fit, test_data)
      }
      metrics <- evaluate_predictions(data[[outcome]], predictions)
      results[[counter]] <- data.frame(
        Model = model_name,
        Repeat = repeat_id,
        LogLoss = metrics$LogLoss,
        Brier = metrics$Brier,
        AUC = metrics$AUC,
        stringsAsFactors = FALSE
      )
      counter <- counter + 1
    }
  }

  do.call(rbind, results)
}

summarize_cv <- function(cv_results) {
  means <- aggregate(cbind(LogLoss, Brier, AUC) ~ Model, cv_results, mean)
  sds <- aggregate(cbind(LogLoss, Brier, AUC) ~ Model, cv_results, sd)
  names(means) <- c("Model", "CV_LogLoss", "CV_Brier", "CV_AUC")
  names(sds) <- c("Model", "CV_LogLoss_SD", "CV_Brier_SD", "CV_AUC_SD")
  summary <- merge(means, sds, by = "Model")
  summary[order(summary$CV_LogLoss), ]
}

count_model_parameters <- function(model) {
  length(coef(model))
}

make_odds_ratio_table <- function(model, scale_map = NULL, label_map = NULL) {
  coefficient_table <- coef(summary(model))
  terms <- rownames(coefficient_table)
  terms <- terms[terms != "(Intercept)"]

  rows <- lapply(terms, function(term) {
    scale <- 1
    if (!is.null(scale_map) && term %in% names(scale_map)) {
      scale <- scale_map[[term]]
    }
    label <- term
    if (!is.null(label_map) && term %in% names(label_map)) {
      label <- label_map[[term]]
    }
    estimate <- coefficient_table[term, "Estimate"]
    std_error <- coefficient_table[term, "Std. Error"]
    data.frame(
      Predictor = label,
      Scale = ifelse(scale == 1, "1-unit / level change", paste0(scale, "-unit change")),
      OddsRatio = exp(estimate * scale),
      CI_Lower = exp((estimate - 1.96 * std_error) * scale),
      CI_Upper = exp((estimate + 1.96 * std_error) * scale),
      P_Value = coefficient_table[term, "Pr(>|z|)"],
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

make_roc_curve <- function(y, p) {
  y <- as.integer(y)
  p <- as.numeric(p)
  thresholds <- sort(unique(c(Inf, p, -Inf)), decreasing = TRUE)
  rows <- lapply(thresholds, function(threshold) {
    flagged <- p >= threshold
    tp <- sum(flagged & y == 1)
    fp <- sum(flagged & y == 0)
    tn <- sum(!flagged & y == 0)
    fn <- sum(!flagged & y == 1)
    data.frame(
      threshold = threshold,
      sensitivity = ifelse(tp + fn == 0, NA_real_, tp / (tp + fn)),
      specificity = ifelse(tn + fp == 0, NA_real_, tn / (tn + fp)),
      stringsAsFactors = FALSE
    )
  })
  roc <- do.call(rbind, rows)
  roc$fpr <- 1 - roc$specificity
  roc
}

make_calibration_table <- function(y, p, bins = 10) {
  y <- as.integer(y)
  p <- as.numeric(p)
  groups <- cut(rank(p, ties.method = "first"),
    breaks = seq(0, length(p), length.out = bins + 1),
    include.lowest = TRUE,
    labels = seq_len(bins)
  )
  rows <- lapply(levels(groups), function(group_id) {
    idx <- which(groups == group_id)
    data.frame(
      RiskBand = paste0("Band ", group_id),
      N = length(idx),
      MeanPredicted = mean(p[idx]),
      ObservedRate = mean(y[idx]),
      ExpectedEvents = sum(p[idx]),
      ObservedEvents = sum(y[idx]),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

make_threshold_table <- function(y, p, thresholds = c(0.10, 0.15, 0.20, 0.25, 0.30, 0.35)) {
  y <- as.integer(y)
  p <- as.numeric(p)
  n <- length(y)
  total_events <- sum(y == 1)

  rows <- lapply(thresholds, function(threshold) {
    flagged <- p >= threshold
    tp <- sum(flagged & y == 1)
    fp <- sum(flagged & y == 0)
    tn <- sum(!flagged & y == 0)
    fn <- sum(!flagged & y == 1)
    data.frame(
      Threshold = threshold,
      Flagged = sum(flagged),
      FlaggedRate = sum(flagged) / n,
      EventsCaptured = tp,
      TotalEvents = total_events,
      Sensitivity = ifelse(tp + fn == 0, NA_real_, tp / (tp + fn)),
      Specificity = ifelse(tn + fp == 0, NA_real_, tn / (tn + fp)),
      PPV = ifelse(tp + fp == 0, NA_real_, tp / (tp + fp)),
      NPV = ifelse(tn + fn == 0, NA_real_, tn / (tn + fn)),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

make_decile_lift_table <- function(y, p, groups = 10) {
  y <- as.integer(y)
  p <- as.numeric(p)
  ordered_idx <- order(p, decreasing = TRUE)
  group_id <- as.integer(cut(
    seq_along(ordered_idx),
    breaks = seq(0, length(y), length.out = groups + 1),
    include.lowest = TRUE,
    labels = seq_len(groups)
  ))
  assigned_group <- integer(length(y))
  assigned_group[ordered_idx] <- group_id
  base_rate <- mean(y)
  total_events <- sum(y)

  rows <- lapply(seq_len(groups), function(group) {
    idx <- assigned_group == group
    data.frame(
      Decile = group,
      N = sum(idx),
      MeanPredicted = mean(p[idx]),
      ObservedRate = mean(y[idx]),
      Events = sum(y[idx]),
      Lift = mean(y[idx]) / base_rate,
      stringsAsFactors = FALSE
    )
  })

  lift <- do.call(rbind, rows)
  lift$CumulativeEvents <- cumsum(lift$Events)
  lift$CumulativeCapture <- lift$CumulativeEvents / total_events
  lift
}

make_decision_economics <- function(threshold_table, review_cost = 750,
                                    escalation_cost = 12000,
                                    intervention_effect = 0.55) {
  avoided_loss <- threshold_table$EventsCaptured * escalation_cost * intervention_effect
  review_cost_total <- threshold_table$Flagged * review_cost
  data.frame(
    Threshold = threshold_table$Threshold,
    Flagged = threshold_table$Flagged,
    EventsCaptured = threshold_table$EventsCaptured,
    AvoidedLoss = avoided_loss,
    ReviewCost = review_cost_total,
    NetValue = avoided_loss - review_cost_total,
    stringsAsFactors = FALSE
  )
}

make_subgroup_calibration <- function(data, group_var, y, p) {
  group_values <- sort(unique(as.character(data[[group_var]])))
  rows <- lapply(group_values, function(group_value) {
    idx <- which(as.character(data[[group_var]]) == group_value)
    data.frame(
      Subgroup = group_var,
      Level = group_value,
      N = length(idx),
      MeanPredicted = mean(p[idx]),
      ObservedRate = mean(y[idx]),
      CalibrationGap = mean(y[idx]) - mean(p[idx]),
      ObservedEvents = sum(y[idx]),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

risk_category <- function(p) {
  cut(p,
    breaks = c(-Inf, 0.10, 0.20, 0.35, Inf),
    labels = c("Monitor", "Watch", "Review", "Priority"),
    right = FALSE
  )
}

predict_probability_ci <- function(model, newdata, level = 0.95) {
  pred <- predict(model, newdata = newdata, type = "link", se.fit = TRUE)
  z <- qnorm(1 - (1 - level) / 2)
  fit <- as.numeric(pred$fit)
  se <- as.numeric(pred$se.fit)
  data.frame(
    PredictedRisk = plogis(fit),
    Lower = plogis(fit - z * se),
    Upper = plogis(fit + z * se),
    stringsAsFactors = FALSE
  )
}
