# -----------------------------------
# Makefile: Standardize Opta & OddsPortal Data
# -----------------------------------

# ----------------------------
# Input and Output Directories
# ----------------------------
DATA_DIR_OPTA       := ../../data/opta
DATA_DIR_ODDSPORTAL := ../../data/oddsportal

# ----------------------------
# Input Files
# ----------------------------
OPTA_MERGED       := $(DATA_DIR_OPTA)/opta_merged.csv
ODDSPORTAL_MERGED := $(DATA_DIR_ODDSPORTAL)/oddsportal_merged.csv

# ----------------------------
# Script
# ----------------------------
# Assumes this Makefile is in the same directory as standardize_teamnames.R
SCRIPT := standardize_teamnames.R

# ----------------------------
# Output Files
# ----------------------------
OPTA_STANDARDIZED       := $(DATA_DIR_OPTA)/opta_standardized.csv
ODDSPORTAL_STANDARDIZED := $(DATA_DIR_ODDSPORTAL)/oddsportal_standardized.csv

TARGETS := $(OPTA_STANDARDIZED) $(ODDSPORTAL_STANDARDIZED)

# ----------------------------
# Default Target
# ----------------------------
all: $(TARGETS)

# ----------------------------
# Directory Creation Rules
# ----------------------------
$(DATA_DIR_OPTA):
	Rscript -e "if (!dir.exists('$(DATA_DIR_OPTA)')) dir.create('$(DATA_DIR_OPTA)', recursive = TRUE)"

$(DATA_DIR_ODDSPORTAL):
	Rscript -e "if (!dir.exists('$(DATA_DIR_ODDSPORTAL)')) dir.create('$(DATA_DIR_ODDSPORTAL)', recursive = TRUE)"

# ----------------------------
# Standardization Rule
# ----------------------------
$(TARGETS): $(SCRIPT) $(OPTA_MERGED) $(ODDSPORTAL_MERGED) | $(DATA_DIR_OPTA) $(DATA_DIR_ODDSPORTAL)
	@echo "Running teamname/competition standardization script..."
	Rscript $(SCRIPT)

# ----------------------------
# Clean Rule
# ----------------------------
.PHONY: clean
clean:
	@echo "Deleting standardized Opta and OddsPortal files..."
	Rscript -e "unlink(c('$(OPTA_STANDARDIZED)', '$(ODDSPORTAL_STANDARDIZED)'), force = TRUE)"
