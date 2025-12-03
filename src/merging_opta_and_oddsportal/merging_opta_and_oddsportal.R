library(dplyr)
library(stringr)
library(readr)
library(lubridate)
library(here)


opta <- read_csv(here("data", "opta", "opta_standardized.csv"))
oddsportal <- read_csv(here("data", "oddsportal", "oddsportal_standardized.csv"))

# ===========
# ODDSPORTAL
# ===========
# Parse kickoff times from raw string (dmy_hm = day-month-year hour:minute)
oddsportal$kickoff <- dmy_hm(oddsportal$KickoffRaw)

# Code odds variable missing data as NAs
oddsportal$HomeOdd[oddsportal$HomeOdd == "-"] <- NA
oddsportal$AwayOdd[oddsportal$AwayOdd == "-"] <- NA

# Remove rows missing crucial fields
oddsportal <- oddsportal %>%
  filter(
    !is.na(kickoff),
    !is.na(HomeTeam),
    !is.na(AwayTeam))

# Create match_id
oddsportal <- oddsportal %>%
  mutate(
    home_clean = gsub(" ", "", HomeTeam),
    away_clean = gsub(" ", "", AwayTeam),
    date_clean = format(kickoff, "%d%m%Y"),
    match_id = paste0(tolower(home_clean), "_", tolower(away_clean), "_", date_clean) ) %>%
  ungroup() %>%
  select(-home_clean, -away_clean, -date_clean)

# ==================
# OPTA PLAYER STATS
# ==================
#-Create opta match id’s in the same way as for oddsportal
opta$kickoff <- dmy_hm(opta$KickoffTimeRaw)
opta <- opta %>%
  mutate(
    home_clean = gsub(" ", "", HomeTeam),
    away_clean = gsub(" ", "", AwayTeam),
    date_clean = format(kickoff, "%d%m%Y"),
    match_id = paste0(tolower(home_clean), "_", tolower(away_clean), "_", date_clean)
  ) %>%
  ungroup() %>%
  select(-home_clean, -away_clean, -date_clean)

# ============================================
# SELECT oddsportal DATA THAT IS ALSO IN opta
# ============================================
# Only select oddsportal data when match id is %in% opta$match_id
oddsportal <- oddsportal[oddsportal$match_id %in% opta$match_id, ]

# Filter out observations with NAs in home and away odds variables
oddsportal_NAs_filtered <- oddsportal %>%
  filter(
    !is.na(HomeOdd),
    !is.na(AwayOdd))

# ==========================================
# MERGE PROCESSED OPTA PLAYER STATS AND 
# ODDSPORTAL DATASETS INTO football_matches
# ==========================================
football_matches <- oddsportal_NAs_filtered %>%
  rename(html_oddsportal = Filename) %>%
  left_join(
    opta %>% 
      select(match_id, HomeGoals, AwayGoals, html_opta = Filename), 
    by = "match_id")
# Removing ".html" suffix from html variables, and "ah_" or "ou_" prefix from html_oddsportal
football_matches <- football_matches %>%
  mutate(
    html_opta = str_remove(html_opta, "\\.html$"),
    html_oddsportal = html_oddsportal %>%
      str_remove("^ah_") %>%
      str_remove("^ou_") %>%
      str_remove("\\.html$")
  )
if (!dir.exists(here("data", "merged_opta_oddsportal"))) {
  dir.create(here("data", "merged_opta_oddsportal"), recursive = TRUE)
}
write_csv(football_matches, here("data", "merged_opta_oddsportal", "football_matches.csv"))