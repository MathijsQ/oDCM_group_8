import os
import csv
import re
from bs4 import BeautifulSoup
from datetime import datetime
from dotenv import load_dotenv

# Google APIs
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from google_auth_oauthlib.flow import InstalledAppFlow

# === Load .env Configuration ===
env_path = '../../.env'
env_folder = '../../'
load_dotenv(env_path)

oauth_path = os.path.join(env_folder, os.getenv("OAUTH_CLIENT"))
folder_id  = os.getenv("DRIVE_ID")
scraper_id = os.getenv("SCRAPER_ID")

# OAuth Scopes
scopes = [
    "https://www.googleapis.com/auth/drive",
    "https://www.googleapis.com/auth/spreadsheets"
]

# Authenticate using OAuth Client (opens browser ONCE)
flow = InstalledAppFlow.from_client_secrets_file(
    oauth_path,
    scopes=scopes
)
creds = flow.run_local_server(port=0)

# Build Drive service
drive_service = build("drive", "v3", credentials=creds)

# === File paths ===
folder_path = "../../data/html"
csv_path    = "../../data/opta/opta_data.csv"


# === Helper: Team cleaner ===
def clean_team_name(name: str) -> str:
    name = re.sub(r'^[\W.]+', '', name)
    name = re.sub(r'[\W.]+$', '', name)
    name = re.sub(r'\d+', '', name)
    return name.strip()


# === HTML Parsing ===
results = []
html_files = [fn for fn in os.listdir(folder_path) if fn.endswith(".html")]

done = 0
for filename in html_files:
    file_path = os.path.join(folder_path, filename)

    with open(file_path, encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    # Defaults
    home_team = away_team = "NA"
    home_goals = away_goals = "NA"
    comp_name = "Unknown"
    kickoff_raw = "NA"

    # ---- Teams + Goals ----
    header_table = soup.find("table", class_=re.compile("Opta-MatchHeader"))

    if header_table:
        for td in header_table.find_all("td"):
            td_class = td.get("class", [])
            text = td.get_text(strip=True)

            if "Opta-TeamName" in td_class:
                if any("Home" in c for c in td_class):
                    home_team = clean_team_name(text)
                elif any("Away" in c for c in td_class):
                    away_team = clean_team_name(text)

        score_spans = header_table.find_all("span", class_=re.compile("Opta-Team-Score"))
        if len(score_spans) >= 2:
            home_goals = score_spans[0].get_text(strip=True)
            away_goals = score_spans[1].get_text(strip=True)
        elif len(score_spans) == 1:
            home_goals = score_spans[0].get_text(strip=True)

    # ---- Kickoff ----
    date_span = soup.find("span", class_="Opta-Date")
    kickoff_raw = date_span.get_text(strip=True) if date_span else "NA"

    # ---- Competition ----
    comp_span = soup.find("span", class_="Opta-Competition")
    comp_name = comp_span.get_text(strip=True) if comp_span else "Unknown"

    # Add row
    results.append([
        home_team,
        away_team,
        home_goals,
        away_goals,
        kickoff_raw,
        comp_name,
        filename
    ])

    done += 1
    print(f"{done} / {len(html_files)}")


# === Save CSV ===
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

print(f"Done! Processed {len(results)} matches.")


# === Upload to Google Drive ===
local_path = csv_path
base_name = os.path.basename(local_path)
name_root, ext = os.path.splitext(base_name)

drive_filename = f"{name_root}_{scraper_id}{ext}"

file_metadata = {
    "name": drive_filename,
    "parents": [folder_id]
}

media = MediaFileUpload(local_path, mimetype="text/csv", resumable=True)

uploaded = drive_service.files().create(
    body=file_metadata,
    media_body=media,
    fields="id, webViewLink"
).execute()

print("Uploaded:", drive_filename)
print("Drive file ID:", uploaded["id"])
print("Open in Drive:", uploaded["webViewLink"])
