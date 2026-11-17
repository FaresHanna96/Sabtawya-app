import type { Cell, Sheet } from './xlsx.ts';

/** A row of the `v_child_monthly_report` view (only what the report needs). */
export type MonthlyRow = {
  child_id: string;
  child_name: string;
  gender: string;
  class_name: string;
  sessions_attended: number;
  sessions_total: number;
  points: number;
};

const classPattern = /^\s*(\d+)\s*(ولاد|بنات)\s*$/;

/** "3 ولاد", "3 بنات", "4 ولاد"...; other names after, alphabetically. */
export function compareClassNames(a: string, b: string): number {
  const ma = classPattern.exec(a);
  const mb = classPattern.exec(b);
  if (ma && mb) {
    const ya = parseInt(ma[1], 10);
    const yb = parseInt(mb[1], 10);
    if (ya !== yb) return ya - yb;
    const boysA = ma[2] === 'ولاد';
    const boysB = mb[2] === 'ولاد';
    if (boysA !== boysB) return boysA ? -1 : 1;
    return 0;
  }
  if (ma) return -1;
  if (mb) return 1;
  return a < b ? -1 : a > b ? 1 : 0;
}

/** A valid, unused sheet name: at most 31 characters, none of : \ / ? * [ ]. */
export function sheetName(name: string, used: Set<string>): string {
  let base = name.replace(/[:\\/?*[\]]/g, ' ').trim().slice(0, 31);
  if (base === '') base = 'Sheet';
  let candidate = base;
  for (let n = 2; used.has(candidate.toLowerCase()); n++) {
    const suffix = ` ${n}`;
    candidate = base.slice(0, 31 - suffix.length) + suffix;
  }
  used.add(candidate.toLowerCase());
  return candidate;
}

type Child = {
  className: string;
  name: string;
  gender: string;
  attended: number;
  held: number;
  points: number;
  percentage: number;
};

/**
 * The workbook of the app's monthly export: one row per child (months added
 * together), best attendance first, one sheet with everyone plus one sheet per
 * class when there are two or more. Same columns as the app's own file.
 */
export function monthlySheets(rows: MonthlyRow[], mainName: string): Sheet[] {
  const byChild = new Map<string, Child>();
  for (const r of rows) {
    const c = byChild.get(r.child_id) ?? {
      className: r.class_name,
      name: r.child_name,
      gender: r.gender === 'girl' ? 'بنت' : 'ولد',
      attended: 0,
      held: 0,
      points: 0,
      percentage: 0,
    };
    c.attended += r.sessions_attended ?? 0;
    c.held += r.sessions_total ?? 0;
    c.points += r.points ?? 0;
    byChild.set(r.child_id, c);
  }
  const children = [...byChild.values()];
  for (const c of children) {
    c.percentage = c.held > 0 ? Math.round((c.attended / c.held) * 1000) / 10 : 0;
  }
  children.sort((a, b) =>
    b.percentage - a.percentage || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0)
  );

  const header: Cell[] = [
    'الفصل',
    'اسم المخدوم',
    'النوع',
    'السبوت المحضورة',
    'عدد الجلسات',
    'إجمالي النقاط',
    'متوسط الحضور %',
  ];
  const widths = [16, 28, 10, 16, 14, 14, 16];
  const groups = new Map<string, Child[]>();
  for (const c of children) {
    const list = groups.get(c.className) ?? [];
    list.push(c);
    groups.set(c.className, list);
  }
  const names = [...groups.keys()].sort(compareClassNames);
  const toRow = (c: Child): Cell[] => [
    c.className,
    c.name,
    c.gender,
    c.attended,
    c.held,
    c.points,
    c.percentage,
  ];

  const used = new Set<string>();
  const main: Sheet = {
    name: sheetName(mainName, used),
    widths,
    rows: [header, ...names.flatMap((n) => groups.get(n)!.map(toRow))],
  };
  if (names.length < 2) return [main];
  return [
    main,
    ...names.map((n): Sheet => ({
      name: sheetName(n, used),
      widths,
      rows: [header, ...groups.get(n)!.map(toRow)],
    })),
  ];
}

/** "2026-10" for the month before the Cairo date [today] ("2026-11-01"). */
export function previousMonth(today: string): string {
  const [y, m] = today.split('-').map((x) => parseInt(x, 10));
  return m === 1 ? `${y - 1}-12` : `${y}-${String(m - 1).padStart(2, '0')}`;
}

/** First and last day of "2026-10": ["2026-10-01", "2026-10-31"]. */
export function monthBounds(month: string): [string, string] {
  const [y, m] = month.split('-').map((x) => parseInt(x, 10));
  const last = new Date(Date.UTC(y, m, 0)).getUTCDate();
  return [`${month}-01`, `${month}-${String(last).padStart(2, '0')}`];
}
