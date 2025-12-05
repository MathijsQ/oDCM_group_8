# -----------------------------------
# Makefile: Compute Tail Probabilities (Likelihood Analysis)
# -----------------------------------

# ----------------------------
# Input and Output Directories
# ----------------------------
DATA_DIR_MERGED := ../../data/merged_opta_oddsportal

# ----------------------------
# Input Files
# ----------------------------
RESULTS_WITH_PARAMS := $(DATA_DIR_MERGED)/results_with_params.csv

# ----------------------------
# Script
# ----------------------------
SCRIPT := likelihood.R

# ----------------------------
# Output Files
# ----------------------------
RESULTS_TAIL_PROB := $(DATA_DIR_MERGED)/results_params_tail_probabilities.csv

TARGETS := $(RESULTS_TAIL_PROB)

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
# Likelihood / Tail Probability Rule
# ----------------------------
$(TARGETS): $(SCRIPT) $(RESULTS_WITH_PARAMS) | $(DATA_DIR_MERGED)
	@echo "Computing extremeness (tail probabilities) for all matches..."
	Rscript $(SCRIPT)

# ----------------------------
# Clean Rule
# ----------------------------
.PHONY: clean
clean:
	@echo "Deleting tail-probability results..."
	Rscript -e "unlink('$(RESULTS_TAIL_PROB)', force = TRUE)"
