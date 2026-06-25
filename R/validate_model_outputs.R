required_files <- c(
  file.path("reports", "growth_model_comparison.csv"),
  file.path("reports", "growth_model_strength.csv"),
  file.path("reports", "growth_model_search_grid.csv"),
  file.path("reports", "shrinkage_status.csv"),
  file.path("reports", "shrinkage_review.csv"),
  file.path("reports", "rolling_origin_validation.csv"),
  file.path("reports", "process_validation.csv"),
  file.path("reports", "locked_holdout_validation.csv"),
  file.path("reports", "model_validity_targets.csv"),
  file.path("reports", "feature_importance.csv"),
  file.path("reports", "feature_stability.csv"),
  file.path("reports", "flag_stability.csv"),
  file.path("reports", "null_permutation_benchmark.csv"),
  file.path("reports", "model_signal_ceiling.csv"),
  file.path("reports", "model_artifacts.rds")
)

missing_files <- required_files[!file.exists(required_files)]
errors <- character()

if (length(missing_files) > 0) {
  errors <- c(errors, paste("Missing model artifact(s):", paste(missing_files, collapse = ", ")))
} else {
  comparison <- read.csv(file.path("reports", "growth_model_comparison.csv"), stringsAsFactors = FALSE)
  strength <- read.csv(file.path("reports", "growth_model_strength.csv"), stringsAsFactors = FALSE)
  targets <- read.csv(file.path("reports", "model_validity_targets.csv"), stringsAsFactors = FALSE)
  artifacts <- readRDS(file.path("reports", "model_artifacts.rds"))

  selected <- comparison[comparison$Selected, , drop = FALSE]
  naive <- comparison[comparison$Model == "Naive prior-year mean growth", , drop = FALSE]

  if (nrow(selected) != 1) {
    errors <- c(errors, "Expected exactly one selected model.")
  }
  if (nrow(naive) != 1) {
    errors <- c(errors, "Expected exactly one naive mean-growth benchmark.")
  }

  if (nrow(selected) == 1 && nrow(naive) == 1) {
    if (selected$Temporal_RMSE >= naive$Temporal_RMSE) {
      errors <- c(errors, "Selected model does not beat naive benchmark on temporal RMSE.")
    }
    if (selected$Temporal_MAE >= naive$Temporal_MAE) {
      errors <- c(errors, "Selected model does not beat naive benchmark on temporal MAE.")
    }
    if (selected$Action_RMSE >= naive$Action_RMSE) {
      errors <- c(errors, "Selected model does not beat naive benchmark on latest-year RMSE.")
    }
  }

  expected_strength <- c(
    "Temporal RMSE improvement percent",
    "Latest-year RMSE improvement percent",
    "Latest-year MAE improvement percent"
  )
  missing_strength <- setdiff(expected_strength, strength$Measure)
  if (length(missing_strength) > 0) {
    errors <- c(errors, paste("Missing model-strength row(s):", paste(missing_strength, collapse = ", ")))
  }

  collect_spec_formulas <- function(spec) {
    formulas <- list(spec$formula)
    if (spec$method %in% c("ensemble", "stacked")) {
      member_formulas <- do.call(c, lapply(spec$fit_args$members, collect_spec_formulas))
      formulas <- c(formulas, member_formulas)
    }
    formulas
  }

  rhs_text <- function(formula) {
    formula_text <- paste(deparse(formula), collapse = " ")
    sub("^[^~]+~", "", formula_text)
  }

  formula_text <- paste(vapply(
    collect_spec_formulas(artifacts$selected_spec),
    rhs_text,
    character(1)
  ), collapse = " ")
  forbidden_ids <- c("teacher_id", "course_id", "section_id")
  leaked_ids <- forbidden_ids[vapply(forbidden_ids, grepl, logical(1), x = formula_text, fixed = TRUE)]
  if (length(leaked_ids) > 0) {
    errors <- c(errors, paste("Selected operating formula includes review ID(s):", paste(leaked_ids, collapse = ", ")))
  }

  forbidden_same_year_outcomes <- c("eoy_score", "score_gain", "readiness_gain", "adjusted_growth_residual")
  leaked_outcomes <- forbidden_same_year_outcomes[
    vapply(
      forbidden_same_year_outcomes,
      function(field) grepl(paste0("\\b", field, "\\b"), formula_text, perl = TRUE),
      logical(1)
    )
  ]
  if (length(leaked_outcomes) > 0) {
    errors <- c(errors, paste("Selected operating formula includes same-year outcome field(s):", paste(leaked_outcomes, collapse = ", ")))
  }

  if (!isTRUE(artifacts$selected_spec$selection_eligible)) {
    errors <- c(errors, "Selected model is not marked selection eligible.")
  }

  required_target_rows <- c(
    "Rolling RMSE lift vs naive",
    "Rolling MAE lift vs naive",
    "Temporal gain R-squared",
    "Section mean gain R-squared",
    "Overall residual bias"
  )
  missing_target_rows <- setdiff(required_target_rows, targets$Metric)
  if (length(missing_target_rows) > 0) {
    errors <- c(errors, paste("Missing validity target row(s):", paste(missing_target_rows, collapse = ", ")))
  }
}

if (length(errors) > 0) {
  message("Model-output validation failed.")
  for (error in errors) {
    message("- ", error)
  }
  quit(status = 1)
}

message("Model-output validation passed.")
