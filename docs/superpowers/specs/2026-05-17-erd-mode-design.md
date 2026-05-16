# ERD Mode — Design Spec

Date: 2026-05-17
Status: Draft

## Goal

Add a second mode to the existing single-page app so it can produce **two kinds of diagrams**:

1. **Schema** — the existing table/column/relation builder (current behavior, no functional change).
2. **ERD** — a new Elmasri/Navathe-style Entity-Relationship diagram builder that draws entities, attributes, and relationships using the textbook notation shown in the reference image (EMPLOYEE/DEPARTMENT/PROJECT/DEPENDENT example).

The two modes share the page chrome (header, sample/reset buttons, PNG/PDF export, footer, CSS) and switch via two pill buttons in the header: **Schema** | **ERD**. Each mode keeps its own diagram state, so toggling does not destroy work in the other mode.

## Non-goals

- No conversion between Schema and ERD (no "generate tables from this ERD" or vice versa). They are independent diagrams that share the page.
- No connector auto-routing — straight lines with manual drag-to-position for clean layouts.
- No persistence beyond in-memory state (matches the current app — no localStorage).
- No undo/redo (matches the current app).
- No foreign-key concept in ERD mode. FK is a relational/schema notion and does not appear in classical ER notation or in the reference picture.
- No PK/CK/Super-key badges. Key attributes are expressed solely by underlining their oval label, exactly as in the reference picture.

## Architecture

### File layout

Continue to be a single `index.html`. The existing schema renderer/builder is left in place. The ERD additions are added in the same file, in clearly-separated sections:

- shared chrome (header, mode switch, export, footer)
- schema state + schema builder + schema renderer (existing)
- **erd state + erd builder + erd renderer** (new)
- shared utilities (`mk`, `txt`, drag handlers, PNG/PDF export pipeline) lifted so both renderers reuse them

### Mode switch

Top-level state gains a `mode` field:

```js
state = {
  mode: 'schema',                    // 'schema' | 'erd'
  schema: { tables: [...] },         // existing
  erd: { entities: [...], relationships: [...] },
};
```

Two pill buttons in the header (`Schema` | `ERD`) toggle `state.mode` and re-render. Header buttons that act on a diagram (Load Sample, Reset Layout, Reset, Download PNG, Download PDF) dispatch to the active mode:

- `Load Sample` in schema mode loads the existing tables sample; in ERD mode loads an EMPLOYEE/DEPARTMENT/PROJECT/DEPENDENT sample matching the reference picture.
- `Download PNG/PDF` exports `schema.png`/`schema.pdf` in schema mode and `erd.png`/`erd.pdf` in ERD mode.
- `Reset Layout` clears pinned `x`/`y` on the active mode's nodes.
- `Reset` clears the active mode's state slice only.

### ERD data model

```js
state.erd = {
  entities: [
    {
      id, name,
      kind: 'strong' | 'weak',
      x?, y?,                                // pinned position after drag
      attributes: [Attribute, ...],
    },
    ...
  ],
  relationships: [
    {
      id, name,
      kind: 'normal' | 'identifying',        // identifying => double diamond
      x?, y?,
      attributes: [Attribute, ...],          // e.g. Hours on WORKS_ON
      participants: [
        {
          entityId,
          role,                              // e.g. "Supervisor" / "Supervisee" for unary
          cardinality: '1' | 'N' | 'M',
          participation: 'total' | 'partial',
        },
        ...
      ],
    },
    ...
  ],
};

// Attribute (nested via children for composite)
{
  id, name,
  kind: 'simple' | 'key' | 'partial-key' | 'composite' | 'multivalued' | 'derived',
  x?, y?,                                    // pinned position after drag
  children: [Attribute, ...],                // only meaningful when kind === 'composite'
}
```

Notes:
- **Relationship degree** is implicit in `participants.length` (1 = unary, 2 = binary, 3 = ternary). No separate enum.
- **Self-relationship (unary)** has two participants with the same `entityId` and distinct `role` labels (e.g. `Supervisor` / `Supervisee` for `SUPERVISION`).
- **Identifying relationship** is paired in practice with a weak entity and a partial-key attribute, but the flags are independent so the user can model freely.
- **Composite attributes** form a tree via `children` (e.g. `Name → Fname / Minit / Lname`).
- No `PK / FK / Candidate / Super` tagging — those concepts are not part of ER notation and are not in the reference picture.

### Sample (loaded by "Load Sample" in ERD mode)

The sample mirrors the reference picture:

