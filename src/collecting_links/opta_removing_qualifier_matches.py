# Import required packages
import os
import time
from dotenv import load_dotenv
import gspread
from google.oauth2.service_account import Credentials

# === Load credentials ===

# Load .env file
env_path = '../../.env'
env_folder= '../../'
load_dotenv(env_path)

# Read .env variables
json_relative = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
sheet_id = os.getenv("SPREADSHEET_ID")

# Create filepath of Google API JSON key
json_full_path = os.path.join(env_folder, json_relative)

scopes = ["https://www.googleapis.com/auth/spreadsheets"]
creds = Credentials.from_service_account_file(json_full_path, scopes=scopes)
gc = gspread.authorize(creds)

# Connect to spreadsheet
sh = gc.open_by_key(sheet_id)
ws = sh.get_worksheet(1)
ws.update([["match_id", "competition"]], "A1:B1")

# Collect qualifier IDs from worksheet 1
wsq = sh.get_worksheet(1).get_all_values()[1:]
opta_ids = [row[0] for row in wsq if row]

bad_ids = set(opta_ids)

# Access main sheet
ws_main = sh.get_worksheet(0)
main_rows = ws_main.get_all_values()
data_rows = main_rows[1:]

# Identify rows to delete
rows_to_delete = []
for i, row in enumerate(data_rows, start=2):
    if row and row[0] in bad_ids:
        rows_to_delete.append(i)

print("Rows to delete:")
print(rows_to_delete)

# Delete rows safely (bottom-to-top)
for row_idx in reversed(rows_to_delete):
    ws_main.delete_rows(row_idx)
    time.sleep(2)
