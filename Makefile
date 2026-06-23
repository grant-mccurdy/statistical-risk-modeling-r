.PHONY: all data model report validate report-rmd clean

RSCRIPT ?= Rscript --vanilla

all: data model report validate

data:
	$(RSCRIPT) R/generate_synthetic_data.R

model: data
	$(RSCRIPT) R/fit_risk_models.R

report: model
	$(RSCRIPT) R/render_markdown_report.R

validate:
	$(RSCRIPT) R/validate_public_safety.R

report-rmd:
	$(RSCRIPT) -e "rmarkdown::render('reports/statistical_risk_modeling_report.Rmd', output_format='github_document', knit_root_dir=getwd())"

clean:
	rm -f data/processed/synthetic_account_risk.csv
	rm -f reports/*.csv reports/model_artifacts.rds reports/statistical_risk_modeling_report.md
	rm -f figures/*.png