- Entities: `EMPLOYEE` (strong), `DEPARTMENT` (strong), `PROJECT` (strong), `DEPENDENT` (weak).
- `EMPLOYEE` attributes: `Ssn` (key), `Name` (composite → `Fname`, `Minit`, `Lname`), `Bdate`, `Address`, `Sex`, `Salary`.
- `DEPARTMENT` attributes: `Name` (key), `Number` (key), `Locations` (multivalued), `Number_of_employees` (derived).
- `PROJECT` attributes: `Name` (key), `Number` (key), `Location`.
- `DEPENDENT` attributes: `Name` (partial-key), `Sex`, `Birth_date`, `Relationship`.
- Relationships:
  - `WORKS_FOR` (binary): EMPLOYEE N (total), DEPARTMENT 1 (total).
  - `MANAGES` (binary): EMPLOYEE 1 (partial), DEPARTMENT 1 (total), attribute `Start_date`.
  - `CONTROLS` (binary): DEPARTMENT 1 (partial), PROJECT N (total).
  - `WORKS_ON` (binary): EMPLOYEE M (partial), PROJECT N (total), attribute `Hours`.
  - `SUPERVISION` (unary): EMPLOYEE `Supervisor` 1 (partial), EMPLOYEE `Supervisee` N (partial).
  - `DEPENDENTS_OF` (identifying, binary): EMPLOYEE 1 (partial), DEPENDENT N (total).

## ERD builder pane (left side)

Mirrors the existing table-card pattern in the schema builder. Two stacked sections:

### Entities section

Header: `Entities` + `+ Add Entity`.

Each entity card:
- name input
- kind toggle: `Strong` / `Weak` (radio or two-button)
- attributes list, each row:
  - name input
  - kind dropdown: `Simple / Key / Partial key / Composite / Multivalued / Derived`
  - if kind is `Composite`: nested attribute list with a `+ Add sub-attribute` button. Sub-attributes use the same row UI but cannot themselves be `Composite` (nesting is limited to one level — matches the textbook and the reference picture, where `Name → Fname/Minit/Lname` is the only composite and its children are all simple).
  - delete button
- `+ Add Attribute`
- delete-entity button (with confirm, like the schema delete-table)

### Relationships section

Header: `Relationships` + `+ Add Relationship`.

