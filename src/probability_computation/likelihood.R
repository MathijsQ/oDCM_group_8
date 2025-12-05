# ====== SETUP ======
library(tidyverse)
library(here)
library(readr)

# ====== INPUT ======
# Load merged Opta–OddsPortal data with fitted parameters
data <- read_csv(here("data", "merged_opta_oddsportal", "results_with_params.csv"))

# ====== TRANSFORMATION ======

# Maximum goals per team used in the probability grid
MAX_GOALS <- 15

# Bivariate Poisson PMF:
#   X = home goals, Y = away goals with parameters (lambda1, lambda2, lambda3)
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

# Helper: compute how "extreme" the realised scoreline is under the model
# Extremeness = sum of probabilities of all scorelines at least as unlikely as the observed one
compute_extremeness <- function(lambda1, lambda2, lambda3,
								home_goals, away_goals,
								max_goals) {
	
	# 1. Full probability matrix for all scorelines
	P <- bivpois_pmf(lambda1, lambda2, lambda3, max_goals)
	
	# 2. Probability of the observed scoreline
	p_obs <- P[home_goals + 1, away_goals + 1]
	
	# 3. Tail probability: all entries with probability <= p_obs
	p_extreme <- sum(P[P <= p_obs])
	
	# 4. Return extremeness score
	return(p_extreme)
}

# (Second definition of compute_extremeness; identical logic retained)
compute_extremeness <- function(lambda1, lambda2, lambda3,
								home_goals, away_goals,
								max_goals) {
	
	# 1. Full probability matrix
	P <- bivpois_pmf(lambda1, lambda2, lambda3, max_goals)
	
	# 2. Probability of the observed scoreline
	p_obs <- P[home_goals + 1, away_goals + 1]
	
	# 3. Tail probability
	p_extreme <- sum(P[P <= p_obs])
	
	# 4. Return extremeness score
	return(p_extreme)
}

# Compute tail probability for each match
data <- data %>%
	dplyr::rowwise() %>%
	mutate(
		tail_probability = compute_extremeness(
			lambda1    = lambda1,
			lambda2    = lambda2,
			lambda3    = lambda3,
			home_goals = HomeGoals,
			away_goals = AwayGoals,
			max_goals  = MAX_GOALS
		)
	)

# Quick diagnostics: distribution and mean extremeness
boxplot(data$tail_probability)
mean(data$tail_probability)

# Simple check for systematic competition differences in extremeness
competition_bias <- lm(tail_probability ~ Competition, data = data)
summary(competition_bias)

# ====== OUTPUT =======
# Save dataset with tail probabilities added
write_csv(
	data,
	here("data", "merged_opta_oddsportal", "results_params_tail_probabilities.csv")
)

paste0('.csv-file with computed tail probabilities created at: ', here("data", "merged_opta_oddsportal", "results_params_tail_probabilities.csv"))