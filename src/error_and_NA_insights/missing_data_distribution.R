library(dplyr)
library(stringr)
library(readr)
library(lubridate)

opta <- read_csv("data/opta/opta_standardized.csv")
oddsportal <- read_csv("data/oddsportal/oddsportal_standardized.csv")

# ===========
# ODDSPORTAL
# ===========
# Parse kickoff times from raw string (dmy_hm = day-month-year hour:minute)
oddsportal$kickoff <- dmy_hm(oddsportal$KickoffRaw)

# Overview of missingness (for inspection / logging)
oddsportal$HomeOdd[oddsportal$HomeOdd == "-"] <- NA
oddsportal$AwayOdd[oddsportal$AwayOdd == "-"] <- NA

missing_table_oddsportal <- oddsportal %>%
  summarise(across(everything(), ~ sum(is.na(.))))
 #96 NAs in kickoff (game kickoff time variable)
 #77 corresponding NAs in HomeTeam and AwayTeam (football team name variables)

# Remove rows missing crucial fields
oddsportal <- oddsportal %>%
  filter(
    !is.na(kickoff),
    !is.na(HomeTeam),
    !is.na(AwayTeam)
  )

oddsportal_unique_matches <-
  oddsportal %>%
  distinct(HomeTeam, AwayTeam, Competition, KickoffRaw) %>%
  nrow()
 #2304 unique matches

# Create match_id
oddsportal <- oddsportal %>%
  mutate(
    home_clean = gsub(" ", "", HomeTeam),
    away_clean = gsub(" ", "", AwayTeam),
    date_clean = format(kickoff, "%d%m%Y"),
    match_id = paste0(tolower(home_clean), "_", tolower(away_clean), "_", date_clean)
  ) %>%
  ungroup() %>%
  select(-home_clean, -away_clean, -date_clean)

# =====================
# OPTA PLAYER STATS
# =====================
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

NAs_opta <- colSums(is.na(opta))
 #0 NAs

# ============================================
# SELECT oddsportal DATA THAT IS ALSO IN opta
# ============================================
#- only select oddsportal data when match id is %in% opta$match_id
oddsportal <- oddsportal[oddsportal$match_id %in% opta$match_id, ]

# =====================
# MISSING VALUE STATS
# =====================
missing_table <- oddsportal %>%
  summarise(across(everything(), ~ sum(is.na(.))))
 #4765 NAs in home and away odds

# Number of unique matches before filtering out home and away odds NAs
number_unique_matches <-
  oddsportal %>%
  distinct(HomeTeam, AwayTeam, Competition, KickoffRaw) %>%
  nrow()
 #2128 unique matches

# Filter out observations with NAs in home and away odds variables
oddsportal_NAs_filtered <- oddsportal %>%
  filter(
    !is.na(HomeOdd),
    !is.na(AwayOdd)
  )

#Number of unique matches after filtering out home and away odds NAs
number_unique_matches <-
  oddsportal_NAs_filtered %>%
  distinct(HomeTeam, AwayTeam, Competition, KickoffRaw) %>%
  nrow()

# =================================
# FINAL DATASET (football_matches)
# =================================
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
if (!dir.exists("data/merged")) {
  dir.create("data/merged", recursive = TRUE)
}
write_csv(football_matches, "data/merged/football_matches.csv")

# ============================================================
# DESCRIPTIVE ANALYSIS OF NA DISTRIBUTION ACROSS COMPETITIONS
# ============================================================

# 1) Overall number and proportion of missing values per variable
overall_na <- oddsportal %>%
  summarise(
    across(
      .cols = everything(),
      .fns  = list(
        n_na = ~sum(is.na(.)),      # number of NAs
        p_na = ~mean(is.na(.))      # proportion of NAs
      ),
      .names = "{.col}_{.fn}"
    )
  )
overall_na

# 2) Observation-level missingness by league
na_by_league <- oddsportal %>%
  group_by(Competition) %>%                         # group by league/competition
  summarise(
    n_matches = n_distinct(match_id),          # number of unique matches in league
    n_obs     = n(),                           # number of observations in league
    across(
      .cols  = c("HomeOdd", "AwayOdd"),
      .fns   = ~mean(is.na(.)),                # share of missing values per variable
      .names = "p_na_{.col}"
    ),
    .groups = "drop"
  )
na_by_league

# 3) Match-level missingness, summarized by league
match_na <- oddsportal %>%
  group_by(match_id, Competition) %>%
  summarise(
    n_obs_match = n(),
    # proportion of observations for this match with missing odds
    p_na_HomeOdds = mean(is.na(HomeOdd)),
    p_na_AwayOdds = mean(is.na(AwayOdd)),
    .groups = "drop"
  )
match_na_by_league <- match_na %>%
  group_by(Competition) %>%
  summarise(
    n_matches     = n(),
    mean_p_na_HomeOdds = mean(p_na_HomeOdds),
    mean_p_na_AwayOdds = mean(p_na_AwayOdds),
    .groups = "drop"
  ) %>%
  arrange(desc(mean_p_na_HomeOdds))
match_na_by_league
