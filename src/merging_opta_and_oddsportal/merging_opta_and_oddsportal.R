library(dplyr)
library(stringr)
library(readr)
library(lubridate)
library(here)


opta <- read_csv(here("data", "opta", "opta_standardized.csv"))
oddsportal <- read_csv(here("data", "oddsportal", "bookmaker_fitted_params.csv"))


# ==========================
# OPTA PLAYER STATS MATCH ID
# ==========================
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

# ==========================================
# MERGE PROCESSED OPTA PLAYER STATS AND 
# ODDSPORTAL DATASETS INTO football_matches
# ==========================================
football_matches <- merge(opta[c('match_id', 'HomeGoals', 'AwayGoals')],oddsportal,
						  by = c('match_id'),
						  all= FALSE)



if (!dir.exists(here("data", "merged_opta_oddsportal"))) {
  dir.create(here("data", "merged_opta_oddsportal"), recursive = TRUE)
}
write_csv(football_matches, here("data", "merged_opta_oddsportal", "results_with_params.csv"))