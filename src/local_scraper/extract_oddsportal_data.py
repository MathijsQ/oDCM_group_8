import os
import csv
from bs4 import BeautifulSoup
from datetime import datetime
import re

folder_path = "../../data/html/odds_portal"
csv_path = "../../data/output/oddsportal_ah_data.csv"

def extract_teams_from_participants(soup):
    participants = soup.find('div', {'data-testid': 'game-participants'})
    home, away = "NA", "NA"
    if participants:
        # Home
        host = participants.find('div', {'data-testid': 'game-host'})
        if host:
            home_p = host.find("p")
            if home_p:
                home = home_p.get_text(strip=True)
        # Away
        guest = participants.find('div', {'data-testid': 'game-guest'})
        if guest:
            away_p = guest.find("p")
            if away_p:
                away = away_p.get_text(strip=True)
    return home, away

def extract_competition(soup):
    competition = "Unknown"
    breadcrumbs = soup.find('div', {'data-testid': 'breadcrumbs-line'})
    if breadcrumbs:
        comp_a = breadcrumbs.find_all("a")
        if comp_a:
            competition = comp_a[-1].text.strip()
    return competition

def extract_date_time(soup):
    # Look for data-testid="game-time-item"
    date, kickoff = "NA", "NA"
    timeblock = soup.find('div', {'data-testid': 'game-time-item'})
    if timeblock:
        # There are <p> for day, for date, and for time
        ps = timeblock.find_all("p")
        # Usually ps[1] is date, ps[2] is kickoff (after "Sunday,")
        if len(ps) >= 3:
            date_raw = ps[1].get_text(strip=True).replace(',', '')
            try:
                dt = datetime.strptime(date_raw, "%d %b %Y")
                date = dt.strftime("%d%m%y")
            except:
                date = date_raw
            kickoff = ps[2].get_text(strip=True)
    return date, kickoff

def extract_ah_odds_bsoup(filepath):
    with open(filepath, encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    competition = extract_competition(soup)
    home, away = extract_teams_from_participants(soup)
    match_date, kickoff_time = extract_date_time(soup)

    # --- Odds Extraction ---
    rows = []
    for block in soup.find_all("div", attrs={"data-testid": "over-under-collapsed-row"}):
        ah_label_p = block.find("p", class_="max-sm:!hidden")
        ah_label = ah_label_p.get_text(strip=True) if ah_label_p else "NA"
        odds = [p.get_text(strip=True) for p in block.find_all("p", attrs={"data-testid": "odd-container-default"})]
        if len(odds) >= 2:
            home_odd = odds[0]
            away_odd = odds[1]
        else:
            fallback_odds = [p.get_text(strip=True) for p in block.find_all("p", class_="ml-auto pr-3 text-xs font-normal")]
            home_odd = fallback_odds[0] if len(fallback_odds) > 0 else "NA"
            away_odd = fallback_odds[1] if len(fallback_odds) > 1 else "NA"
        rows.append([home, away, competition, match_date, kickoff_time, ah_label, home_odd, away_odd])
    return rows

all_rows = []
for filename in os.listdir(folder_path):
    if filename.endswith(".html"):
        file_path = os.path.join(folder_path, filename)
        ah_rows = extract_ah_odds_bsoup(file_path)
        for row in ah_rows:
            all_rows.append([filename] + row)

# Ensure the output directory exists:
os.makedirs(os.path.dirname(csv_path), exist_ok=True)

with open(csv_path, "w", newline='', encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(["Filename", "HomeTeam", "AwayTeam", "Competition", "Date", "KickoffTime", "AsianHandicap", "HomeOdd", "AwayOdd"])
    writer.writerows(all_rows)

print(f"Done! Extracted AH odds and meta-data from {len(all_rows)} rows in {len(os.listdir(folder_path))} files.")
