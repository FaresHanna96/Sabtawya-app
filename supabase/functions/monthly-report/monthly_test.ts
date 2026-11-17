// Run without Deno, from the repo root:
//   node --test supabase/functions/monthly-report/monthly_test.ts
// (Node 22.18+ runs TypeScript directly.) Under Deno: deno test.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  compareClassNames,
  monthBounds,
  type MonthlyRow,
  monthlySheets,
  previousMonth,
  sheetName,
} from './monthly.ts';
import { columnName, escapeXml, xlsxEntries } from './xlsx.ts';

const row = (
  id: string,
  name: string,
  cls: string,
  attended: number,
  total: number,
  points = attended * 5,
  gender = 'boy',
): MonthlyRow => ({
  child_id: id,
  child_name: name,
  gender,
  class_name: cls,
  sessions_attended: attended,
  sessions_total: total,
  points,
});

test('months', () => {
  assert.equal(previousMonth('2026-11-01'), '2026-10');
  assert.equal(previousMonth('2027-01-01'), '2026-12');
  assert.deepEqual(monthBounds('2026-02'), ['2026-02-01', '2026-02-28']);
  assert.deepEqual(monthBounds('2028-02'), ['2028-02-01', '2028-02-29']);
});

test('class order: grade, boys before girls, others last', () => {
  const names = ['4 بنات', 'ملائكة', '3 بنات', '4 ولاد', '3 ولاد'];
  assert.deepEqual(names.sort(compareClassNames), [
    '3 ولاد',
    '3 بنات',
    '4 ولاد',
    '4 بنات',
    'ملائكة',
  ]);
});

test('sheet names are short, clean and unique', () => {
  const used = new Set<string>();
  assert.equal(sheetName('3 ولاد', used), '3 ولاد');
  assert.equal(sheetName('3 ولاد', used), '3 ولاد 2');
  assert.equal(sheetName('a/b:c', used), 'a b c');
  assert.equal(sheetName('x'.repeat(40), used).length, 31);
});

test('one row per child, best attendance first, a sheet per class', () => {
  const sheets = monthlySheets(
    [
      row('1', 'مينا', '3 ولاد', 5, 6),
      row('2', 'بيتر', '3 ولاد', 6, 6),
      row('3', 'مريم', '3 بنات', 3, 6, 15, 'girl'),
    ],
    'التقرير الشهري',
  );
  assert.deepEqual(sheets.map((s) => s.name), ['التقرير الشهري', '3 ولاد', '3 بنات']);
  const main = sheets[0].rows;
  assert.equal(main.length, 4);
  assert.equal(main[0].length, 7);
  // Same class first (3 ولاد), best percentage first inside it.
  assert.deepEqual(main[1], ['3 ولاد', 'بيتر', 'ولد', 6, 6, 30, 100]);
  assert.deepEqual(main[2], ['3 ولاد', 'مينا', 'ولد', 5, 6, 25, 83.3]);
  assert.deepEqual(main[3], ['3 بنات', 'مريم', 'بنت', 3, 6, 15, 50]);
});

test('a single class gives one sheet; months of a child are added', () => {
  const sheets = monthlySheets(
    [row('1', 'مينا', '3 ولاد', 2, 4), row('1', 'مينا', '3 ولاد', 3, 4)],
    'x',
  );
  assert.equal(sheets.length, 1);
  assert.deepEqual(sheets[0].rows[1], ['3 ولاد', 'مينا', 'ولد', 5, 8, 25, 62.5]);
});

test('xlsx parts are complete and escape their text', () => {
  const entries = xlsxEntries(monthlySheets([row('1', 'a<b>&"c', '3 ولاد', 1, 2)], 'S'));
  const names = entries.map((e) => e.name);
  for (
    const n of [
      '[Content_Types].xml',
      '_rels/.rels',
      'xl/workbook.xml',
      'xl/_rels/workbook.xml.rels',
      'xl/styles.xml',
      'xl/worksheets/sheet1.xml',
    ]
  ) {
    assert.ok(names.includes(n), n);
  }
  const sheet = new TextDecoder().decode(
    entries.find((e) => e.name === 'xl/worksheets/sheet1.xml')!.data,
  );
  assert.ok(sheet.includes('a&lt;b&gt;&amp;&quot;c'));
  assert.ok(sheet.includes('rightToLeft="1"'));
  assert.equal(escapeXml('a\u0001b'), 'ab');
  assert.equal(columnName(0), 'A');
  assert.equal(columnName(26), 'AA');
});

test('writes a sample file for a manual check when SAMPLE_OUT is set', async () => {
  const out = process.env.SAMPLE_OUT;
  if (!out) return;
  const { mkdirSync, writeFileSync } = await import('node:fs');
  const { dirname, join } = await import('node:path');
  const entries = xlsxEntries(
    monthlySheets(
      [
        row('1', 'مينا', '3 ولاد', 5, 6),
        row('2', 'بيتر', '3 ولاد', 6, 6),
        row('3', 'مريم', '3 بنات', 3, 6, 15, 'girl'),
      ],
      'التقرير الشهري',
    ),
  );
  for (const e of entries) {
    const p = join(out, e.name);
    mkdirSync(dirname(p), { recursive: true });
    writeFileSync(p, e.data);
  }
});
