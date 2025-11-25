# === SETUP ===

# Import packages
library(tidyverse)
library(stringr)
library(lubridate)
library(googledrive)
library(dotenv)
library(readr)
library(here)

# Load .env file
dotenv::load_dot_env(file=here(".env"))
folder_id <-Sys.getenv("DRIVE_ID")

# Google drive 
drive_deauth()	#public folder, so no auth needed
fld <- as_id(folder_id)
folder <- drive_ls(fld)

# === INPUT ===
targets_opta <- folder$name[str_starts(folder$name, 'opta_data')]
targets_oddsportal <- folder$name[str_starts(folder$name, 'oddsportal_data')]
opta_rows <- folder[folder$name %in% targets_opta, ]
oddsportal_rows <- folder[folder$name %in% targets_oddsportal, ]
saved_paths_opta <- c()
saved_paths_oddsportal <- c()
for (i in seq_len(nrow(opta_rows))) {
	local_path = file.path(here("data","opta", opta_rows$name[i]))
	saved_paths_opta[i] <- local_path
	drive_download(
		file      = opta_rows[i, ],
		path      = local_path,
		overwrite = TRUE
	)
}

for (i in seq_len(nrow(oddsportal_rows))) {
	local_path = file.path(here("data","oddsportal", oddsportal_rows$name[i]))
	saved_paths_oddsportal[i] <- local_path
	drive_download(
		file      = oddsportal_rows[i, ],
		path      = local_path,
		overwrite = TRUE
	)
}

# Create local up to date datasets for opta and oddsportal data
opta <- saved_paths_opta%>%
	lapply(read_csv)%>%
	bind_rows()

oddsportal <- saved_paths_oddsportal%>%
	lapply(read_csv)%>%
	bind_rows()

# Save the combined dataframes
write_csv(opta, here('data','opta', 'opta_merged.csv'))
write_csv(oddsportal, here('data', 'oddsportal', 'oddsportal_merged.csv'))

cat('opta data saved at', here('data','opta', 'opta_merged.csv'))
cat('oddsportal data saved at', here('data', 'oddsportal', 'oddsportal_merged.csv'))