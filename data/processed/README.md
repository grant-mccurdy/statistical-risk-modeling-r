# Processed Data

Generated public-safe modeling files are written here by the R pipeline.

The primary generated dataset is:

```text
data/processed/education_readiness_risk.csv
```

It contains one row per public-safe assessment transition. Current-window
features are used to predict whether the next assessment window will require
support review.

Regenerate it with:

```bash
make data
```
