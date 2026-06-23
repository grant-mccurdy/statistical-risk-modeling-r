.PHONY: all data model report report-pdf validate report-rmd clean

RSCRIPT ?= Rscript --vanilla

all: data model report validate

data:
	$(RSCRIPT) R/generate_synthetic_data.R

model: data
	$(RSCRIPT) R/fit_growth_models.R

report: model
	$(RSCRIPT) R/render_markdown_report.R

report-pdf: report
	$(RSCRIPT) -e "rmarkdown::render('reports/assessment_growth_section_performance_report.Rmd', output_format='pdf_document', output_file='assessment_growth_section_performance_report.pdf', knit_root_dir=getwd())"

validate:
	$(RSCRIPT) R/validate_public_safety.R

report-rmd:
	$(RSCRIPT) -e "rmarkdown::render('reports/assessment_growth_section_performance_report.Rmd', output_format='github_document', knit_root_dir=getwd())"

clean:
	rm -f data/processed/education_readiness_risk.csv data/processed/education_section_growth.csv
	rm -f reports/*.csv reports/model_artifacts.rds reports/*_report.md
	rm -f reports/*_report.pdf
	rm -f figures/*.png
