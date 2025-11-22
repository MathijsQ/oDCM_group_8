import os
import csv
import re
from bs4 import BeautifulSoup
from datetime import datetime

folder_path = "../../data/html"
csv_path = "../../data/all_match_data.csv"

def clean_team_name(name):
    name = re.sub(r'^[\W.]+', '', name)   # Remove leading non-word chars and periods
    name = re.sub(r'[\W.]+$', '', name)   # Remove trailing non-word chars and periods
    name = re.sub(r'\d+', '', name)       # Remove digits
    return name.strip()

def get_team_abbr(name):
    name = clean_team_name(name)
    words = [w for w in name.split() if w.isalpha() or w.isalnum()]
    abbr = '_'.join([w[:3].upper() for w in words[:2]]) if len(words) >= 2 else name[:3].upper()
    return abbr

def get_comp_code(compname):
    words = [w for w in compname.split() if w.isalpha()]
    code = ''.join([w[0].upper() for w in words[:2]]) if len(words) >= 2 else compname[:2].upper()
    return code

def extract_match_date(soup, filename):
    candidates = soup.find_all(["span", "td", "div"])
    raw_texts = [c.get_text(" ", strip=True) for c in candidates] + [soup.get_text(" ", strip=True), filename]
    patterns = [r'(\d{1,2} [A-Za-z]+ \d{4})', r'(\d{2}/\d{2}/\d{4})', r'(\d{2}-\d{2}-\d{4})']
    for txt in raw_texts:
        for pat in patterns:
            found = re.search(pat, txt)
            if found:
                date_text = found.group(1)
                try:
                    if '-' in date_text:
                        dt = datetime.strptime(date_text, "%d-%m-%Y")
                    elif '/' in date_text:
                        dt = datetime.strptime(date_text, "%d/%m/%Y")
                    else:
                        dt = datetime.strptime(date_text, "%d %B %Y")
                    return dt.strftime("%d%m%y")
                except: continue
    # Fallback: look for yymmdd in filename
    fname_found = re.search(r'(\d{6})', filename)
    return fname_found.group(1) if fname_found else "NA"

results = []

for filename in os.listdir(folder_path):
    if filename.endswith(".html"):
        file_path = os.path.join(folder_path, filename)
        with open(file_path, encoding="utf-8") as f:
            soup = BeautifulSoup(f, "html.parser")

        # Always define defaults before extracting
        home_team, away_team, home_goals, away_goals = "NA", "NA", "NA", "NA"
        match_date, comp_name, comp_code = "NA", "Unknown", "UN"

        header_table = soup.find("table", class_=re.compile("Opta-MatchHeader"))
        if header_table:
            for td in header_table.find_all("td"):
                td_class = td.get("class", [])
                td_text = td.get_text(strip=True)
                if "Opta-TeamName" in td_class:
                    if any("Home" in c for c in td_class):
                        home_team = clean_team_name(td_text)
                    elif any("Away" in c for c in td_class):
                        away_team = clean_team_name(td_text)
            score_spans = header_table.find_all("span", class_=re.compile("Opta-Team-Score"))
            if len(score_spans) >= 2:
                home_goals = score_spans[0].get_text(strip=True)
                away_goals = score_spans[1].get_text(strip=True)
            elif len(score_spans) == 1:
                home_goals = score_spans[0].get_text(strip=True)
                away_goals = "NA"

        match_date = extract_match_date(soup, filename)

        comp_patterns = r"Premier League|Bundesliga|Serie A|Primera División|Ligue 1|La Liga|Championship|Eredivisie|Süper Lig|European"
        comp_tag = soup.find(string=re.compile(comp_patterns))
        comp_name = comp_tag.strip() if comp_tag else "Unknown"
        comp_code = get_comp_code(comp_name)

        match_id = f"{get_team_abbr(home_team)}_{get_team_abbr(away_team)}_{match_date}_{comp_code}"

        results.append([match_id, home_team, home_goals, away_goals, away_team, match_date, comp_name, filename])

with open(csv_path, "w", newline='', encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(["MatchID", "HomeTeam", "HomeGoals", "AwayGoals", "AwayTeam", "MatchDate", "Competition", "Filename"])
    writer.writerows(results)

print(f"Done! Processed {len(results)} matches from {len(os.listdir(folder_path))} HTML files.")

