# ============================================================
# Purpose:
#   - Load merged OddsPortal data
#   - Reshape to long format with AH + O/U half-lines
#   - Remove bookmaker margin and compute fair probabilities
#   - Fit bivariate Poisson parameters per match
#   - Evaluate line-by-line fit quality (p_book vs p_model)
#   - Save fitted parameters and line-level diagnostics
# ============================================================

# =====================
# SETUP
# =====================

# Core packages
library(tidyverse)
library(stringr)
library(lubridate)
library(readr)
library(here)
library(tibble)
library(purrr)
library(digest)

# External data / services
library(googledrive)
library(dotenv)

# =====================
# INPUT
# =====================

# Load merged, standardized OddsPortal data
oddsportal <- read_csv(here("data", "oddsportal", "oddsportal_standardized.csv"))

# =====================
# BASIC CLEANING & KEYS
# =====================

# Parse kickoff times from raw string (dmy_hm = day-month-year hour:minute)
oddsportal$kickoff <- dmy_hm(oddsportal$KickoffRaw)

# =====================
# MISSING DATA FILTERING
# =====================

# Overview of missingness (for inspection / logging)
missing_table <- oddsportal %>%
	summarise(across(everything(), ~ sum(is.na(.))))

# Remove rows missing crucial fields
oddsportal <- oddsportal %>%
	filter(
		!is.na(kickoff),
		!is.na(HomeTeam),
		!is.na(AwayTeam)
	)

# =====================
# CREATE MATCH_ID
# =====================

# format of match_id: hashed(hometeam_awayteam_ddmmyyyy)
oddsportal <- oddsportal %>%
	mutate(
		home_clean = gsub(" ", "", HomeTeam),
		away_clean = gsub(" ", "", AwayTeam),
		date_clean = format(kickoff, "%d%m%Y"),
		key_string = paste0(home_clean, "_", away_clean, "_", date_clean)
	) %>%
	rowwise() %>% 
	mutate(
		match_id_full = digest(key_string, algo = "md5"),
		match_id      = substr(match_id_full, 1, 24)
	) %>%
	ungroup() %>%
	select(-home_clean, -away_clean, -date_clean, -key_string, -match_id_full)

# =====================
# KEEP SCRAPING_ID WITH DATA FOR TIMESTAMP INTEGRATION LATER ON
# =====================

oddsportal <- oddsportal %>%
	mutate(
		scraping_id = substr(Filename, 4, nchar(Filename)),      # remove first 3 chars
		scraping_id = sub("\\.html$", "", scraping_id)           # strip ending ".html"
	)


# =====================
# LONG FORMAT + MARKET / LINE / SIDE
# =====================

# Build a long format with:
#   - market = "asian" or "over_under"
#   - side   = "home"/"away" for AH, "over"/"under" for O/U
#   - line_value = numeric handicap/total (home-based for AH; absolute for totals)
oddsportal_long <- oddsportal %>%
	mutate(
		market = ifelse(str_starts(Market, "Asian"), "asian", "over_under")
	) %>%
	pivot_longer(
		cols      = c(HomeOdd, AwayOdd),
		names_to  = "side_raw",
		values_to = "odds"
	) %>%
	mutate(
		side = case_when(
			market == "asian"      & side_raw == "HomeOdd" ~ "home",
			market == "asian"      & side_raw == "AwayOdd" ~ "away",
			market == "over_under" & side_raw == "HomeOdd" ~ "over",
			market == "over_under" & side_raw == "AwayOdd" ~ "under"
		)
	) %>%
	# Extract the numeric line embedded in Market (e.g. "Asian Handicap -1.5")
	mutate(
		line_raw = str_extract(Market, "[+-]?[0-9]+(?:\\.[0-9]+)?")
	) %>%
	mutate(
		line_value = case_when(
			market == "asian"      ~ as.numeric(line_raw),              # signed handicap for home
			market == "over_under" ~ abs(as.numeric(line_raw))          # totals are always positive
		)
	) %>%
	rename(
		home_team = HomeTeam,
		away_team = AwayTeam
	) %>%
	select(
		match_id,
		scraping_id,
		kickoff,
		home_team,
		away_team,
		market,
		line_value,
		side,
		odds
	)

# =====================
# REMOVE MISSING / BAD ODDS & NORMALISE MARGINS
# =====================

# 1) Remove placeholder '-' odds and ensure numeric
# 2) Keep only lines where both sides (e.g. home/away or over/under) are present
oddsportal_long <- oddsportal_long %>%
	filter(odds != "-") %>%
	mutate(odds = as.numeric(odds)) %>%
	group_by(match_id, market, line_value) %>%
	filter(n() == 2) %>%        # exactly 2 sides quoted for each line
	ungroup()

