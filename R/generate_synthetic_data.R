source(file.path("R", "model_utils.R"))

ensure_project_dirs()

raw_path <- file.path("data", "raw", "synthetic_education_assessment_long.csv")
sibling_source <- file.path(
  "..",
  "education-data-simulation-engine",
  "data",
  "marts",
  "student_assessment_long.csv"
)

if (!file.exists(raw_path) && file.exists(sibling_source)) {
  file.copy(sibling_source, raw_path, overwrite = TRUE)
}

if (!file.exists(raw_path)) {
  set.seed(20260623)
  n_students <- 700
  student_id <- sprintf("SYN-SIS-%06d", seq_len(n_students))
  student_profile <- data.frame(
    sis_user_id = student_id,
    grade_level = sample(9:12, n_students, replace = TRUE),
    attendance_category = sample(
      c("normal", "high", "at_risk"),
      n_students,
      replace = TRUE,
      prob = c(0.62, 0.24, 0.14)
    ),
    base_readiness = pmin(pmax(rnorm(n_students, 53, 15), 12), 96),
    stringsAsFactors = FALSE
  )
  student_profile$attendance_probability <- ifelse(
    student_profile$attendance_category == "normal",
    runif(n_students, 0.90, 0.99),
    ifelse(
      student_profile$attendance_category == "high",
      runif(n_students, 0.78, 0.92),
      runif(n_students, 0.58, 0.80)
    )
  )

  course_tracks <- c("regular", "honors", "ap", "beyond_core")
  rows <- list()
  counter <- 1
  for (sequence_index in seq_len(14)) {
    window <- ifelse(sequence_index %% 2 == 1, "beginning_of_year", "end_of_year")
    school_year_offset <- floor((sequence_index - 1) / 2)
    for (student_row in seq_len(n_students)) {
      track <- sample(course_tracks, 1, prob = c(0.48, 0.23, 0.24, 0.05))
      seasonal_gain <- ifelse(window == "end_of_year", 5.5, 0)
      time_drift <- -0.6 * school_year_offset + 0.35 * pmax(school_year_offset - 4, 0)
      track_effect <- c(regular = -2.5, honors = 3.5, ap = 5.5, beyond_core = -1.0)[[track]]
      attendance_effect <- c(normal = 4.5, high = -1.5, at_risk = -7.5)[[
        student_profile$attendance_category[student_row]
      ]]
      present <- runif(1) <= student_profile$attendance_probability[student_row]
      latent <- student_profile$base_readiness[student_row] +
        seasonal_gain + time_drift + track_effect + attendance_effect +
        4 * sin(2 * pi * sequence_index / 4) + rnorm(1, 0, 5)
      score <- ifelse(present, pmin(pmax(latent + rnorm(1, 0, 3), 0), 100), 0)
      posterior <- ifelse(present, pmin(pmax(0.65 * latent + 0.35 * score, 0), 100), NA_real_)
      rows[[counter]] <- data.frame(
        school_year = paste0(2025 + school_year_offset, "-", 2026 + school_year_offset),
        school_year_offset = school_year_offset,
        sis_user_id = student_profile$sis_user_id[student_row],
        student_label = paste("Synthetic Student", student_row),
        grade_level = student_profile$grade_level[student_row],
        course_id = paste0("MATH-", toupper(track)),
        course_name = paste(tools::toTitleCase(gsub("_", " ", track)), "Math"),
        course_track = track,
        section_id = paste0("SEC-", sprintf("%03d", sample(1:48, 1))),
        section_label = paste("Section", sample(1:48, 1)),
        teacher_id = paste0("T-", sprintf("%03d", sample(1:24, 1))),
        teacher_label = paste("Synthetic Teacher", sample(1:24, 1)),
        assignment_label = paste(window, sequence_index),
        sequence_index = sequence_index,
        assessment_window = window,
        expected_transition_type = "synthetic",
        actual_transition_type = "synthetic",
        generation_mode = "fallback_simulation",
        population_status = "synthetic",
        attendance_category = student_profile$attendance_category[student_row],
        attendance_probability = student_profile$attendance_probability[student_row],
        score = round(score, 2),
        present_student_score = ifelse(present, round(score, 2), NA_real_),
        potential_score = round(pmin(pmax(latent, 0), 100), 2),
        posterior_readiness_after = round(posterior, 4),
        growth_delta = NA_real_,
        latent_transition_type = "synthetic",
        latent_readiness_before = NA_real_,
        latent_readiness_after = NA_real_,
        latent_transition_delta = NA_real_,
        academic_profile_status = "synthetic",
        is_populated = "true",
        is_present = ifelse(present, "true", "false"),
        is_nonparticipation_zero = ifelse(present, "false", "true"),
        stringsAsFactors = FALSE
      )
      counter <- counter + 1
    }
  }
  write.csv(do.call(rbind, rows), raw_path, row.names = FALSE)
}

