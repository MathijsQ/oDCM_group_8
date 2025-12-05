# -----------------------------------
# Makefile: Final Dataset Formatting
# -----------------------------------

# ----------------------------
# Input and Output Directories
# ----------------------------
DATA_DIR_MERGED        := ../../data/merged_opta_oddsportal
DATA_DIR_ODDSPORTAL    := ../../data/oddsportal
DATA_DIR_FINAL         := ../../final_datasets

# ----------------------------
# Input Files
# ----------------------------
TAIL_PROBABILITIES     := $(DATA_DIR_MERGED)/results_params_tail_probabilities.csv
BOOKMAKER_LINES_FITTED := $(DATA_DIR_ODDSPORTAL)/bookmaker_lines_fitted.csv

# ----------------------------
# Script
# ----------------------------
SCRIPT := formatting.R

# ----------------------------
# Output Files
# ----------------------------
MATCH_MODEL_RESULTS    := $(DATA_DIR_FINAL)/match_model_results.csv
BOOKMAKER_MODEL_ODDS   := $(DATA_DIR_FINAL)/bookmaker_vs_model_odds.csv

TARGETS := $(MATCH_MODEL_RESULTS) $(BOOKMAKER_MODEL_ODDS)

# ----------------------------
# Default Target
# ----------------------------
all: $(TARGETS)

# ----------------------------
# Directory Creation
# ----------------------------
$(DATA_DIR_FINAL):
	Rscript -e "if (!dir.exists('$(DATA_DIR_FINAL)')) dir.create('$(DATA_DIR_FINAL)', recursive = TRUE)"

# ----------------------------
# Formatting Rule
# ----------------------------
$(TARGETS): $(SCRIPT) $(TAIL_PROBABILITIES) $(BOOKMAKER_LINES_FITTED) | $(DATA_DIR_FINAL)
	@echo "Formatting final datasets..."
	Rscript $(SCRIPT)

# ----------------------------
# Clean Rule
# ----------------------------
.PHONY: clean
clean:
	@echo "Deleting formatted final datasets..."
	Rscript -e "unlink(c('$(MATCH_MODEL_RESULTS)', '$(BOOKMAKER_MODEL_ODDS)'), force = TRUE)"
