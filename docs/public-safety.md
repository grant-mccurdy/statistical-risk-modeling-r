# Public-Safety Notes

This repository is a public-safe portfolio project. It preserves statistical
modeling and communication methods while excluding private source material.

## Excluded Material

The project intentionally excludes:

- Professor prompts, exams, rubrics, syllabi, lecture transcripts, and private
  course documents
- Raw private coursework files and private source datasets
- Real student, patient, school-private, customer, credential, or personal data
- Private local paths, tokens, API keys, and credentials
- Copyrighted source documents that are not licensed for redistribution

## Public-Safe Replacement

The analysis uses public-safe education assessment records. The data contains
simulated student, teacher, course, section, attendance, assessment-window, and
readiness fields. Score and readiness behavior is generalized from a
bootstrapped assessment workflow, but the repository does not include real
student-identifiable data, private rosters, raw LMS exports, exact source rows,
or private assessment artifacts.

The public framing is original: predicting whether a public-safe assessment
transition should receive human support review at the next assessment window.
The implementation preserves transferable methods such as model-family
comparison, GLM validation, calibration, threshold interpretation, diagnostics,
sensitivity analysis, and executive-facing communication.

## Validation

Run:

```bash
make validate
```

The validation script checks that the project does not contain known private
source identifiers, prohibited source document formats, or unexpected raw files.
The only permitted raw data file is the public-safe education assessment extract
documented in `data/raw/README.md`.