Each relationship card:
- name input
- kind toggle: `Normal` / `Identifying`
- participants list (1–3 rows), each row:
  - entity dropdown (any entity, including the same entity again — that's how unary works)
  - role label input (optional, used for self-relationships like Supervisor/Supervisee)
  - cardinality dropdown: `1 / N / M`
  - participation toggle: `Partial / Total`
  - delete-participant button
- `+ Add Participant` (disabled when count is 3)
- relationship-attributes list (same UI as entity attributes, but kinds restricted to `Simple / Multivalued / Derived` — relationships don't have key attributes)
- `+ Add Attribute`
- delete-relationship button (with confirm)

## ERD renderer (right SVG pane)

### Symbol mapping (matches the reference picture)

| Concept | SVG |
|---|---|
| Strong entity | Rectangle, light-grey fill, name centered, optional 1px inner stroke. Drag handle on the whole shape. |
| Weak entity | Double rectangle (outer rect + inner rect inset ~4px). |
| Relationship | Diamond (rotated square), light-grey fill, name centered. |
| Identifying relationship | Double diamond (outer + inner inset). |
| Attribute (simple) | Oval, white fill, thin stroke, label centered. Connected to its owner by a thin line. |
| Key attribute | Same oval, label rendered with an SVG `text-decoration: underline` (full underline). |
| Partial-key attribute | Same oval, label underlined with a **dashed** line (rendered as a separate `<line>` with `stroke-dasharray`, since SVG `text-decoration` cannot do dashed). |
| Multivalued attribute | Double oval (outer + inner inset). |
| Derived attribute | Single oval with **dashed** stroke (`stroke-dasharray`). |
| Composite attribute | Single parent oval, with child ovals branching off via lines. Children can be `Simple / Key / Partial-key / Multivalued / Derived` (not `Composite` — nesting is one level only). |
| Total participation | Double line from entity rectangle to the relationship diamond (parallel lines ~3px apart). |
| Partial participation | Single line. |
| Cardinality label | Small text (`1` / `N` / `M`) placed on the connector near the diamond. |
| Role label | Small text placed near the entity end of a self-relationship connector (e.g. `Supervisor`, `Supervisee`). |

Colors and stroke weights follow the existing palette (`C.HDR`, `C.BRD`, `C.REL`) so ERD and Schema feel like one product.

### Layout

Default auto-layout:
- Entities placed in a grid (similar to current `layoutTables` — 2 columns, gap, top-left origin).
- Each entity's attribute ovals fan out above and around it on a circular arc; composite children fan off their parent oval.
- Each relationship diamond is placed at the centroid of its participant entities. Self-relationships place the diamond at a fixed offset to one side of the single participant entity.
- Relationship attributes fan out from the diamond.

Pinning by drag: any node (entity, relationship, attribute oval, including composite children) is draggable. Dragging sets `x`/`y` on the underlying object and from then on the auto-layout respects that pin, exactly like the existing table drag-pin in schema mode. The drag handler is shared between modes.

### Connectors

Straight lines from the edge of one shape to the edge of the other:
- Entity ↔ relationship: line from entity rectangle edge to diamond edge. Doubled if participation is `total`. Cardinality label placed at the diamond end. Role label placed at the entity end (only rendered if `role` is non-empty).
- Attribute ↔ owner: line from oval edge to owner rectangle/diamond edge.
- Composite parent ↔ child: line from parent oval edge to child oval edge.

No routing avoidance. If the user wants a cleaner layout, they drag.

## Shared infrastructure

The following utilities currently live inside the schema script section. They are lifted to be shared with the ERD renderer (no functional change to schema mode):

- `mk(tag, attrs)`, `txt(x, y, s, attrs)` — SVG primitives.
- `escapeAttr` — HTML attribute escaping for the builder.
- `uid(prefix)` — id generator.
- The drag-to-pin pointer-event machinery on `#svg` — generalized so it dispatches to the active mode's drag handler (which knows which node types are draggable).
- `downloadPng` / `downloadPdf` / `svgToCanvas` — already mode-agnostic; just need the filename to depend on `state.mode`.

## Out-of-scope concerns explicitly addressed

- **PK / FK / Candidate key / Super key tags on attributes:** Not represented. Classical ER notation (the textbook style in the reference picture) shows keys only by underlining. PK/CK/Super are not visually distinguished in ER, and FK belongs to the relational/schema model. Users who want to express PK/FK relationships use Schema mode.
- **Composite key:** Already representable — just mark multiple attributes on the same entity as `kind: 'key'`. No special UI needed (matches the textbook).
- **Mixing modes in one diagram:** Not supported. The two modes are independent.

## Risks and trade-offs

- **Auto-layout for ER diagrams is harder than for tables**, because there are many more nodes (entities + every attribute oval + every relationship + every relationship attribute) and the graph is not a rigid grid. The picture in the reference image was hand-laid-out. Mitigation: a reasonable default fan layout + ubiquitous drag-to-pin lets the user reproduce textbook-style layouts in a minute or two. The "Reset Layout" button gives an escape hatch when pinning makes things worse.
- **Underline rendering in exported PNG/PDF:** SVG `text-decoration: underline` is not reliably honored when SVG is rasterized via `XMLSerializer` → `<img>` → `<canvas>` (which is how the current PNG/PDF export works — see `svgToCanvas` in `index.html`). To avoid that risk, key-attribute underlines are drawn as explicit `<line>` elements positioned under the text, not via `text-decoration`. Same approach as the dashed partial-key underline. This guarantees export fidelity.
- **Single-file growth:** `index.html` is already ~1000 lines and will roughly double. Acceptable for now — the project is intentionally a single-file static page. If it grows beyond ~2500 lines we revisit splitting into modules.

## Acceptance criteria

1. Opening the page shows Schema mode by default, identical to current behavior.
2. Clicking `ERD` switches the builder and SVG to ERD mode. Clicking `Schema` switches back. Switching back and forth preserves both diagrams.
3. In ERD mode, "Load Sample" loads the EMPLOYEE/DEPARTMENT/PROJECT/DEPENDENT diagram. Rendered output visually matches the reference picture: rectangles for entities, double rectangle for DEPENDENT, diamonds for relationships, double diamond for DEPENDENTS_OF, underlined key attributes (Ssn, DEPARTMENT.Name+Number, PROJECT.Name+Number), dashed-underline partial key (DEPENDENT.Name), composite Name on EMPLOYEE with Fname/Minit/Lname children, multivalued Locations (double oval), derived Number_of_employees (dashed oval), double lines for total participation, single lines for partial, correct cardinality labels (1/N/M) at the diamond ends, role labels (Supervisor/Supervisee) on the SUPERVISION self-relationship.
4. The builder panel lets the user add/edit/delete entities, attributes (including composite children), relationships, and participants. Edits update the SVG live (matching the schema-mode "edit feels instant" behavior).
5. Drag-to-pin works on entities, relationships, and attribute ovals.
6. Download PNG and Download PDF in ERD mode produce a file named `erd.png` / `erd.pdf` that visually matches what is on screen, including all underlines and dashed strokes.
7. Schema-mode behavior is unchanged (no regression in current functionality).