# Remove bookmaker margin:
#   - p_raw  = 1 / odds (implied probability with margin)
#   - p_book = p_raw / sum(p_raw) = fair probability (margin removed)
oddsportal_long <- oddsportal_long %>%
	group_by(match_id, market, line_value) %>%
	mutate(
		p_raw    = 1 / odds,
		p_sum    = sum(p_raw),
		p_book   = p_raw / p_sum,      # fair probabilities
		odds_fair = 1 / p_book         # fair decimal odds
	) %>%
	ungroup()

# Keep only half-lines:
#   - AH: ..., -1.5, -0.5, 0.5, 1.5, ...
#   - O/U: 0.5, 1.5, 2.5, ...
oddsportal_long_halves <- oddsportal_long %>%
	filter(abs((line_value %% 1) - 0.5) < 1e-6)

# =====================
# BIVARIATE POISSON MODEL HELPERS
# =====================

# Global grid size: maximum goals per team considered in the PMF
MAX_GOALS <- 15

# Bivariate Poisson PMF:
#   X = home goals, Y = away goals, with parameters (lambda1, lambda2, lambda3)
#   Returns a (max_goals+1) x (max_goals+1) matrix of P(X = x, Y = y)
bivpois_pmf <- function(lambda1, lambda2, lambda3, max_goals = MAX_GOALS) {
	P <- matrix(0, nrow = max_goals + 1, ncol = max_goals + 1)
	rownames(P) <- 0:max_goals
	colnames(P) <- 0:max_goals
	
	lambda_sum <- lambda1 + lambda2 + lambda3
	base <- exp(-lambda_sum)
	
	for (x in 0:max_goals) {
		for (y in 0:max_goals) {
			k_max <- min(x, y)
			s <- 0
			for (k in 0:k_max) {
				term <- (lambda1^(x - k) / factorial(x - k)) *
					(lambda2^(y - k) / factorial(y - k)) *
					(lambda3^k       / factorial(k))
				s <- s + term
			}
			P[x + 1, y + 1] <- base * s
		}
	}
	
	P
}

# Probability for O/U half-lines given P:
#   - line: total goals threshold (e.g. 2.5)
#   - side: "over" or "under"
prob_ou <- function(P, line, side = c("over", "under")) {
	side <- match.arg(side)
	max_goals <- nrow(P) - 1
	goals <- 0:max_goals
	
	# total goals matrix: X + Y
	total_mat <- outer(goals, goals, "+")
	
	if (side == "over") {
		mask <- total_mat > line
	} else {
		mask <- total_mat < line
	}
	
	sum(P[mask])
}

# Probability for AH half-lines given P:
#   - h_home: handicap applied to home team (e.g. -0.5, +1.5, ...)
#   - side: "home" or "away" (which bet we consider)
# Logic:
#   home wins bet if (X + h_home) > Y  <=> X - Y > -h_home
prob_ah <- function(P, h_home, side = c("home", "away")) {
	side <- match.arg(side)
	max_goals <- nrow(P) - 1
	goals <- 0:max_goals
	
	# goal difference matrix: diff = X - Y
	diff_mat <- outer(goals, goals, "-")
	
	# home wins if diff > -h_home
	thr <- -h_home
	p_home_win <- sum(P[diff_mat > thr])
	
	# Half-lines have no push: away win prob = 1 - home
	p_away_win <- 1 - p_home_win
	
	if (side == "home") {
		p_home_win
	} else {
		p_away_win
	}
}

# Loss function for one match:
#   - par = c(lambda1, lambda2, lambda3)
#   - match_df: all AH + O/U half-lines for a single unique_id
#   Returns sum of squared errors between p_model and p_book
single_match_loss <- function(par, match_df, max_goals = MAX_GOALS) {
	lambda1 <- par[1]
	lambda2 <- par[2]
	lambda3 <- par[3]
	
	# Guard against invalid parameter values
	if (lambda1 <= 0 || lambda2 <= 0 || lambda3 < 0) {
		return(1e6)  # large penalty
	}
	
	# Build joint scoreline distribution for this parameter set
	P <- bivpois_pmf(lambda1, lambda2, lambda3, max_goals = max_goals)
	
	# Compute model probabilities for each line
	p_model <- numeric(nrow(match_df))
	
	for (i in seq_len(nrow(match_df))) {
		mkt  <- match_df$market[i]
		line <- match_df$line_value[i]
		side <- match_df$side[i]
		
		if (mkt == "over_under") {
			p_model[i] <- prob_ou(P, line = line, side = side)
		} else if (mkt == "asian") {
			p_model[i] <- prob_ah(P, h_home = line, side = side)
		} else {
			p_model[i] <- NA_real_
		}
	}
	
	# Drop lines where we couldn't compute model probability
	valid  <- !is.na(p_model) & !is.na(match_df$p_book)
	p_model <- p_model[valid]
	p_book  <- match_df$p_book[valid]
	
	# Sum of squared errors between model and bookmaker probabilities
	sum((p_model - p_book)^2)
}

