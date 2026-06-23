# Processed Data

Generated public-safe modeling files are written here by the R pipeline.

The primary generated dataset is:

```text
data/processed/education_section_growth.csv
```

It contains one row per same-student BOY/EOY pair where both assessments are
present and the section and simulated teacher match across the pair. The main
metric is:

```text
score_gain = eoy_score - boy_score
```

The pipeline also regenerates `education_readiness_risk.csv` as a supporting
transition table from the original project history, but the primary report now
uses the BOY/EOY growth table.

Regenerate processed data with:

```bash
make data
```
