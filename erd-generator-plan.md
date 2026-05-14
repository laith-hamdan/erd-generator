# ERD Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a single-file HTML tool (`erd-generator.html`) where a student can add tables, columns, constraints, and foreign keys through a simple UI, see a live Entity–Relationship Diagram render with the same visual theme as [erd.html](erd.html), and download the diagram as PNG or PDF.

**Architecture:**
A single self-contained HTML page with three regions: a top action bar (load sample, reset, PNG, PDF), a two-pane body (left = builder UI listing tables/columns, right = live SVG preview), and a footer ("Made by Laith Hamdan"). All state lives in one in-memory JavaScript object; every edit calls `render()`, which re-renders both the builder list and the SVG from scratch. Relationships are *derived* from columns whose constraint is `FK` and whose `fkTable`/`fkColumn` targets are set — students never edit a separate "relationships" list. SVG rendering, crow's-foot connectors, and PNG/PDF export are ported from the existing [erd.html](erd.html).

**Tech Stack:** Vanilla HTML/CSS/JS (no build step, no framework). External CDN: jsPDF (already used in erd.html). Fonts: Inter + JetBrains Mono via Google Fonts.

**Notes on testing approach:**
There is no automated test harness for this single-file static page. Each task ends with a **manual browser verification** step (open the file in a browser, perform listed actions, confirm expected behavior). After every task, commit before moving on.

**Plan location & output file:**
- Plan: `/home/lait/Desktop/second-semester-25-26/Database/project/erd-generator-plan.md`
- Code output: `/home/lait/Desktop/second-semester-25-26/Database/project/erd-generator.html`

---

## File Structure

A single file. Sections inside it, top to bottom:

1. `<head>` — meta, fonts, `<style>` block (theme copied from erd.html + builder UI styles).
2. `<body>`
   - Header: title + subtitle + action buttons (Load Sample, Reset, Download PNG, Download PDF).
   - Main grid: left = builder panel; right = preview panel containing the `<svg id="svg">`.
   - Footer: "Made by Laith Hamdan".
3. `<script>` block — application code, organized as:
   - `state` object (single source of truth)
   - `uid()` helper
   - `render()` — top-level re-render entry point
   - `renderBuilder()` — left panel UI
   - `renderSvg()` — right panel SVG diagram
   - Layout helpers (`layoutTables`, `tableHeight`)
   - SVG helpers (`mk`, `txt`, `drawTable`, `drawRelationship`, `crowfoot`, `onebar`)
   - Event handlers (add table, delete table, add column, etc.) — wired via event delegation
   - Sample loader (the library ERD)
   - Export functions (`svgToCanvas`, `downloadPng`, `downloadPdf`) — ported from erd.html
4. jsPDF CDN `<script>` tag before the application script.

---

## Data Model (locked in across all tasks)

```js
let state = {
  tables: [
    // {
    //   id: 't1',
    //   name: 'AUTHORS',
    //   columns: [
    //     {
    //       id: 'c1',
    //       name: 'author_id',
    //       type: 'NUMBER(5)',
    //       constraint: 'PK',    // one of: '', 'PK', 'FK', 'UQ'
    //       fkTableId: null,     // only used when constraint === 'FK'
    //       fkColumnId: null,    // only used when constraint === 'FK'
    //       relLabel: ''         // optional verb for the relationship line, only used when constraint === 'FK'
    //     }
    //   ]
    // }
  ]
};
```

