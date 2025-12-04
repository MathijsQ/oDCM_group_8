# ====== SETUP ======
library(tidyverse)
library(here)
library(readr)

# ====== INPUT ======
data <- read_csv(here('data', 'merged_opta_oddsportal', 'results_with_params.csv'))

# ====== TRANSFORMATION ======

# Define max goals
MAX_GOALS <- 15

# Redefine poisson matrix helper
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

# Helper function that computes the extremeness of the outcome of the match according to the bookmaker odds
compute_extremeness <- function(lambda1, lambda2, lambda3,
								home_goals, away_goals,
								max_goals) {
	
	# 1. Build full probability matrix
	P <- bivpois_pmf(lambda1, lambda2, lambda3, max_goals)
	
	# 2. Probability of the observed scoreline
	p_obs <- P[home_goals + 1, away_goals + 1]
	
	# 3. Tail probability (Option C)
	p_extreme <- sum(P[P <= p_obs])
	
	# 4. Return the extremeness score
	return(p_extreme)
}

# Apply it to all the matches with sufficient data
compute_extremeness <- function(lambda1, lambda2, lambda3,
                                home_goals, away_goals,
                                max_goals) {

  # 1. Build full probability matrix
  P <- bivpois_pmf(lambda1, lambda2, lambda3, max_goals)

  # 2. Probability of the observed scoreline
  p_obs <- P[home_goals + 1, away_goals + 1]

  # 3. Tail probability (Option C)
  p_extreme <- sum(P[P <= p_obs])

  # 4. Return the extremeness score
  return(p_extreme)
}

# Apply it to each match
data <- data %>%
	dplyr::rowwise()%>%
	mutate(
	tail_probability = compute_extremeness(lambda1=lambda1, lambda2=lambda2, lambda3=lambda3,
										   home_goals=HomeGoals, away_goals=AwayGoals,
										   max_goals = MAX_GOALS)
)
boxplot(data$tail_probability)

mean(data$tail_probability)

competition_bias <- lm(tail_probability ~ Competition, data=data)
summary(competition_bias)

# ====== OUTPUT =======
write_csv(data, here('data', 'merged_opta_oddsportal', 'results_params_tail_probabilities.csv'))
