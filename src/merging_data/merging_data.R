# === SETUP ===

# Import packages
library(tidyverse)
library(stringr)
library(lubridate)
library(googledrive)
library(dotenv)
library(readr)
library(here)

# Load .env file (contains DRIVE_ID)
dotenv::load_dot_env(file = here(".env"))
folder_id <- Sys.getenv("DRIVE_ID")

# Ensure local directories exist
dir.create(here("data", "opta"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("data", "oddsportal"), recursive = TRUE, showWarnings = FALSE)

# Google Drive: no authentication needed (public folder)
drive_deauth()
fld <- as_id(folder_id)
folder <- drive_ls(fld)

# === INPUT ===

# Identify Opta and OddsPortal files by prefix
targets_opta       <- folder$name[str_starts(folder$name, "opta_data")]
targets_oddsportal <- folder$name[str_starts(folder$name, "oddsportal_data")]

opta_rows       <- folder[folder$name %in% targets_opta, ]
oddsportal_rows <- folder[folder$name %in% targets_oddsportal, ]

saved_paths_opta       <- c()
saved_paths_oddsportal <- c()

# Download Opta files
for (i in seq_len(nrow(opta_rows))) {
	local_path <- file.path(here("data", "opta", opta_rows$name[i]))
	saved_paths_opta[i] <- local_path
	
	drive_download(
		file      = opta_rows[i, ],
		path      = local_path,
		overwrite = TRUE
	)
}

# Download OddsPortal files
for (i in seq_len(nrow(oddsportal_rows))) {
	local_path <- file.path(here("data", "oddsportal", oddsportal_rows$name[i]))
	saved_paths_oddsportal[i] <- local_path
	
	drive_download(
		file      = oddsportal_rows[i, ],
		path      = local_path,
		overwrite = TRUE
	)
}

# === TRANSFORMATION ===

# Load and merge all Opta files
opta <- saved_paths_opta %>%
	lapply(read_csv) %>%
	bind_rows()

# Load and merge all OddsPortal files
oddsportal <- saved_paths_oddsportal %>%
	lapply(read_csv) %>%
	bind_rows()

# === OUTPUT ===

write_csv(opta, here("data", "opta", "opta_merged.csv"))
write_csv(oddsportal, here("data", "oddsportal", "oddsportal_merged.csv"))

cat("opta data saved at", here("data", "opta", "opta_merged.csv"), "\n")
cat("oddsportal data saved at", here("data", "oddsportal", "oddsportal_merged.csv"), "\n")