Relationships are derived at render time by scanning every column with `constraint === 'FK'` that has both `fkTableId` and `fkColumnId` set. The FK side is "many" (crow's foot); the referenced PK side is "one" (single bar).

---

## Task 1: Scaffold the HTML file with theme and footer

**Files:**
- Create: `erd-generator.html`

- [ ] **Step 1: Create the file with full document scaffold, theme styles copied from erd.html, an empty SVG placeholder area, and the footer.**

Write the file with this exact starting content (this gives the engineer a working foundation that matches erd.html's look):

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>ERD Generator</title>
    <link
      href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500&family=Inter:wght@500;600;700&display=swap"
      rel="stylesheet"
    />
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body {
        background: #edf0f7;
        font-family: "Inter", system-ui, sans-serif;
        min-height: 100vh;
        display: flex;
        flex-direction: column;
        padding: 32px 24px 24px;
        gap: 18px;
      }
      header.page {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 6px;
      }
      h1 {
        font-size: 22px;
        font-weight: 700;
        color: #0f172a;
        letter-spacing: -0.4px;
      }
      .sub {
        font-size: 12px;
        color: #64748b;
      }
      .actions {
        display: flex;
        gap: 10px;
        flex-wrap: wrap;
        justify-content: center;
        margin-top: 6px;
      }
      .btn {
        appearance: none;
        border: 1px solid #1e3a5f;
        background: #1e3a5f;
        color: #fff;
        font-family: "Inter", system-ui, sans-serif;
        font-size: 12px;
        font-weight: 600;
        letter-spacing: 0.3px;
        padding: 8px 16px;
        border-radius: 8px;
        cursor: pointer;
        transition: transform .08s ease, background .15s ease, box-shadow .15s ease;
        box-shadow: 0 1px 3px rgba(0,0,0,.12);
      }
      .btn:hover { background: #274d7a; }
      .btn:active { transform: translateY(1px); }
      .btn.secondary { background: #fff; color: #1e3a5f; }
      .btn.secondary:hover { background: #f1f5f9; }
      .btn.ghost { background: transparent; color: #1e3a5f; border-color: #cbd5e1; box-shadow: none; }
      .btn.ghost:hover { background: #f1f5f9; }
      .btn.danger { border-color: #b91c1c; background: #fff; color: #b91c1c; }
      .btn.danger:hover { background: #fef2f2; }

      main.layout {
        display: grid;
        grid-template-columns: minmax(320px, 380px) 1fr;
        gap: 18px;
        align-items: start;
        width: 100%;
        max-width: 1400px;
        margin: 0 auto;
      }
      @media (max-width: 900px) {
        main.layout { grid-template-columns: 1fr; }
      }
      .card {
        background: #fff;
        border-radius: 14px;
        box-shadow: 0 1px 4px rgba(0,0,0,.08), 0 6px 24px rgba(0,0,0,.07);
        padding: 18px;
      }
      .card.preview { padding: 18px; overflow: auto; }

      footer.page {
        margin-top: 16px;
        font-size: 12px;
        color: #64748b;
        text-align: center;
      }
    </style>
  </head>
  <body>
    <header class="page">
      <h1>ERD Generator</h1>
      <p class="sub">Design your Entity–Relationship Diagram and export it</p>
      <div class="actions">
        <button class="btn ghost" id="btn-sample" type="button">Load Sample</button>
        <button class="btn ghost" id="btn-reset" type="button">Reset</button>
        <button class="btn" id="btn-png" type="button">Download PNG</button>
        <button class="btn secondary" id="btn-pdf" type="button">Download PDF</button>
      </div>
    </header>

    <main class="layout">
      <section class="card builder" id="builder"></section>
      <section class="card preview">
        <svg id="svg" xmlns="http://www.w3.org/2000/svg" width="800" height="500"></svg>
      </section>
    </main>

    <footer class="page">Made by Laith Hamdan</footer>

    <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>
    <script>
      // Application code goes here in later tasks.
    </script>
  </body>
</html>
```

- [ ] **Step 2: Manual verification**

Open `erd-generator.html` in a browser. Confirm:
- Header reads "ERD Generator" with subtitle and four buttons.
- A two-pane white-card layout is visible (left small/empty, right with empty SVG).
- Footer says "Made by Laith Hamdan".
- No console errors.

- [ ] **Step 3: Commit**

```bash
git add erd-generator.html
git commit -m "feat(erd-generator): scaffold page with theme and footer"
```

---

## Task 2: State, render skeleton, Add Table

**Files:**
- Modify: `erd-generator.html` (replace the placeholder `<script>` body)

- [ ] **Step 1: Add state, render skeleton, and event wiring**

Inside the bottom `<script>` block (the one after the jsPDF CDN), replace the placeholder comment with:

```js
const TYPES = ['NUMBER(5)', 'NUMBER(3)', 'NUMBER(4)', 'VARCHAR(50)', 'VARCHAR(100)', 'VARCHAR(150)', 'VARCHAR(255)', 'VARCHAR(20)', 'DATE', 'BOOLEAN'];
const CONSTRAINTS = [
  { v: '',   label: 'None' },
  { v: 'PK', label: 'PK — Primary Key' },
  { v: 'FK', label: 'FK — Foreign Key' },
  { v: 'UQ', label: 'UQ — Unique' },
];

let _idSeq = 0;
const uid = (p) => `${p}${++_idSeq}`;

let state = { tables: [] };

function makeColumn(overrides = {}) {
  return {
    id: uid('c'),
    name: 'column_name',
    type: 'NUMBER(5)',
    constraint: '',
    fkTableId: null,
    fkColumnId: null,
    relLabel: '',
    ...overrides,
  };
}

function makeTable(overrides = {}) {
  const tableNumber = state.tables.length + 1;
  return {
    id: uid('t'),
    name: `TABLE_${tableNumber}`,
    columns: [makeColumn({ name: 'id', type: 'NUMBER(5)', constraint: 'PK' })],
    ...overrides,
  };
}

function addTable() {
  state.tables.push(makeTable());
  render();
}

function render() {
  renderBuilder();
  renderSvg();
}

function renderBuilder() {
  const root = document.getElementById('builder');
  if (state.tables.length === 0) {
    root.innerHTML = `
      <div style="display:flex;flex-direction:column;gap:12px;align-items:flex-start">
        <p style="color:#64748b;font-size:13px">No tables yet. Add one to start designing.</p>
        <button class="btn" id="add-first-table" type="button">+ Add Table</button>
      </div>`;
    document.getElementById('add-first-table').addEventListener('click', addTable);
    return;
  }
  // Real list rendering arrives in Task 3.
  root.innerHTML = `<p style="color:#64748b;font-size:13px">${state.tables.length} table(s) — list UI lands in next task.</p>
    <div style="margin-top:10px"><button class="btn" id="add-table" type="button">+ Add Table</button></div>`;
  document.getElementById('add-table').addEventListener('click', addTable);
}

function renderSvg() {
  // Real SVG rendering arrives in Task 5.
}

document.getElementById('btn-sample').addEventListener('click', () => { /* Task 8 */ });
document.getElementById('btn-reset').addEventListener('click', () => {
  if (state.tables.length === 0 || confirm('Clear everything?')) {
    state = { tables: [] };
    render();
  }
});
document.getElementById('btn-png').addEventListener('click', () => { /* Task 7 */ });
document.getElementById('btn-pdf').addEventListener('click', () => { /* Task 7 */ });

render();
```

- [ ] **Step 2: Manual verification**

Reload the page. Confirm:
- Builder pane shows "No tables yet" and a `+ Add Table` button.
- Clicking `+ Add Table` updates the pane to show "1 table(s)" and the button now reads `+ Add Table` (further clicks increment the count).
- Clicking `Reset` after adding tables prompts a confirm, then returns to empty state.
- No console errors.

- [ ] **Step 3: Commit**

```bash
git add erd-generator.html
git commit -m "feat(erd-generator): state + render skeleton + add table"
```

---

## Task 3: Render the table cards in the builder pane

**Files:**
- Modify: `erd-generator.html` — replace `renderBuilder()` and add CSS for the builder list.

- [ ] **Step 1: Add CSS for builder cards**

Inside the `<style>` block, just before the closing `</style>`, add:

```css
.builder-actions { display:flex; justify-content:space-between; align-items:center; margin-bottom:12px; }
.builder-actions h2 { font-size:13px; font-weight:600; color:#0f172a; letter-spacing:.3px; text-transform:uppercase; }
.t-card { border:1px solid #e2e8f0; border-radius:10px; padding:12px; margin-bottom:12px; background:#fafbff; }
.t-head { display:flex; align-items:center; gap:8px; margin-bottom:10px; }
.t-name {
  flex:1; font-family:"Inter",sans-serif; font-size:13px; font-weight:600;
  padding:6px 8px; border:1px solid #cbd5e1; border-radius:6px; background:#fff; color:#0f172a;
}
.t-name:focus { outline:2px solid #6366f1; outline-offset:1px; border-color:#6366f1; }
.col-list { display:flex; flex-direction:column; gap:6px; }
.col-row {
  display:grid; grid-template-columns: 1fr 1fr 1fr 28px; gap:6px; align-items:center;
}
.col-row.has-fk { grid-template-columns: 1fr 1fr 1fr 28px; }
.col-row .fk-target { grid-column: 1 / -1; display:flex; gap:6px; }
.col-row input, .col-row select, .fk-target select {
  font-family:"JetBrains Mono",monospace; font-size:11px; padding:5px 6px;
  border:1px solid #cbd5e1; border-radius:5px; background:#fff; color:#0f172a; width:100%;
}
.col-row input:focus, .col-row select:focus, .fk-target select:focus {
  outline:2px solid #6366f1; outline-offset:1px; border-color:#6366f1;
}
.icon-btn {
  width:28px; height:28px; border:1px solid #e2e8f0; background:#fff; color:#64748b;
  border-radius:6px; cursor:pointer; font-size:14px; line-height:1; display:flex; align-items:center; justify-content:center;
}
.icon-btn:hover { background:#fee2e2; color:#b91c1c; border-color:#fecaca; }
.col-add { margin-top:8px; }
.col-add .btn { padding:6px 10px; font-size:11px; }
```

- [ ] **Step 2: Replace `renderBuilder()` with the full implementation**

Replace the existing `renderBuilder()` function with:

```js
function renderBuilder() {
  const root = document.getElementById('builder');
  const headerHtml = `
    <div class="builder-actions">
      <h2>Tables</h2>
      <button class="btn" id="add-table" type="button">+ Add Table</button>
    </div>`;

  if (state.tables.length === 0) {
    root.innerHTML = headerHtml + `<p style="color:#64748b;font-size:13px">No tables yet. Click "Add Table" to start.</p>`;
    document.getElementById('add-table').addEventListener('click', addTable);
    return;
  }

  const cardsHtml = state.tables.map((t) => `
    <div class="t-card" data-tid="${t.id}">
      <div class="t-head">
        <input class="t-name" data-action="rename-table" value="${escapeAttr(t.name)}" />
        <button class="icon-btn" data-action="delete-table" title="Delete table">×</button>
      </div>
      <div class="col-list">
        ${t.columns.map((c) => renderColumnRow(t, c)).join('')}
      </div>
      <div class="col-add">
        <button class="btn ghost" data-action="add-column" type="button">+ Add Column</button>
      </div>
    </div>
  `).join('');

  root.innerHTML = headerHtml + cardsHtml;

  document.getElementById('add-table').addEventListener('click', addTable);
  wireBuilderEvents();
}

function renderColumnRow(table, col) {
  // Column row content lands in Task 4. For now, render a stub.
  return `<div class="col-row" data-cid="${col.id}">
    <span style="font-family:'JetBrains Mono',monospace;font-size:11px;color:#475569">${escapeAttr(col.name)}</span>
    <span></span><span></span>
    <button class="icon-btn" data-action="delete-column" title="Delete column">×</button>
  </div>`;
}

function escapeAttr(s) {
  return String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function wireBuilderEvents() {
  // Real wiring lands in Task 4. Provide minimal handlers now.
  document.querySelectorAll('[data-action="delete-table"]').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      const tid = e.target.closest('.t-card').dataset.tid;
      if (confirm('Delete this table?')) {
        state.tables = state.tables.filter((t) => t.id !== tid);
        // Also clear any FKs that pointed here.
        state.tables.forEach((t) => t.columns.forEach((c) => {
          if (c.fkTableId === tid) { c.fkTableId = null; c.fkColumnId = null; }
        }));
        render();
      }
    });
  });
  document.querySelectorAll('[data-action="rename-table"]').forEach((inp) => {
    inp.addEventListener('input', (e) => {
      const tid = e.target.closest('.t-card').dataset.tid;
      const t = state.tables.find((t) => t.id === tid);
      if (t) { t.name = e.target.value; renderSvg(); }
    });
  });
  document.querySelectorAll('[data-action="add-column"]').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      const tid = e.target.closest('.t-card').dataset.tid;
      const t = state.tables.find((t) => t.id === tid);
      if (t) { t.columns.push(makeColumn()); render(); }
    });
  });
  document.querySelectorAll('[data-action="delete-column"]').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      const tid = e.target.closest('.t-card').dataset.tid;
      const cid = e.target.closest('.col-row').dataset.cid;
      const t = state.tables.find((t) => t.id === tid);
      if (t) { t.columns = t.columns.filter((c) => c.id !== cid); render(); }
    });
  });
}
```

- [ ] **Step 3: Manual verification**

Reload. Confirm:
- Empty state shows the same as before, now with a top header bar.
- Add Table creates a card titled `TABLE_1` with one stub column named `id` and an `Add Column` button.
- Renaming the table input updates immediately (no save needed).
- `+ Add Column` appends a row.
- `×` on a column removes it; `×` on the table header prompts then removes the table.
- No console errors.

- [ ] **Step 4: Commit**

```bash
git add erd-generator.html
git commit -m "feat(erd-generator): table cards with add/delete in builder"
```

---

## Task 4: Full column editor row (name, type, constraint, FK picker)

**Files:**
- Modify: `erd-generator.html` — replace `renderColumnRow()` and extend `wireBuilderEvents()`.

- [ ] **Step 1: Replace `renderColumnRow()` with the full version**

```js
function renderColumnRow(table, col) {
  const typeOptions = TYPES.map((t) => `<option value="${t}" ${t === col.type ? 'selected' : ''}>${t}</option>`).join('')
    + (TYPES.includes(col.type) ? '' : `<option value="${escapeAttr(col.type)}" selected>${escapeAttr(col.type)}</option>`);
  const constraintOptions = CONSTRAINTS.map((c) => `<option value="${c.v}" ${c.v === col.constraint ? 'selected' : ''}>${c.label}</option>`).join('');

  let fkPicker = '';
  if (col.constraint === 'FK') {
    const otherTables = state.tables.filter((t) => t.id !== table.id);
    const tableOpts = `<option value="">— table —</option>` + otherTables.map((t) => `<option value="${t.id}" ${t.id === col.fkTableId ? 'selected' : ''}>${escapeAttr(t.name)}</option>`).join('');
    const targetTable = otherTables.find((t) => t.id === col.fkTableId);
    const colOpts = !targetTable
      ? `<option value="">— column —</option>`
      : `<option value="">— column —</option>` + targetTable.columns.map((c) => `<option value="${c.id}" ${c.id === col.fkColumnId ? 'selected' : ''}>${escapeAttr(c.name)}</option>`).join('');
    fkPicker = `
      <div class="fk-target">
        <select data-action="fk-table" title="Referenced table">${tableOpts}</select>
        <select data-action="fk-column" title="Referenced column">${colOpts}</select>
        <input data-action="rel-label" placeholder="label (e.g. writes)" value="${escapeAttr(col.relLabel)}" style="flex:1" />
      </div>`;
  }

  return `<div class="col-row${col.constraint === 'FK' ? ' has-fk' : ''}" data-cid="${col.id}">
    <input data-action="col-name" value="${escapeAttr(col.name)}" placeholder="column_name" />
    <select data-action="col-type">${typeOptions}</select>
    <select data-action="col-constraint">${constraintOptions}</select>
    <button class="icon-btn" data-action="delete-column" title="Delete column">×</button>
    ${fkPicker}
  </div>`;
}
```

- [ ] **Step 2: Extend `wireBuilderEvents()` — add column-level handlers**

At the bottom of `wireBuilderEvents()`, append:

```js
  const findCol = (el) => {
    const tid = el.closest('.t-card').dataset.tid;
    const cid = el.closest('.col-row').dataset.cid;
    const t = state.tables.find((t) => t.id === tid);
    return { t, c: t && t.columns.find((c) => c.id === cid) };
  };

  document.querySelectorAll('[data-action="col-name"]').forEach((inp) => {
    inp.addEventListener('input', (e) => {
      const { c } = findCol(e.target);
      if (c) { c.name = e.target.value; renderSvg(); }
    });
  });
  document.querySelectorAll('[data-action="col-type"]').forEach((sel) => {
    sel.addEventListener('change', (e) => {
      const { c } = findCol(e.target);
      if (c) { c.type = e.target.value; renderSvg(); }
    });
  });
  document.querySelectorAll('[data-action="col-constraint"]').forEach((sel) => {
    sel.addEventListener('change', (e) => {
      const { c } = findCol(e.target);
      if (!c) return;
      c.constraint = e.target.value;
      if (c.constraint !== 'FK') { c.fkTableId = null; c.fkColumnId = null; c.relLabel = ''; }
      render(); // full re-render so the FK picker appears/disappears
    });
  });
  document.querySelectorAll('[data-action="fk-table"]').forEach((sel) => {
    sel.addEventListener('change', (e) => {
      const { c } = findCol(e.target);
      if (!c) return;
      c.fkTableId = e.target.value || null;
      c.fkColumnId = null;
      render();
    });
  });
  document.querySelectorAll('[data-action="fk-column"]').forEach((sel) => {
    sel.addEventListener('change', (e) => {
      const { c } = findCol(e.target);
      if (!c) return;
      c.fkColumnId = e.target.value || null;
      renderSvg();
    });
  });
  document.querySelectorAll('[data-action="rel-label"]').forEach((inp) => {
    inp.addEventListener('input', (e) => {
      const { c } = findCol(e.target);
      if (c) { c.relLabel = e.target.value; renderSvg(); }
    });
  });
```

- [ ] **Step 3: Manual verification**

Reload. Confirm:
- Each column row shows: name input, type dropdown, constraint dropdown, delete button.
- Changing constraint to `FK` reveals a second row with: target-table dropdown, target-column dropdown, label input.
- Switching constraint away from FK collapses the picker and clears its values.
- Picking a different target table resets the column dropdown.
- Editing inputs does not lose keyboard focus on the input being edited (column-level edits call `renderSvg()` only, not `render()`).
- No console errors.

- [ ] **Step 4: Commit**

```bash
git add erd-generator.html
git commit -m "feat(erd-generator): full column editor with FK picker"
```

---

## Task 5: SVG renderer — draw tables only (no relationships yet)

**Files:**
- Modify: `erd-generator.html` — replace the stub `renderSvg()` and add helpers.

- [ ] **Step 1: Add layout + drawing helpers and the real `renderSvg()`**

Replace the stub `renderSvg()` with this block (this includes new helper functions; place them all in the script):

```js
const NS = 'http://www.w3.org/2000/svg';
const RH = 28, HH = 38, TW = 240;
const C = {
  HDR: '#1e3a5f', HDR_T: '#ffffff',
  ROW_A: '#ffffff', ROW_B: '#f8faff', BRD: '#e2e8f0',
  COL_N: '#1e293b', COL_T: '#94a3b8', REL: '#6366f1',
};
const BADGE = {
  PK: { bg: '#fef9c3', t: '#854d0e' },
  FK: { bg: '#dbeafe', t: '#1e40af' },
  UQ: { bg: '#dcfce7', t: '#166534' },
};

function mk(tag, attrs) {
  const e = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
  return e;
}
function txt(x, y, s, attrs) {
  const e = mk('text', { x, y, ...attrs });
  e.textContent = s;
  return e;
}
function tableHeight(t) { return HH + t.columns.length * RH; }

function layoutTables() {
  // Simple grid: 2 columns, 60px gap, top-left at (40, 40).
  const COLS = 2, GAP_X = 80, GAP_Y = 60, X0 = 40, Y0 = 40;
  const rows = [];
  state.tables.forEach((t, i) => {
    const col = i % COLS, row = Math.floor(i / COLS);
    rows[row] = rows[row] || [];
    rows[row][col] = t;
  });
  const positions = {};
  let yCursor = Y0;
  rows.forEach((rowTables) => {
    let rowMaxH = 0;
    rowTables.forEach((t, col) => {
      positions[t.id] = { x: X0 + col * (TW + GAP_X), y: yCursor };
      rowMaxH = Math.max(rowMaxH, tableHeight(t));
    });
    yCursor += rowMaxH + GAP_Y;
  });
  return positions;
}

function drawTable(svg, t, pos) {
  const h = tableHeight(t);
  const { x, y } = pos;

  // Clip path so row backgrounds respect rounded corners.
  const cpId = `cp-${t.id}`;
  const cp = mk('clipPath', { id: cpId });
  cp.appendChild(mk('rect', { x, y, width: TW, height: h, rx: 8 }));
  svg.appendChild(cp);

  // Shadow.
  svg.appendChild(mk('rect', { x: x + 3, y: y + 4, width: TW, height: h, rx: 8, fill: 'rgba(0,0,0,.07)' }));

  const g = mk('g', { 'clip-path': `url(#${cpId})` });

  // Header.
  g.appendChild(mk('rect', { x, y, width: TW, height: HH, fill: C.HDR }));
  g.appendChild(txt(x + TW / 2, y + HH / 2 + 1, t.name || '(unnamed)', {
    'text-anchor': 'middle', 'dominant-baseline': 'central',
    fill: C.HDR_T, 'font-family': "'Inter',sans-serif",
    'font-size': 13, 'font-weight': 700, 'letter-spacing': '0.8',
  }));

  // Rows.
  t.columns.forEach((col, i) => {
    const ry = y + HH + i * RH;
    const fill = i % 2 === 0 ? C.ROW_A : C.ROW_B;
    g.appendChild(mk('rect', { x, y: ry, width: TW, height: RH, fill }));
    g.appendChild(mk('line', { x1: x, y1: ry, x2: x + TW, y2: ry, stroke: C.BRD, 'stroke-width': 0.5 }));

    let nx = x + 8;
    if (col.constraint && BADGE[col.constraint]) {
      const b = BADGE[col.constraint];
      g.appendChild(mk('rect', { x: x + 6, y: ry + 7, width: 26, height: 14, rx: 3, fill: b.bg }));
      g.appendChild(txt(x + 19, ry + RH / 2, col.constraint, {
        'text-anchor': 'middle', 'dominant-baseline': 'central',
        fill: b.t, 'font-family': "'JetBrains Mono',monospace",
        'font-size': 9, 'font-weight': 600,
      }));
      nx = x + 37;
    }
    g.appendChild(txt(nx, ry + RH / 2, col.name || '(unnamed)', {
      'dominant-baseline': 'central', fill: C.COL_N,
      'font-family': "'JetBrains Mono',monospace",
      'font-size': 11, 'font-weight': col.constraint ? 500 : 400,
    }));
    g.appendChild(txt(x + TW - 8, ry + RH / 2, col.type || '', {
      'text-anchor': 'end', 'dominant-baseline': 'central',
      fill: C.COL_T, 'font-family': "'JetBrains Mono',monospace",
      'font-size': 10,
    }));
  });

  svg.appendChild(g);

  // Border.
  svg.appendChild(mk('rect', { x, y, width: TW, height: h, rx: 8, fill: 'none', stroke: C.BRD, 'stroke-width': 1 }));
}

function renderSvg() {
  const svg = document.getElementById('svg');
  while (svg.firstChild) svg.removeChild(svg.firstChild);

  if (state.tables.length === 0) {
    svg.setAttribute('width', 800);
    svg.setAttribute('height', 200);
    svg.appendChild(txt(400, 100, 'Add a table to see your diagram here', {
      'text-anchor': 'middle', 'dominant-baseline': 'central',
      fill: '#94a3b8', 'font-family': "'Inter',sans-serif",
      'font-size': 14,
    }));
    return;
  }

  const positions = layoutTables();
  state.tables.forEach((t) => drawTable(svg, t, positions[t.id]));

  // Resize SVG to fit.
  let maxX = 0, maxY = 0;
  state.tables.forEach((t) => {
    const p = positions[t.id];
    maxX = Math.max(maxX, p.x + TW);
    maxY = Math.max(maxY, p.y + tableHeight(t));
  });
  svg.setAttribute('width', maxX + 40);
  svg.setAttribute('height', maxY + 40);
}
```

- [ ] **Step 2: Manual verification**

Reload. Confirm:
- Empty state shows muted "Add a table to see your diagram here" text in the preview pane.
- Adding tables shows them in a 2-column grid in the SVG.
- Header is dark navy, alternating row stripes, monospace columns/types.
- PK/FK/UQ badges render in the same colors as `erd.html` (yellow/blue/green).
- Renaming a column or table updates the SVG live.
- No console errors.

- [ ] **Step 3: Commit**

```bash
git add erd-generator.html
git commit -m "feat(erd-generator): SVG renderer for tables"
```

---

## Task 6: Draw FK relationships with crow's-foot connectors

**Files:**
- Modify: `erd-generator.html` — add relationship-drawing helpers and extend `renderSvg()`.

- [ ] **Step 1: Add relationship helpers**

Add these functions to the script (anywhere after `drawTable`):

```js
function seg(x1, y1, x2, y2) {
  return mk('line', { x1, y1, x2, y2, stroke: C.REL, 'stroke-width': 1.5, 'stroke-linecap': 'round' });
}
function relPath(d) {
  return mk('path', { d, fill: 'none', stroke: C.REL, 'stroke-width': 1.5, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' });
}

// Crow's foot at the "many" side. dir = 'right' means the line arrives going → into the box's LEFT edge.
function crowfoot(g, bx, by, dir) {
  const F = 16, B = 9, BAR = 23;
  if (dir === 'right') {
    g.appendChild(seg(bx - F, by, bx, by - B));
    g.appendChild(seg(bx - F, by, bx, by));
    g.appendChild(seg(bx - F, by, bx, by + B));
    g.appendChild(seg(bx - BAR, by - B, bx - BAR, by + B));
  } else {
    g.appendChild(seg(bx + F, by, bx, by - B));
    g.appendChild(seg(bx + F, by, bx, by));
    g.appendChild(seg(bx + F, by, bx, by + B));
    g.appendChild(seg(bx + BAR, by - B, bx + BAR, by + B));
  }
}
// Single bar at the "one" side. dir = 'right' means the line leaves going → from the box's RIGHT edge.
function onebar(g, ex, ey, dir) {
  const OFF = 8, H = 9;
  if (dir === 'right') g.appendChild(seg(ex + OFF, ey - H, ex + OFF, ey + H));
  else                 g.appendChild(seg(ex - OFF, ey - H, ex - OFF, ey + H));
}

function collectRelationships(positions) {
  // Each relationship: source = the table containing the FK column ("many" side),
  // target = the referenced table ("one" side).
  const rels = [];
  state.tables.forEach((srcTable) => {
    srcTable.columns.forEach((col) => {
      if (col.constraint !== 'FK' || !col.fkTableId || !col.fkColumnId) return;
      const tgtTable = state.tables.find((t) => t.id === col.fkTableId);
      if (!tgtTable) return;
      const tgtCol = tgtTable.columns.find((c) => c.id === col.fkColumnId);
      if (!tgtCol) return;
      rels.push({ srcTable, srcCol: col, tgtTable, tgtCol, label: col.relLabel });
    });
  });
  return rels;
}

function columnY(table, col, pos) {
  const idx = table.columns.findIndex((c) => c.id === col.id);
  return pos.y + HH + idx * RH + RH / 2;
}

function drawRelationship(svg, rel, positions) {
  // "many" side = FK side (srcTable). "one" side = PK side (tgtTable).
  const sp = positions[rel.srcTable.id];
  const tp = positions[rel.tgtTable.id];
  const sy = columnY(rel.srcTable, rel.srcCol, sp);
  const ty = columnY(rel.tgtTable, rel.tgtCol, tp);

  const srcCx = sp.x + TW / 2, tgtCx = tp.x + TW / 2;

  // Decide which sides to connect based on horizontal position.
  // Convention used in erd.html: many side connector arrives at table's LEFT edge → crowfoot dir='right'.
  let sx, manyDir, ex, oneDir;
  if (srcCx > tgtCx) {
    // Source ("many") sits to the RIGHT of target ("one").
    sx = sp.x;            // FK side: enter at left edge of source
    manyDir = 'right';
    ex = tp.x + TW;       // PK side: leave from right edge of target
    oneDir = 'right';
  } else {
    sx = sp.x + TW;
    manyDir = 'left';
    ex = tp.x;
    oneDir = 'left';
  }

  // Orthogonal path with one elbow at horizontal midpoint between the two endpoints.
  const midX = (sx + ex) / 2;
  const d = `M${ex},${ty} L${midX},${ty} L${midX},${sy} L${sx},${sy}`;

  const g = mk('g', {});
  g.appendChild(relPath(d));
  onebar(g, ex, ty, oneDir);
  crowfoot(g, sx, sy, manyDir);

  if (rel.label) {
    g.appendChild(txt(midX, Math.min(sy, ty) - 6, rel.label, {
      'text-anchor': 'middle', fill: '#818cf8',
      'font-family': "'Inter',sans-serif", 'font-size': 11, 'font-style': 'italic',
    }));
  }
  svg.appendChild(g);
}
```

- [ ] **Step 2: Extend `renderSvg()` to draw relationships behind tables**

Find the `renderSvg()` function and change the part that draws tables so relationships are drawn FIRST (so tables sit on top of the lines). Replace the body after the empty-state check with:

```js
  const positions = layoutTables();

  // Draw relationships first so tables paint over the connectors.
  const rels = collectRelationships(positions);
  rels.forEach((r) => drawRelationship(svg, r, positions));

  // Then draw tables.
  state.tables.forEach((t) => drawTable(svg, t, positions[t.id]));

  // Resize SVG to fit.
  let maxX = 0, maxY = 0;
  state.tables.forEach((t) => {
    const p = positions[t.id];
    maxX = Math.max(maxX, p.x + TW);
    maxY = Math.max(maxY, p.y + tableHeight(t));
  });
  svg.setAttribute('width', maxX + 40);
  svg.setAttribute('height', maxY + 40);
```

- [ ] **Step 3: Manual verification**

Reload. Confirm:
- Add at least two tables (e.g., AUTHORS with `author_id PK`, BOOKS with `book_id PK` and `author_id FK → AUTHORS.author_id`).
- A purple orthogonal connector appears between BOOKS and AUTHORS.
- The end at AUTHORS side has a single bar; the end at BOOKS side has a three-pronged crow's foot with a perpendicular bar 23px inboard.
- Typing a label in the FK label input renders italic purple text above the line midpoint.
- Removing the FK target clears the relationship line.
- Deleting a referenced table also clears the dangling FK (this was wired in Task 3).
- No console errors.

- [ ] **Step 4: Commit**

```bash
git add erd-generator.html
git commit -m "feat(erd-generator): crow's-foot relationship connectors"
```

---

## Task 7: PNG and PDF export

**Files:**
- Modify: `erd-generator.html` — replace the empty `btn-png` and `btn-pdf` handlers, add export helper.

- [ ] **Step 1: Add export helper and wire the buttons**

Append the following to the script, then replace the two empty button handlers at the bottom:

```js
function svgToCanvas(scale) {
  return new Promise((resolve, reject) => {
    const src = document.getElementById('svg');
    const w = parseInt(src.getAttribute('width'), 10);
    const h = parseInt(src.getAttribute('height'), 10);

    const clone = src.cloneNode(true);
    clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
    clone.setAttribute('xmlns:xlink', 'http://www.w3.org/1999/xlink');
    clone.setAttribute('width', w);
    clone.setAttribute('height', h);

    const xml = new XMLSerializer().serializeToString(clone);
    const svg64 = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(xml);

    const img = new Image();
    img.onload = () => {
      const canvas = document.createElement('canvas');
      canvas.width = w * scale;
      canvas.height = h * scale;
      const ctx = canvas.getContext('2d');
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.setTransform(scale, 0, 0, scale, 0, 0);
      ctx.drawImage(img, 0, 0);
      resolve({ canvas, w, h });
    };
    img.onerror = reject;
    img.src = svg64;
  });
}

function downloadHref(href, name) {
  const a = document.createElement('a');
  a.href = href;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
}

async function downloadPng() {
  if (state.tables.length === 0) { alert('Add at least one table first.'); return; }
  const { canvas } = await svgToCanvas(2);
  canvas.toBlob((blob) => {
    const url = URL.createObjectURL(blob);
    downloadHref(url, 'erd.png');
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }, 'image/png');
}

async function downloadPdf() {
  if (state.tables.length === 0) { alert('Add at least one table first.'); return; }
  const { canvas, w, h } = await svgToCanvas(2);
  const { jsPDF } = window.jspdf;
  const pdf = new jsPDF({
    orientation: w >= h ? 'landscape' : 'portrait',
    unit: 'pt',
    format: [w, h],
  });
  pdf.addImage(canvas.toDataURL('image/png'), 'PNG', 0, 0, w, h);
  pdf.save('erd.pdf');
}
```

Now replace the existing empty handlers near the bottom:

```js
document.getElementById('btn-png').addEventListener('click', downloadPng);
document.getElementById('btn-pdf').addEventListener('click', downloadPdf);
```

- [ ] **Step 2: Manual verification**

Reload. Build a tiny 2-table ERD. Confirm:
- `Download PNG` saves `erd.png`; opening it shows the diagram on a white background, sharp at 2× scale.
- `Download PDF` saves `erd.pdf`; the page size fits the SVG, content matches the preview.
- With zero tables, clicking either button shows an alert and skips the download.
- No console errors.

- [ ] **Step 3: Commit**

```bash
git add erd-generator.html
git commit -m "feat(erd-generator): PNG and PDF export"
```

---

## Task 8: Load Sample (Library template)

**Files:**
- Modify: `erd-generator.html` — replace the empty `btn-sample` handler.

- [ ] **Step 1: Add the sample loader**

Append to the script:

```js
function loadSample() {
  if (state.tables.length > 0 && !confirm('Replace your current diagram with the sample?')) return;
  _idSeq = 0;
  const t = (name, columns) => ({ id: uid('t'), name, columns });
  const c = (overrides) => makeColumn(overrides);

  const authors = t('AUTHORS', [
    c({ name: 'author_id', type: 'NUMBER(5)', constraint: 'PK' }),
    c({ name: 'first_name', type: 'VARCHAR(50)' }),
    c({ name: 'last_name', type: 'VARCHAR(50)' }),
    c({ name: 'nationality', type: 'VARCHAR(50)' }),
  ]);
  const categories = t('CATEGORIES', [
    c({ name: 'category_id', type: 'NUMBER(5)', constraint: 'PK' }),
    c({ name: 'name', type: 'VARCHAR(50)', constraint: 'UQ' }),
    c({ name: 'description', type: 'VARCHAR(255)' }),
  ]);
  const books = t('BOOKS', [
    c({ name: 'book_id', type: 'NUMBER(5)', constraint: 'PK' }),
    c({ name: 'isbn', type: 'VARCHAR(20)', constraint: 'UQ' }),
    c({ name: 'title', type: 'VARCHAR(150)' }),
    c({ name: 'author_id', type: 'NUMBER(5)', constraint: 'FK', fkTableId: authors.id, fkColumnId: authors.columns[0].id, relLabel: 'writes' }),
    c({ name: 'category_id', type: 'NUMBER(5)', constraint: 'FK', fkTableId: categories.id, fkColumnId: categories.columns[0].id, relLabel: 'classifies' }),
    c({ name: 'year_published', type: 'NUMBER(4)' }),
    c({ name: 'total_copies', type: 'NUMBER(3)' }),
    c({ name: 'available_copies', type: 'NUMBER(3)' }),
  ]);
  const members = t('MEMBERS', [
    c({ name: 'member_id', type: 'NUMBER(5)', constraint: 'PK' }),
    c({ name: 'first_name', type: 'VARCHAR(50)' }),
    c({ name: 'last_name', type: 'VARCHAR(50)' }),
    c({ name: 'email', type: 'VARCHAR(100)', constraint: 'UQ' }),
    c({ name: 'join_date', type: 'DATE' }),
    c({ name: 'status', type: 'VARCHAR(10)' }),
  ]);
  const loans = t('LOANS', [
    c({ name: 'loan_id', type: 'NUMBER(5)', constraint: 'PK' }),
    c({ name: 'book_id', type: 'NUMBER(5)', constraint: 'FK', fkTableId: books.id, fkColumnId: books.columns[0].id, relLabel: 'borrowed in' }),
    c({ name: 'member_id', type: 'NUMBER(5)', constraint: 'FK', fkTableId: members.id, fkColumnId: members.columns[0].id, relLabel: 'makes' }),
    c({ name: 'loan_date', type: 'DATE' }),
    c({ name: 'due_date', type: 'DATE' }),
    c({ name: 'return_date', type: 'DATE' }),
    c({ name: 'status', type: 'VARCHAR(10)' }),
  ]);

  state = { tables: [authors, categories, books, members, loans] };
  render();
}
```

Replace the empty sample handler at the bottom:

```js
document.getElementById('btn-sample').addEventListener('click', loadSample);
```

- [ ] **Step 2: Manual verification**

Reload. Click `Load Sample`. Confirm:
- All five tables (AUTHORS, CATEGORIES, BOOKS, MEMBERS, LOANS) appear in the builder pane.
- The SVG preview shows all five tables with the expected PK/FK/UQ badges and four FK connectors.
- FK labels render as `writes`, `classifies`, `borrowed in`, `makes` above the connector midpoints.
- `Download PNG` and `Download PDF` produce a file visually equivalent to `erd.html` (allowing layout differences from the simpler 2-column grid).
- No console errors.

- [ ] **Step 3: Commit**

```bash
git add erd-generator.html
git commit -m "feat(erd-generator): load library sample template"
```

---

## Task 9: Polish — auto-scroll, drag-to-reorder columns, in-table FK self-prevention

**Files:**
- Modify: `erd-generator.html` — small UX tweaks.

This task is deliberately narrow: it only adds the conveniences the student will hit in their first 60 seconds. Skip anything not listed here.

- [ ] **Step 1: After adding a column, focus its name input**

Find the `add-column` handler inside `wireBuilderEvents()` and change it to:

```js
  document.querySelectorAll('[data-action="add-column"]').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      const tid = e.target.closest('.t-card').dataset.tid;
      const t = state.tables.find((t) => t.id === tid);
      if (!t) return;
      const newCol = makeColumn({ name: '' });
      t.columns.push(newCol);
      render();
      const inp = document.querySelector(`.t-card[data-tid="${t.id}"] .col-row[data-cid="${newCol.id}"] [data-action="col-name"]`);
      if (inp) inp.focus();
    });
  });
