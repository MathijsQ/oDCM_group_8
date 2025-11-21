import os
from bs4 import BeautifulSoup
from datetime import datetime
import re
import csv

def extract_opta_matches(file_path):
    with open(file_path, encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    competition = None
    comp_link = soup.find("a", class_=re.compile("Opta-MatchLink"))
    if comp_link:
        match = re.search(r'/soccer/([^/]+)-', comp_link.get('href', ''))
        if match:
            competition = match.group(1).replace('-', ' ').title()
        else:
            competition = comp_link.text.strip()

    matches = soup.find_all("tbody", class_=re.compile(r"Opta-fixture.*Opta-Match-"))
    result = []
    for match_tb in matches:
        match_id = match_tb.get("data-match")
        date_epoch = match_tb.get("data-date")
        match_date = (datetime.utcfromtimestamp(int(date_epoch)/1000).strftime("%d%m%y")
                      if date_epoch else "NA")

        # Robust home/away team extraction
        home_team_td = match_tb.find("td", string=re.compile(r".+"))  # gets first td with text
        away_team_td = None
        # Find all <td>s and get those that contain team names/away designation
        td_candidates = match_tb.find_all("td")
        for td in td_candidates:
            td_class = td.get("class", [])
            td_text = td.text.strip()
            if td_class and "Opta-TeamName" in td_class:
                if "Home" in " ".join(td_class):
                    home_team_td = td
                elif "Away" in " ".join(td_class):
                    away_team_td = td

        home_name = home_team_td.text.strip() if home_team_td else "NA"
        away_name = away_team_td.text.strip() if away_team_td else "NA"

        home_score_td = match_tb.find("td", class_=re.compile("Opta-Team-Left"))
        away_score_td = match_tb.find("td", class_=re.compile("Opta-Team-Right"))
        home_score_span = home_score_td.find("span", class_=re.compile("Opta-Team-Score")) if home_score_td else None
        away_score_span = away_score_td.find("span", class_=re.compile("Opta-Team-Score")) if away_score_td else None
        home_goals = home_score_span.text.strip() if home_score_span else "NA"
        away_goals = away_score_span.text.strip() if away_score_span else "NA"

        home_code = ''.join(word[0].upper() for word in home_name.split() if word)
        away_code = ''.join(word[0].upper() for word in away_name.split() if word)
        comp_code = ''.join(word[0].upper() for word in competition.split()) if competition else "NA"
        unique_id = f"{home_code}_{away_code}_{match_date}_{comp_code}"

        result.append([
            unique_id, home_name, away_name, home_goals, away_goals, match_date, competition
        ])
    return result

# Folder path (relative to extract_match_data.py)
folder_path = "../../data/html"
all_results = []

for filename in os.listdir(folder_path):
    if filename.endswith(".html"):
        file_path = os.path.join(folder_path, filename)
        match_data = extract_opta_matches(file_path)
        all_results.extend(match_data)

# Output file in the same folder as the script
csv_path = "../../data/all_match_data.csv"
with open(csv_path, "w", newline='', encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(["MatchID", "HomeTeam", "AwayTeam", "HomeGoals", "AwayGoals", "MatchDate", "Competition"])
    writer.writerows(all_results)

print(f"Done! Processed {len(all_results)} matches from {len(os.listdir(folder_path))} HTML files.")
