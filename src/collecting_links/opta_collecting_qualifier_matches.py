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
from selenium.common.exceptions import NoSuchElementException

# === Helper function opta cookies ===

def accept_cookies_if_present_opta(driver):
    # 1) Check if the <aside id="usercentrics-cmp-ui"> element exists
    try:
        driver.find_element(By.ID, "usercentrics-cmp-ui")
    except NoSuchElementException:
        # No cookie popup at all
        print("No cookie popup container found.")
        return False

    # 2) If it exists, click the shadow DOM button via JS
    script = """
    const aside = document.querySelector('aside#usercentrics-cmp-ui');
    if (!aside) return false;

    const root = aside.shadowRoot;
    if (!root) return false;

    const btn = root.querySelector('button#accept, button[aria-label="Accept All"], button.uc-accept-button');
    if (!btn) return false;

    btn.click();
    return true;
    """

    clicked = driver.execute_script(script)

    if clicked:
        print("Cookie popup clicked successfully.")
    else:
        print("Cookie popup found, but Accept button not found.")

    return clicked


# === Connecting to our scraping match id status database ===

# Load .env file
env_path = '../../.env'
env_folder= '../../'
load_dotenv(env_path)

# Read .env variables
json_relative = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
sheet_id = os.getenv("SPREADSHEET_ID")

# Create filepath of Google API JSON key
json_full_path = os.path.join(env_folder, json_relative)

# Build credentials
scopes = ["https://www.googleapis.com/auth/spreadsheets"]
creds = Credentials.from_service_account_file(json_full_path, scopes=scopes)

# Authorize gspread
gc = gspread.authorize(creds)

# Open spreadsheet
sh = gc.open_by_key(sheet_id)
ws = sh.get_worksheet(1)
print("Success! Connected to:", sh.title)
print("First row:", ws.row_values(1))

# Set column names
ws.update([["match_id", "competition"]], "A1:B1")

# === Collecting match id's ===

# Setting up Chrome WebDriver with WebDriver Manager using Service
service = Service(ChromeDriverManager().install())
driver = webdriver.Chrome(service=service)

# Starting url
url = 'https://optaplayerstats.statsperform.com/en_GB/soccer/competitions'

# Select competitions
comps = ['UEFA Champions League', 'UEFA Europa League']

for comp in comps:
    driver.get(url)          # Redirect to the base url
    time.sleep(5)            # Wait for page to load
    accept_cookies_if_present_opta(driver=driver)

    # Redirect to competition page
    href = driver.find_element(By.LINK_TEXT, comp)
    href.click()
    time.sleep(5)
    # Select the 24/25 season
    select = Select(driver.find_element(By.ID, "season-select"))
    select.select_by_visible_text("2024/2025")
    time.sleep(5)            # Wait for whole page to load

    # Stages to scrape (qualifiers, play-offs etc.)
    stages = ['Play-offs', '3rd Qualifying Round', '2nd Qualifying Round', '1st Qualifying Round']

    for stage in stages:
        # Open the stage dropdown
        # Often there are 2 dropdowns; if so, use the second one (index 1)
        dropdown = driver.find_element(By.CSS_SELECTOR, "h3.Opta-Exp")
        dropdown.click()
        time.sleep(5)

        # Click the specific stage by visible text
        driver.find_element(By.LINK_TEXT, stage).click()
        time.sleep(5)        # Wait for fixtures of this stage to load

        # Collect only VISIBLE fixtures for this stage
        visible_rows = [
            row for row in driver.find_elements(By.CSS_SELECTOR, "tbody.Opta-fixture")
            if row.is_displayed()]

        opta_ids = []
        for row in visible_rows:
            match_id = row.get_attribute("data-match")
            if match_id:
                opta_ids.append(match_id)

        unique_check = len(opta_ids) == len(set(opta_ids))
        print(f'[{comp} – {stage}] All match ids are unique: {unique_check}')

        # Create list of already existing opta IDs
        sheet = ws.get_all_values()

        existing_ids = []
        # Build existing list only for rows where column B == comp
        for row in sheet[1:]:  # skip header
            if len(row) >= 2 and row[1].strip() == comp:
                existing_ids.append(row[0])

        rows = []  # this will become a list of [match_id, competition]

        for opta_id in opta_ids:
            if opta_id not in existing_ids:
                row = [opta_id, comp]
                rows.append(row)

        if rows:
            ws.append_rows(rows, value_input_option="RAW")

# Summary: how many rows per competition
sheet = ws.get_all_values()
result_n = []

for comp in comps:
    comp_filter = [row for row in sheet[1:] if len(row) >= 2 and row[1] == comp]
    n_rows = len(comp_filter)
    result_n.append({'comp': comp, 'n': n_rows})

print(result_n)

driver.quit()
