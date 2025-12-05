# -----------------------------------
# Makefile: Fit Bivariate Poisson Model
# -----------------------------------

# ----------------------------
# Input and Output Directories
# ----------------------------
DATA_DIR_ODDSPORTAL := ../../data/oddsportal

# ----------------------------
# Input Files
# ----------------------------
ODDSPORTAL_STANDARDIZED := $(DATA_DIR_ODDSPORTAL)/oddsportal_standardized.csv

# ----------------------------
# Script
# ----------------------------
SCRIPT := fit_bivariate_poisson.R

# ----------------------------
# Output Files
# ----------------------------
BOOKMAKER_LINES_FITTED := $(DATA_DIR_ODDSPORTAL)/bookmaker_lines_fitted.csv
BOOKMAKER_PARAMS       := $(DATA_DIR_ODDSPORTAL)/bookmaker_fitted_params.csv

TARGETS := $(BOOKMAKER_LINES_FITTED) $(BOOKMAKER_PARAMS)

# ----------------------------
# Default Target
# ----------------------------
all: $(TARGETS)

# ----------------------------
# Directory Creation Rule
# ----------------------------
$(DATA_DIR_ODDSPORTAL):
	Rscript -e "if (!dir.exists('$(DATA_DIR_ODDSPORTAL)')) dir.create('$(DATA_DIR_ODDSPORTAL)', recursive = TRUE)"

# ----------------------------
# Model Fitting Rule
# ----------------------------
$(TARGETS): $(SCRIPT) $(ODDSPORTAL_STANDARDIZED) | $(DATA_DIR_ODDSPORTAL)
	@echo "Running bivariate Poisson fitting script..."
	Rscript $(SCRIPT)

# ----------------------------
# Clean Rule
# ----------------------------
.PHONY: clean
clean:
	@echo "Deleting fitted bookmaker model outputs..."
	Rscript -e "unlink(c('$(BOOKMAKER_LINES_FITTED)', '$(BOOKMAKER_PARAMS)'), force = TRUE)"