assessment <- read.csv(raw_path, stringsAsFactors = FALSE)
assessment <- assessment[order(assessment$sis_user_id, assessment$sequence_index), ]
assessment$is_present_bool <- tolower(as.character(assessment$is_present)) == "true"

n_rows <- nrow(assessment)
next_same_student <- c(
  assessment$sis_user_id[-1] == assessment$sis_user_id[-n_rows],
  FALSE
)

assessment$next_sequence_index <- ifelse(
  next_same_student,
  c(assessment$sequence_index[-1], NA),
  NA
)
assessment$next_assessment_window <- ifelse(
  next_same_student,
  c(assessment$assessment_window[-1], NA),
  NA
)
assessment$next_score <- ifelse(
  next_same_student,
  c(assessment$score[-1], NA),
  NA
)
assessment$next_present <- ifelse(
  next_same_student,
  c(assessment$is_present_bool[-1], NA),
  NA
)
assessment$next_readiness <- ifelse(
  next_same_student,
  c(assessment$posterior_readiness_after[-1], NA),
  NA
)

risk_data <- assessment[
  !is.na(assessment$next_score) & !is.na(assessment$next_present),
  c(
    "school_year", "school_year_offset", "sis_user_id", "grade_level",
    "course_id", "course_name", "course_track", "section_id",
    "assessment_window", "sequence_index", "attendance_category",
    "attendance_probability", "score", "posterior_readiness_after",
    "is_present_bool", "next_sequence_index", "next_assessment_window",
    "next_score", "next_present", "next_readiness"
  )
]

risk_data$support_risk_next <- as.integer(
  risk_data$next_score < 50 | !risk_data$next_present
)
risk_data$support_risk_next_45 <- as.integer(
  risk_data$next_score < 45 | !risk_data$next_present
)
risk_data$current_absent <- as.integer(!risk_data$is_present_bool)
risk_data$current_readiness_missing <- as.integer(
  is.na(risk_data$posterior_readiness_after)
)
risk_data$current_readiness <- risk_data$posterior_readiness_after

median_source <- risk_data[!is.na(risk_data$current_readiness), ]
group_medians <- aggregate(
  current_readiness ~ grade_level + course_track + assessment_window,
  data = median_source,
  FUN = median
)
overall_median <- median(risk_data$current_readiness, na.rm = TRUE)

missing_readiness <- which(is.na(risk_data$current_readiness))
for (row_id in missing_readiness) {
  row <- risk_data[row_id, ]
  match_row <- group_medians[
    group_medians$grade_level == row$grade_level &
      group_medians$course_track == row$course_track &
      group_medians$assessment_window == row$assessment_window,
    "current_readiness"
  ]
  risk_data$current_readiness[row_id] <- ifelse(
    length(match_row) == 1 && !is.na(match_row),
    match_row,
    overall_median
  )
}

risk_data$current_readiness_z <- as.numeric(scale(risk_data$current_readiness))
risk_data$sequence_z <- as.numeric(scale(risk_data$sequence_index))
risk_data$readiness_below_45 <- pmax(45 - risk_data$current_readiness, 0)
risk_data$readiness_45_to_60 <- pmin(
  pmax(risk_data$current_readiness - 45, 0),
  15
)
risk_data$readiness_above_60 <- pmax(risk_data$current_readiness - 60, 0)
risk_data$semester_sin <- sin(pi * risk_data$sequence_index)
risk_data$semester_cos <- cos(pi * risk_data$sequence_index)
risk_data$annual_sin <- sin(2 * pi * risk_data$sequence_index / 4)
risk_data$annual_cos <- cos(2 * pi * risk_data$sequence_index / 4)

risk_data <- risk_data[order(risk_data$sis_user_id, risk_data$sequence_index), ]
write.csv(
  risk_data,
  file.path("data", "processed", "education_readiness_risk.csv"),
  row.names = FALSE
)

assessment$present_score <- suppressWarnings(as.numeric(assessment$present_student_score))
assessment$readiness_after <- suppressWarnings(as.numeric(assessment$posterior_readiness_after))

boy <- assessment[assessment$assessment_window == "beginning_of_year", ]
eoy <- assessment[assessment$assessment_window == "end_of_year", ]

growth_pairs <- merge(
  boy,
  eoy,
  by = c("sis_user_id", "school_year"),
  suffixes = c("_boy", "_eoy")
)

