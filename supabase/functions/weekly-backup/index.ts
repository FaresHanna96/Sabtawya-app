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

// Weekly backup, emailed to BACKUP_TO through the app's Gmail sender. The
// free Supabase plan keeps no backups of its own. Two calls, one cron job each:
//
//   {}                  every data table as a CSV (Excel opens them)
//   {"part":"photos"}   the children's photos and the class pictures
//
// Every zip is encrypted (AES-256) with BACKUP_PASSWORD, because it holds
// children's personal data and an email is not a safe place for a plain file.
// With no password set the function refuses to send anything. Open the zips
// with 7-Zip or WinRAR; Windows' built-in zip viewer cannot read AES.
//
// {"dryRun":true} builds and verifies the zips without sending (for testing).
//
// Called by pg_cron (no sign-in), so it only runs with the secret header
// that matches app_config.backup_secret, which clients cannot read.

configure({ useWebWorkers: false });

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
);
const GMAIL_USER = Deno.env.get('GMAIL_USER') ?? '';
const GMAIL_PASS = Deno.env.get('GMAIL_PASS') ?? '';
const BACKUP_TO = Deno.env.get('BACKUP_TO') ?? '';
const PASSWORD = Deno.env.get('BACKUP_PASSWORD') ?? '';

// Gmail refuses mail above 25 MB, and attachments grow by a third in transit.
const MAX_ZIP_BYTES = 15 * 1024 * 1024;

// The app's data. Left out: device tokens and config (secrets), visit and
// notification logs (noise), and the fixed email rules (in the migrations).
const TABLES = [
  'children',
  'classes',
  'profiles',
  'servant_details',
  'class_servants',
  'servant_invites',
  'attendance_years',
  'attendance_sessions',
  'attendance_records',
  'child_visit_logs',
  'events',
  'event_payments',
  'event_reservations',
  'competitions',
  'competition_marks',
  'lessons',
  'lesson_breaks',
  'lesson_extras',
  'servant_attendances',
  'servant_lesson_preps',
  'servant_lesson_prep_photos',
  'activity_log',
];

type Entry = { name: string; data: Uint8Array };

async function readAll(table: string): Promise<Record<string, unknown>[]> {
  const page = 1000;
  const out: Record<string, unknown>[] = [];
  for (let from = 0; ; from += page) {
    const { data, error } = await supabase
      .from(table)
      .select('*')
      .range(from, from + page - 1);
    if (error) throw new Error(`${table}: ${error.message}`);
    out.push(...(data ?? []));
    if (!data || data.length < page) return out;
  }
}

function toCsv(rows: Record<string, unknown>[]): string {
  if (rows.length === 0) return '﻿';
  const cols = Object.keys(rows[0]);
  const cell = (v: unknown) => {
    if (v === null || v === undefined) return '';
    const s = typeof v === 'object' ? JSON.stringify(v) : String(v);
    return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  // A BOM so Excel reads the Arabic as UTF-8.
  return '﻿' + [cols.join(','), ...rows.map((r) => cols.map((c) => cell(r[c])).join(','))]
    .join('\r\n');
}

/** An AES-256 encrypted zip. [store]: no compression (photos are already). */
async function makeZip(entries: Entry[], store = false): Promise<Uint8Array> {
  const writer = new ZipWriter(new Uint8ArrayWriter(), {
    password: PASSWORD,
    encryptionStrength: 3,
  });
  for (const e of entries) {
    await writer.add(
      e.name,
      new Uint8ArrayReader(e.data),
      store ? { level: 0 } : undefined,
    );
  }
  return await writer.close();
}

/** Opens the zip again: the password works and a wrong or missing one fails. */
async function verifyZip(zip: Uint8Array, firstName: string): Promise<boolean> {
  const open = async (password?: string) => {
    const reader = new ZipReader(new Uint8ArrayReader(zip), { password });
    const entries = await reader.getEntries();
    const entry = entries.find((e) => e.filename === firstName);
    if (!entry || entry.directory) throw new Error('entry missing');
    await entry.getData!(new Uint8ArrayWriter());
  };
  try {
    await open(PASSWORD);
  } catch {
    return false;
  }
  try {
    await open(undefined);
    return false; // opened without the password
  } catch {
    return true;
  }
}

function transporter() {
  return nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 587,
    secure: false,
    auth: { user: GMAIL_USER, pass: GMAIL_PASS },
  });
}

const day = () => new Date().toISOString().slice(0, 10);

