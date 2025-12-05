# -----------------------------------
# Root Makefile: Full Data Pipeline
# -----------------------------------

# Base source directory (relative to project root)
SRC := src

# Submodules (locations of the sub-Makefiles)
MERGING_DATA            := $(SRC)/merging_data
STANDARDIZE_TEAMNAMES   := $(SRC)/standardize_teamnames
MODELLING               := $(SRC)/modelling
PROBABILITY_COMPUTATION := $(SRC)/probability_computation
FORMATTING_FINAL        := $(SRC)/formatting_final_datasets
FINAL_REPORT            := $(SRC)/final_report

# -----------------------------------
# Default target: full pipeline
# -----------------------------------
all: timestamps standardize modelling likelihood formatting report
	@echo "Full pipeline executed successfully."

# -----------------------------------
# Alternative target: timestamps only
# -----------------------------------
timestamps_only: timestamps
	@echo "Timestamp merging step executed successfully."

# -----------------------------------
# Individual step targets
# -----------------------------------
timestamps:
	$(MAKE) -C $(MERGING_DATA)

standardize: timestamps
	$(MAKE) -C $(STANDARDIZE_TEAMNAMES)

modelling: standardize
	$(MAKE) -C $(MODELLING)

likelihood: modelling
	$(MAKE) -C $(PROBABILITY_COMPUTATION)

formatting: likelihood
	$(MAKE) -C $(FORMATTING_FINAL)

report: formatting
	$(MAKE) -C $(FINAL_REPORT)

# -----------------------------------
# Clean everything (in reverse order)
# -----------------------------------
.PHONY: clean all timestamps_only \
        timestamps standardize modelling likelihood formatting report

clean:
	@echo "Cleaning all submodules..."
	-$(MAKE) -C $(FINAL_REPORT) clean
	-$(MAKE) -C $(FORMATTING_FINAL) clean
	-$(MAKE) -C $(PROBABILITY_COMPUTATION) clean
	-$(MAKE) -C $(MODELLING) clean
	-$(MAKE) -C $(STANDARDIZE_TEAMNAMES) clean
	-$(MAKE) -C $(MERGING_DATA) clean
	@echo "All submodules cleaned."
