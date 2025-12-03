library(dplyr)
library(stringr)
library(readr)
library(lubridate)
library(here)


opta <- read_csv(here("data", "opta", "opta_standardized.csv"))
oddsportal <- read_csv(here("data", "oddsportal", "oddsportal_standardized.csv"))

# ===========================================================================
# ODDSPORTAL: Missing Data Insights of Raw and Processed OddsPortal Datasets
# ===========================================================================
# Processing: Parse kickoff times from raw string (dmy_hm = day-month-year hour:minute)
oddsportal$kickoff <- dmy_hm(oddsportal$KickoffRaw)
# Processing: Code odds variables missing data as NAs
oddsportal$HomeOdd[oddsportal$HomeOdd == "-"] <- NA
oddsportal$AwayOdd[oddsportal$AwayOdd == "-"] <- NA

# Insight: Overview of missing data in "raw" OddsPortal scraped dataset
missing_table_oddsportal <- oddsportal %>%
  summarise(across(everything(), ~ sum(is.na(.))))
 #96 NAs in kickoff (game kickoff time variable)
 #77 corresponding NAs in HomeTeam and AwayTeam (football team name variables)
 #5149 corresponding NAs in HomeOdd and AwayOdd (odds)

# Processing: Remove rows missing kickoff time and/or team names (these are crucial to create the match_id's)
oddsportal <- oddsportal %>%
  filter(
    !is.na(kickoff),
    !is.na(HomeTeam),
    !is.na(AwayTeam))

# Insight: Number of matches after removing rows with missing data in kickoff time and/or team names
oddsportal_unique_matches <-
  oddsportal %>%
  distinct(HomeTeam, AwayTeam, Competition, KickoffRaw) %>%
  nrow()
 #2304 unique matches

# Processing: Create match_id
oddsportal <- oddsportal %>%
  mutate(
    home_clean = gsub(" ", "", HomeTeam),
    away_clean = gsub(" ", "", AwayTeam),
    date_clean = format(kickoff, "%d%m%Y"),
    match_id = paste0(tolower(home_clean), "_", tolower(away_clean), "_", date_clean)
  ) %>%
  ungroup() %>%
  select(-home_clean, -away_clean, -date_clean)

# =========================================================================================
# OPTA PLAYER STATS: Missing Data Insights of Raw and Processed Opta Player Stats Datasets
# =========================================================================================
# Processing: Create opta match id’s in the same way as for oddsportal
opta$kickoff <- dmy_hm(opta$KickoffTimeRaw)
opta <- opta %>%
  mutate(
    home_clean = gsub(" ", "", HomeTeam),
    away_clean = gsub(" ", "", AwayTeam),
    date_clean = format(kickoff, "%d%m%Y"),
    match_id = paste0(tolower(home_clean), "_", tolower(away_clean), "_", date_clean)) %>%
  ungroup() %>%
  select(-home_clean, -away_clean, -date_clean)

# Insight: Number of NAs in "raw" Opta Player Stats scraped dataset
NAs_opta <- colSums(is.na(opta))
 #0 NAs

# =====================
# MISSING VALUE STATS
# =====================
# Processing: Select only OddsPortal data for those football matches that are also in Opta Player Stats
# (when oddsportal$match_id is %in% opta$match_id),
# to ensure that data on their actual score game can also be obtained and thus used
oddsportal <- oddsportal[oddsportal$match_id %in% opta$match_id, ]

# Insight: Overview of missing data when selecting only OddsPortal football matches also scraped from Opta Player Stats,
# and after having removed NAs from crucial fields (kickoff time, and team names variables)
missing_table <- oddsportal %>%
  summarise(across(everything(), ~ sum(is.na(.))))
 #4765 NAs in home and away odds

# Processing: Filter out observations with NAs in home and away odds variables
oddsportal_NAs_filtered <- oddsportal %>%
  filter(
    !is.na(HomeOdd),
    !is.na(AwayOdd))

# Insight: Number of unique matches after filtering out home and away odds NAs
number_unique_matches_no_NAs <-
  oddsportal_NAs_filtered %>%
  distinct(HomeTeam, AwayTeam, Competition, KickoffRaw) %>%
  nrow()
 #2128 matches are part of the dataset used for the analysis ("data/merged_opta_oddsportal/football_matches.csv")

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
        p_na = ~mean(is.na(.))),      # proportion of NAs
      .names = "{.col}_{.fn}"))
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
