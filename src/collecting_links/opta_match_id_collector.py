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

#  Build credentials
scopes = ["https://www.googleapis.com/auth/spreadsheets"]
creds = Credentials.from_service_account_file(json_full_path, scopes=scopes)

# Authorize gspread
gc = gspread.authorize(creds)

# Open spreadsheet
sh = gc.open_by_key(sheet_id)
ws = sh.sheet1
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

# Select competition
comps = ['Premier League', 'Bundesliga', 'Primera División', 'Ligue 1', 'Serie A', 'UEFA Champions League', 'UEFA Europa League']

for comp in comps:
    driver.get(url) # Redirect to the base url
    time.sleep(5)   # Wait for page to load
    accept_cookies_if_present_opta(driver=driver)


    # Redirect to competition page
    href = driver.find_element(By.LINK_TEXT, comp)
    href.click()

    # Click the stats page link
    stats_ref = driver.find_element(By.LINK_TEXT, "Opta Player Stats")
    stats_ref.click()
    time.sleep(5)

    # Select the 24/25 season
    select = Select(driver.find_element(By.ID, "season-select"))
    select.select_by_visible_text("2024/2025")
    time.sleep(5)   # Wait for whole page to load

    # Create Soup element
    html = driver.page_source
    soup = BeautifulSoup(html, "html.parser")

    # Collect competitions match-id's
    fixtures = soup.find("div", class_="Opta-fixtures-list")
    list_fixtures = fixtures.find_all("tbody", class_="Opta-fixture")

    opta_ids = []   # Create empty opta match ids list
    
    # Loop through list of fixtures and collect match_id
    for fixture in list_fixtures:
        opta_id = fixture.get('data-match')
        opta_ids.append(opta_id)

    unique_check = len(opta_ids) == len(set(opta_ids))
    print(f'All match ids are unique: {unique_check}')

    # Create list of already existing opta id's
    # read entire sheet
    sheet = ws.get_all_values()

    existing_ids = []
    
    # build existing list only for rows where column B == comp
    for row in sheet[1:]:  # skip header
        if len(row) >= 2:
            if row[1].strip() == comp:
                existing_ids.append(row[0])
        
    rows = []  # this will become a list of [match_id]

    for opta_id in opta_ids:
        if opta_id not in existing_ids:
            row = [opta_id, comp]   # two rows: match_id, and comp
            rows.append(row)

    if rows:
        ws.append_rows(rows, value_input_option="RAW")
    
    if not rows:
        print('All collected match ids are already getting tracked!')

sheet = ws.get_all_values()
result_n = []

for comp in comps:
    comp_filter = [row for row in sheet if row[1]==comp]
    n_rows = len(comp_filter)
    result_n.append(
        {'comp': comp,
         'n': n_rows}
    )
print(result_n)