growth_pairs$same_section <- growth_pairs$section_id_boy == growth_pairs$section_id_eoy
growth_pairs$same_teacher <- growth_pairs$teacher_id_boy == growth_pairs$teacher_id_eoy
growth_pairs$boy_present <- tolower(as.character(growth_pairs$is_present_boy)) == "true"
growth_pairs$eoy_present <- tolower(as.character(growth_pairs$is_present_eoy)) == "true"
growth_pairs$analysis_included <- growth_pairs$same_section &
  growth_pairs$same_teacher &
  growth_pairs$boy_present &
  growth_pairs$eoy_present &
  !is.na(growth_pairs$present_score_boy) &
  !is.na(growth_pairs$present_score_eoy)

growth_data <- growth_pairs[growth_pairs$analysis_included, ]
growth_data$score_gain <- growth_data$present_score_eoy - growth_data$present_score_boy
growth_data$readiness_gain <- growth_data$readiness_after_eoy - growth_data$readiness_after_boy
growth_data$boy_score <- growth_data$present_score_boy
growth_data$eoy_score <- growth_data$present_score_eoy
growth_data$boy_readiness <- growth_data$readiness_after_boy
growth_data$eoy_readiness <- growth_data$readiness_after_eoy
growth_data$boy_score_z <- as.numeric(scale(growth_data$boy_score))
growth_data$boy_readiness_z <- as.numeric(scale(growth_data$boy_readiness))
growth_data$boy_below_45 <- pmax(45 - growth_data$boy_score, 0)
growth_data$boy_45_to_60 <- pmin(pmax(growth_data$boy_score - 45, 0), 15)
growth_data$boy_above_60 <- pmax(growth_data$boy_score - 60, 0)
growth_data$annual_sin <- sin(2 * pi * growth_data$sequence_index_boy / 4)
growth_data$annual_cos <- cos(2 * pi * growth_data$sequence_index_boy / 4)

growth_data <- growth_data[
  ,
  c(
    "school_year", "school_year_offset_boy", "sis_user_id",
    "grade_level_boy", "course_id_boy", "course_name_boy",
    "course_track_boy", "section_id_boy", "section_label_boy",
    "teacher_id_boy", "teacher_label_boy", "attendance_category_boy",
    "attendance_probability_boy", "boy_score", "eoy_score",
    "boy_readiness", "eoy_readiness", "score_gain", "readiness_gain",
    "boy_score_z", "boy_readiness_z", "boy_below_45",
    "boy_45_to_60", "boy_above_60", "annual_sin", "annual_cos"
  )
]

names(growth_data) <- c(
  "school_year", "school_year_offset", "sis_user_id", "grade_level",
  "course_id", "course_name", "course_track", "section_id",
  "section_label", "teacher_id", "teacher_label", "attendance_category",
  "attendance_probability", "boy_score", "eoy_score", "boy_readiness",
  "eoy_readiness", "score_gain", "readiness_gain", "boy_score_z",
  "boy_readiness_z", "boy_below_45", "boy_45_to_60", "boy_above_60",
  "annual_sin", "annual_cos"
)

growth_data <- growth_data[order(growth_data$section_id, growth_data$sis_user_id), ]
write.csv(
  growth_data,
  file.path("data", "processed", "education_section_growth.csv"),
  row.names = FALSE
)

growth_profile <- data.frame(
  Measure = c(
    "Raw assessment rows",
    "BOY/EOY candidate pairs",
    "Included paired records",
    "Unique public-safe student IDs",
    "Unique section-year groups",
    "Unique simulated teachers",
    "Mean BOY score",
    "Mean EOY score",
    "Mean BOY/EOY gain",
    "Median section paired records"
  ),
  Value = c(
    format(nrow(assessment), big.mark = ","),
    format(nrow(growth_pairs), big.mark = ","),
    format(nrow(growth_data), big.mark = ","),
    format(length(unique(growth_data$sis_user_id)), big.mark = ","),
    format(length(unique(paste(growth_data$section_id, growth_data$school_year))), big.mark = ","),
    format(length(unique(growth_data$teacher_id)), big.mark = ","),
    format_num(mean(growth_data$boy_score), 1),
    format_num(mean(growth_data$eoy_score), 1),
    format_num(mean(growth_data$score_gain), 1),
    format_num(median(as.numeric(table(paste(growth_data$section_id, growth_data$school_year)))), 0)
  ),
  stringsAsFactors = FALSE
)

write.csv(
  growth_profile,
  file.path("reports", "growth_extract_profile.csv"),
  row.names = FALSE
)

message("Wrote data/processed/education_readiness_risk.csv")
message("Wrote data/processed/education_section_growth.csv")
message("Rows: ", nrow(risk_data))
message("Growth rows: ", nrow(growth_data))
