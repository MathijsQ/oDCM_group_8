#FIRST: Run src/scraping_html/collecting_scraping_db.py in the command terminal,
#and src/error_and_NA_insights/missing_data_distribution.R,
library(dplyr)
library(readr)
library(stringr)
library(ggplot2)
library(here)

football_matches <- read_csv(here("data", "merged", "football_matches.csv"))
opta_db <- read_csv(here("data", "scraping_logs", "opta_database.csv"))
oddsportal_db <- read_csv(here("data", "scraping_logs", "oddsportal_database.csv"))
#opta_db: match_id column is the scraping ID, which corresponds to the oddsportal_matched_opta$Filename column, but without the .html at the end
#oddsportal_db: scrape_id column is the scraping ID, which is the same as the $scraping_id in the bookmaker_params.csv file derived from the fit_bivariate_poisson.R file

#=====================
# RENAMING VARIABLES
#=====================
opta_db <- opta_db %>%
  rename(html_opta = match_id)
oddsportal_db <- oddsportal_db %>%
  rename(html_oddsportal = scrape_id)

#=================================================================
# COMPLETING oddsportal_matched_opta WITH THE INFORMATION IN opta
#=================================================================
# Selecting only variables of interest for error distribution analysis
# oddsportal_matched_opta = main dataset (many rows per match)
# opta                    = match-level info (one row per match_id)
temp_errors <- football_matches %>%
  select(-KickoffRaw, -Market, -HomeOdd, -AwayOdd, -HomeGoals, -AwayGoals) %>%
  distinct(.)

#==================================================
# ODDSPORTAL ERROR DISTRIBUTION SUMMARY STATISTICS
#==================================================
errors_oddsportal <- temp_errors %>%
  select(-html_opta) %>%  # columns to keep from errordistr
  left_join(
    oddsportal_db %>% 
      select(-competition),    # columns to keep from oddsportal_db
    by = "html_oddsportal")

# 1) Frequency distribution of errors per league
errorfreq_oddsportal <- errors_oddsportal %>%
  group_by(Competition, errors) %>%      # one row = (league, error value)
  count(name = "n", .drop = FALSE) %>%  # keep 0/NA levels if present
  group_by(Competition) %>%
  mutate(proportion = n / sum(n)) %>%            # within‑league percentages
  ungroup()
errorfreq_oddsportal

# 2) Summary statistics of errors per league
errors_oddsportal_stats <- errors_oddsportal %>%
  group_by(Competition) %>%
  summarise(
    n_matches   = n(),
    n_complete_first = sum(is.na(errors)),
    mean_errors = mean(errors, na.rm = TRUE),
    sd_errors  = sd(errors, na.rm = TRUE)
  ) %>%
  mutate(mean_errors   = ifelse(is.nan(mean_errors),   0, mean_errors))
errors_oddsportal_stats

# 3) Plot of the distribution of the error count
errorcountdistr_oddsportal <- ggplot(errors_oddsportal %>% filter(!is.na(errors)), aes(x = factor(errors), fill = Competition)) +
  geom_bar(position ="dodge") +
  labs(x = "Number of errors before completion",
       y = "Count",
       title = "Distribution of error counts for OddsPortal")
ggsave("data/oddsportal/errorcountdistr_oddsportal.png", plot = errorcountdistr_oddsportal, width = 6, height = 4, dpi = 300)

#=========================================================
# OPTA PLAYER STATS ERROR DISTRIBUTION SUMMARY STATISTICS
#=========================================================
errors_opta <- temp_errors %>%
  select(-html_oddsportal) %>%  # columns to keep from errordistr
  left_join(
    opta_db %>% 
      select(-competition),    # columns to keep from oddsportal_db
    by = "html_opta")

# 1) Frequency distribution of errors per league
errorfreq_opta <- errors_opta %>%
  group_by(Competition, error) %>%      # one row = (league, error value)
  count(name = "n", .drop = FALSE) %>%  # keep 0/NA levels if present
  group_by(Competition) %>%
  mutate(proportion = n / sum(n)) %>%            # within‑league percentages
  ungroup()
errorfreq_opta
total_errors_opta <- sum(errors_opta$error, na.rm = T)
 #237
laliga_errors_opta <- sum(errors_opta$error[errors_opta$Competition == "La Liga"], na.rm = TRUE)
 #103
prop_laliga_errors_opta <- (laliga_errors_opta/total_errors_opta)*100
 #43.46%

# 2) Summary statistics of errors per league
errors_opta_stats <- errors_opta %>%
  group_by(Competition) %>%
  summarise(
    n_matches   = n(),
    n_complete_first = sum(is.na(error)),
    mean_errors = mean(error, na.rm = TRUE),
    sd_errors  = sd(error, na.rm = TRUE)
  ) %>%
  mutate(mean_errors   = ifelse(is.nan(mean_errors),   0, mean_errors))
errors_opta_stats

# 3) Plot of the distribution of the error count
errorcountdistr_opta <- ggplot(errors_opta %>% filter(!is.na(error)), aes(x = factor(error), fill = Competition)) +
  geom_bar(position ="dodge") +
  labs(x = "Number of errors before completion",
       y = "Count",
       title = "Distribution of error counts for Opta Player Stats")
ggsave("data/opta/errorcountdistr_opta.png", plot = errorcountdistr_opta, width = 6, height = 4, dpi = 300)


