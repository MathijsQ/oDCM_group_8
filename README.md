# When Data Meets the Odds: <br> Investigating the Alignment Between On-Field Performance and Betting Markets
*In this project we aim to scrape web data from two sources and combine them to create useful insights in the football and betting markets. By block scraping we collect data on which we later compute interesting statistics and create plots to un-derstand how the two markets are interact with each other and influence each other.*

## 1. Motivation
The primary business problem motivating the creation of this dataset is the need to better understand how foot-ball performance statistics relate to betting odds set by bookmakers. Betting sites are gaining users rapidly and according to ResearchAndMarkets.com the global sports betting market reached a value of nearly USD 107.4 billion in 2024 (YahooFinance, 2025).

By combining detailed match-level statistics and pre-match odds, this dataset enables the exploration of the relationship between objective performance indicators (e.g. goals, expected goals, possessions, shots (on target) etc.) and subjective market evaluations (i.e., bookmaker odds). This integration offers insights into how real-world performance data influences the betting markets. Furthermore, we aim to streamline the data collection process by automating access to two key sources that are normally analyzed separately. Thereby, reducing time and effort for future researchers. 

**This dataset will be used to shed light on topics like:**
- Basic sample statistics 
  - Goals per match
  - Distribution of goal differences between teams
  - Hometeam vs Awayteam win ratio
  - are there differences between competitions
- Convert odds to probability distribution
- Deeper statistics in betting data
  - Where lie the average over/under line
  - where lie the average +/- handicap line
  - Are there differences 

## Source comparisons
In the end we used the websites **Optaplayerstats.statsperform.com** as the main website to collect game statistics and **Oddsportal.com** for all necessary bookmaker data. Below you can read other sources we took into considera-tion and our motivation for choosing/not choosing the website.

| Source | Extraction method (web scraping vs API) | Research fit | Accessibility | Efficiency to scrape |
| :--- | :--- | :--- | :--- | :--- |
| fbref.com | Web scraping | This website stores actual football statistics for more than 100 men’s and women’s club and national team competitions. | There is no login needed to access data from the website. But automated web scraping requests using *requests* package gets blocked. | It would be efficient if we find a way how to scrape the data without getting blocked. This is what we still need to find out. |
| oddsportal.com | Web scraping | This website stores the odds of the big bookmakers for all of the matches that we will scrape from fbref.com. | There is no login needed to access data from the website, but automated web scraping requests using *requests* package gets blocked. | It would be efficient if we find a way how to scrape the data without getting blocked. This is what we still need to find out. |
| Optaplayerstats.statsperform.com | Web scraping | This website stores football statistics for the most prominent competitions on both match and player level. | There is no login needed to access data from the website. Compared with the two sites above, Opta is more accessible when using Selenium. | It is the most efficient source that we have, since we are getting access of the data by using Selenium. |
| Bet365’s API on RapidAPI | API | This API provides real-time odds for BET365 (pre-game, live & historical odds). | There is a limited accessibility for free usage. You can only do 200 requests per month. | Not efficient, since there is a very small limit on the amount of requests with the free package. |
| API-Football | API | This API provides football statistics as well as pre-match and in-play odds for football matches. | There is a limited accessibility for free usage. You can do 100 requests per day. | It is more efficient than the RapidAPI because there are more requests possible per day. Whether this is enough or not, should be further investigated. |

## 2. Data Extraction Plan
### Sampling
We scrape the football match statistics and betting odds from two public sources:
- From **Opta Player Stats**, we will extract:
  - Match-level data such as goals, kickoff times and dates, and other team-level statistics.
  - Metadata including competition name, season, date, home and away teams, and final score.
- From **OddsPortal**, we will extract:
  - Pre-match odds for the main outcomes (home win, away win, Asian Handicap (AH) and Over/Under (OU)).
   -Additional metadata such as competition, date, and bookmaker name.

We collected data for the **2024–2025 season** across the **top five European leagues** (Premier League, La Liga, Serie A, Bundesliga, Ligue 1) and **European competitions** (Champions League, Europa League, and Conference League). Since we want a complete overview of teams and odds patterns, we are not using random sampling. This ensures that all leagues and teams are consistently represented in the dataset.
To align data from Opta Player Stats and OddsPortal, we will construct unique match identifiers based on team names, match date, and competition.

