# Public-Safety Notes

This repository is a public-safe portfolio project. It preserves statistical
modeling methods and report structure while excluding private source material.

## Excluded Material

The project intentionally excludes:

- Professor prompts, exams, rubrics, syllabi, lecture transcripts, and private
  course documents
- Raw private coursework files and source datasets
- Real student, patient, school-private, customer, credential, or personal data
- Private local paths, tokens, API keys, and credentials
- Copyrighted source documents that are not licensed for redistribution

## Public-Safe Replacement

The analysis uses synthetic B2B account-risk records generated from transparent
simulation rules. The dataset is not calibrated to a private person, school,
patient cohort, employer, or customer base.

The business framing is original: predicting whether an account should receive
an escalation review in the next quarter. The private source work was used only
to identify transferable methods such as GLM model comparison, validation,
calibration, threshold interpretation, and sensitivity analysis.

## Validation

Run:

```bash
make validate
```

The validation script checks that the project does not contain known private
source identifiers, prohibited source document formats, or raw files in
`data/raw/` beyond this README.
