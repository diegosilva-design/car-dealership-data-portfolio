/**
 * Lead → Sale workflow · Google Apps Script
 * ------------------------------------------
 * Does 4 things, with no servers or licenses:
 *  1. doPost     → receives the form, saves the lead and ASSIGNS it (round-robin) to an active salesperson.
 *  2. notify     → emails the salesperson as soon as the lead comes in.
 *  3. checkSLA   → every 15 min: lead not contacted > 1 h → reminder to the salesperson; > 4 h → alert to the sales manager.
 *  4. onEdit     → when the salesperson changes the "status", records the contact time and moves the funnel forward.
 *  +  doGet      → serves the data WITHOUT personal information to feed the dashboard.
 *
 * Setup: see README.md in this folder.
 */

const CONFIG = {
  LEADS_SHEET: 'Leads',
  SALESPEOPLE_SHEET: 'Salespeople',        // columns: name | email | active (TRUE/FALSE)
  SALES_MANAGER_EMAIL: 'sales.manager@example.com',
  SLA_REMINDER_HOURS: 1,
  SLA_ESCALATION_HOURS: 4,
  ESTIMATED_MARGIN: 0.07,                  // average margin over price, for the dashboard
};

const PRICES = {
  'Toyota Yaris': 15990000, 'Toyota Corolla Cross': 24990000, 'Toyota Hilux': 32990000,
  'Chevrolet Groove': 11990000, 'Chevrolet Tracker': 18490000, 'Hyundai Accent': 13990000,
  'Hyundai Tucson': 27990000, 'Kia Soluto': 11490000, 'Kia Sportage': 26990000,
  'Suzuki Swift': 12490000, 'Suzuki Vitara': 19990000, 'MG ZS': 15490000,
  'Nissan Kicks': 17990000, 'Peugeot 2008': 22990000,
};

// Public columns (same as data/leads.csv) + internal columns holding personal data.
const PUBLIC_COLS = ['lead_id', 'lead_date', 'month', 'period', 'channel', 'brand', 'model', 'price_clp', 'district',
  'salesperson', 'contacted', 'hours_to_first_contact', 'test_drive', 'quote', 'sale', 'sale_date', 'margin_clp'];
const INTERNAL_COLS = ['status', 'contact_date', 'alert', 'name', 'phone', 'email', 'payment', 'trade_in', 'comment'];
const COLUMNS = PUBLIC_COLS.concat(INTERNAL_COLS);
const STATUSES = ['New', 'Contacted', 'Test drive', 'Quote', 'Sold', 'Lost'];

/** Run ONCE by hand: creates sheets, headers, the status dropdown and the SLA trigger. */
function setup() {
  const ss = SpreadsheetApp.getActive();
  const leads = ss.getSheetByName(CONFIG.LEADS_SHEET) || ss.insertSheet(CONFIG.LEADS_SHEET);
  leads.getRange(1, 1, 1, COLUMNS.length).setValues([COLUMNS]).setFontWeight('bold');
  leads.setFrozenRows(1);
  // Plain text so Sheets doesn't turn "2026-10" or "2026-10-04 10:30" into dates
  ['lead_date', 'month', 'sale_date'].forEach(c => leads.getRange(1, COLUMNS.indexOf(c) + 1, leads.getMaxRows(), 1).setNumberFormat('@'));
  const statusCol = COLUMNS.indexOf('status') + 1;
  leads.getRange(2, statusCol, leads.getMaxRows() - 1, 1).setDataValidation(
    SpreadsheetApp.newDataValidation().requireValueInList(STATUSES, true).build());

  if (!ss.getSheetByName(CONFIG.SALESPEOPLE_SHEET)) {
    const s = ss.insertSheet(CONFIG.SALESPEOPLE_SHEET);
    s.getRange(1, 1, 3, 3).setValues([['name', 'email', 'active'],
      ['Camila Rojas', 'camila@example.com', true], ['Matias Soto', 'matias@example.com', true]]);
  }

  ScriptApp.getProjectTriggers().filter(t => t.getHandlerFunction() === 'checkSLA').forEach(t => ScriptApp.deleteTrigger(t));
  ScriptApp.newTrigger('checkSLA').timeBased().everyMinutes(15).create();
}

