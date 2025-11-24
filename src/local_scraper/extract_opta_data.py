import os
import csv
import re
from bs4 import BeautifulSoup

folder_path = "../../data/html"
csv_path = "../../data/opta/match_data.csv"

def clean_team_name(name: str) -> str:
    """
    Basic cleaning of team names:
    - remove leading/trailing non-word characters and periods
    - remove digits
    - strip whitespace
    """
    name = re.sub(r'^[\W.]+', '', name)   # Remove leading non-word chars and periods
    name = re.sub(r'[\W.]+$', '', name)   # Remove trailing non-word chars and periods
    name = re.sub(r'\d+', '', name)       # Remove digits
    return name.strip()

results = []

# Only process .html files and keep the list for a correct count
html_files = [fn for fn in os.listdir(folder_path) if fn.endswith(".html")]
done = 0
for filename in html_files:
    file_path = os.path.join(folder_path, filename)
    # If there are odd encodings, this may still fail; then you could add try/except.
    with open(file_path, encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    # Defaults
    home_team = "NA"
    away_team = "NA"
    home_goals = "NA"
    away_goals = "NA"
    comp_name = "Unknown"
    kickoff_raw = "NA"

    # ---- Header table: teams and scores ----
    header_table = soup.find("table", class_=re.compile("Opta-MatchHeader"))
    if header_table:
        # Team names
        for td in header_table.find_all("td"):
            td_class = td.get("class", [])
            td_text = td.get_text(strip=True)
            if "Opta-TeamName" in td_class:
                if any("Home" in c for c in td_class):
                    home_team = clean_team_name(td_text)
                elif any("Away" in c for c in td_class):
                    away_team = clean_team_name(td_text)

        # Goals
        score_spans = header_table.find_all("span", class_=re.compile("Opta-Team-Score"))
        if len(score_spans) >= 2:
            home_goals = score_spans[0].get_text(strip=True)
            away_goals = score_spans[1].get_text(strip=True)
        elif len(score_spans) == 1:
            home_goals = score_spans[0].get_text(strip=True)
            away_goals = "NA"

    # ---- Kickoff: raw datetime string ----
    date_span = soup.find("span", class_="Opta-Date")
    if date_span:
        kickoff_raw = date_span.get_text(strip=True)
    else:
        kickoff_raw = "NA"

    # ---- Competition ----
    comp_span = soup.find("span", class_="Opta-Competition")
    if comp_span:
        comp_name = comp_span.get_text(strip=True)
    else:
        comp_name = "Unknown"

    results.append([
        home_team,
        away_team,
        home_goals,
        away_goals,
        kickoff_raw,
        comp_name,
        filename
    ])
    done = done+1
    print(f'{done}   /    {len(html_files)}')

# Ensure the output folder exists
os.makedirs(os.path.dirname(csv_path), exist_ok=True)

with open(csv_path, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow([
        "HomeTeam",
        "AwayTeam",
        "HomeGoals",
        "AwayGoals",
        "KickoffTimeRaw",
        "Competition",
        "Filename"
    ])
    writer.writerows(results)

print(f"Done! Processed {len(results)} matches from {len(html_files)} HTML files.")
