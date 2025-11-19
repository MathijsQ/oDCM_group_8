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
import random

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


# === Helper function block suspicion abort ===

def safe_wait_css(driver, css_selector, block_suspicions, max_suspicions = 3, wait_time = 10):
    try:
        WebDriverWait(driver, wait_time).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, css_selector))
        )
        return True, 0, False
    
    except TimeoutException:
        block_suspicions = block_suspicions + 1
        print(f'WARNING! Timeout waiting for selector: {css_selector}')
        print(f'WARNING! Currrent BLOCK suspicion count: {block_suspicions}')

        if block_suspicions >= max_suspicions:
            print('ERROR, Too many block suspicions -> STOPPING SESSION')
            return False, block_suspicions, True
        
        sleep_seconds = random.uniform(8,15)
        print(f'Backing off for {sleep_seconds:.1f}s...')
        time.sleep(sleep_seconds)

        return False, block_suspicions, False

# === Helper function to keep track of potential errors per link ===
def increment_error_count(ws, row_index, col_index=5):
    cell_value = ws.cell(row_index, col_index).value
    try:
        current = int(cell_value) if cell_value not in (None, "") else 0
    except ValueError:
        current = 0  

    new_value = current + 1
    ws.update_cell(row_index, col_index, new_value)


# Creating output directory
output_dir = "../../data/html"
os.makedirs(output_dir, exist_ok=True)

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

# Make sure status column has a header
ws.update([['status']], "C1")

# Setting up Chrome WebDriver with WebDriver Manager using Service
service = Service(ChromeDriverManager().install())
driver = webdriver.Chrome(service=service)

# Starting url
url = 'https://optaplayerstats.statsperform.com/en_GB/soccer/competitions'


# Select competition
comps = ['Premier League', 'Bundesliga', 'Primera División', 'Ligue 1', 'Serie A', 'UEFA Champions League', 'UEFA Europa League']

selected_comp = random.choice(comps)

# Access url in selenium
driver.get(url)
time.sleep(5)
accept_cookies_if_present_opta(driver=driver)

# Redirect to competition page
href = driver.find_element(By.LINK_TEXT, selected_comp)
href.click()

# Click the stats page link
stats_ref = driver.find_element(By.LINK_TEXT, "Opta Player Stats")
stats_ref.click()
time.sleep(5)

# Select the 24/25 season
select = Select(driver.find_element(By.ID, "season-select"))
select.select_by_visible_text("2024/2025")
time.sleep(5)   # Wait for whole page to load


# Pick batch size
batch_size = random.choice(range(20,41))
print(f'Scraping {batch_size} matches this session...')

# Block suspicion counter
block_suspicions = 0

while batch_size > 0:

    population = []

    rows = ws.get_all_values()[1:]  # skip header

    for idx, row in enumerate(rows, start=2):
        competition = row[1]
        status = row[2]
        opta_id = row[0]

        if competition == selected_comp and status.strip() == "":
            population.append((idx, opta_id))

    # == EMPTY POPULATION BREAK ==
    if not population:
        print(f"No remaining links for: {selected_comp}")
        break

    match_to_scrape = random.choice(population)
    db_index = match_to_scrape[0]               # This is the idx
    opta_id_to_scrape = match_to_scrape[1]      # This is the opta id
    print(f'Scraping opta id {opta_id_to_scrape}, with db_index of {db_index}...')

    # Define css search logic
    css_match_overview = 'tbody[data-match]'
    
    # Call block suspicion function
    success, block_suspicions, should_stop = safe_wait_css(
        driver=driver,
        css_selector=css_match_overview,
        block_suspicions=block_suspicions
    )
    if should_stop:
        break
    if not success:
        continue


    time.sleep(random.uniform(0.5, 1.25))

    # Find the corresponding match on the website
    match_element = driver.find_element(By.CSS_SELECTOR,f'[data-match="{opta_id_to_scrape}"]')
    v = match_element.find_element(By.CLASS_NAME, 'Opta-Divider')
    v.click()

    # Define the timestamp at which the link was accessed
    timestamp = time.time()

    # Define css search logic
    css_match_stats = 'thead.Opta-Player-Stats'
    
    # Call block suspicion function
    success, block_suspicions, should_stop = safe_wait_css(
        driver=driver,
        css_selector=css_match_stats,
        block_suspicions=block_suspicions
    )
    if should_stop:
        increment_error_count(ws, db_index)
        break
    if not success:
        increment_error_count(ws, db_index)
        # Go back to base_url
        driver.back()
        time.sleep(random.uniform(0.4, 1.2))
        continue

    # Add small human delay as well
    time.sleep(random.uniform(0.7,1.5))

    # Collect html
    html_content = driver.page_source
    
    filename = f'{output_dir}/{opta_id_to_scrape}.html'
    
    # Write file
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(html_content)

    # Update status of opta id
    ws.update_cell(db_index, 3, "done")
    ws.update_cell(db_index, 4, timestamp)
    # Decrease count of batch size
    batch_size = batch_size - 1

    # Go back to base_url
    driver.back()
    time.sleep(random.uniform(0.4, 1.2))


# Compute total OPTA scraping progress
final_sheet_after_scraping = ws.get_all_values()

# Extract status column (skip header)
status_col = [row[2] for row in final_sheet_after_scraping[1:]]

done_count = status_col.count('done')
total_scrapes = len(status_col)

progress_pct = (done_count / total_scrapes) * 100 if total_scrapes > 0 else 0

print(f"Total scraping progress after this session: {done_count} of {total_scrapes} "
      f"({progress_pct:.2f}%)")




