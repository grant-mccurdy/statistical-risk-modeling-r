source(file.path("R", "model_utils.R"))

ensure_project_dirs()

required_tables <- c(
  file.path("reports", "growth_extract_profile.csv"),
  file.path("reports", "growth_model_comparison_display.csv"),
  file.path("reports", "growth_shape_review.csv"),
  file.path("reports", "growth_final_metrics.csv"),
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

growth <- read.csv(
  file.path("data", "processed", "education_section_growth.csv"),
  stringsAsFactors = FALSE
)

profile <- read_display_csv(file.path("reports", "growth_extract_profile.csv"))
model_comparison <- read_display_csv(
  file.path("reports", "growth_model_comparison_display.csv"),
  check_names = FALSE
)
shape_review <- read_display_csv(file.path("reports", "growth_shape_review.csv"))
final_metrics <- read_display_csv(file.path("reports", "growth_final_metrics.csv"))
section_ttests <- read_display_csv(file.path("reports", "section_ttests.csv"))
section_signals <- read_display_csv(file.path("reports", "section_adjusted_signals.csv"))
section_highlights <- read_display_csv(file.path("reports", "section_signal_highlights.csv"))
teacher_summary <- read_display_csv(file.path("reports", "teacher_growth_summary.csv"))
course_summary <- read_display_csv(file.path("reports", "course_growth_summary.csv"))
diagnostics <- read_display_csv(file.path("reports", "growth_diagnostics.csv"))
sensitivity <- read_display_csv(file.path("reports", "growth_sensitivity.csv"))

metric_value <- function(metric_name) {
  final_metrics$Value[final_metrics$Metric == metric_name][1]
}

profile_value <- function(measure_name) {
  profile$Value[profile$Measure == measure_name][1]
}

as_report_num <- function(x) {
  suppressWarnings(as.numeric(gsub(",", "", x)))
}

signed_num <- function(x) {
  x <- as_report_num(x)
  ifelse(x > 0, paste0("+", format_num(x, 2)), format_num(x, 2))
}

artifact_ref <- function(path) {
  paste0("[", path, "](", basename(path), ")")
}

selected_model <- metric_value("Selected model")
included_pairs <- profile_value("Included paired records")
section_groups <- profile_value("Unique section-year groups")
teachers <- profile_value("Unique simulated teachers")
mean_boy <- metric_value("Mean BOY score")
mean_eoy <- metric_value("Mean EOY score")
mean_gain <- metric_value("Mean raw BOY/EOY gain")
holdout_rmse <- metric_value("Holdout RMSE")
holdout_r2 <- metric_value("Holdout R-squared")
category_counts <- table(section_signals$Category)
above_expected <- ifelse("Above expected" %in% names(category_counts), category_counts[["Above expected"]], 0)
below_expected <- ifelse("Below expected" %in% names(category_counts), category_counts[["Below expected"]], 0)
within_expected <- ifelse("Within expected range" %in% names(category_counts), category_counts[["Within expected range"]], 0)

names(model_comparison) <- c(
  "Model", "Selected", "Role", "Params", "CV RMSE", "CV SD", "CV MAE",
  "CV R2", "Holdout RMSE", "Holdout R2", "Delta"
)
names(shape_review) <- c("Family", "Why tested", "Decision", "CV RMSE", "Holdout RMSE")
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

top_n <- function(df, n = 12) {
  df[seq_len(min(nrow(df), n)), , drop = FALSE]
}

short_section_label <- function(section, year) {
  section <- sub("^Y[0-9]+-", "", section)
  section_num <- suppressWarnings(as.integer(sub("^SEC-", "", section)))
  section <- ifelse(is.na(section_num), section, sprintf("S%02d", section_num))
  year <- paste0(substr(year, 3, 4), "-", substr(year, 8, 9))
  paste(year, section)
}

compact_category <- function(category) {
  out <- ifelse(category == "Within expected range", "In range", category)
  sub(" expected$", "", out)
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
  ifelse(key %in% names(labels), labels[key], gsub("-", " ", key))
}

audit_target <- function(section, teacher = NULL, course = NULL, year = NULL) {
  pieces <- c()
  if (!is.null(section) && !is.null(year)) {
    pieces <- c(pieces, short_section_label(section, year))
  }
  if (!is.null(teacher)) {
    pieces <- c(pieces, teacher)
  }
  if (!is.null(course)) {
    pieces <- c(pieces, pretty_course(course))
  }
  paste(pieces, collapse = " / ")
}

raw_improvement_report <- top_n(section_ttests, 8)
raw_improvement_report$Section <- short_section_label(
  raw_improvement_report$Section,
  raw_improvement_report$Year
)
raw_improvement_report <- raw_improvement_report[
  ,
  c("Section", "N", "BOY", "EOY", "Gain", "95% CI", "p-value"),
  drop = FALSE
]

section_highlights_report <- section_highlights
section_highlights_report$Section <- short_section_label(
  section_highlights_report$Section,
  section_highlights_report$Year
)
section_highlights_report$Category <- compact_category(section_highlights_report$Category)
section_highlights_report <- section_highlights_report[
  ,
  c(
    "Section", "Teacher", "N", "Raw gain", "Expected gain",
    "Adjusted signal", "Category"
  ),
  drop = FALSE
]
names(section_highlights_report) <- c(
  "Section", "Teacher", "N", "Raw", "Expected", "Signal", "Result"
)

shape_review_report <- shape_review[
  ,
  c("Family", "Decision", "CV RMSE", "Holdout RMSE"),
  drop = FALSE
]

model_comparison_report <- model_comparison[
  ,
  c("Model", "Selected", "CV RMSE", "Holdout RMSE", "Holdout R2"),
  drop = FALSE
]

course_summary_report <- top_n(course_summary, 12)
course_summary_report$Course <- pretty_course(course_summary_report$Course)
course_summary_report <- course_summary_report[
  ,
  c("Course", "Sections", "Records", "Raw gain", "Expected gain", "Adjusted signal"),
  drop = FALSE
]
names(course_summary_report) <- c("Course", "Sections", "Records", "Raw", "Expected", "Signal")

section_signals_numeric <- section_signals
section_signals_numeric$SignalValue <- as_report_num(section_signals_numeric$`Adjusted signal`)
support_sections <- section_signals_numeric[
  section_signals_numeric$Category == "Below expected",
  ,
  drop = FALSE
]
support_sections <- head(support_sections[order(support_sections$SignalValue), , drop = FALSE], 3)
bright_sections <- section_signals_numeric[
  section_signals_numeric$Category == "Above expected",
  ,
  drop = FALSE
]
bright_sections <- head(
  bright_sections[order(bright_sections$SignalValue, decreasing = TRUE), , drop = FALSE],
  2
)

make_section_audit_rows <- function(df, focus) {
  if (nrow(df) == 0) {
    return(data.frame(Level = character(), Target = character(), Reason = character()))
  }
  data.frame(
    Level = paste("Section", focus),
    Target = mapply(
      audit_target,
      df$Section,
      df$Teacher,
      df$Course,
      df$Year,
      USE.NAMES = FALSE
    ),
    Reason = paste0(
      "Raw ", df$`Raw gain`,
      " vs expected ", df$`Expected gain`,
      "; signal ", signed_num(df$`Adjusted signal`), "."
    ),
    stringsAsFactors = FALSE
  )
}

course_numeric <- course_summary
course_numeric$SignalValue <- as_report_num(course_numeric$`Adjusted signal`)
course_low <- course_numeric[which.min(course_numeric$SignalValue), , drop = FALSE]
course_high <- course_numeric[which.max(course_numeric$SignalValue), , drop = FALSE]

teacher_numeric <- teacher_summary
teacher_numeric$SignalValue <- as_report_num(teacher_numeric$`Adjusted signal`)
teacher_low <- teacher_numeric[which.min(teacher_numeric$SignalValue), , drop = FALSE]

audit_queue_report <- rbind(
  make_section_audit_rows(support_sections, "support"),
  make_section_audit_rows(bright_sections, "bright spot"),
  data.frame(
    Level = "Course support",
    Target = pretty_course(course_low$Course),
    Reason = paste0(
      "Course signal ", signed_num(course_low$`Adjusted signal`),
      "; raw ", course_low$`Raw gain`,
      " vs expected ", course_low$`Expected gain`, "."
    ),
    stringsAsFactors = FALSE
  ),
  data.frame(
    Level = "Course bright spot",
    Target = pretty_course(course_high$Course),
    Reason = paste0(
      "Course signal ", signed_num(course_high$`Adjusted signal`),
      "; raw ", course_high$`Raw gain`,
      " vs expected ", course_high$`Expected gain`, "."
    ),
    stringsAsFactors = FALSE
  ),
  data.frame(
    Level = "Teacher support",
    Target = teacher_low$Teacher,
    Reason = paste0(
      "Average signal ", signed_num(teacher_low$`Adjusted signal`),
      " across ", teacher_low$Sections,
      " sections; review with composition context."
    ),
    stringsAsFactors = FALSE
  )
)

report_lines <- c(
  "# Assessment Growth and Section Performance Analytics in R",
  "",
  "## Recommendation",
  "",
  paste0(
    "This study evaluates **beginning-of-year to end-of-year improvement** in a public-safe education assessment extract. ",
    "The business question is: which course sections improved more or less than expected after accounting for starting performance, readiness, attendance, course track, grade level, and school-year context?"
  ),
  "",
  paste0(
    "Use BOY/EOY gain as the headline metric, but use **adjusted growth signals** for section review. ",
    "Raw gains are easy to understand, but they can reward sections that started low and penalize sections that started near a ceiling. ",
    "The adjusted signal compares observed gain with expected gain for a similar starting profile."
  ),
  "",
  paste0(
    "The analysis includes ", included_pairs, " paired BOY/EOY records across ",
    section_groups, " section-year groups and ", teachers, " simulated teachers. ",
    "The average BOY score is ", mean_boy, ", the average EOY score is ",
    mean_eoy, ", and the mean raw gain is ", mean_gain, " points."
  ),
  "",
  paste0(
    "The selected expected-growth model is **", selected_model,
    "**. It achieved holdout RMSE **", holdout_rmse,
    "** and holdout R-squared **", holdout_r2,
    "**. Section signals should be used for instructional review, curriculum support, and follow-up analysis; they should not be used as automatic teacher evaluation or personnel decisions."
  ),
  "",
  "## Direct Answers",
  "",
  "1. The main metric is BOY/EOY score improvement: end-of-year score minus beginning-of-year score for the same simulated student in the same section and teacher context.",
  paste0("2. The average raw gain is ", mean_gain, " points across ", included_pairs, " paired records."),
  paste0("3. Raw section gains are reported, but the primary comparison is adjusted growth: observed section gain minus expected gain from the selected model."),
  paste0("4. The section review layer flags ", above_expected, " section-year groups above expected growth and ", below_expected, " below expected growth, with ", within_expected, " within expected range. Start with the audit queue below rather than a raw ranking."),
  paste0(
    "5. Course and teacher summaries are pattern-finding views. ",
    pretty_course(course_low$Course), " is the clearest course support review; ",
    pretty_course(course_high$Course), " is the clearest course bright spot; ",
    teacher_low$Teacher, " merits a composition-aware support review."
  ),
  "",
  "<!-- PDF_PAGE_BREAK -->",
  "",
  "**Initial audit queue**",
  "",
  markdown_table(audit_queue_report),
  "",
  "## Data Audit",
  "",
  "The analysis starts from a public-safe assessment extract. A record enters the growth model only when the same simulated student has valid BOY and EOY scores in the same section and with the same simulated teacher. This keeps the improvement metric tied to a section experience instead of mixing students across sections.",
  "",
  markdown_table(profile),
  "",
  "The extract uses simulated identifiers and generalized score/readiness behavior from a bootstrapped assessment workflow. It is not a release of real student records or real personnel data.",
  "",
  "## Raw Section Improvement",
  "",
  "The first layer is descriptive: calculate the BOY/EOY score gain inside each section-year group and run a paired-improvement t-test against zero. This answers whether a section improved, but it does not by itself prove that the section improved more than expected given its starting point.",
  "",
  paste0(
    "The table below shows high-signal section-year groups from the review layer, with their raw BOY/EOY t-test results included for context. The full section t-test table is generated as ",
    artifact_ref("reports/section_ttests.csv"), "."
  ),
  "",
  markdown_table(raw_improvement_report),
  "",
  "![Distribution of BOY/EOY improvement](../figures/growth_distribution.png)",
  "",
  "## Adjusted Growth Model",
  "",
  "The adjusted model estimates expected BOY/EOY gain from starting score/readiness and context. This is the key step that makes the analysis more useful than a raw gain ranking: it accounts for floor effects, ceiling effects, attendance context, course track, grade level, and school-year timing.",
  "",
  "![Nonparametric and parametric BOY score shape](../figures/baseline_growth_shape.png)",
  "",
  "<!-- PDF_PAGE_BREAK -->",
  "",
  "**Model family review**",
  "",
  markdown_table(shape_review_report),
  "",
  markdown_table(model_comparison_report),
  "",
  paste0(
    "The full model-comparison table is generated as ",
    artifact_ref("reports/growth_model_comparison_display.csv"), "."
  ),
  "",
  "![Expected-growth model comparison](../figures/growth_model_comparison.png)",
  "",
  "## Section Performance Signals",
  "",
  "For each section-year group, the adjusted signal is the reliability-weighted average residual: observed gain minus expected gain, weighted toward zero for smaller groups. Positive values mean the section improved more than expected for its starting mix; negative values mean it improved less than expected.",
  "",
  markdown_table(section_highlights_report),
  "",
  "![Sections above or below expected growth](../figures/section_adjusted_signals.png)",
  "",
  paste0(
    "The full section signal table is generated as ",
    artifact_ref("reports/section_adjusted_signals.csv"),
    " so reviewers can inspect all section-year groups, not only the highlights shown in the report."
  ),
  "",
  "## Instructor and Course Summary",
  "",
  "Teacher and course summaries aggregate the section-level evidence. They are useful for spotting patterns that deserve follow-up, such as a course sequence that may need curriculum review or a teacher group whose sections repeatedly exceed expected growth. They should not be treated as standalone teacher quality scores.",
  "",
  markdown_table(teacher_summary),
  "",
  "<!-- PDF_PAGE_BREAK -->",
  "",
  "**Course-level summary**",
  "",
  markdown_table(course_summary_report),
  "",
  "![Teacher and course growth summaries](../figures/teacher_course_summary.png)",
  "",
  "<!-- PDF_PAGE_BREAK -->",
  "",
  "## Diagnostics and Sensitivity",
  "",
  "The diagnostics below check whether the expected-growth model is centered and whether the raw section rankings materially differ from adjusted rankings.",
  "",
  markdown_table(diagnostics),
  "",
  markdown_table(sensitivity),
  "",
  "![Growth model diagnostics](../figures/growth_diagnostics.png)",
  "",
  "## Bottom Line",
  "",
  "- BOY/EOY improvement is the right stakeholder metric because it is easy to explain and aligned with instructional growth.",
  "- Raw improvement should be shown, but adjusted growth should drive section review because starting level, attendance, course track, and ceiling effects matter.",
  "- The strongest use case is instructional review: identify sections that exceed expected growth, sections that lag expected growth, and course patterns that deserve support.",
  "- Avoid framing results as teacher quality rankings. The outputs are public-safe analytical signals, not personnel decisions.",
  "",
  "## Reproducibility",
  "",
  "Rebuild the full evidence packet with `make all`. The core pipeline uses base R, the included public-safe extract, and no credentials, private files, or network access.",
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
    "**Purpose:** identify public-safe course sections with unusually high or low BOY/EOY improvement after accounting for starting profile and context."
  ),
  "",
  paste0(
    "**Headline metric:** average raw BOY/EOY gain is ", mean_gain,
    " points across ", included_pairs, " paired records."
  ),
  "",
  paste0(
    "**Recommendation:** use adjusted growth signals for instructional review. The model flags ",
    above_expected, " section-year groups above expected growth and ",
    below_expected, " below expected growth."
  ),
  "",
  paste0(
    "**Model support:** selected model is ", selected_model,
    " with holdout RMSE ", holdout_rmse,
    " and holdout R-squared ", holdout_r2, "."
  ),
  "",
  "**Decision use:** review section outliers, compare course patterns, and look for instructional practices or curriculum issues that merit follow-up.",
  "",
  "**Guardrail:** do not use the section or teacher summaries as automatic teacher evaluation, compensation, discipline, or personnel decisions.",
  "",
  "## Decisions for Stakeholders",
  "",
  "- Decide which section outliers should be reviewed first.",
  "- Compare raw gains with adjusted gains before drawing conclusions.",
  "- Use teacher/course summaries as pattern-finding views, not rankings.",
  "- Monitor missingness and section sizes before operationalizing the workflow."
)

