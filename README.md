# When Data Meets the Odds: <br> Investigating the Alignment Between On-Field Performance and Betting Markets

*In this project we aim to scrape web data from two sources and combine them to create useful insights in the football and betting markets. By block scraping we collect data on which we later compute interesting statistics and create plots to understand how the two markets are interact with each other and influence each other.*

## 1. Motivation

The primary business problem motivating the creation of this dataset is the need to better understand how football performance statistics relate to betting odds set by bookmakers. Betting sites are gaining users rapidly and according to ResearchAndMarkets.com the global sports betting market reached a value of nearly USD 107.4 billion in 2024 (YahooFinance, 2025).

By combining detailed match-level statistics and pre-match odds, this dataset enables the exploration of the relationship between objective performance indicators (e.g. goals, expected goals, possessions, shots (on target) etc.) and subjective market evaluations (i.e., bookmaker odds). This integration offers insights into how real-world performance data influences the betting markets. Furthermore, we aim to streamline the data collection process by automating access to two key sources that are normally analyzed separately. Thereby, reducing time and effort for future researchers.

**This dataset will be used to shed light on topics like:** - Basic sample statistics - Goals per match - Distribution of goal differences between teams - Hometeam vs Awayteam win ratio - are there differences between competitions - Convert odds to probability distribution - Deeper statistics in betting data - Where lie the average over/under line - where lie the average +/- handicap line - Are there differences

## Source comparisons

In the end we used the websites **Optaplayerstats.statsperform.com** as the main website to collect game statistics and **Oddsportal.com** for all necessary bookmaker data. Below you can read other sources we took into consideration and our motivation for choosing/not choosing the website.

| Source | Extraction method (web scraping vs API) | Research fit | Accessibility | Efficiency to scrape |
|:--------------|:--------------|:--------------|:--------------|:--------------|
| fbref.com | Web scraping | This website stores actual football statistics for more than 100 men’s and women’s club and national team competitions. | There is no login needed to access data from the website. But automated web scraping requests using *requests* package gets blocked. | It would be efficient if we find a way how to scrape the data without getting blocked. This is what we still need to find out. |
| oddsportal.com | Web scraping | This website stores the odds of the big bookmakers for all of the matches that we will scrape from fbref.com. | There is no login needed to access data from the website, but automated web scraping requests using *requests* package gets blocked. | It would be efficient if we find a way how to scrape the data without getting blocked. This is what we still need to find out. |
| Optaplayerstats.statsperform.com | Web scraping | This website stores football statistics for the most prominent competitions on both match and player level. | There is no login needed to access data from the website. Compared with the two sites above, Opta is more accessible when using Selenium. | It is the most efficient source that we have, since we are getting access of the data by using Selenium. |
| Bet365’s API on RapidAPI | API | This API provides real-time odds for BET365 (pre-game, live & historical odds). | There is a limited accessibility for free usage. You can only do 200 requests per month. | Not efficient, since there is a very small limit on the amount of requests with the free package. |
| API-Football | API | This API provides football statistics as well as pre-match and in-play odds for football matches. | There is a limited accessibility for free usage. You can do 100 requests per day. | It is more efficient than the RapidAPI because there are more requests possible per day. Whether this is enough or not, should be further investigated. |

## 2. Data extraction plan

### 2.1 Using two data sources

Although all required match information—including final results—is available on OddsPortal, we chose to scrape from two sources: Opta Player Stats and OddsPortal. Our initial idea was to include player-level statistics, but the OddsPortal pages we scraped did not contain player odds, even though such odds **are provided by bookmakers.**

For educational purposes, we still proceeded with both sources so that we could learn how to connect two independently scraped datasets in a reliable way. As a result, no player names or player-level statistics appear in our final dataset; all information is at the match and team level.

### 2.2 Sampling

We scraped football match statistics and betting odds from Opta Player Stats and OddsPortal.

From **Opta Player Stats**, we extracted:

-   Match-level information such as goals scored and kickoff dates and times\
-   Team statistics and metadata, including competition, season, home and away teams, and final score

From **OddsPortal**, we extracted:

