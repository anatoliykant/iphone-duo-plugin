# Intake — getting the mockup out of Figma or Sketch

Goal: a table of screens with frame size, size class, structure facts and a rendered image, plus existing designer comments. Everything below is read-only.

## Figma (MCP tools)

Tool names below are those of the npm server `mcp-figma` registered under the server name `figma` (`claude mcp add figma -- npx -y mcp-figma mcp`); the `mcp__<server>__` prefix follows that name, so a differently named server exposes the same tools under a different prefix.

Tool names as exposed by the Figma MCP server: `mcp__figma__get_file`, `mcp__figma__get_file_nodes`, `mcp__figma__get_image`, `mcp__figma__get_image_fills`, `mcp__figma__get_comments`, `mcp__figma__post_comment` (write — §Comments only), `mcp__figma__get_file_components`, `mcp__figma__get_file_styles`, `mcp__figma__check_api_key`.

### URL → ids

`https://www.figma.com/design/<fileKey>/<name>?node-id=12-345&t=…` → `fileKey` = the path segment after `/design/` (or `/file/`), node id = `12-345` with the dash replaced by a colon → `12:345`. A URL without `node-id` means "the whole page".

### How the MCP returns data

`get_file` and `get_file_nodes` do **not** return JSON inline: they write the Figma REST response to a cache file (`~/.mcp-figma/cache/file_nodes_<fileKey>_<timestamp>.json`) and return its path. Read it with `jq` (or `grep`) — never load the whole file into context:

```bash
F=<path returned by the tool>
jq -r '"\(.name) | \(.lastModified)"' "$F"
jq -r '.nodes | to_entries[] | "\(.key)\t\(.value.document.type)\t\(.value.document.name)\t\(.value.document.absoluteBoundingBox.width)x\(.value.document.absoluteBoundingBox.height)\tchildren=\(.value.document.children|length)"' "$F"
jq -r '.nodes["<id>"].document.children[] | "\(.type)\t\(.name)\t\(.absoluteBoundingBox.width)x\(.absoluteBoundingBox.height)\tlayout=\(.layoutMode // "-")"' "$F"
jq -r '.. | objects | select(.type=="TEXT") | "\(.name)\t\(.style.fontSize)\t\(.style.fontWeight)\t\(.absoluteBoundingBox.width)"' "$F" | sort -u | head -40
```

Shape: `{ name, lastModified, nodes: { "<id>": { document: { id, name, type, absoluteBoundingBox, layoutMode, children: [...] } } } }` — the REST `GET /files/:key/nodes` payload.

### Steps

1. `check_api_key` once. Missing key → stop and ask the user to configure the Figma MCP token; do not guess from screenshots.
2. **Frames.** `get_file(fileKey, depth: 2)` → `document.children` (pages) → each page's `children` of type `FRAME` / `SECTION` are the screens. Record `name`, `id`, `absoluteBoundingBox.width/height` for **every page** — Duo mockups often sit on a separate page ("Duo", "Foldable", …) that the given node ids do not cover; list all frames whose width or height is ≈ 466 / 678 / 626 / 890 before concluding "no Duo frames" (D1). More than ~12 screens → show the list and ask which to review.
3. **Structure.** `get_file_nodes(fileKey, node_ids: [...])` per screen **without `depth`** — rows, pills, links and bar items sit 6–15 levels deep, `depth: 4` misses them; use `depth` only to enumerate a section's frames. Extract:
   - `absoluteBoundingBox` of the frame and of direct children → where bars, lists and controls sit (top / bottom / centre band);
   - `layoutMode` (`HORIZONTAL` / `VERTICAL`), `paddingLeft/Right/Top/Bottom`, `itemSpacing` → auto-layout vs pinned pixels;
   - `style.fontSize`, `fontWeight`, `lineHeightPx`, `textAutoResize` on `TEXT` nodes → type sizes, longest line width;
   - `fills[].color` (0–1 RGB) → contrast checks (convert to hex, compute WCAG ratio yourself — do not eyeball);
   - `componentId` / names such as "Tab Bar", "Toolbar", "Navigation Bar", "Sheet", "Button/Primary" → which chrome is system-like vs hand-drawn;
   - children whose `absoluteBoundingBox` spans the frame's horizontal centre ± 24 pt on a regular-width frame → fold-avoidance candidates (D9).
