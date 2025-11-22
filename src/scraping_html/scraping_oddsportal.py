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


# === Helper: wait for CSS selector, track possible blocking ===
def safe_wait_css(driver, css_selector, block_suspicions, max_suspicions=3, wait_time=10):
    try:
        WebDriverWait(driver, wait_time).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, css_selector))
        )
        return True, 0, False  # success → reset suspicion counter
    except TimeoutException:
        block_suspicions = block_suspicions + 1
        print(f'WARNING! Timeout waiting for selector: {css_selector}')
        print(f'WARNING! Current BLOCK suspicion count: {block_suspicions}')

        if block_suspicions >= max_suspicions:
            print('ERROR, Too many block suspicions -> STOPPING SESSION')
            return False, block_suspicions, True

        sleep_seconds = random.uniform(8, 15)
        print(f'Backing off for {sleep_seconds:.1f}s...')
        time.sleep(sleep_seconds)

        return False, block_suspicions, False


# === Helper: increment per-link error counter in sheet ===
def increment_error_count(ws, row_index, col_index=7):
    cell_value = ws.cell(row_index, col_index).value
    try:
        current = int(cell_value) if cell_value not in (None, "") else 0
    except ValueError:
        current = 0
    ws.update_cell(row_index, col_index, current + 1)


# Create output directory for saved HTML
output_dir = "../../data/html/odds_portal"
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
ws = sh.get_worksheet(2)
print("Success! Connected to:", sh.title)
print("First row:", ws.row_values(1))

# === Selenium setup ===
service = Service(ChromeDriverManager().install())
driver = webdriver.Chrome(service=service)

base_url = 'https://www.oddsportal.com'

# Open base URL
driver.get(base_url)
time.sleep(5)

# === Accept cookies (OneTrust) ===
wait = WebDriverWait(driver, 10)
wait.until(EC.presence_of_element_located((By.ID, "onetrust-consent-sdk")))
accept_btn = wait.until(
    EC.element_to_be_clickable((By.ID, "onetrust-accept-btn-handler"))
)
accept_btn.click()

# Pick random batch size for this session
batch_size = random.choice(range(20, 41))
print(f'Scraping {batch_size} matches this session...')

# Global suspicion counter
block_suspicions = 0

# === Main scraping loop ===
while batch_size > 0:

    population = []
    rows = ws.get_all_values()[1:]  # all rows, skip header

    # Build population of matches where OU or AH is not yet done
    for idx, row in enumerate(rows, start=2):
        competition = row[1]
        status = row[2]     # OU status (col C)
        odds_id = row[0]
        status_ah = row[4]  # AH status (col E)

        if status.strip() == "" or status_ah.strip() == "":
            population.append((idx, odds_id))

    # Nothing left to scrape
    if not population:
        print("No remaining links.. Aborting...")
        break

    # Randomly pick a match from population
    match_to_scrape = random.choice(population)
    db_index = match_to_scrape[0]
    link_to_scrape = match_to_scrape[1]
    print(f'Scraping following link: {base_url}{link_to_scrape}, with db_index of {db_index}...')

    # ==== OVER/UNDER ====
    driver.get(f'{base_url}{link_to_scrape}#over-under;2')
    timestamp_ou = time.time()

    css_odds_over_under = 'div[data-testid="over-under-collapsed-row"]'

    # Wait for OU section to exist (any provider)
    success, block_suspicions, should_stop = safe_wait_css(
        driver=driver,
        css_selector=css_odds_over_under,
        block_suspicions=block_suspicions
    )
    if should_stop:
        increment_error_count(ws, db_index)
        break
    if not success:
        increment_error_count(ws, db_index)
        continue

    # Switch to classic bookies
    classic_bookies = driver.find_element(By.CSS_SELECTOR, 'div[data-testid="classic"]')
    classic_bookies.click()
    time.sleep(random.uniform(0.5, 1.25))

    # Wait again for OU rows under classic bookies
    success, block_suspicions, should_stop = safe_wait_css(
        driver=driver,
        css_selector=css_odds_over_under,
        block_suspicions=block_suspicions
    )
    if should_stop:
        increment_error_count(ws, db_index)
        break
    if not success:
        increment_error_count(ws, db_index)
        continue

    # Save OU HTML
    html_content = driver.page_source
    h = hashlib.sha256(link_to_scrape.encode()).hexdigest()[:24]
    filename = f'{output_dir}/ou_{h}.html'
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(html_content)

    # Mark OU as done in sheet (cols C and D)
    ws.update_cell(db_index, 3, "done")
    ws.update_cell(db_index, 4, timestamp_ou)

    # ==== ASIAN HANDICAP ====
    driver.get(f'{base_url}{link_to_scrape}#ah;2')
    time.sleep(random.uniform(0.5, 1.25))
    driver.refresh()
    timestamp_ah = time.time()

    css_odds_over_under = 'div[data-testid="over-under-collapsed-row"]'

    # Wait for AH section to exist (any provider)
    success, block_suspicions, should_stop = safe_wait_css(
        driver=driver,
        css_selector=css_odds_over_under,
        block_suspicions=block_suspicions
    )
    if should_stop:
        increment_error_count(ws, db_index)
        break
    if not success:
        increment_error_count(ws, db_index)
        continue

    # Switch to classic bookies
    classic_bookies = driver.find_element(By.CSS_SELECTOR, 'div[data-testid="classic"]')
    classic_bookies.click()
    time.sleep(random.uniform(0.5, 1.25))

    # Wait again for AH rows under classic bookies
    success, block_suspicions, should_stop = safe_wait_css(
        driver=driver,
        css_selector=css_odds_over_under,
        block_suspicions=block_suspicions
    )
    if should_stop:
        increment_error_count(ws, db_index)
        break
    if not success:
        increment_error_count(ws, db_index)
        continue

    time.sleep(random.uniform(0.5, 1.25))

    # Save AH HTML
    html_content = driver.page_source
    h = hashlib.sha256(link_to_scrape.encode()).hexdigest()[:24]
    filename = f'{output_dir}/ah_{h}.html'
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(html_content)

    # Mark AH as done in sheet (cols E and F)
    ws.update_cell(db_index, 5, "done")
    ws.update_cell(db_index, 6, timestamp_ah)

    # One match (OU + AH) done in this batch
    batch_size = batch_size - 1

# === Compute total scraping progress (OU + AH) ===
final_sheet_after_scraping = ws.get_all_values()

status_col = [row[2] for row in final_sheet_after_scraping[1:]]  # OU
status_col_ = [row[4] for row in final_sheet_after_scraping[1:]]  # AH

done_count = status_col.count('done') + status_col_.count('done')
total_scrapes = len(status_col) * 2

progress_pct = (done_count / total_scrapes) * 100 if total_scrapes > 0 else 0

print(
    f"Total scraping progress after this session: {done_count} of {total_scrapes} "
    f"({progress_pct:.2f}%)"
)
