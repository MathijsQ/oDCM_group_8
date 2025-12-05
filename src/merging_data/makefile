# -----------------------------------
# Makefile: Merge Raw Data with Timestamp Logs
# -----------------------------------

# ----------------------------
# Input and Output Directories
# ----------------------------
DATA_DIR_OPTA        := ../../data/opta
DATA_DIR_ODDSPORTAL  := ../../data/oddsportal
DATA_DIR_LOGS        := ../../data/scraping_logs

# ----------------------------
# Input Files
# ----------------------------
OPTA_MERGED              := $(DATA_DIR_OPTA)/opta_merged.csv
ODDSPORTAL_MERGED        := $(DATA_DIR_ODDSPORTAL)/oddsportal_merged.csv
OPTA_LOGS                := $(DATA_DIR_LOGS)/opta_database.csv
ODDSPORTAL_LOGS          := $(DATA_DIR_LOGS)/oddsportal_database.csv

# ----------------------------
# Script
# ----------------------------
SCRIPT := merging_data_with_timestamps.R

# ----------------------------
# Output Files
# ----------------------------
OPTA_WITH_TIMESTAMPS        := $(DATA_DIR_OPTA)/opta_merged_with_timestamps.csv
ODDSPORTAL_WITH_TIMESTAMPS  := $(DATA_DIR_ODDSPORTAL)/oddsportal_merged_with_timestamps.csv

TARGETS := $(OPTA_WITH_TIMESTAMPS) $(ODDSPORTAL_WITH_TIMESTAMPS)

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
# Merge-with-Timestamps Rule
# ----------------------------
$(TARGETS): $(SCRIPT) $(OPTA_MERGED) $(ODDSPORTAL_MERGED) $(OPTA_LOGS) $(ODDSPORTAL_LOGS) | $(DATA_DIR_OPTA) $(DATA_DIR_ODDSPORTAL)
	@echo "Merging datasets with timestamp logs..."
	Rscript $(SCRIPT)

# ----------------------------
# Clean Rule
# ----------------------------
.PHONY: clean
clean:
	@echo "Deleting merged timestamp datasets..."
	Rscript -e "unlink(c('$(OPTA_WITH_TIMESTAMPS)', '$(ODDSPORTAL_WITH_TIMESTAMPS)'), force = TRUE)"