``
For example:
Manchester United vs Liverpool on 01/01/2024 in the Premier League → MUD_LIV_010124_PL
``

These identifiers will allow us to merge data across sources accurately.

### Extraction method
We identified the correct pages by manually exploring the sites and inspecting their HTML structure to ensure we comply with the site restrictions, as well as check the robots.txt file. For Opta Player Stats and OddsPortal we found that none of the relevant directories are disallowed. There are only restrictions regarding large AI bots and other similar systems.

We included a proper delay after a suspicious activity warnings have been detected between requests to avoid being blocked or overloading the websites.

Because all the required data are already available online, scraping does not need to happen continuously.
Our extraction frequency will mainly depend on technical and anti-bot considerations. We use Selenium, as it can bypass anti-bot restrictions that prevent simpler tools like requests from accessing the pages.
We, as a group of four, will scrape data in blocks and created a local scraper to get the data in a google drive. After all the data is scraped we combine the four blocks of the two websites and combine them using the unique match_id as stated above to form one complete dataset.

### Processing during collection
During scraping, Selenium will automatically:
1.	Visit each match or odds page.
2.	Extract the selected information using the correct CSS selectors.
3.	Save the structured data in a clear format (e.g., CSV or JSON) for later analysis.

We will only store the necessary data fields and metadata. All files will be stored locally. The dataset does not contain any sensitive or confidential data, since no data at the individual level will be gath-ered. That is, usernames, IP addresses, demographics, sexual orientations, beliefs, opinions, memberships, pass-words, financial information, biometric information, or similar, will not form part of the final dataset. The final dataset will only contain information regarding the predicted odds that certain selected football teams have of winning, losing, or tying against other football teams.

## 3. Data extraction Process
As of 20/11/2025, the data collection process has started. This section describes the setup and implementation of the plan and how we overcome issues that we have encountered. 
### Challenges
The extraction pipeline is designed around stable and consistent features of the *Opta Player Stats* interface, in order to support performance and scalability during data collection. As such, to be able to identify matches in a robust way regardless of possible layout changes, each match is represented as a `<tbody>` element with a unique data-match attribute. Furthermore, to mirror genuine browser interaction, clickable `td.Opta-Divider.Opta-Dash` elements are used to navigate to match-level pages. By using these elements (*tbody and td.Opta-Divider.Opta-Dash*), the likelihood of breakage due to site updates is reduced.

To avoid high-frequency automated scraping, occasional low-intensity scraping sessions are set in place for data collection. In these sessions, each team member retrieves and processes only the matches that have not yet been scraped as noted in our Google Sheets log. During each session, *Selenium* is used to retrieve and save the full HTML for each match. To reduce the time spent on the website and avoid unnecessary repeated requests, pars-ing of structured information will occur offline, separately from collection. Anti-bot systems such as *Akamai* may also occasionally interfere with the data collection process, so we will each implement basic block detection. If we do not get the HTML structures we expect (such as match header containers, or key Opta class names), or if the response is similar to a known block pattern (“Access Denied”, empty HTML, etc.), we will not make further requests, ensuring data quality and protecting server load. 

The total scope of the project is approximately 1,750 matches (five competitions of ≈350 matches each), so we must make sure that the process remains stable, avoid redundant work, and prevent long-term session interrup-tions.
### Monitoring systems 
A centralized, lightweight Google Sheets log that is integrated into the scraping workflow will be used for data monitoring. For each match ID, the log helps to track (a) whether the match has been scraped, (b) the timestamp of the moment where the scraping occurred, and optionally, (c) an indicator of the state of the response (such as normal HTML vs. blocked/empty content). This log allows us to assess which matches have a valid HTML and which require new scraping attempts at any given moment. Since the log is updated in real time, we can immediately establish which matches need to be processed at a given point in time, and work on those. The spreadsheet will be accessed using the Google Spreadsheet API. All the devices on which we will scrape will have a JSON key stored locally that allows access to our logging spreadsheet. 