# =====================
# PER-MATCH FITTING
# =====================

# Fit bivariate Poisson parameters for a single unique_id
fit_one_match <- function(id, data, max_goals = MAX_GOALS) {
	match_df <- data %>% filter(match_id == id)
	
	n_lines <- nrow(match_df)
	n_ah    <- sum(match_df$market == "asian")
	n_ou    <- sum(match_df$market == "over_under")
	
	# Basic metadata (assume constant within unique_id)
	home_team <- first(match_df$home_team)
	away_team <- first(match_df$away_team)
	kickoff   <- first(match_df$kickoff)
	scraping_id <- first(match_df$scraping_id)
	
	# Skip matches with too few lines to constrain the model
	if (n_lines < 4) {
		return(tibble(
			match_id   = id,
			scraping_id = scraping_id,
			home_team   = home_team,
			away_team   = away_team,
			kickoff     = kickoff,
			lambda1     = NA_real_,
			lambda2     = NA_real_,
			lambda3     = NA_real_,
			loss        = NA_real_,
			convergence = NA_integer_,
			n_lines     = n_lines,
			n_ah        = n_ah,
			n_ou        = n_ou
		))
	}
	
	# Initial guess for (lambda1, lambda2, lambda3)
	start_par <- c(1.5, 1.2, 0.1)
	
	# Fit parameters using bounded optimisation
	fit <- try(
		optim(
			par       = start_par,
			fn        = single_match_loss,
			match_df  = match_df,
			max_goals = max_goals,
			method    = "L-BFGS-B",
			lower     = c(0.01, 0.01, 0)
		),
		silent = TRUE
	)
	
	# If optimisation fails, return NA params with diagnostics
	if (inherits(fit, "try-error")) {
		return(tibble(
			match_id   = id,
			scraping_id = scraping_id,
			home_team   = home_team,
			away_team   = away_team,
			kickoff     = kickoff,
			lambda1     = NA_real_,
			lambda2     = NA_real_,
			lambda3     = NA_real_,
			loss        = NA_real_,
			convergence = NA_integer_,
			n_lines     = n_lines,
			n_ah        = n_ah,
			n_ou        = n_ou
		))
	}
	
	# Successful fit: return parameters and diagnostics
	tibble(
		match_id   = id,
		scraping_id = scraping_id,
		home_team   = home_team,
		away_team   = away_team,
		kickoff     = kickoff,
		lambda1     = fit$par[1],
		lambda2     = fit$par[2],
		lambda3     = fit$par[3],
		loss        = fit$value,
		convergence = fit$convergence,
		n_lines     = n_lines,
		n_ah        = n_ah,
		n_ou        = n_ou
	)
}

# Vector of unique match ids to fit
oddsportal_ids <- unique(oddsportal_long_halves$match_id)

# Fit parameters for all matches
bookmaker_params <- map_dfr(
	oddsportal_ids,
	~ fit_one_match(.x, oddsportal_long_halves)
)

# =====================
# LINE-BY-LINE FIT DIAGNOSTICS
# =====================

# Join fitted parameters back onto the half-lines data
odds_with_params <- oddsportal_long_halves %>%
	select(-scraping_id)%>%
	inner_join(
		bookmaker_params %>% select(match_id, scraping_id, lambda1, lambda2, lambda3),
		by = "match_id"
	)

# Compute model probabilities and errors for all lines in a given match
compute_line_fits <- function(df, max_goals = MAX_GOALS) {
	P <- bivpois_pmf(df$lambda1[1], df$lambda2[1], df$lambda3[1], max_goals)
	
	df %>%
		rowwise() %>%
		mutate(
			p_model = if (market == "asian") {
				prob_ah(P, h_home = line_value, side)
			} else if (market == "over_under") {
				prob_ou(P, line_value, side)
			} else {
				NA_real_
			},
			abs_err = abs(p_model - p_book),
			sq_err  = (p_model - p_book)^2
		) %>%
		ungroup()
}

# Apply line-fit evaluation per match
bookmaker_line_fits <- odds_with_params %>%
	group_by(match_id) %>%
	group_modify(~ compute_line_fits(.x)) %>%
	ungroup()

# For convenience: store absolute difference directly as p_diff
bookmaker_line_fits <- bookmaker_line_fits %>%
	mutate(
		p_diff = abs(p_book - p_model)
	)

# =====================
# OUTPUT
# =====================

# Save line-level fitted probabilities and errors
write_csv(
	bookmaker_line_fits,
	here("data", "oddsportal", "bookmaker_lines_fitted.csv")
)

# Save per-match fitted parameters + diagnostics
write_csv(
	bookmaker_params,
	here("data", "oddsportal", "bookmaker_fitted_params.csv")
)