writeLines(executive_lines, file.path("reports", "executive_brief.md"))

model_card_lines <- c(
  "# Model Card",
  "",
  "## Intended Use",
  "",
  "Estimate expected BOY/EOY assessment improvement and identify public-safe section-year groups whose growth is higher or lower than expected for instructional review.",
  "",
  "## Not Intended For",
  "",
  "Teacher evaluation, compensation, discipline, student placement, grading, employment, admissions, clinical decisions, or automated decisions with real student or personnel data.",
  "",
  "## Data",
  "",
  paste0(
    "Public-safe paired BOY/EOY assessment records with ", included_pairs,
    " modeled pairs, simulated identifiers, generalized score/readiness behavior, and no real student-identifiable or personnel records."
  ),
  "",
  "## Model",
  "",
  paste0(
    "Selected expected-growth model: ", selected_model,
    ". Candidate families include context-only, linear BOY score, quadratic BOY score, piecewise BOY score, readiness-augmented, and spline benchmark specifications."
  ),
  "",
  "## Performance",
  "",
  markdown_table(final_metrics),
  "",
  "## Monitoring Recommendations",
  "",
  "- Track BOY/EOY pairing rates and missing EOY assessments.",
  "- Monitor section sizes before ranking or escalating section signals.",
  "- Refit the model when course mix, assessment design, or attendance patterns change.",
  "- Compare raw and adjusted growth before communicating section findings.",
  "",
  "## Public-Safety Boundary",
  "",
  "No private coursework prompts, raw private source datasets, credentials, real student records, real personnel records, patient records, or customer records are included."
)

writeLines(model_card_lines, file.path("docs", "model-card.md"))
message("Wrote reports/assessment_growth_section_performance_report.md")
message("Wrote reports/executive_brief.md")
message("Wrote docs/model-card.md")
