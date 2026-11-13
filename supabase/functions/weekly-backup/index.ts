import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import JSZip from 'npm:jszip@3.10.1';
import nodemailer from 'npm:nodemailer@6.9.14';

// Weekly backup: every data table as a CSV (Excel opens them), zipped and
// emailed to BACKUP_TO through the app's Gmail sender. The free Supabase
// plan keeps no backups of its own.
//
// Called by pg_cron (no sign-in), so it only runs with the secret header
// that matches app_config.backup_secret, which clients cannot read.

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
);
const GMAIL_USER = Deno.env.get('GMAIL_USER') ?? '';
const GMAIL_PASS = Deno.env.get('GMAIL_PASS') ?? '';
const BACKUP_TO = Deno.env.get('BACKUP_TO') ?? '';

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
  if (!GMAIL_USER || !GMAIL_PASS || !BACKUP_TO) {
    return new Response('mail not configured', { status: 500 });
  }

  try {
    const zip = new JSZip();
    const counts: string[] = [];
    for (const t of TABLES) {
      const rows = await readAll(t);
      zip.file(`${t}.csv`, toCsv(rows));
      counts.push(`${t}: ${rows.length}`);
    }
    const day = new Date().toISOString().slice(0, 10);
    const content = await zip.generateAsync({
      type: 'uint8array',
      compression: 'DEFLATE',
    });

    const transporter = nodemailer.createTransport({
      host: 'smtp.gmail.com',
      port: 587,
      secure: false,
      auth: { user: GMAIL_USER, pass: GMAIL_PASS },
    });
    await transporter.sendMail({
      from: `سبتاوية <${GMAIL_USER}>`,
      to: BACKUP_TO,
      subject: `نسخة احتياطية أسبوعية — سبتاوية ${day}`,
      text:
        `النسخة الاحتياطية الأسبوعية لبيانات التطبيق (ملفات CSV تفتح في Excel).\n` +
        `احتفظ بها في مكان آمن: فيها بيانات المخدومين.\n\n` +
        counts.join('\n'),
      attachments: [
        { filename: `sabtawya-backup-${day}.zip`, content },
      ],
    });

    return new Response(JSON.stringify({ ok: true, day, counts }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