/** 1. Receives the form. */
function doPost(e) {
  const lock = LockService.getScriptLock();
  lock.waitLock(10000);   // prevents two simultaneous leads from getting the same salesperson
  try {
    const d = JSON.parse(e.postData.contents);
    const missing = ['name', 'phone', 'email', 'model', 'channel'].filter(k => !d[k]);
    if (missing.length) return json({ ok: false, error: 'Missing fields: ' + missing.join(', ') });

    const sheet = SpreadsheetApp.getActive().getSheetByName(CONFIG.LEADS_SHEET);
    const now = new Date();
    const tz = Session.getScriptTimeZone();
    const id = 'L' + Utilities.formatDate(now, tz, 'yyMMddHHmmss');
    const salesperson = nextSalesperson();
    const brand = d.model.split(' ')[0];
    const walkIn = d.channel === 'Walk-in';

    const row = {
      lead_id: id, lead_date: Utilities.formatDate(now, tz, 'yyyy-MM-dd HH:mm'), month: Utilities.formatDate(now, tz, 'yyyy-MM'),
      period: 'after', channel: d.channel, brand: brand, model: d.model.substring(brand.length + 1) || d.model,
      price_clp: PRICES[d.model] || '', district: d.district || '', salesperson: salesperson.name,
      contacted: walkIn ? 'yes' : 'no', hours_to_first_contact: walkIn ? 0.1 : '',
      test_drive: 'no', quote: 'no', sale: 'no', sale_date: '', margin_clp: '',
      status: walkIn ? 'Contacted' : 'New', contact_date: '', alert: 0,
      name: d.name, phone: d.phone, email: d.email, payment: d.payment || '', trade_in: d.trade_in || '', comment: d.comment || '',
    };
    sheet.appendRow(COLUMNS.map(c => row[c]));
    notify(salesperson, row);
    return json({ ok: true, lead_id: id, salesperson: salesperson.name });
  } catch (err) {
    return json({ ok: false, error: String(err) });
  } finally {
    lock.releaseLock();
  }
}

/** Round-robin among salespeople marked as active. */
function nextSalesperson() {
  const rows = SpreadsheetApp.getActive().getSheetByName(CONFIG.SALESPEOPLE_SHEET).getDataRange().getValues().slice(1);
  const active = rows.filter(r => r[0] && r[2] === true).map(r => ({ name: r[0], email: r[1] }));
  if (!active.length) throw new Error('No active salespeople');
  const props = PropertiesService.getScriptProperties();
  const i = Number(props.getProperty('rr') || 0);
  props.setProperty('rr', String(i + 1));
  return active[i % active.length];
}

/** 2. Immediate notice to the salesperson. */
function notify(salesperson, r) {
  if (!salesperson.email) return;
  MailApp.sendEmail({
    to: salesperson.email,
    subject: `New lead ${r.lead_id}: ${r.brand} ${r.model} (${r.channel})`,
    body: `Hi ${salesperson.name},\n\nYou have a new lead. Goal: contact them within ${CONFIG.SLA_REMINDER_HOURS} hour.\n\n` +
      `Customer: ${r.name}\nPhone: ${r.phone}\nEmail: ${r.email}\nModel: ${r.brand} ${r.model}\n` +
      `Payment: ${r.payment} · Trade-in: ${r.trade_in}\nComment: ${r.comment}\n\n` +
      `Once you contact them, change their status in the sheet to "Contacted".`,
  });
}