We also plan on storing raw HTML files for each match, which will allow for the verification of parsing accuracy by comparing the parsed outputs against the raw HTML. In case we change our parsing logic later in the project, we can simply process previously collected HTML files again without revisiting the website. Basic quality checks (verifying expected numbers of matches per match week, confirming that the extracted team names match the corresponding metadata, etc.) will be performed periodically.

Since all match IDs and their statuses are stored in the same place, this log allows us to easily detect potential issues such as incomplete match sets, unusually small HTML files, or a sudden streak of bad responses.
### Infrastructure specifics
`<tbody>` and `td.Opta-Divider.Opta-Dash` elements are used to uniquely represent each match and mirror genuine browsing behavior. Selenium is used to retrieve the full HTML of each match, and parsing is separately done, offline. Basic block detection will be implemented by every team member in each of the occasional scraping sessions. Furthermore, a Google Sheets log will be maintained throughout the data collection process, helping ensure transparency as well as reproducibility later on. This logbook helps to keep track of relevant events such as detection of blocks, HTML anomalies, or changes in website structure that affect selectors, but does not track who scraped each match or how many matches were scraped per scraping session, since these details do not impact data quality. Only match-level information (scraped status, timestamps, and any associated response issues) is recorded.

To support reproducibility, parsed datasets will be derived from stored raw HTML in a way that can be traced, and variable definitions will be documented when parsing begins. The final dataset, as well as the HTML collec-tion and scraping scripts, will be kept to ensure long-term accessibility and reproducibility.







## Dependencies 
**Download the right packages**
```
pip install gspread google-auth python-dotenv selenium webdriver-manager beautifulsoup4 google-api-python-client google-auth-oauthlib google-auth-httplib2
```
## Running Instructions 
1. Clone the github repo
-make new directory: scraping_assignment
-in this directory, clone the repo
	- git clone https://github.com/MathijsQ/oDCM_group_8
  - make the following new folder: scraping_assignment/**keys**
2. Place the google api json key in **/keys** folder
- download via and put in keys folder:
  - <https://mega.nz/file/DRJGzAjS#Omq-BqarSS2z7EKRCJ7kFSRrsZ7Uw80-j19wEdwQ9no>
  - <https://mega.nz/file/uARTmYQa#CEqIKQzlvmXpHwmglxDF1Trk43m84-GDV7tJrD7lt3I>
3. Place **.env** file in the root directory of the **cloned_github_repo**
- download .env and put in **odcm_group8** folder:
  - <https://mega.nz/file/uARTmYQa#CEqIKQzlvmXpHwmglxDF1Trk43m84-GDV7tJrD7lt3I>
- Add the following lines to the .env file:
```
SCRAPER_ID=1
DRIVE_ID=1sbvgEj4CnwcCXIt94lGclA4ibmis4AOT
OAUTH_CLIENT=../keys/client_secret_462496109222-v95ajc5muovgq68ttf93g11556np8itd.apps.googleusercontent.com.json
```
(Geert used SCRAPER_ID=1, Maria used 2, Nigel used 3, Mathijs used 4)

4. Open cmd in the folder **odcm_group8/src/scraping_html/** and run either: 
- python scraping_opta.py
- python scraping_oddsportal.py
-py -("your python version") scraping_opta.py
-py -("your python version") scraping_oddsportal.py

## About 

This dataset was created by Team 8 of the mandatory Online Data Collection and Management course designed for students at Tilburg University following the MSc in Marketing Analytics program. More specifically, it was consolidated by Geert Huissen, Mathijs Quarles van Ufford, María Orgaz Jiménez, and Nigel de Jong – all stu-dents of said program at Tilburg University.

## Source list
https://finance.yahoo.com/news/sports-betting-market-trends-growth-081500944.html?guccounter=1&guce_referrer=aHR0cHM6Ly93d3cuZ29vZ2xlLmNvbS8&guce_referrer_sig=AQAAAMVG_Oq1pxwgPPLN2quY8mipodqxBTiPH5tVfdf4YO-jS0d2Hmmn7c44mHDzSYE1xwkZ7JGnLuznmWbZWOg7L7fd3JuZYvdNHrsD6C-exOLqybOJfa07mF8V-f0x3N6SV1H-X-M48igYiYMV_bFALslnK6ZZqVUms3agCZb5J0VJ