4. **Render.** `get_image(fileKey, ids: [...], format: "png", scale: 2)` → look at each screen (Read the image). Render **frames individually** — a whole section is downscaled silently (a 6 000-pt section comes back at ~4 000 px even at scale 2) and becomes unreadable. Renders catch what JSON hides: hierarchy, density, stretched forms, safe-area collisions.
5. **Comments.** `get_comments(fileKey)` returns the whole comment list **inline** (it can approach 1 MB; the harness spills oversized results to a tool-results file — `jq` that file, never read it whole). Root comments carry `client_meta.node_id`; replies carry only `parent_id` — join them. Match node ids against the **full-depth** descendant id set of the reviewed frames (collect ids with `jq '.. | objects | .id? // empty'` on the node JSON), otherwise every anchored comment looks unrelated. Do not repeat resolved points; reference open ones.
6. **Styles / components** (optional). `get_file_styles`, `get_file_components` → whether text styles map to Dynamic Type styles (Large Title / Title 1–3 / Headline / Body / Callout / Subhead / Footnote / Caption 1–2) or are ad-hoc sizes.

### Size-class mapping (widths in points at the frame's scale)

| Frame size (pt) | Treat as | Notes |
|---|---|---|
| 320–430 wide | compact — phone; a proxy for the **Duo outer display**, not a Duo mockup | the outer display is wider and shorter than a phone |
| ≈ 466 × 678 | compact — **Duo outer, portrait** (derived) | vertical bars on the hardware side |
| ≈ 678 × 466 | compact × compact — Duo outer, landscape (derived) | vertical bars |
| ≈ 626 × 890 | **regular × regular — Duo inner, portrait** (derived) | the only pose with **horizontal** bars; when folded (table pose) the hinge is horizontal at y ≈ 445 |
| ≈ 890 × 626 | **regular × regular — Duo inner, landscape / book pose** (derived) | vertical bars; when folded the hinge is **vertical at x ≈ 445** — the fold band is a vertical strip |
| ≈ 313 × 890 or ≈ 445 × 626, next to another app | compact — **Split View half** (derived) | asymmetric safe area on the divider side |
| 744–1032 wide | regular — iPad | not a Duo mockup |

Trust `absoluteBoundingBox` over frame names: files name 890 × 626 frames "Portrait", or call the app's own folded two-pane arrangement "Split View". Label every derived number "derived @3x, not Apple-stated" in the report. A file whose frames are all 320–430 wide — on every page — has **no Duo mockup** (D1).

## Sketch

No MCP. Ask for exports or make them:

```bash
# if Sketch is installed — exports every artboard of the document at @2x
/Applications/Sketch.app/Contents/MacOS/sketchtool export artboards "<file>.sketch" --formats=png --scales=2 --output="<dir>"
/Applications/Sketch.app/Contents/MacOS/sketchtool list artboards "<file>.sketch"     # names + sizes as JSON
```

Without `sketchtool`: the designer exports artboards (PNG @2x or PDF) and names them `<screen>@<width>x<height>.png`. Read each image. `list artboards` (or the file names) gives frame sizes for the size-class mapping; everything else is visual: relative sizes, presence of bars, centre-band controls, text density. State "visual-only review" in the report and downgrade measured-number checks (type size, tap target, contrast) to "cannot verify from export".

## Measuring from images

- Reference the frame width: on a 626-wide @2x export, 1 pt = 2 px; measure tap targets and gutters relative to that.
- Tap-target and type-size checks need the JSON (Figma) or a labelled artboard (Sketch); from a bare image report them as NOTE "estimate".
- Contrast: compute from the hex values in `fills`; formula in `hig-general-checklist.md` §Color.

## Output of intake (feed the report)

| Screen (name / node id) | Frame size → class | Nav pattern | Bars + items | Lists / grids (columns) | Longest text line | Centre-band controls (regular only) | Custom chrome | Existing comments |
|---|---|---|---|---|---|---|---|---|