/** 3. Runs every 15 min: reminder and escalation for unattended leads. */
function checkSLA() {
  const sheet = SpreadsheetApp.getActive().getSheetByName(CONFIG.LEADS_SHEET);
  const data = sheet.getDataRange().getValues();
  const col = (n) => COLUMNS.indexOf(n);
  const emails = {};
  SpreadsheetApp.getActive().getSheetByName(CONFIG.SALESPEOPLE_SHEET).getDataRange().getValues().slice(1).forEach(r => emails[r[0]] = r[1]);
  const now = new Date();
  const escalated = [];

  for (let i = 1; i < data.length; i++) {
    const r = data[i];
    if (r[col('status')] !== 'New') continue;
    const hours = (now - new Date(String(r[col('lead_date')]).replace(' ', 'T'))) / 36e5;
    const alert = Number(r[col('alert')] || 0);
    if (hours >= CONFIG.SLA_ESCALATION_HOURS && alert < 2) {
      escalated.push(`${r[col('lead_id')]} · ${r[col('salesperson')]} · ${hours.toFixed(1)} h without contact · ${r[col('channel')]}`);
      sheet.getRange(i + 1, col('alert') + 1).setValue(2);
    } else if (hours >= CONFIG.SLA_REMINDER_HOURS && alert < 1) {
      const to = emails[r[col('salesperson')]];
      if (to) MailApp.sendEmail(to, `⏰ Lead ${r[col('lead_id')]} has waited ${hours.toFixed(1)} h for contact`,
        `${r[col('name')]} (${r[col('phone')]}) is waiting for a reply about the ${r[col('brand')]} ${r[col('model')]}.`);
      sheet.getRange(i + 1, col('alert') + 1).setValue(1);
    }
  }
  if (escalated.length) {
    MailApp.sendEmail(CONFIG.SALES_MANAGER_EMAIL, `⚠ ${escalated.length} lead(s) not contacted for over ${CONFIG.SLA_ESCALATION_HOURS} h`,
      'Please review and reassign if needed:\n\n' + escalated.join('\n'));
  }
}

/** 4. Simple trigger: the salesperson changes the status and the sheet updates the funnel. */
function onEdit(e) {
  const sheet = e.range.getSheet();
  if (sheet.getName() !== CONFIG.LEADS_SHEET || e.range.getColumn() !== COLUMNS.indexOf('status') + 1 || e.range.getRow() < 2) return;
  const r = e.range.getRow();
  const row = sheet.getRange(r, 1, 1, COLUMNS.length).getValues()[0];
  const get = (n) => row[COLUMNS.indexOf(n)];
  const set = (n, v) => sheet.getRange(r, COLUMNS.indexOf(n) + 1).setValue(v);
  const status = e.value;
  const level = STATUSES.indexOf(status);   // 1 Contacted, 2 Test drive, 3 Quote, 4 Sold

  if (level >= 1 && !get('contact_date') && status !== 'Lost') {
    const now = new Date();
    set('contact_date', now);
    set('contacted', 'yes');
    const from = new Date(String(get('lead_date')).replace(' ', 'T'));
    set('hours_to_first_contact', Math.round((now - from) / 36e5 * 10) / 10);
  }
  if (level >= 2 && status !== 'Lost') set('test_drive', 'yes');
  if (level >= 3 && status !== 'Lost') set('quote', 'yes');
  if (status === 'Sold') {
    set('sale', 'yes');
    set('sale_date', Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy-MM-dd'));
    if (get('price_clp')) set('margin_clp', Math.round(get('price_clp') * CONFIG.ESTIMATED_MARGIN));
  }
}

/** Data for the dashboard: ONLY public columns, never name/phone/email. */
function doGet() {
  const data = SpreadsheetApp.getActive().getSheetByName(CONFIG.LEADS_SHEET).getDataRange().getValues();
  const rows = data.slice(1).map(r => {
    const o = {};
    PUBLIC_COLS.forEach(c => { const v = r[COLUMNS.indexOf(c)]; o[c] = v === '' || v == null ? '' : String(v); });
    return o;
  });
  return json(rows);
}

function json(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
