library(dplyr)
library(stringr)
library(readr)
library(lubridate)
library(here)

# === INPUT === -----------------------------------------------------------

opta       <- read_csv(here("data", "opta", "opta_standardized.csv"))
oddsportal <- read_csv(here("data", "oddsportal", "oddsportal_standardized.csv"))

# === HELPER: CREATE MATCH ID ============================================

make_match_id <- function(df, home_col, away_col, kickoff_raw_col) {
	df %>%
		mutate(
			kickoff    = dmy_hm({{ kickoff_raw_col }}),
			home_clean = gsub(" ", "", {{ home_col }}),
			away_clean = gsub(" ", "", {{ away_col }}),
			date_clean = format(kickoff, "%d%m%Y"),
			match_id   = paste0(
				tolower(home_clean), "_",
				tolower(away_clean), "_",
				date_clean
			)
		) %>%
		select(-home_clean, -away_clean, -date_clean)
}

# =========================================================================
# ODDSPORTAL: RAW MISSING DATA & STRUCTURAL (FILE-LEVEL) MISSINGNESS
# =========================================================================

# Parse kickoff times from raw string
oddsportal$kickoff <- dmy_hm(oddsportal$KickoffRaw)

# Convert "-" to NA in odds fields
oddsportal$HomeOdd[oddsportal$HomeOdd == "-"] <- NA
oddsportal$AwayOdd[oddsportal$AwayOdd == "-"] <- NA

# Overview of missing data in raw OddsPortal dataset
na_summary_raw_odds <- oddsportal %>%
	summarise(across(everything(), ~ sum(is.na(.))))

# Keep old name for backward compatibility
missing_table_oddsportal <- na_summary_raw_odds

# NEW: structural missingness by file (HomeTeam, AwayTeam, kickoff)
na_by_file_odds <- oddsportal %>%
	group_by(Filename) %>%
	summarise(
		n_rows        = n(),
		n_na_hometeam = sum(is.na(HomeTeam)),
		n_na_awayteam = sum(is.na(AwayTeam)),
		n_na_kickoff  = sum(is.na(kickoff)),
		.groups       = "drop"
	)

# ============================
# OVERALL STRUCTURAL MISSINGNESS
# ============================

na_structural_summary <- na_by_file_odds %>%
	summarise(
		files_missing_hometeam = sum(n_na_hometeam > 0),
		files_missing_awayteam = sum(n_na_awayteam > 0),
		files_missing_kickoff  = sum(n_na_kickoff > 0),
		total_problematic_files = sum(
			(n_na_hometeam + n_na_awayteam + n_na_kickoff) > 0
		)
	)

na_structural_summary

# Inspect na_by_file_odds to see which scraped pages structurally miss teams/kickoffs

# Remove rows missing kickoff time and/or team names
# (crucial to create match_id's correctly)
oddsportal <- oddsportal %>%
	filter(
		!is.na(kickoff),
		!is.na(HomeTeam),
		!is.na(AwayTeam)
	)

# Number of unique matches after removing these rows
n_unique_matches_raw <- oddsportal %>%
	distinct(HomeTeam, AwayTeam, Competition, KickoffRaw) %>%
	nrow()

# Keep old name for backward compatibility
oddsportal_unique_matches <- n_unique_matches_raw

# Create match_id for OddsPortal
oddsportal <- make_match_id(
	df             = oddsportal,
	home_col       = HomeTeam,
	away_col       = AwayTeam,
	kickoff_raw_col = KickoffRaw
)

# =========================================================================
# OPTA PLAYER STATS: MATCH IDS AND MISSING DATA
# =========================================================================

# Create Opta match_id in the same way
opta <- make_match_id(
	df             = opta,
	home_col       = HomeTeam,
	away_col       = AwayTeam,
	kickoff_raw_col = KickoffTimeRaw
)

# Number of NAs in Opta player stats
na_summary_opta_raw <- colSums(is.na(opta))

# Backward compatibility
NAs_opta <- na_summary_opta_raw

# =====================
# MISSING VALUE STATS
# =====================

# Restrict OddsPortal to matches that are also in Opta
# (so we can link odds to actual match results)
oddsportal <- oddsportal[oddsportal$match_id %in% opta$match_id, ]

# Overview of missing data after:
# - removing rows with missing kickoff/team names
# - restricting to matches present in Opta
na_summary_filtered_odds <- oddsportal %>%
	summarise(across(everything(), ~ sum(is.na(.))))

# Backward compatibility
missing_table <- na_summary_filtered_odds

# Filter out observations with missing home and/or away odds
odds_clean <- oddsportal %>%
	filter(
		!is.na(HomeOdd),
		!is.na(AwayOdd)
	)

# Backward compatibility name
oddsportal_NAs_filtered <- odds_clean

# Number of unique matches with no NA odds
n_unique_matches_clean <- odds_clean %>%
	distinct(HomeTeam, AwayTeam, Competition, KickoffRaw) %>%
	nrow()

# Backward compatibility
number_unique_matches_no_NAs <- n_unique_matches_clean

# ============================================================
# DESCRIPTIVE ANALYSIS OF NA DISTRIBUTION ACROSS COMPETITIONS
# ============================================================

# 1) Overall number and proportion of missing values per variable
na_overall <- oddsportal %>%
	summarise(
		across(
			.cols = everything(),
			.fns  = list(
				n_na = ~ sum(is.na(.)),
				p_na = ~ mean(is.na(.))
			),
			.names = "{.col}_{.fn}"
		)
	)

# Backward compatibility
overall_na <- na_overall

# 2) Observation-level missingness by competition
na_by_competition <- oddsportal %>%
	group_by(Competition) %>%
	summarise(
		n_matches = n_distinct(match_id),  # number of unique matches
		n_obs     = n(),                   # number of rows/observations
		across(
			.cols  = c("HomeOdd", "AwayOdd"),
			.fns   = ~ mean(is.na(.)),
			.names = "p_na_{.col}"
		),
		.groups = "drop"
	)

# Backward compatibility
na_by_league <- na_by_competition

# 3) Match-level missingness summarised by competition
na_by_match <- oddsportal %>%
	group_by(match_id, Competition) %>%
	summarise(
		n_obs_match     = n(),
		p_na_HomeOdds   = mean(is.na(HomeOdd)),
		p_na_AwayOdds   = mean(is.na(AwayOdd)),
		.groups         = "drop"
	)

na_match_by_competition <- na_by_match %>%
	group_by(Competition) %>%
	summarise(
		n_matches          = n(),
		mean_p_na_HomeOdds = mean(p_na_HomeOdds),
		mean_p_na_AwayOdds = mean(p_na_AwayOdds),
		.groups            = "drop"
	) %>%
	arrange(desc(mean_p_na_HomeOdds))

# Backward compatibility
match_na         <- na_by_match
match_na_by_league <- na_match_by_competition
