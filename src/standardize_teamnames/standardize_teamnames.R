# === SETUP ===

# Import packages
library(tidyverse)
library(stringr)
library(lubridate)
library(googledrive)
library(dotenv)
library(readr)
library(here)

# === INPUT ===

# Download the most up to data data locally
source(here('src', 'merging_data', 'merging_data.R'))

# Load opta and oddsportal data into environment
opta <- read_csv(here('data', 'opta', 'opta_merged.csv'))
oddsportal <- read_csv(here('data', 'oddsportal', 'oddsportal_merged.csv'))

# === TRANSFORMATION ===

# Parse kickoffs
opta$kickoff <- dmy_hm(opta$KickoffTimeRaw)
oddsportal$kickoff <- dmy_hm(oddsportal$KickoffRaw)

# Normalise competition names function
normalize_comp <- function(x) {
	case_when(
		str_detect(x, "Premier League") ~ "Premier League",
		str_detect(x, "Bundesliga")     ~ "Bundesliga",
		str_detect(x, "Serie A")        ~ "Serie A",
		str_detect(x, "La.?Liga|Primera Div") ~ "La Liga",
		str_detect(x, "Ligue 1")        ~ "Ligue 1",
		str_detect(x, "Champions League") ~ "Champions League",
		str_detect(x, "Europa League")   ~ "Europa League",
		TRUE ~ x
	)
}

# Apply function to both Competition columns
opta$Competition <- normalize_comp(opta$Competition)
oddsportal$Competition <- normalize_comp(oddsportal$Competition)

# Create list of unique teamnames
unique_teams_opta <- unique(c(opta$HomeTeam, opta$AwayTeam))

# === Pivotting Oddsportal data ===

# Create temporary unique id
oddsportal$unique_id <- substr(oddsportal$Filename, 4, nchar(oddsportal$Filename))

# Split data into _asian and _over_under markets
oddsportal_asian <- oddsportal%>%filter(str_starts(Filename, "ah_"))
oddsportal_over_under <- oddsportal%>%filter(str_starts(Filename, "ou_"))

	# Create wide data for asian handicap market
oddsportal_asian_wide <- oddsportal_asian%>%
	pivot_wider(
		id_cols = c(Filename, unique_id, HomeTeam, AwayTeam, Competition, kickoff),
		names_from = Market,
		values_from = c(HomeOdd, AwayOdd),
		values_fill = NA
	)

	# Create wide data for over/under market
oddsportal_over_under_wide <- oddsportal_over_under%>%rename(
	over = HomeOdd,
	under = AwayOdd 			# Rename odd variables
)%>%
	pivot_wider(
		id_cols = c(Filename, unique_id,HomeTeam, AwayTeam, Competition, kickoff),
		names_from = Market,
		values_from = c(over, under),
		values_fill = NA
	)							# Pivot wider



# ======= FUNCTION FOR COLLECTION TEAMNAMES =========
build_lookup_from_seed <- function(opta, oddsportal, seed_opta, seed_odds) {
	library(dplyr)
	
	# lookup table starts with the one known pair
	lookup <- tibble(
		opta_name = seed_opta,
		odds_name = seed_odds
	)
	
	# queue of pairs to expand
	queue <- lookup
	
	# keep track of which Opta teams we have already expanded
	processed_opta <- character(0)
	
	while (nrow(queue) > 0) {
		# take first pair from queue
		current <- queue[1, ]
		queue   <- queue[-1, , drop = FALSE]
		
		opta_team <- current$opta_name
		odds_team <- current$odds_name
		
		# skip if we've already expanded this team
		if (opta_team %in% processed_opta) {
			next
		}
		
		# ---- STEP A: all Opta matches of this team ----
		opta_matches <- opta %>%
			filter(HomeTeam == opta_team | AwayTeam == opta_team)
		
		if (nrow(opta_matches) == 0) {
			processed_opta <- c(processed_opta, opta_team)
			next
		}
		
		# collect new pairs from these matches
		new_pairs_list <- vector("list", nrow(opta_matches))
		
		for (i in seq_len(nrow(opta_matches))) {
			m <- opta_matches[i, ]
			
			comp <- m$Competition
			ko   <- m$kickoff
			
			# opponent in Opta
			opp_opta <- if (m$HomeTeam == opta_team) m$AwayTeam else m$HomeTeam
			
			# ---- STEP B: corresponding match in OddsPortal ----
			odds_matches <- oddsportal %>%
				filter(
					Competition == comp,
					kickoff == ko,
					(HomeTeam == odds_team | AwayTeam == odds_team)
				)
			
			# only trust if we find exactly one
			if (nrow(odds_matches) == 1) {
				o <- odds_matches[1, ]
				
				# Opponent in OddsPortal: whoever is NOT odds_team
				if (o$HomeTeam == odds_team) {
					opp_odds <- o$AwayTeam
				} else if (o$AwayTeam == odds_team) {
					opp_odds <- o$HomeTeam
				} else {
					next
				}
				
				new_pairs_list[[i]] <- tibble(
					opta_name = opp_opta,
					odds_name = opp_odds
				)
			} else {
				# 0 or >1 matches -> ambiguous or missing, skip
				next
			}
		}
		
		# bind all proposed pairs from this expansion
		new_pairs <- bind_rows(new_pairs_list) %>%
			distinct()
		
		# remove already known mappings
		new_pairs <- anti_join(new_pairs, lookup,
							   by = c("opta_name", "odds_name"))
		
		# add them to lookup and to queue
		if (nrow(new_pairs) > 0) {
			lookup <- bind_rows(lookup, new_pairs)
			queue  <- bind_rows(queue, new_pairs)
		}
		
		# mark this team as processed
		processed_opta <- c(processed_opta, opta_team)
	}
	
	lookup %>% distinct()
}

team_lookup <- build_lookup_from_seed(opta=opta, oddsportal = oddsportal_over_under_wide, "Paris Saint-Germain FC","PSG")
teams_unknown <- setdiff(unique_teams_opta,team_lookup$opta_name)
print(teams_unknown)
