# FIRST:
# 1) Run: src/scraping_html/collecting_scraping_db.py (Python)
# 2) Run: src/merging_opta_and_oddsportal/merging_opta_and_oddsportal.R (R)

library(dplyr)
library(readr)
library(stringr)
library(ggplot2)
library(here)

# Ensure required directories exist
dir.create(here("data", "opta"), recursive = TRUE, showWarnings = FALSE)

# === INPUT =================================================================

opta          <- read_csv(here("data", "opta", "opta_standardized.csv"))
oddsportal    <- read_csv(here("data", "oddsportal", "oddsportal_standardized.csv"))
opta_db       <- read_csv(here("data", "scraping_logs", "opta_database.csv"))
oddsportal_db <- read_csv(here("data", "scraping_logs", "oddsportal_database.csv"))

# Rename columns with HTML identifiers in error log databases
opta_db <- opta_db %>%
	rename(html_opta = match_id)

oddsportal_db <- oddsportal_db %>%
	rename(html_oddsportal = scrape_id)

# ==================================================
# ODDSPORTAL ERROR DISTRIBUTION SUMMARY STATISTICS
# ==================================================

# Create html_oddsportal ID from Filename (drop "ah_"/"ou_" prefix and ".html" suffix)
oddsportal <- oddsportal %>%
	mutate(
		html_oddsportal = Filename %>%
			str_remove("^ah_") %>%
			str_remove("^ou_") %>%
			str_remove("\\.html$")
	) %>%
	select(Competition, html_oddsportal) %>%
	distinct()

# Join OddsPortal HTMLs (with competition) to error count database
errors_oddsportal <- oddsportal %>%
	left_join(
		oddsportal_db %>% select(-competition),
		by = "html_oddsportal"
	)

# 1) Frequency distribution of errors per competition
errorfreq_oddsportal <- errors_oddsportal %>%
	group_by(Competition, errors) %>%              # one row = (competition, error value)
	count(name = "n", .drop = FALSE) %>%           # keep zero/NA levels if present
	group_by(Competition) %>%
	mutate(proportion = n / sum(n)) %>%            # within-competition percentages
	ungroup()
errorfreq_oddsportal

# 2) Summary statistics of errors per competition
errors_oddsportal_stats <- errors_oddsportal %>%
	group_by(Competition) %>%
	summarise(
		n_matches        = n(),
		n_complete_first = sum(is.na(errors)),       # scraped without any retry
		mean_errors      = mean(errors, na.rm = TRUE),
		sd_errors        = sd(errors, na.rm = TRUE)
	) %>%
	mutate(
		mean_errors = ifelse(is.nan(mean_errors), 0, mean_errors)
	)
errors_oddsportal_stats

# 3) Plot: distribution of error counts
errorcountdistr_oddsportal <- ggplot(
	errors_oddsportal %>% filter(!is.na(errors)),
	aes(x = factor(errors), fill = Competition)
) +
	geom_bar(position = "dodge") +
	labs(
		x     = "Number of errors before completion",
		y     = "Count",
		title = "Distribution of error counts for OddsPortal"
	)

ggsave(
	here("data", "oddsportal", "errorcountdistr_oddsportal.png"),
	plot   = errorcountdistr_oddsportal,
	width  = 6,
	height = 4,
	dpi    = 300
)

# =========================================================
# OPTA PLAYER STATS ERROR DISTRIBUTION SUMMARY STATISTICS
# =========================================================

# Create html_opta ID from Filename (drop ".html" suffix)
opta <- opta %>%
	mutate(
		html_opta = str_remove(Filename, "\\.html$")
	) %>%
	select(Competition, html_opta) %>%
	distinct()

# Join Opta HTMLs (with competition) to error count database
errors_opta <- opta %>%
	left_join(
		opta_db %>% select(-competition),
		by = "html_opta"
	)

# 1) Frequency distribution of errors per competition
errorfreq_opta <- errors_opta %>%
	group_by(Competition, error) %>%               # one row = (competition, error value)
	count(name = "n", .drop = FALSE) %>%           # keep zero/NA levels if present
	group_by(Competition) %>%
	mutate(proportion = n / sum(n)) %>%            # within-competition percentages
	ungroup()
errorfreq_opta

# Total number of errors in Opta
total_errors_opta <- sum(errors_opta$error, na.rm = TRUE)

# Total errors in La Liga and percentage
laliga_errors_opta <- sum(
	errors_opta$error[errors_opta$Competition == "La Liga"],
	na.rm = TRUE
)
prop_laliga_errors_opta <- (laliga_errors_opta / total_errors_opta) * 100

# 2) Summary statistics of errors per competition
errors_opta_stats <- errors_opta %>%
	group_by(Competition) %>%
	summarise(
		n_matches        = n(),
		n_complete_first = sum(is.na(error)),
		mean_errors      = mean(error, na.rm = TRUE),
		sd_errors        = sd(error, na.rm = TRUE)
	) %>%
	mutate(
		mean_errors = ifelse(is.nan(mean_errors), 0, mean_errors)
	)
errors_opta_stats

# 3) Plot: distribution of error counts
errorcountdistr_opta <- ggplot(
	errors_opta %>% filter(!is.na(error)),
	aes(x = factor(error), fill = Competition)
) +
	geom_bar(position = "dodge") +
	labs(
		x     = "Number of errors before completion",
		y     = "Count",
		title = "Distribution of error counts for Opta Player Stats"
	)

ggsave(
	here("data", "opta", "errorcountdistr_opta.png"),
	plot   = errorcountdistr_opta,
	width  = 6,
	height = 4,
	dpi    = 300
)
