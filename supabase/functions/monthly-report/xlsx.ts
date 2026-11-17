// A minimal .xlsx writer: strings and numbers, a styled header row, right to
// left sheets, an auto filter and a frozen header. An .xlsx is a zip of XML
// files; this builds those files and leaves zipping to the caller, so the same
// code runs under Deno (zip.js) and in a plain Node test.

export type Cell = string | number | null;
export type Sheet = {
  name: string;
  /** Column widths in characters. */
  widths: number[];
  /** The first row is the header. */
  rows: Cell[][];
};
export type Entry = { name: string; data: Uint8Array };

const enc = new TextEncoder();

export function escapeXml(s: string): string {
  return s
    // Control characters are not allowed in XML 1.0.
    // deno-lint-ignore no-control-regex
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** 0 -> A, 25 -> Z, 26 -> AA. */
export function columnName(index: number): string {
  let n = index + 1;
  let out = '';
  while (n > 0) {
    const r = (n - 1) % 26;
    out = String.fromCharCode(65 + r) + out;
    n = Math.floor((n - 1) / 26);
  }
  return out;
}

function sheetXml(sheet: Sheet): string {
  const cols = sheet.widths.length;
  const last = `${columnName(Math.max(cols, 1) - 1)}${Math.max(sheet.rows.length, 1)}`;
  const rows = sheet.rows.map((row, r) => {
    const cells = row.map((v, c) => {
      const ref = `${columnName(c)}${r + 1}`;
      const style = r === 0 ? ' s="1"' : '';
      if (v === null || v === '') return `<c r="${ref}"${style}/>`;
      if (typeof v === 'number') {
        return `<c r="${ref}"${style}><v>${Number.isFinite(v) ? v : 0}</v></c>`;
      }
      return `<c r="${ref}"${style} t="inlineStr"><is><t xml:space="preserve">${
        escapeXml(v)
      }</t></is></c>`;
    });
    return `<row r="${r + 1}">${cells.join('')}</row>`;
  });
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
    '<sheetViews><sheetView rightToLeft="1" workbookViewId="0">' +
    '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>' +
    '</sheetView></sheetViews>' +
    '<sheetFormatPr defaultRowHeight="15"/>' +
    `<cols>${
      sheet.widths.map((w, i) =>
        `<col min="${i + 1}" max="${i + 1}" width="${w}" customWidth="1"/>`
      ).join('')
    }</cols>` +
    `<sheetData>${rows.join('')}</sheetData>` +
    (sheet.rows.length > 0 ? `<autoFilter ref="A1:${last}"/>` : '') +
    '</worksheet>';
}

const STYLES = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
  '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
  '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>' +
  '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font></fonts>' +
  '<fills count="3"><fill><patternFill patternType="none"/></fill>' +
  '<fill><patternFill patternType="gray125"/></fill>' +
  '<fill><patternFill patternType="solid"><fgColor rgb="FF1F3A5F"/><bgColor indexed="64"/></patternFill></fill></fills>' +
  '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>' +
  '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
  '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' +
  '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyAlignment="1">' +
  '<alignment horizontal="center" vertical="center"/></xf></cellXfs>' +
  '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>' +
  '</styleSheet>';

/** The files of a workbook holding [sheets] (at least one). */
export function xlsxEntries(sheets: Sheet[]): Entry[] {
  if (sheets.length === 0) throw new Error('a workbook needs a sheet');
  const files: Record<string, string> = {};
  files['[Content_Types].xml'] =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
    '<Default Extension="xml" ContentType="application/xml"/>' +
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
    sheets.map((_, i) =>
      `<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`
    ).join('') +
    '</Types>';
  files['_rels/.rels'] = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
    '</Relationships>';
  files['xl/workbook.xml'] = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
    '<sheets>' +
    sheets.map((s, i) =>
      `<sheet name="${escapeXml(s.name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>`
    ).join('') +
    '</sheets></workbook>';
  files['xl/_rels/workbook.xml.rels'] =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    sheets.map((_, i) =>
      `<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>`
    ).join('') +
    `<Relationship Id="rId${sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>` +
    '</Relationships>';
  files['xl/styles.xml'] = STYLES;
  sheets.forEach((s, i) => {
    files[`xl/worksheets/sheet${i + 1}.xml`] = sheetXml(s);
  });
  return Object.entries(files).map(([name, text]) => ({
    name,
    data: enc.encode(text),
  }));
}
