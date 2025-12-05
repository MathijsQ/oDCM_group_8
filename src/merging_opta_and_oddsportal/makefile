# -----------------------------------
# Makefile: Merge Opta Results with Bookmaker Parameters
# -----------------------------------

# ----------------------------
# Input and Output Directories
# ----------------------------
DATA_DIR_OPTA           := ../../data/opta
DATA_DIR_ODDSPORTAL     := ../../data/oddsportal
DATA_DIR_MERGED         := ../../data/merged_opta_oddsportal

# ----------------------------
# Input Files
# ----------------------------
OPTA_STANDARDIZED       := $(DATA_DIR_OPTA)/opta_standardized.csv
BOOKMAKER_PARAMS        := $(DATA_DIR_ODDSPORTAL)/bookmaker_fitted_params.csv

# ----------------------------
# Script
# ----------------------------
SCRIPT := merging_opta_and_oddsportal.R

# ----------------------------
# Output Files
# ----------------------------
MERGED_RESULTS := $(DATA_DIR_MERGED)/results_with_params.csv

TARGETS := $(MERGED_RESULTS)

# ----------------------------
# Default Target
# ----------------------------
all: $(TARGETS)

# ----------------------------
# Directory Creation Rule
# ----------------------------
$(DATA_DIR_MERGED):
	Rscript -e "if (!dir.exists('$(DATA_DIR_MERGED)')) dir.create('$(DATA_DIR_MERGED)', recursive = TRUE)"

# ----------------------------
# Merging Rule
# ----------------------------
$(TARGETS): $(SCRIPT) $(OPTA_STANDARDIZED) $(BOOKMAKER_PARAMS) | $(DATA_DIR_MERGED)
	@echo "Merging Opta results with fitted bookmaker parameters..."
	Rscript $(SCRIPT)

# ----------------------------
# Clean Rule
# ----------------------------
.PHONY: clean
clean:
	@echo "Deleting merged Opta–OddsPortal dataset..."
	Rscript -e "unlink('$(MERGED_RESULTS)', force = TRUE)"
