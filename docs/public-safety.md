# Public-Safety Notes

This repository is a public-safe portfolio project. It preserves statistical
modeling and communication methods while excluding private source material.

## Excluded Material

The project intentionally excludes:

- Professor prompts, exams, rubrics, syllabi, lecture transcripts, and private
  course documents
- Raw private coursework files and private source datasets
- Real student, personnel, patient, school-private, customer, credential, or
  personal data
- Private local paths, tokens, API keys, and credentials
- Copyrighted source documents that are not licensed for redistribution

## Public-Safe Replacement

The analysis uses public-safe education assessment records. The data contains
simulated student, teacher, course, section, attendance, assessment-window, and
readiness fields. Score and readiness behavior is generalized from a
bootstrapped assessment workflow, but the repository does not include real
student-identifiable data, private rosters, raw LMS exports, exact source rows,
private assessment artifacts, or real personnel records.

The public framing is original: analyzing BOY/EOY improvement and section-level
growth signals in a public-safe assessment workflow. The implementation
preserves transferable methods such as paired improvement analysis,
model-family comparison, cross-validation, residual diagnostics, sensitivity
analysis, and executive-facing communication.

## Validation

Run:

```bash
make validate
```

The validation script checks that the project does not contain known private
source identifiers, prohibited source document formats, or unexpected raw files.
The only permitted raw data file is the public-safe education assessment extract
documented in `data/raw/README.md`.
