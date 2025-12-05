library(dplyr)
library(readr)
library(stringr)
library(here)

# Ensure required directories exist
dir.create(here("data", "opta"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("data", "oddsportal"), recursive = TRUE, showWarnings = FALSE)

# === INPUT =================================================================
# Raw datasets
opta       <- read_csv(here("data", "opta", "opta_merged.csv"))
oddsportal <- read_csv(here("data", "oddsportal", "oddsportal_merged.csv"))
# Error log databases
opta_db       <- read_csv(here("data", "scraping_logs", "opta_database.csv"))
oddsportal_db <- read_csv(here("data", "scraping_logs", "oddsportal_database.csv"))

# === TRANSFORMATIONS =======================================================
# Rename columns with HTML identifiers in error log databases
opta_db <- opta_db %>%
  rename(html_opta = match_id)
oddsportal_db <- oddsportal_db %>%
  rename(html_oddsportal = scrape_id)

# ==========
# ODDSPORTAL
# ==========
# Create html_oddsportal ID from Filename (drop "ah_"/"ou_" prefix and ".html" suffix)
oddsportal <- oddsportal %>%
  mutate(
    html_oddsportal = Filename %>%
      str_remove("^ah_") %>%
      str_remove("^ou_") %>%
      str_remove("\\.html$")) %>%
  select(-Filename)

# Join Asian Handicap timestamps (most recent) from error count data base ("oddsportal_db") to OddsPortal raw dataset
oddsportal <- oddsportal %>%
  left_join(oddsportal_db %>% select(html_oddsportal, timestamp_ah),
    by = "html_oddsportal")%>%
	rename(
		timestamp = timestamp_ah
	)

# =====
# OPTA
# =====
# Create html_opta ID from Filename (drop ".html" suffix)
opta <- opta %>%
  mutate(html_opta = str_remove(Filename, "\\.html$")) %>%
  select(-Filename)

# Join timestamps from error count data base ("opta_db") to Opta raw dataset
opta <- opta %>%
  left_join(opta_db %>% select(html_opta, timestamp),
    by = "html_opta")

# === OUTPUT ===========================================================
write_csv(opta, here("data", "opta", "opta_merged_with_timestamps.csv"))
write_csv(oddsportal, here("data", "oddsportal", "oddsportal_merged_with_timestamps.csv"))

paste0('raw data with timestamps csv files created at:', here("data", "opta", "opta_merged_with_timestamps.csv"))
paste0('raw data with timestamps csv files created at:', here("data", "oddsportal", "oddsportal_merged_with_timestamps.csv"))