-   Pre-match odds for Asian Handicap (*1 team starts the match with a handicap; add the match result to the handicap and you know the outcome of the bet*), and Over/Under (*whether summed goals of both teams are over or under a certain threshold*) markets. These two markets were deemed best for creating an **implied prbability distribution**, as it provides an indication of the total amount of goals scores, and how these total goals are expected to be divided between the two teams.\
-   Metadata such as competition and date

Our dataset covers the 2024–2025 season across the top five European leagues (Premier League, La Liga, Serie A, Bundesliga, Ligue 1) and the Champions League. Because we aimed for full coverage, we did not use random sampling; instead, we scraped all available matches within these leagues.

To merge both sources, we constructed a unique match identifier based on team names, match date, and competition. For example:

-   Holstein Kiel vs Stuttgart on 08/03/2025 → `holsteinkiel_stuttgart_080325`

This identifier allows us to link Opta match results to OddsPortal odds.

## 3. Dependencies

**Download the right packages in terminal**

```         
pip install gspread google-auth python-dotenv selenium webdriver-manager beautifulsoup4 google-api-python-client google-auth-oauthlib google-auth-httplib2
```

**Download all packages required in Rstudio**

```         
required_packages <- c("tidyverse", "dplyr", "stringr", "lubridate", "googledrive", "dotenv", "readr", "here", "ggplot2", "tibble", "purrr", "digest")

install.packages(required_packages)
```

## 4. Running Instructions

To avoid leaking our private api keys we provide the two `..._merged.csv` files in the **zip file** and give running instructions from there on out until our final report is created.

### The Pipeline

#### 1. Clone the github repo:

-   make new directory --\> scraping_assignment
-   in this directory, clone the repo using:

```         
git clone "https://github.com/MathijsQ/oDCM_group_8"
```

#### 2. Insert raw data in correct folder

-   Create directories in /data/ : - opta AND - oddsportal
-   insert `..._merged.csv` in the corresponding folder

#### 3. In terminal run script from the "/src/scraping_html" directory:

```         
python collecting_scraping_db.py
```

#### 4. Run "standardize_teamnames.R" in R

This script takes the two `..._merged.cvs` files and creates two files correspondingly called: `..._standardized.csv`.

#### 5. Two steps in the `src/error_and_NA_insights` folders:

-   Run `missing_data_distribution.R`

    This script takes the two standardized csv's and creates a summary of missing data by competition (`match_na_by_league`) and a similar summary per match (`match_na`).

-   Run `error_distribution.R`

    This script follows the previous step and creates a plot of the distribution of the error count for opta and for oddsportal

#### 6. Run "fit_bivariate_poisson.R"

This script takes the two standardized csv's to create `bookmaker_lines_fitted.csv` and `bookmaker_fitted_params.csv`.

#### 7. Run "merging_opta_and_oddsportal.R"

This script takes the "opta_standardized.csv" and the "bookmaker_fitted_params.csv" to eventually create a merged dataset called: `results_with_params.csv`.

#### 8. Run "likelihood.R"

This script takes the "results_with_params.csv" in order to create `results_params_tail_probabilities.csv`.

#### 9. Run "formatting.R" to create the **two final datasets**

This script takes "results_params_tail_probabilities.csv" and "bookmaker_lines_fitted.csv" in order to make the final datasets called `bookmaker_vs_models_odds.csv` and `match_model_results`

#### 10. Run "final_report.Rmd" to create the **Final Report** in pdf

## About

This dataset was created by Team 8 of the mandatory Online Data Collection and Management course designed for students at Tilburg University following the MSc in Marketing Analytics program. More specifically, it was consolidated by Geert Huissen, Mathijs Quarles van Ufford, María Orgaz Jiménez, and Nigel de Jong – all students of said program at Tilburg University.

## Source list

<https://finance.yahoo.com/news/sports-betting-market-trends-growth-081500944.html?guccounter=1&guce_referrer=aHR0cHM6Ly93d3cuZ29vZ2xlLmNvbS8&guce_referrer_sig=AQAAAMVG_Oq1pxwgPPLN2quY8mipodqxBTiPH5tVfdf4YO-jS0d2Hmmn7c44mHDzSYE1xwkZ7JGnLuznmWbZWOg7L7fd3JuZYvdNHrsD6C-exOLqybOJfa07mF8V-f0x3N6SV1H-X-M48igYiYMV_bFALslnK6ZZqVUms3agCZb5J0VJ>
