# 3 · Implementation

| File | What it is |
|---|---|
| [`form.html`](form.html) | Quote request form: filled in by customers on the website, or by reception/salespeople for WhatsApp, social media, phone and walk-in leads |
| [`apps-script.gs`](apps-script.gs) | Automation: saves the lead, assigns it, notifies, checks the SLA every 15 min and serves data to the dashboard |

## Demo mode (no setup needed)

Open `form.html` in a browser. If the `APPS_SCRIPT_URL` constant is empty, the form saves responses in the browser itself and simulates round-robin assignment. Good enough to show the workflow in an interview.

## Connect it to Google Sheets (15 minutes)

1. Create a new Google Sheets spreadsheet.
2. Go to **Extensions → Apps Script**, delete the contents and paste [`apps-script.gs`](apps-script.gs).
3. In `CONFIG`, change `SALES_MANAGER_EMAIL` to a test email of your own.
4. Select the **`setup`** function and click **Run**. Accept the permissions. This creates:
   - the **Leads** sheet, with columns and the status dropdown;
   - the **Salespeople** sheet (`name | email | active`), which you fill in with test emails;
   - a trigger that runs `checkSLA` every 15 minutes.
5. Go to **Deploy → New deployment → Web app**:
   - *Execute as:* me
   - *Who has access:* anyone
6. Copy the URL ending in `/exec` and paste it into:
   - `APPS_SCRIPT_URL` in `form.html` (to save leads);
   - `DATA_SOURCE_URL` in `../4-measurement/dashboard.html` (to see live data).

## Test it end to end

1. Submit the form → a row appears in **Leads** with status `New`, and the assigned salesperson gets an email.
2. Wait over 1 hour (or lower `SLA_REMINDER_HOURS` to `0.05` to test) → the reminder arrives.
3. Change the status to `Contacted` → `contact_date`, `contacted` and `hours_to_first_contact` fill in.
4. Move on to `Test drive`, `Quote` and `Sold` → the funnel updates itself and the margin is calculated.
5. Open the dashboard → the new lead shows up.

## Design decisions

- **Google Sheets, not a CRM:** many mid-size dealerships have no CRM, or don't use it well. A spreadsheet is familiar, free and enough to prove the workflow's value before investing in a CRM.
- **Round-robin with `LockService`:** two leads arriving at the same moment can't be assigned to the same salesperson by mistake.
- **`doGet` only serves columns without personal data:** the dashboard can be public without exposing names, phone numbers or emails.
- **Form uses `Content-Type: text/plain`:** avoids Apps Script's CORS block without needing a middle server.
