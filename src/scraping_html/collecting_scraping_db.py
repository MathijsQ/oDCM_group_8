# Importing required libraries
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from bs4 import BeautifulSoup
import os
from dotenv import load_dotenv
import gspread
from google.oauth2.service_account import Credentials
import time
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import Select
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, NoSuchElementException
import random
import hashlib
import csv

# Create output directory for saved HTML
output_dir = "../../data/scraping_logs"
os.makedirs(output_dir, exist_ok=True)

# === Connect to Google Sheet with relative paths ===
env_path = '../../.env'
env_folder = '../../'
load_dotenv(env_path)

json_relative = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
sheet_id = os.getenv("SPREADSHEET_ID")
json_full_path = os.path.join(env_folder, json_relative)

# Build credentials and authorize gspread
scopes = ["https://www.googleapis.com/auth/spreadsheets"]
creds = Credentials.from_service_account_file(json_full_path, scopes=scopes)
gc = gspread.authorize(creds)

# Open target spreadsheet and worksheet
sh = gc.open_by_key(sheet_id)

# get to opta sheet
ws_opta = sh.get_worksheet(0)
opta_data = ws_opta.get_all_values()

# get to oddsportal sheet
ws_odds = sh.get_worksheet(2)
oddsportal_data = ws_odds.get_all_values()

# Transform scraping id oddsportal to match previous hashing
header = oddsportal_data[0]
rows = oddsportal_data[1:]

# Optional: rename header of first column
header[0] = "scrape_id"

for i, row in enumerate(rows, start=1):  # start=1 because row 0 is header
    original_value = row[0]              # whatever you hashed before (e.g. link)
    hashed_id = hashlib.sha256(original_value.encode("utf-8")).hexdigest()[:24]
    oddsportal_data[i][0] = hashed_id    # replace first column with hash



opta_path = os.path.join(output_dir, "opta_database.csv")
odds_path = os.path.join(output_dir, "oddsportal_database.csv")

with open(opta_path, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerows(opta_data)

with open(odds_path, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerows(oddsportal_data)




