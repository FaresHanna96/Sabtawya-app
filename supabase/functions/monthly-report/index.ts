import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  configure,
  Uint8ArrayReader,
  Uint8ArrayWriter,
  ZipReader,
  ZipWriter,
} from 'npm:@zip.js/zip.js@2.24.0';
import nodemailer from 'npm:nodemailer@6.9.14';
import { monthBounds, type MonthlyRow, monthlySheets, previousMonth } from './monthly.ts';
import { type Entry, xlsxEntries } from './xlsx.ts';

// The monthly attendance report (the same columns as the app's "التقرير
// الشهري" Excel export) emailed to every active admin on the 1st of the month,
// for the month that just ended. Sent through the app's Gmail sender.
//
//   {}                       last month, mailed to the admins
//   {"month":"2026-10"}      that month instead
//   {"dryRun":true}          builds the file and says what it would send, mails nothing
//
// Called by pg_cron (no sign-in), so it only runs with the secret header that
// matches app_config.backup_secret, which clients cannot read.

configure({ useWebWorkers: false });

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
);
const GMAIL_USER = Deno.env.get('GMAIL_USER') ?? '';
const GMAIL_PASS = Deno.env.get('GMAIL_PASS') ?? '';

/** Today in Cairo as "2026-11-01". */
function cairoToday(): string {
  return new Date().toLocaleDateString('en-CA', { timeZone: 'Africa/Cairo' });
}

/** The .xlsx file: a zip (without encryption) of the workbook's XML files. */
async function zipEntries(entries: Entry[]): Promise<Uint8Array> {
  const writer = new ZipWriter(new Uint8ArrayWriter());
  for (const e of entries) {
    await writer.add(e.name, new Uint8ArrayReader(e.data));
  }
  return await writer.close();
}

/** Opens the file again, as Excel would: every part must be there. */
async function verifyXlsx(bytes: Uint8Array): Promise<boolean> {
  const reader = new ZipReader(new Uint8ArrayReader(bytes));
  try {
    const names = (await reader.getEntries()).map((e) => e.filename);
    return ['[Content_Types].xml', 'xl/workbook.xml', 'xl/styles.xml', 'xl/worksheets/sheet1.xml']
      .every((n) => names.includes(n));
  } finally {
    await reader.close();
  }
}

async function readMonth(month: string): Promise<MonthlyRow[]> {
  const [first, last] = monthBounds(month);
  // The attendance year that covers the month (it may be the previous year
  // on the 1st of January).
  const { data: year, error: yearError } = await supabase
    .from('attendance_years')
    .select('id')
    .lte('start_date', last)
    .gte('end_date', first)
    .order('start_date', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (yearError) throw new Error(`attendance_years: ${yearError.message}`);
  if (!year) return [];

  const out: MonthlyRow[] = [];
  const page = 1000;
  for (let from = 0; ; from += page) {
    const { data, error } = await supabase
      .from('v_child_monthly_report')
      .select(
        'child_id, child_name, gender, class_name, sessions_attended, sessions_total, points',
      )
      .eq('year_id', year.id)
      .eq('month_start', first)
      .eq('child_is_active', true)
      .order('child_id')
      .range(from, from + page - 1);
    if (error) throw new Error(`v_child_monthly_report: ${error.message}`);
    out.push(...((data ?? []) as MonthlyRow[]));
    if (!data || data.length < page) return out;
  }
}

async function adminEmails(): Promise<string[]> {
  const { data, error } = await supabase
    .from('profiles')
    .select('email')
    .eq('role', 'admin')
    .eq('is_active', true)
    .eq('is_hidden', false);
  if (error) throw new Error(`profiles: ${error.message}`);
  return (data ?? [])
    .map((p: { email: string | null }) => (p.email ?? '').trim())
    .filter((e: string) => e.includes('@'));
}

async function report(month: string, dryRun: boolean) {
  const rows = await readMonth(month);
  const attended = rows.reduce((n, r) => n + (r.sessions_attended ?? 0), 0);
  // No attendance taken that month: nothing worth mailing.
  if (rows.length === 0 || attended === 0) {
    return { month, skipped: 'no attendance recorded', children: rows.length };
  }

  const sheets = monthlySheets(rows, 'التقرير الشهري');
  const bytes = await zipEntries(xlsxEntries(sheets));
  if (!(await verifyXlsx(bytes))) throw new Error('the workbook failed its own check');

  const to = await adminEmails();
  const summary = {
    month,
    children: new Set(rows.map((r) => r.child_id)).size,
    sheets: sheets.map((s) => s.name),
    bytes: bytes.length,
    recipients: to.length,
  };
  if (dryRun) return { ...summary, sent: 0 };
  if (to.length === 0) return { ...summary, sent: 0, skipped: 'no admin email' };

  const transport = nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 587,
    secure: false,
    auth: { user: GMAIL_USER, pass: GMAIL_PASS },
  });
  let sent = 0;
  // One mail per admin, so nobody's address is shown to the others.
  for (const address of to) {
    await transport.sendMail({
      from: `سبتاوية <${GMAIL_USER}>`,
      to: address,
      subject: `التقرير الشهري — سبتاوية ${month}`,
      text: `التقرير الشهري للحضور عن شهر ${month} (ملف Excel مرفق).\n` +
        `فيه لكل مخدوم: السبوت المحضورة، عدد الجلسات، الطايوهات ونسبة الحضور.\n` +
        `الملف فيه بيانات المخدومين: احتفظ به في مكان آمن.`,
      attachments: [{
        filename: `sabtawya-monthly-${month}.xlsx`,
        content: bytes,
        contentType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      }],
    });
    sent++;
  }
  return { ...summary, sent };
}

serve(async (req) => {
  const { data: cfg } = await supabase
    .from('app_config')
    .select('value')
    .eq('key', 'backup_secret')
    .maybeSingle();
  const secret = req.headers.get('x-backup-secret') ?? '';
  if (!cfg?.value || secret !== cfg.value) {
    return new Response('forbidden', { status: 403 });
  }

  let body: { month?: string; dryRun?: boolean } = {};
  try {
    body = await req.json();
  } catch {
    // an empty body means last month
  }
  const dryRun = body.dryRun === true;
  if (body.month !== undefined && !/^\d{4}-(0[1-9]|1[0-2])$/.test(body.month)) {
    return new Response('month must look like 2026-10', { status: 400 });
  }
  if (!dryRun && (!GMAIL_USER || !GMAIL_PASS)) {
    return new Response('mail not configured', { status: 500 });
  }

  try {
    const month = body.month ?? previousMonth(cairoToday());
    const result = await report(month, dryRun);
    return new Response(JSON.stringify({ ok: true, dryRun, ...result }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
