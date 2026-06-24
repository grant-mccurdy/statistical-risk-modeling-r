source(file.path("R", "model_utils.R"))

ensure_project_dirs()

required_tables <- c(
  file.path("reports", "growth_extract_profile.csv"),
  file.path("reports", "growth_model_comparison_display.csv"),
  file.path("reports", "growth_shape_review.csv"),
  file.path("reports", "growth_final_metrics.csv"),
  file.path("reports", "model_dependency_status.csv"),
  file.path("reports", "future_review_priorities.csv"),
  file.path("reports", "historical_section_evidence.csv"),
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

profile <- read_display_csv(file.path("reports", "growth_extract_profile.csv"))
model_comparison <- read_display_csv(
  file.path("reports", "growth_model_comparison_display.csv"),
  check_names = FALSE
)
shape_review <- read_display_csv(file.path("reports", "growth_shape_review.csv"))
final_metrics <- read_display_csv(file.path("reports", "growth_final_metrics.csv"))
dependency_status <- read_display_csv(file.path("reports", "model_dependency_status.csv"))
future_priorities <- read_display_csv(file.path("reports", "future_review_priorities.csv"))
historical_evidence <- read_display_csv(file.path("reports", "historical_section_evidence.csv"))
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

pretty_target <- function(target) {
  ifelse(grepl("^MATH-", target), pretty_course(target), target)
}

priority_row <- function(priority) {
  future_priorities[future_priorities$Priority == priority, , drop = FALSE][1, , drop = FALSE]
}

short_priority <- function(priority) {
  sub(" review$", "", priority)
}

compact_priority <- function(priority) {
  labels <- c(
    "Teacher support review" = "T support",
    "Teacher bright spot review" = "T bright",
    "Course support review" = "C support",
    "Course bright spot review" = "C bright"
  )
  ifelse(priority %in% names(labels), labels[priority], short_priority(priority))
}

short_model_name <- function(model) {
  labels <- c(
    "EOY readiness model" = "EOY readiness",
    "Gain readiness model" = "Gain readiness",
    "EOY GAM" = "EOY GAM",
    "Gain GAM" = "Gain GAM",
    "EOY interaction model" = "EOY interaction",
    "Gain interaction model" = "Gain interaction",
    "Teacher/course leakage benchmark" = "Leakage check",
    "EOY linear benchmark" = "EOY linear",
    "Gain linear benchmark" = "Gain linear",
    "Gain gradient boosting" = "Gain GBM",
    "EOY gradient boosting" = "EOY GBM",
    "Gain random forest" = "Gain RF",
    "EOY random forest" = "EOY RF"
  )
  ifelse(model %in% names(labels), labels[model], model)
}

selected_model <- metric_value("Selected model")
selected_target <- metric_value("Selected target strategy")
selected_method <- metric_value("Selected method")
candidate_count <- metric_value("Candidate models tested")
included_pairs <- profile_value("Included paired records")
section_groups <- profile_value("Unique section-year groups")
teachers <- profile_value("Unique simulated teachers")
mean_boy <- metric_value("Mean BOY score")
mean_eoy <- metric_value("Mean EOY score")
mean_gain <- metric_value("Mean raw BOY/EOY gain")
cv_gain_rmse <- metric_value("CV expected-gain RMSE")
cv_gain_r2 <- metric_value("CV expected-gain R-squared")
cv_eoy_r2 <- metric_value("CV EOY R-squared")
holdout_gain_rmse <- metric_value("Holdout expected-gain RMSE")
holdout_gain_r2 <- metric_value("Holdout expected-gain R-squared")
holdout_eoy_rmse <- metric_value("Holdout EOY RMSE")
holdout_eoy_r2 <- metric_value("Holdout EOY R-squared")
category_counts <- table(section_signals$Category)
above_expected <- ifelse("Above expected" %in% names(category_counts), category_counts[["Above expected"]], 0)
below_expected <- ifelse("Below expected" %in% names(category_counts), category_counts[["Below expected"]], 0)
within_expected <- ifelse("Within expected range" %in% names(category_counts), category_counts[["Within expected range"]], 0)

names(model_comparison) <- c(
  "Model", "Selected", "Role", "Target", "Method", "Params", "CV RMSE",
  "CV SD", "CV MAE", "CV R2", "CV EOY R2", "Holdout RMSE",
  "Holdout R2", "Holdout EOY R2", "Delta"
)
names(shape_review) <- c(
  "Family", "Representative model", "Why tested", "Decision",
  "CV RMSE", "Holdout RMSE"
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
names(future_priorities) <- c(
  "Priority", "Target", "Mean adjusted gap", "Review signal",
  "Evidence", "Follow-up"
)
names(historical_evidence) <- c(
  "Priority", "Target", "Section", "Teacher", "Course", "Year", "N",
  "Raw gain", "Expected gain", "Adjusted signal"
)
names(diagnostics) <- c("Diagnostic", "Estimate", "Interpretation")
names(sensitivity) <- c("Measure", "Value")

support_teacher <- priority_row("Teacher support review")
bright_teacher <- priority_row("Teacher bright spot review")
support_course <- priority_row("Course support review")
bright_course <- priority_row("Course bright spot review")

future_priorities_report <- data.frame(
  Priority = short_priority(future_priorities$Priority),
  Target = pretty_target(future_priorities$Target),
  Gap = future_priorities$`Mean adjusted gap`,
  Evidence = sub(" paired records\\.$", " records", future_priorities$Evidence),
  stringsAsFactors = FALSE
)

historical_evidence_report <- historical_evidence
historical_evidence_report$Priority <- compact_priority(historical_evidence_report$Priority)
historical_evidence_report$Section <- short_section_label(
  historical_evidence_report$Section,
  historical_evidence_report$Year
)
historical_evidence_report$Course <- pretty_course(historical_evidence_report$Course)
historical_evidence_report <- historical_evidence_report[
  ,
  c(
    "Priority", "Section", "Teacher", "Course", "N",
    "Raw gain", "Expected gain", "Adjusted signal"
  ),
  drop = FALSE
]
names(historical_evidence_report) <- c(
  "Priority", "Section", "Teacher", "Course", "N", "Raw", "Expected", "Signal"
)

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
section_highlights_report$Course <- pretty_course(section_highlights_report$Course)
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

shape_review_report <- shape_review[
  ,
  c("Family", "Representative model", "Decision", "CV RMSE", "Holdout RMSE"),
  drop = FALSE
]
shape_review_report$Decision <- ifelse(
  grepl("^Selected", shape_review_report$Decision),
  "Selected",
  ifelse(grepl("^Excluded", shape_review_report$Decision), "Excluded", "Compared")
)

model_comparison_compact <- model_comparison
model_comparison_compact$Model <- short_model_name(model_comparison_compact$Model)
model_rows <- unique(c(
  seq_len(min(6, nrow(model_comparison_compact))),
  which(model_comparison$Role == "Excluded leakage benchmark")[1]
))
model_comparison_report <- model_comparison_compact[
  model_rows,
  c(
    "Model", "Target", "Method", "CV RMSE",
    "CV R2", "CV EOY R2", "Holdout RMSE"
  ),
  drop = FALSE
]
names(model_comparison_report) <- c(
  "Model", "Target", "Method", "CV RMSE", "Gain R2", "EOY R2", "Holdout RMSE"
)

teacher_summary_report <- top_n(teacher_summary, 12)
teacher_summary_report <- teacher_summary_report[
  ,
  c("Teacher", "Sections", "Records", "Raw gain", "Expected gain", "Adjusted signal"),
  drop = FALSE
]
names(teacher_summary_report) <- c("Teacher", "Sections", "Records", "Raw", "Expected", "Signal")

course_summary_report <- top_n(course_summary, 12)
course_summary_report$Course <- pretty_course(course_summary_report$Course)
course_summary_report <- course_summary_report[
  ,
  c("Course", "Sections", "Records", "Raw gain", "Expected gain", "Adjusted signal"),
  drop = FALSE
]
names(course_summary_report) <- c("Course", "Sections", "Records", "Raw", "Expected", "Signal")

dependency_report <- dependency_status
dependency_report$Installed <- ifelse(dependency_report$Installed == "TRUE", "Available", "Not installed")

appendix_metric_names <- c(
  "Selected model",
  "Selected target strategy",
  "Selected method",
  "Candidate models tested",
  "Operational candidates tested",
  "Repeated CV folds",
  "Repeated CV repeats",
  "CV expected-gain RMSE",
  "CV expected-gain R-squared",
  "CV EOY R-squared",
  "Holdout expected-gain RMSE",
  "Holdout expected-gain R-squared",
  "Holdout EOY R-squared",
  "Mean raw BOY/EOY gain"
)
appendix_metrics <- final_metrics[
  match(appendix_metric_names, final_metrics$Metric),
  ,
  drop = FALSE
]

report_lines <- c(
  "# Assessment Growth and Section Performance Analytics in R",
  "",
  "## Recommendation",
  "",
  paste0(
    "This study uses seven years of public-safe BOY/EOY assessment history to build an expected-score baseline for future instructional planning. ",
    "The decision question is not which historical section requires action; those sections are already in the past. ",
    "The decision question is which teachers and courses should receive closer review before the next assessment cycle because their historical growth patterns were directionally above or below expectation."
  ),
  "",
  paste0(
    "Use **BOY/EOY score gain** as the stakeholder metric: EOY score minus BOY score. ",
    "Use the model only to set the expected baseline for students with similar starting scores, readiness, attendance, grade level, course track, and school-year context. ",
    "A positive signal means growth was above expectation; a negative signal means growth was below expectation."
  ),
  "",
  paste0(
    "The future-facing review priorities are **", support_teacher$Target,
    "** for teacher support, **", bright_teacher$Target,
    "** as a teacher bright spot, **", pretty_target(support_course$Target),
    "** for course support, and **", pretty_target(bright_course$Target),
    "** as a course bright spot. These are review priorities, not personnel ratings."
  ),
  "",
  markdown_table(future_priorities_report),
  "",
  "The gap column is the average observed-minus-expected BOY/EOY gain. The generated CSV also keeps the reliability-weighted review signal used to rank recurring patterns.",
  "",
  "<!-- PDF_PAGE_BREAK -->",
  "",
  "## Approach and Rationale",
  "",
  paste0(
    "The analysis includes ", included_pairs, " paired BOY/EOY records across ",
    section_groups, " historical section-year groups and ", teachers,
    " simulated teachers. The mean BOY score is ", mean_boy,
    ", the mean EOY score is ", mean_eoy,
    ", and the mean raw gain is ", mean_gain, " points."
  ),
  "",
  paste0(
    "The selected baseline is **", selected_model, "**, a ", selected_method,
    " using the ", selected_target, " target. The model search tested ",
    candidate_count, " candidates across linear, interaction, GAM, random-forest, ",
    "gradient-boosting, and leakage-check specifications."
  ),
  "",
  paste0(
    "The model's holdout expected-gain R-squared is **", holdout_gain_r2,
    "**, while its holdout EOY R-squared is **", holdout_eoy_r2,
    "**. This difference is expected: BOY score explains much of final EOY score, ",
    "but year-over-year gain is noisier after the starting score is removed. ",
    "That is why the report aggregates signals at the teacher and course level instead of acting on individual predictions."
  ),
  "",
  "The operating baseline intentionally excludes teacher IDs, course IDs, and section IDs. Including those IDs would make the prediction slightly different, but it would also subtract away the persistent teacher and course patterns this study is designed to surface for future review.",
  "",
  "## Direct Answers",
  "",
  "1. The main metric is BOY/EOY improvement: end-of-year score minus beginning-of-year score for the same public-safe student record.",
  paste0("2. The average raw gain is ", mean_gain, " points across ", included_pairs, " paired records."),
  paste0("3. The strongest baseline predicts EOY score and converts it to expected gain; holdout EOY R-squared is ", holdout_eoy_r2, " and holdout expected-gain RMSE is ", holdout_gain_rmse, "."),
  paste0("4. Historical sections are evidence, not future action targets. The review layer flags ", above_expected, " historical section-year groups above expected growth and ", below_expected, " below expected growth, with ", within_expected, " within expected range."),
  paste0(
    "5. Recommended next-cycle review targets are ", support_teacher$Target,
    " for teacher support, ", bright_teacher$Target, " for teacher bright-spot learning, ",
    pretty_target(support_course$Target), " for course support, and ",
    pretty_target(bright_course$Target), " as a course bright spot."
  ),
  "",
  "## Data Audit",
  "",
  "The analysis starts from a public-safe assessment extract. A record enters the growth model only when the same public-safe student has valid BOY and EOY scores in the same section and with the same simulated teacher. This keeps the improvement metric tied to one section experience instead of mixing students across sections.",
  "",
  markdown_table(profile),
  "",
  "<!-- PDF_PAGE_BREAK -->",
  "",
  "## Future Review Priorities",
  "",
  "The recommendations below are the operational layer of the study. They use all seven years of historical evidence, weighted toward recurring teacher and course patterns. The purpose is to decide what to review before the next cycle, not to treat past sections as current operational units.",
  "",
  markdown_table(future_priorities_report),
  "",
  "The table below shows the historical section evidence behind those priorities. It is intentionally placed after the future priorities because historical sections explain the signal; they are not the action target.",
  "",
  markdown_table(historical_evidence_report),
  "",
  paste0(
    "The full future-priority table is generated as ",
    artifact_ref("reports/future_review_priorities.csv"),
    ", and the supporting historical evidence table is generated as ",
    artifact_ref("reports/historical_section_evidence.csv"), "."
  ),
  "",
  "<!-- PDF_PAGE_BREAK -->",
  "",
  "## Raw Section Improvement",
  "",
  "The first descriptive layer calculates BOY/EOY score gain inside each historical section-year group and runs a paired-improvement t-test against zero. This answers whether a section improved, but it does not by itself show whether the section improved more than expected for its starting profile.",
  "",
  paste0(
    "The table below shows high-signal historical section-year groups from the review layer, with raw BOY/EOY t-test results included for context. The full section t-test table is generated as ",
    artifact_ref("reports/section_ttests.csv"), "."
  ),
  "",
  markdown_table(raw_improvement_report),
  "",
  "![Distribution of BOY/EOY improvement](../figures/growth_distribution.png)",
  "",
  "## Expected-Growth Baseline",
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
    "The compact table shows the strongest candidates by repeated-CV RMSE plus the leakage check. The full model-comparison table is generated as ",
    artifact_ref("reports/growth_model_comparison_display.csv"), "."
  ),
  "",
  "![Expected-growth model comparison](../figures/growth_model_comparison.png)",
  "",
  "<!-- PDF_PAGE_BREAK -->",
  "",
  "## Historical Section Signals",
  "",
  "For each historical section-year group, the adjusted signal is the reliability-weighted average residual: observed gain minus expected gain, weighted toward zero for smaller groups. Positive values mean the section improved more than expected for its starting mix; negative values mean it improved less than expected.",
  "",
  markdown_table(section_highlights_report),
  "",
  "![Sections above or below expected growth](../figures/section_adjusted_signals.png)",
  "",
  paste0(
    "The full section signal table is generated as ",
    artifact_ref("reports/section_adjusted_signals.csv"),
    " so reviewers can inspect all historical section-year groups, not only the highlights shown in the report."
  ),
  "",
  "<!-- PDF_PAGE_BREAK -->",
  "",
  "## Teacher and Course Signal Summary",
  "",
  "Teacher and course summaries aggregate the historical section evidence into future-facing review signals. They are useful for identifying where leaders may want to inspect pacing, curriculum alignment, attendance mix, or practices worth transferring. They should not be treated as standalone teacher quality scores.",
  "",
  markdown_table(teacher_summary_report),
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
  "The diagnostics below separate two questions: how well the model predicts the expected baseline, and how much raw section rankings change after adjustment. The EOY R-squared describes baseline strength; the gain R-squared describes how noisy individual growth remains after BOY score is removed.",
  "",
  markdown_table(diagnostics),
  "",
  markdown_table(sensitivity),
  "",
  "![Growth model diagnostics](../figures/growth_diagnostics.png)",
  "",
  "## Technical Appendix",
  "",
  "The expanded model search used the installed R packages below. The operating model excludes persistent teacher, course, and section IDs; the leakage benchmark is reported only to show why those fields should not be used inside the baseline.",
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
  "## Bottom Line",
  "",
  "- BOY/EOY improvement is the right stakeholder metric because it is easy to explain and aligned with instructional growth.",
  "- The expected-score baseline should be used to create fairer teacher and course review signals, not to rank individual students or automate personnel decisions.",
  "- Historical sections should be treated as evidence. Future action should focus on recurring teacher and course patterns before the next cycle.",
  "- The model predicts final EOY score strongly, but individual gain remains noisy; aggregate signals and human review are necessary.",
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
    "**Purpose:** use seven years of public-safe BOY/EOY assessment history to identify teacher and course patterns that deserve review before the next assessment cycle."
  ),
  "",
  paste0(
    "**Headline metric:** average raw BOY/EOY gain is ", mean_gain,
    " points across ", included_pairs, " paired records."
  ),
  "",
  paste0(
    "**Baseline:** selected model is ", selected_model,
    " with holdout EOY R-squared ", holdout_eoy_r2,
    " and holdout expected-gain RMSE ", holdout_gain_rmse, "."
  ),
  "",
  paste0(
    "**Future priorities:** review ", support_teacher$Target,
    " for support, study ", bright_teacher$Target,
    " as a bright spot, review ", pretty_target(support_course$Target),
    " for course support, and use ", pretty_target(bright_course$Target),
    " as a course reference pattern."
  ),
  "",
  "**Guardrail:** historical sections explain the signal, but future action should focus on upcoming teacher/course planning. Do not use the outputs for automatic teacher evaluation, compensation, discipline, or personnel decisions.",
  "",
  "## Decisions for Stakeholders",
  "",
  "- Decide which teacher/course review conversations should happen before the next cycle.",
  "- Compare raw gains with adjusted gains before drawing conclusions.",
  "- Use historical section evidence as context, not as the future recommendation itself.",
  "- Monitor pairing rates, section sizes, and course mix before operationalizing the workflow."
)

writeLines(executive_lines, file.path("reports", "executive_brief.md"))

model_card_lines <- c(
  "# Model Card",
  "",
  "## Intended Use",
  "",
  "Estimate an expected BOY/EOY assessment-growth baseline and identify public-safe teacher/course patterns that deserve future instructional review.",
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
    "Selected baseline: ", selected_model,
    ". Candidate families include direct gain models, predicted EOY models, interaction surfaces, GAM smooths, random forests, gradient boosting, and an excluded teacher/course ID leakage check."
  ),
  "",
  "## Performance",
  "",
  markdown_table(final_metrics),
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
