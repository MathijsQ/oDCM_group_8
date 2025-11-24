import os
import csv
from bs4 import BeautifulSoup
from datetime import datetime
import re
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from google.oauth2.service_account import Credentials
from dotenv import load_dotenv
from google_auth_oauthlib.flow import InstalledAppFlow

# === Connect to Google API
# Load .env file
env_path = '../../.env'
env_folder = '../../'
load_dotenv(env_path)

# Read .env variables
json_relative = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
sheet_id = os.getenv("SPREADSHEET_ID")
scraper_id = os.getenv("SCRAPER_ID")  

# Create filepath of Google API JSON key
json_full_path = os.path.join(env_folder, json_relative)

# Build credentials with Drive + Sheets scope
scopes = [
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive"
]

oauth_path = os.path.join(env_folder, os.getenv("OAUTH_CLIENT"))

flow = InstalledAppFlow.from_client_secrets_file(
    oauth_path,
    scopes=scopes
)

# This opens a browser ONCE
creds = flow.run_local_server(port=0)

# Create Drive service for uploading
drive_service = build("drive", "v3", credentials=creds)

folder_path = "../../data/html/odds_portal"
csv_path = "../../data/oddsportal/oddsportal_data.csv"

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
    kickoff_raw = "NA"
    timeblock = soup.find('div', {'data-testid': 'game-time-item'})
    if timeblock:
        # There are <p> for day, for date, and for time
        ps = timeblock.find_all("p")
        # Usually ps[1] is date, ps[2] is kickoff (after "Sunday,")
        if len(ps) == 3:
            date_raw = ps[1].get_text(strip=True).replace(',', ' ')
            time_raw = ps[2].get_text(strip=True)
            kickoff_raw = date_raw+time_raw
        else:
            kickoff_raw = 'NA'
            
    return kickoff_raw

def extract_ah_odds_bsoup(filepath):
    with open(filepath, encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    competition = extract_competition(soup)
    home, away = extract_teams_from_participants(soup)
    kickoff_raw = extract_date_time(soup)

    # --- Odds Extraction ---
    rows = []
    for block in soup.find_all("div", attrs={"data-testid": "over-under-collapsed-row"}):
        ah_label_p = block.find("p", class_="max-sm:!hidden")
        ah_label = ah_label_p.get_text(strip=True) if ah_label_p else "NA"
        odds = [p.get_text(strip=True) for p in block.find_all("p", attrs={"data-testid": "odd-container-default"})]
        if len(odds) >= 2:
            home_odd = odds[0]
            away_odd = odds[1]
        
        rows.append([home, away, competition, kickoff_raw, ah_label, home_odd, away_odd])
    return rows
done = 0
all_rows = []
for filename in os.listdir(folder_path):
    if filename.endswith(".html"):
        file_path = os.path.join(folder_path, filename)
        ah_rows = extract_ah_odds_bsoup(file_path)
        for row in ah_rows:
            all_rows.append([filename] + row)
    done = done +1
    print(f'{done}    /    {len(os.listdir(folder_path))}')

# Ensure the output directory exists:
os.makedirs(os.path.dirname(csv_path), exist_ok=True)

with open(csv_path, "w", newline='', encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow([
    "Filename", "HomeTeam", "AwayTeam", "Competition",
    "KickoffRaw", "Market", "HomeOdd", "AwayOdd"])
    writer.writerows(all_rows)

print(f"Done! Extracted Asian handicap and over/under odds and meta-data from {len(os.listdir(folder_path))} matches out of the total {len(os.listdir(folder_path))} files.")

# CSV file produced by your scraper
local_path = csv_path   # e.g. "../../data/opta/match_data.csv"

# Extract just the filename
base_name = os.path.basename(local_path)     # "match_data.csv"

# Read scraper ID and Drive folder ID from .env
scraper_id = os.getenv("SCRAPER_ID")
folder_id  = os.getenv("DRIVE_ID")

# Insert scraper ID into the filename before uploading
# match_data.csv → match_data_geert.csv
name_parts = os.path.splitext(base_name)
drive_filename = f"{name_parts[0]}_{scraper_id}{name_parts[1]}"

# Metadata for Drive
file_metadata = {
    "name": drive_filename,
    "parents": [folder_id]
}

# Upload media (CSV file)
media = MediaFileUpload(local_path, mimetype="text/csv", resumable=True)

uploaded = drive_service.files().create(
    body=file_metadata,
    media_body=media,
    fields="id, webViewLink"
).execute()

print("Uploaded:", drive_filename)
print("Drive file ID:", uploaded["id"])
print("Open in Drive:", uploaded["webViewLink"])