```

- [ ] **Step 2: After adding a table, focus its name input and scroll into view**

Change `addTable` to:

```js
function addTable() {
  const newTable = makeTable();
  state.tables.push(newTable);
  render();
  const inp = document.querySelector(`.t-card[data-tid="${newTable.id}"] .t-name`);
  if (inp) { inp.focus(); inp.select(); inp.scrollIntoView({ behavior: 'smooth', block: 'center' }); }
}
```

- [ ] **Step 3: Mark FK rows in the SVG**

(Already done by Task 5 via the constraint badge.) Nothing to add — verify the FK column is shown with the blue `FK` badge in the diagram.

- [ ] **Step 4: Manual verification**

Reload. Confirm:
- Adding a new table immediately focuses its name field, ready for typing.
- Adding a new column immediately focuses its name field with empty placeholder.
- All Task 1–8 functionality still works.
- No console errors.

- [ ] **Step 5: Commit**

```bash
git add erd-generator.html
git commit -m "feat(erd-generator): focus and scroll UX polish"
```

---

## Task 10: Final pass — visual check against erd.html

**Files:** (read-only review)

- [ ] **Step 1: Side-by-side visual diff against [erd.html](erd.html)**

Open both `erd.html` and `erd-generator.html` (after clicking `Load Sample`) in side-by-side browser windows. Confirm:
- Same dark navy table header (#1e3a5f).
- Same row striping (`#ffffff` / `#f8faff`).
- Same monospace fonts (JetBrains Mono) for columns and types.
- Same PK (yellow), FK (blue), UQ (green) badge styles.
- Same purple relationship lines (#6366f1) with crow's-foot + single-bar markers.
- Same purple italic relationship labels.
- Footer of `erd-generator.html` reads "Made by Laith Hamdan".

If anything visually drifts from `erd.html`, fix the relevant constant in `C`, `BADGE`, or the SVG drawing code and re-verify. Commit any fix as `style(erd-generator): match erd.html visual ...`.

- [ ] **Step 2: End-to-end smoke test**

Starting from an empty `erd-generator.html`:
1. Click `Load Sample` → verify diagram matches erd.html structurally.
2. Add a new table `PUBLISHERS` with `pub_id PK`, `name VARCHAR(100)`.
3. In BOOKS, add column `pub_id NUMBER(5) FK → PUBLISHERS.pub_id` with label `published by`.
4. Verify a new crow's-foot line connects BOOKS to PUBLISHERS.
5. `Download PNG` and `Download PDF` — open both files, confirm they reflect all six tables and five connectors.

- [ ] **Step 3: Commit (if any fixes were made)**

```bash
git add erd-generator.html
git commit -m "polish(erd-generator): final visual parity with erd.html"
```

---

## Self-Review

**Spec coverage:**
- "Single HTML file" → Task 1 produces `erd-generator.html`, a self-contained file.
- "Choose number of tables" → Task 2 (`Add Table`) + Task 3 (delete table).
- "Columns with constraints" → Task 4 (name/type/constraint editor).
- "Relationships" → Task 4 (FK target picker) + Task 6 (crow's-foot rendering).
- "Full diagram view" → Task 5 (table render) + Task 6 (connectors).
- "PNG/PDF download" → Task 7.
- "Same theme as erd.html" → Task 1 (CSS theme copy) + Task 5/6 (SVG colors & fonts copied) + Task 10 (visual diff).
- "Made by Laith Hamdan footer" → Task 1.
- "Smooth, easy for students" → Task 9 (auto-focus, scroll-into-view) + sensible defaults (default column on new table, dropdowns for types/constraints, inline FK picker that appears only when needed, sample loader in Task 8).

**Placeholder scan:** No `TBD`/`TODO` in tasks; every code block is complete; every step has a concrete action.

**Type consistency:**
- `state.tables[].columns[]` has fields: `id, name, type, constraint, fkTableId, fkColumnId, relLabel` — consistent everywhere (Task 2 `makeColumn`, Task 4 picker, Task 6 `collectRelationships`, Task 8 sample loader).
- Function names: `render`, `renderBuilder`, `renderSvg`, `renderColumnRow`, `wireBuilderEvents`, `addTable`, `loadSample`, `svgToCanvas`, `downloadPng`, `downloadPdf` — referenced consistently.
- DOM data attributes (`data-tid`, `data-cid`, `data-action="..."`) — match between render output (Tasks 3, 4) and event handlers (Tasks 3, 4).

---

## Execution Handoff

Plan complete and saved to `erd-generator-plan.md` (next to `erd.html`). Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
