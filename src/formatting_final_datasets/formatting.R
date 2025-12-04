# ====== SETUP ======
library(tidyverse)
library(here)
library(readr)

# ====== INPUT ======
probabilities_matches <- read_csv(here('data', 'merged_opta_oddsportal', 'results_params_tail_probabilities.csv'))
bookmaker_lines_fitted <- read_csv(here('data', 'oddsportal', 'bookmaker_lines_fitted.csv'))

# ====== TRANSFORMATION ======

# Filter out wrong columns
# Match dataset
probabities <- probabilities_matches%>%
	select(
		match_id,
		home_team,
		away_team,
		HomeGoals,
		AwayGoals,
		Competition,
		kickoff,
		tail_probability,
		lambda1,
		lambda2,
		lambda3,
		n_lines,
		n_ah,
		n_ou,
		loss
	)

# Odds dataset
odds <- bookmaker_lines_fitted %>%
	select(
		match_id,
		home_team,
		away_team,
		market,
		line_value,
		side,
		odds,
		odds_fair,
		p_raw,
		p_sum,
		p_book,
		p_model,
		p_diff
		
	)

# Renaming columns
# Match dataset
probabities <- probabities%>%
	rename(
		home_goals = HomeGoals,
		away_goals = AwayGoals,
		competition = Competition,
		expected_homegoals = lambda1,
		expected_awaygoals = lambda2,
		covariance_component = lambda3,
		lines_used = n_lines,
		lines_used_asian = n_ah,
		lines_used_overunder = n_ou,
		fit_loss = loss
	)

# Odds dataset
odds <- odds%>%
	rename(
		bet_side = side
	)

# ========== OUTPUT =========
# Ensure directory exists
if (!dir.exists(here("data", "final_datasets"))) {
	dir.create(here("data", "final_datasets"), recursive = TRUE)
}

write_csv(probabities, here('data', 'final_datasets', 'match_model_results.csv'))
write_csv(odds, here('data', 'final_datasets', 'bookmaker_vs_model_odds.csv'))
