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
from selenium.common.exceptions import TimeoutException
from selenium.common.exceptions import NoSuchElementException
from selenium.common.exceptions import ElementNotInteractableException

# === Connecting to our scraping match id status database ===

# Load .env file (contains credential paths and sheet ID)
env_path = '../../.env'
env_folder= '../../'
load_dotenv(env_path)

# Read .env variables with Google credentials and spreadsheet ID
json_relative = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
sheet_id = os.getenv("SPREADSHEET_ID")

# Construct full path to Google Service Account key
json_full_path = os.path.join(env_folder, json_relative)

# Build credentials and authorize access to Google Sheets
scopes = ["https://www.googleapis.com/auth/spreadsheets"]
creds = Credentials.from_service_account_file(json_full_path, scopes=scopes)
gc = gspread.authorize(creds)

# Open target spreadsheet and worksheet
sh = gc.open_by_key(sheet_id)
ws = sh.get_worksheet(2)
print("Success! Connected to:", sh.title)
print("First row:", ws.row_values(1))

# Overwrite header row with column labels
ws.update([["odds_id", "competition"]], "A1:B1")

# === Collecting match id's ===

# Setup Chrome WebDriver
service = Service(ChromeDriverManager().install())
driver = webdriver.Chrome(service=service)

# Base URL for oddsportal
url = 'https://www.oddsportal.com'

# Load homepage
driver.get(url)
time.sleep(5)

# Setup wait object for expected_conditions
wait = WebDriverWait(driver, 10)

# Wait for OddsPortal cookie banner (OneTrust) to appear
wait.until(EC.presence_of_element_located((By.ID, "onetrust-consent-sdk")))

# Wait until cookie button is clickable and accept it
accept_btn = wait.until(
    EC.element_to_be_clickable((By.ID, "onetrust-accept-btn-handler"))
)
accept_btn.click()

# List of competitions with display names and URL fragments
comps = ['Premier League', 'Bundesliga', 'Primera División', 'Ligue 1', 
         'Serie A', 'UEFA Champions League', 'UEFA Europa League']

# URL fragments for each competition
comps_links = ['/football/england/premier-league',
               '/football/germany/bundesliga',
               '/football/spain/laliga',
               '/football/france/ligue-1',
               '/football/italy/serie-a',
               '/football/europe/champions-league',
               '/football/europe/europa-league']

# ===== Loop over each competition =====
for comp in comps_links:

    # Load page 1 of results for the competition
    driver.get(f'{url}{comp}-2024-2025/results/')
    time.sleep(5)

    # Pagination button selector used by OddsPortal
    selector = 'a.pagination-link'

    # Determine total number of <a.pagination-link> elements
    # Assumes last element on first page is "Next"
    pages = driver.find_elements(By.CSS_SELECTOR, selector)
    n_pages = len(pages) - 1   # number of numeric pages
    print(f'The number of pages needed for this competition is {n_pages}')

    # Loop through all pages (1 = first page)
    for page in range(1, n_pages + 1):

        # === FIRST PAGE (no URL modification needed) ===
        if page == 1:
            print('No link construction needed for this page')
            # Trigger lazy-loading by forcing scroll to bottom
            driver.execute_script("window.scrollTo(0,999999);")
            time.sleep(2)

        # === SUBSEQUENT PAGES: construct URL + reload ===
        else:
            # Build fragment URL for the page: /#/page/{page}/
            page_url = f'{url}{comp}-2024-2025/results/#/page/{page}/'

            # Load URL (hash navigation)
            driver.get(page_url)
            time.sleep(0.2)

            # Force full reload (needed because hash does not refresh data)
            driver.refresh()
            time.sleep(5)

            # For lazy loading: scroll up, then scroll fully down
            driver.execute_script("window.scrollTo(0,0);")
            time.sleep(2)
            driver.execute_script("window.scrollTo(0,999999);")
            time.sleep(2)

        # === Parse page after lazy loading ===
        html = driver.page_source
        soup = BeautifulSoup(html, "html.parser")

        # Find all match rows using data-testid attribute
        list_fixtures = soup.find_all("div", attrs={'data-testid': 'game-row'})

        # Collect match URLs
        odds_ids = []
        for fixture in list_fixtures:
            link_tag = fixture.find('a', href=True)
            if not link_tag:
                continue
            odds_id = link_tag['href']
            odds_ids.append(odds_id)

        # Check for duplicate IDs on the page
        unique_check = len(odds_ids) == len(set(odds_ids))
        print(f'All match ids are unique: {unique_check}')

        # Load existing rows from sheet for duplication check
        sheet = ws.get_all_values()
        existing_ids = []

        # Build list of existing IDs for this competition only
        for row in sheet[1:]:
            if len(row) >= 2 and row[1].strip() == comp:
                existing_ids.append(row[0])

        # Assemble rows to insert into Google Sheet
        rows = []
        for odds_id in odds_ids:
            if odds_id not in existing_ids:
                rows.append([odds_id, comp])

        # Append new match IDs (if any)
        if rows:
            ws.append_rows(rows, value_input_option="RAW")
        else:
            print('All collected match ids are already getting tracked!')

    # After finishing this competition, return to base URL
    driver.get(url)
    time.sleep(5)

# === Sanity check: count how many ids per competition ===
sheet = ws.get_all_values()
result_n = []

for comp in comps_links:
    comp_filter = [row for row in sheet if row[1] == comp]
    n_rows = len(comp_filter)
    result_n.append({'comp': comp, 'n': n_rows})

print(result_n)