async function dataBackup(dryRun: boolean) {
  const files: Entry[] = [];
  const counts: string[] = [];
  const enc = new TextEncoder();
  for (const t of TABLES) {
    const rows = await readAll(t);
    files.push({ name: `${t}.csv`, data: enc.encode(toCsv(rows)) });
    counts.push(`${t}: ${rows.length}`);
  }
  const zip = await makeZip(files);
  if (zip.length > MAX_ZIP_BYTES) {
    throw new Error(`the data zip is ${zip.length} bytes, over the mail limit`);
  }
  const verified = await verifyZip(zip, files[0].name);
  if (!verified) throw new Error('the encrypted zip failed its own check');
  if (!dryRun) {
    await transporter().sendMail({
      from: `سبتاوية <${GMAIL_USER}>`,
      to: BACKUP_TO,
      subject: `نسخة احتياطية أسبوعية — سبتاوية ${day()}`,
      text:
        `النسخة الاحتياطية الأسبوعية لبيانات التطبيق (ملفات CSV تفتح في Excel).\n` +
        `الملف مشفّر بكلمة سر النسخ الاحتياطي: افتحه ببرنامج 7-Zip أو WinRAR.\n` +
        `احتفظ به في مكان آمن: فيه بيانات المخدومين.\n\n` +
        counts.join('\n'),
      attachments: [{ filename: `sabtawya-backup-${day()}.zip`, content: zip }],
    });
  }
  return { part: 'data', bytes: zip.length, verified, sent: !dryRun, counts };
}

/** Children's photos and class pictures, in zips of at most MAX_ZIP_BYTES. */
async function photoBackup(dryRun: boolean) {
  const items: { bucket: string; path: string }[] = [];
  const children = await readAll('children');
  for (const c of children) {
    if (c.photo_path) items.push({ bucket: 'child-photos', path: String(c.photo_path) });
  }
  const classes = await readAll('classes');
  for (const c of classes) {
    if (c.patron_photo_path) {
      items.push({ bucket: 'class-patrons', path: String(c.patron_photo_path) });
    }
  }

  const parts: { files: number; bytes: number; sent: boolean }[] = [];
  const missing: string[] = [];
  let batch: Entry[] = [];
  let batchBytes = 0;
  let next = 0;

  const flush = async (last: boolean) => {
    if (batch.length === 0) return;
    const zip = await makeZip(batch, true);
    if (!(await verifyZip(zip, batch[0].name))) {
      throw new Error('the encrypted photo zip failed its own check');
    }
    const n = parts.length + 1;
    if (!dryRun) {
      await transporter().sendMail({
        from: `سبتاوية <${GMAIL_USER}>`,
        to: BACKUP_TO,
        subject: `نسخة احتياطية للصور (جزء ${n}${last ? '، الأخير' : ''}) — سبتاوية ${day()}`,
        text:
          `صور المخدومين وصور الفصول، الجزء ${n}${last ? ' وهو الأخير' : ''}.\n` +
          `الملف مشفّر بكلمة سر النسخ الاحتياطي: افتحه ببرنامج 7-Zip أو WinRAR.\n` +
          `اسم كل صورة هو مسارها كما في عمود photo_path في ملف children.csv ` +
          `(أو patron_photo_path في classes.csv) من النسخة الأسبوعية للبيانات.\n` +
          `احتفظ به في مكان آمن: فيه صور المخدومين.`,
        attachments: [{
          filename: `sabtawya-photos-${day()}-part-${n}.zip`,
          content: zip,
        }],
      });
    }
    parts.push({ files: batch.length, bytes: zip.length, sent: !dryRun });
    batch = [];
    batchBytes = 0;
  };

  for (const item of items) {
    next++;
    const { data, error } = await supabase.storage.from(item.bucket).download(item.path);
    if (error || !data) {
      missing.push(`${item.bucket}/${item.path}`);
      continue;
    }
    const bytes = new Uint8Array(await data.arrayBuffer());
    // Close the part before it would grow past the limit.
    if (batch.length > 0 && batchBytes + bytes.length > MAX_ZIP_BYTES) {
      await flush(false);
    }
    batch.push({ name: `${item.bucket}/${item.path}`, data: bytes });
    batchBytes += bytes.length;
  }
  await flush(true);

  if (parts.length === 0 && !dryRun) {
    // Nothing to send: say so rather than staying silent.
    await transporter().sendMail({
      from: `سبتاوية <${GMAIL_USER}>`,
      to: BACKUP_TO,
      subject: `نسخة احتياطية للصور — لا توجد صور — سبتاوية ${day()}`,
      text: 'لا توجد صور محفوظة في التطبيق هذا الأسبوع.',
    });
  }
  return { part: 'photos', listed: items.length, scanned: next, missing, parts };
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

  let body: { part?: string; dryRun?: boolean } = {};
  try {
    body = await req.json();
  } catch {
    // an empty body means the data backup
  }
  const dryRun = body.dryRun === true;

  // Never send a plain copy: no password, no backup.
  if (PASSWORD.length < 12) {
    return new Response('BACKUP_PASSWORD is not set (at least 12 characters)', {
      status: 500,
    });
  }
  if (!dryRun && (!GMAIL_USER || !GMAIL_PASS || !BACKUP_TO)) {
    return new Response('mail not configured', { status: 500 });
  }

  try {
    const result = body.part === 'photos'
      ? await photoBackup(dryRun)
      : await dataBackup(dryRun);
    return new Response(JSON.stringify({ ok: true, day: day(), dryRun, ...result }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
