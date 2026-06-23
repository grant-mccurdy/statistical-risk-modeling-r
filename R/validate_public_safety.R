source(file.path("R", "model_utils.R"))

project_files <- list.files(
  ".",
  recursive = TRUE,
  all.files = TRUE,
  full.names = TRUE,
  no.. = TRUE
)

project_files <- project_files[!grepl("^\\./\\.git/", project_files)]

raw_files <- list.files(
  file.path("data", "raw"),
  recursive = TRUE,
  all.files = TRUE,
  full.names = TRUE,
  no.. = TRUE
)

allowed_raw <- c(
  file.path("data", "raw", "README.md"),
  file.path("data", "raw", "synthetic_education_assessment_long.csv")
)
raw_violations <- setdiff(raw_files, allowed_raw)

prohibited_extensions <- c("\\.docx$", "\\.pdf$", "\\.pptx$", "\\.xlsx$")
prohibited_binary_files <- project_files[
  grepl(paste(prohibited_extensions, collapse = "|"), project_files, ignore.case = TRUE)
]
allowed_binary_files <- c("./reports/assessment_growth_section_performance_report.pdf")
prohibited_binary_files <- setdiff(prohibited_binary_files, allowed_binary_files)

text_extensions <- paste(
  c(
    "\\.R$", "\\.Rmd$", "\\.md$", "\\.txt$", "\\.csv$", "\\.json$",
    "\\.yml$", "\\.yaml$", "Makefile$", "LICENSE$"
  ),
  collapse = "|"
)

text_files <- project_files[grepl(text_extensions, project_files, ignore.case = TRUE)]
text_files <- setdiff(text_files, "./R/validate_public_safety.R")

private_identifier_patterns <- c(
  "/home/.*/repos/private",
  "\\.*/private/.*/source/"
)

credential_patterns <- c(
  "-----BEGIN [A-Z ]+PRIVATE KEY-----",
  "AKIA[0-9A-Z]{16}",
  "sk-[A-Za-z0-9]{20,}",
  "xox[baprs]-[A-Za-z0-9-]{10,}"
)

scan_patterns <- c(private_identifier_patterns, credential_patterns)
violations <- data.frame(File = character(), Pattern = character(), stringsAsFactors = FALSE)

for (file in text_files) {
  text <- readLines(file, warn = FALSE)
  if (length(text) == 0) {
    next
  }
  combined <- paste(text, collapse = "\n")
  for (pattern in scan_patterns) {
    if (grepl(pattern, combined, perl = TRUE)) {
      violations <- rbind(
        violations,
        data.frame(File = file, Pattern = pattern, stringsAsFactors = FALSE)
      )
    }
  }
}

errors <- character()

if (length(raw_violations) > 0) {
  errors <- c(
    errors,
    paste("Unexpected files in data/raw:", paste(raw_violations, collapse = ", "))
  )
}

if (length(prohibited_binary_files) > 0) {
  errors <- c(
    errors,
    paste("Prohibited document/source file types:", paste(prohibited_binary_files, collapse = ", "))
  )
}

if (nrow(violations) > 0) {
  errors <- c(
    errors,
    paste(
      "Private identifier or credential pattern found:",
      paste(paste(violations$File, violations$Pattern, sep = " -> "), collapse = "; ")
    )
  )
}

if (length(errors) > 0) {
  message("Public-safety validation failed.")
  for (error in errors) {
    message("- ", error)
  }
  quit(status = 1)
}

message("Public-safety validation passed.")
message("Checked ", length(text_files), " text files and ", length(project_files), " total files.")
