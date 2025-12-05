# When Data Meets the Odds: <br> Investigating the Alignment Between On-Field Performance and Betting Markets

*In this project we aim to scrape web data from two sources and combine them to create useful insights in the football and betting markets. By block scraping we collect data on which we later compute interesting statistics and create plots to understand how the two markets are interact with each other and influence each other.*

## 1. Motivation

The primary business problem motivating the creation of this dataset is the need to better understand how football performance statistics relate to betting odds set by bookmakers. Betting sites are gaining users rapidly and according to ResearchAndMarkets.com the global sports betting market reached a value of nearly USD 107.4 billion in 2024 (YahooFinance, 2025).

By combining detailed match-level statistics and pre-match odds, this dataset enables the exploration of the relationship between objective performance indicators (e.g. goals, expected goals, possessions, shots (on target) etc.) and subjective market evaluations (i.e., bookmaker odds). This integration offers insights into how real-world performance data influences the betting markets. Furthermore, we aim to streamline the data collection process by automating access to two key sources that are normally analyzed separately. Thereby, reducing time and effort for future researchers.

**This dataset will be used to shed light on topics like:** 
- Basic sample statistics 
- Goals per match 
- Distribution of goal differences between teams
- Hometeam vs Awayteam win ratio
- are there differences between competitions?
- Convert odds to probability distribution?
- Deeper statistics in betting data?
- Where lie the average over/under line?
- where lie the average +/- handicap line? 
- Are there differences?

## 2. Purpose and Scope

This repository provides the complete reproducible framework for our project. It includes the raw scraped data, scraping logs, and the source code required to transform this raw data into analysis-ready datasets. Additionally, the final report and appendices are included in PDF format.

### Note on Reproducibility:

-   **Web Scraping:** The data collection phase has already been completed. The scraping scripts require specific API keys and credentials; therefore, they are provided for reference only and are not intended to be re-run by the user.

-   **Local Processing:** The core of this package is the local processing pipeline. While the final processed CSV files are not shipped within this package to save space, the entire analysis—from raw data to final report—can be fully recreated locally using the provided pipeline.

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

## 4. Running the Pipeline:

This project uses a **Makefile** to automate the workflow. Because the live scraping cannot be reproduced without credentials, the pipeline focuses on processing the included raw data into the final results.

### The Full Pipeline

#### 1. Clone the github repo:

-   make new directory --\> scraping_assignment
-   in this directory, clone the repo using:

```         
git clone "https://github.com/MathijsQ/oDCM_group_8"
```

#### 2. Insert raw data in correct folder from the zip file

-   Create directories in /data/ : - opta AND - oddsportal
-   insert `..._merged.csv` in the corresponding folder

#### 3. From project root directory execute complete workflow

```         
make
```

This performs the following actions in order:

-   **Data Preparation:** Attaches timestamps to raw data and standardizes team and competition names.
-   **Modeling:** Fits the bivariate Poisson model and computes tail probabilities.
-   **Output Generation:** Creates all processed CSV files (stored in **data/final_datasets/**).
-   **Reporting:** Knits the final report and appendices.

### The Process Timestamps Only Pipeline

If you only wish to attach the scraping timestamps to the raw data without running the full analysis, use:

```         
make timestamps_only
```

This generates the intermediate files `oddsportal_merged_with_timestamps.csv` and `opta_merged_with_timestamps.csv` inside the respective data folders. This pipeline creates these two complete and usable datasets from the two websites for others to use.

### Cleaning Pipeline

If you wish to delete the entire folder back to the original repository, use:

```         
make clean
```

## 5. Data Package Overview

To keep the package lightweight, we include only the necessary raw inputs. All analytical datasets and model outputs are generated locally by the pipeline.

### 5.1 Included Raw Inputs:

-   **Raw Merged Data:** Located in `data/oddsportal/` and `data/opta/`, these are the primary raw datasets containing the scraped match and odds information.
-   **Scraping Logs:** Located in `data/scraping_logs/`, these databases track scraping reliability, error counts, and execution timestamps. They are essential for auditing the data collection process and attaching precise timestamps to the raw observations.

### 5.2 Final Analysis Datasets

These are the primary files used for the report's figures and final conclusions. Detailed variable explanations are provided in **Appendix A** and **Appendix B** of the report.

-   `data/final_datasets/bookmaker_vs_model_odds.csv`: Contains the comparative analysis between bookmaker odds and our model's predictions.
-   `data/final_datasets/match_model_results.csv`: Stores the comprehensive match-level results.

*Note: The pipeline creates several other intermediate CSV files which serve as technical bridges between processing steps.*

## 6. Final Directory Structure

***Folder tree as talked about: STILL A TO-DO!!***

## About

This dataset was created by Team 8 of the mandatory Online Data Collection and Management course designed for students at Tilburg University following the MSc in Marketing Analytics program. More specifically, it was consolidated by Geert Huissen, Mathijs Quarles van Ufford, María Orgaz Jiménez, and Nigel de Jong – all students of said program at Tilburg University.

## Source list

<https://finance.yahoo.com/news/sports-betting-market-trends-growth-081500944.html?guccounter=1&guce_referrer=aHR0cHM6Ly93d3cuZ29vZ2xlLmNvbS8&guce_referrer_sig=AQAAAMVG_Oq1pxwgPPLN2quY8mipodqxBTiPH5tVfdf4YO-jS0d2Hmmn7c44mHDzSYE1xwkZ7JGnLuznmWbZWOg7L7fd3JuZYvdNHrsD6C-exOLqybOJfa07mF8V-f0x3N6SV1H-X-M48igYiYMV_bFALslnK6ZZqVUms3agCZb5J0VJ>
