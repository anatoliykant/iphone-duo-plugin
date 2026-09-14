# General HIG checklist — iOS / iPadOS, fetched live

The HIG pages are large (70–280 KB each) and change; nothing below quotes their text. Each area lists **what to check**, the **page and section anchors** to fetch, and the well-known thresholds to confirm against the live sentence before citing. If the live page disagrees with a threshold here, the page wins.

## How to fetch (no JavaScript needed)

The HTML pages are a JavaScript app; their JSON twins carry the content:

```bash
P=https://developer.apple.com/tutorials/data/design/human-interface-guidelines
curl -s "$P/typography.json" | grep -oE '"anchor":"[^"]+"' | awk '!s[$0]++' | head -40          # section anchors
curl -s "$P/typography.json" | grep -oE '"text":"[^"]{20,255}"' | grep -iE 'points|legib|Dynamic Type' | head   # quick look (BSD grep caps repetition at 255)
# Full sentences: paragraphs are split into inline fragments at every link — flatten them with jq before quoting
curl -s "$P/accessibility.json" | jq -r '.. | objects | select(.type? == "paragraph") | [.inlineContent[]? | .text? // .title? // ""] | join("")' | grep -iE 'control size|contrast' | head
```

Pages verified 2026-09-14 (`http=200`): `designing-for-ios`, `layout`, `typography`, `color`, `dark-mode`, `accessibility`, `materials`, `toolbars`, `tab-bars`, `sheets`, `buttons`, `lists-and-tables`, `designing-for-iphone-duo`. **404**: `liquid-glass` (Liquid Glass is inside `materials`), `navigation-bars` (navigation bars are covered by `toolbars` → anchors `Navigation`, `Titles`). Quote the sentence, not the page: the report needs `page §anchor: "…"`.

## Areas and checks

Ids `G-<area><n>` are what the report's Rule column uses.

### G-L · Layout — `layout.json` (anchors: Visual-hierarchy, Adaptability, Size-classes, Guides-and-safe-areas, Grids, Platform-considerations)

- G-L1 Content and controls stay inside the safe area; only backgrounds extend under the status bar, Dynamic Island, home indicator and (on Duo) cameras. Fail: text or buttons in those regions.
- G-L2 The layout adapts to size classes; a compact and a regular arrangement exist for screens that gain from width (Adaptability, Size-classes). Fail: regular width = compact stretched.
- G-L3 Margins and guides respected; content aligned to a grid; no elements flush to the display edge (Guides-and-safe-areas, Grids).
- G-L4 Landscape / multitasking considered where the app supports it.
- Thresholds (live Accessibility → Mobility table, 2026-09-14): **default control size 44 × 44 pt, minimum 28 × 28 pt**; Buttons: "hit region of at least 44 × 44 pt". Severity: below 28 pt → MUST-FIX; 28–44 pt → SHOULD.

### G-T · Typography — `typography.json` (Ensuring-legibility, Conveying-hierarchy, Using-system-fonts, Using-custom-fonts, Supporting-Dynamic-Type, Specifications → iOS-iPadOS-Dynamic-Type-sizes)

- G-T1 Text styles map to system styles (Large Title, Title 1–3, Headline, Body, Callout, Subhead, Footnote, Caption 1–2) so Dynamic Type works; ad-hoc sizes are flagged.
- G-T2 Legibility: confirm live the minimum size sentence (historically **11 pt** minimum, body **17 pt** default); fail when body copy or labels are below.
- G-T3 Hierarchy by weight/size, not by many faces; custom fonts only when the brand requires and still Dynamic-Type-aware.
- G-T4 Longest text line has a bound (a design choice, Apple gives no Duo number); flag edge-to-edge paragraphs on regular width.

### G-C · Color and appearance — `color.json`, `dark-mode.json`

- G-C1 Contrast — live Accessibility "Color and effects" table (2026-09-14): text up to 17 pt **4.5:1**, 18 pt and larger **3:1**, **bold of any size 3:1**; Dark Mode page: "no lower than 4.5:1". Compute from the fills, never eyeball; blend translucent fills over their backdrop first:

  ```bash
  python3 - <<'EOF'
  def lin(c): c/=255; return c/12.92 if c<=0.03928 else ((c+0.055)/1.055)**2.4
  def hexrgb(h): h=h.lstrip('#'); return tuple(int(h[i:i+2],16) for i in (0,2,4))
  def blend(fg,a,bg): return tuple(round(a*f+(1-a)*b) for f,b in zip(fg,bg))
  def lum(rgb): r,g,b=map(lin,rgb); return 0.2126*r+0.7152*g+0.0722*b
  def ratio(a,b): la,lb=sorted((lum(a),lum(b)),reverse=True); return (la+0.05)/(lb+0.05)
  text, bg = hexrgb('8C8C9A'), hexrgb('FFFFFF')            # e.g. subtitle on white → 3.32:1
  pill = blend(hexrgb('858595'), 0.20, bg)                  # a 20 % fill over white
  print(round(ratio(text,bg),2), round(ratio(hexrgb('0F5CF2'),pill),2))
  EOF
  ```
- G-C2 Color is not the only carrier of meaning (state, selection, errors).
- G-C3 Dark Mode frames exist or the design declares system colors / semantic colors; flag hard-coded white surfaces.

### G-A · Accessibility — `accessibility.json` (Vision, Hearing, Mobility, Speech, Cognitive)

- G-A1 Control sizes (Mobility table): default 44 × 44 pt, minimum 28 × 28 pt — below 28 MUST-FIX, 28–44 SHOULD; measure from the JSON, not the render, and decide whether the row or the pill is the control.
- G-A2 Every icon-only control has a label (VoiceOver) — in a mockup: an annotation or a component property; flag unlabeled icon buttons.
- G-A3 Motion / autoplay has a non-motion path (Vision → Motion); flag designs that depend on animation for meaning.
- G-A4 Text scales — no fixed-height containers around text.

### G-N · Navigation, toolbars, tab bars — `toolbars.json` (Best-practices, Titles, Navigation, Actions, Item-groupings, Platform-considerations → iOS), `tab-bars.json` (Best-practices, iOS)

- G-N1 System navigation bar / toolbar / tab bar components, not hand-drawn chrome (on iOS 26 these are Liquid Glass bars — see G-M).
- G-N2 Tab bar carries top-level sections only; confirm the live sentence on the tab count (historically **up to five** on iPhone); badges for status; no actions in tabs.
- G-N3 Toolbar: title semantics (Titles), Back/Close placement (Navigation), actions grouped (Item-groupings), primary action prominent, secondary in overflow; every item has a symbol **and** a title.
- G-N4 Search placement follows the platform pattern (iOS 26: search in the tab bar / bottom) — confirm live.
- G-N5 iPhone Duo bars: see `duo-design-rules.md` D8–D13 (vertical bars on the outer display).

### G-S · Sheets, modals, alerts — `sheets.json` (Anatomy, Best-practices, iOS-iPadOS)

- G-S1 Sheets for short, focused tasks; detents where partial height helps; grabber visible when resizable.
- G-S2 A clear way out (Close / Cancel) and a prominent primary action; no destructive action as the default.
- G-S3 Alerts: title + optional message, two or three actions, no stacked marketing copy.

### G-B · Buttons, lists — `buttons.json`, `lists-and-tables.json`

- G-B1 Button roles distinguishable (prominent / regular / destructive) without relying on color alone; consistent sizes.
- G-B2 Lists use system list styles; disclosure indicators for navigation rows; swipe actions not the only path.

### G-M · iOS 26 design system (Liquid Glass) — `materials.json`, plus `toolbars` / `tab-bars` iOS sections

- G-M1 Bars and controls that sit over content use the system material (Liquid Glass) — flag opaque custom bars and "glass" imitations drawn as gradients.
- G-M2 Content scrolls under bars; the mockup shows the bar over content, not a solid band cutting the scroll view.
- G-M3 Tab bar and toolbar behaviors of iOS 26 (minimising on scroll, grouped floating items) are not overridden by custom chrome — confirm the live iOS section.
- Newer than the model's training data may be partial: quote the page, never memory.

### G-I · Designing for iOS — `designing-for-ios.json` (Best-practices)

- G-I1 One-handed reach: primary actions in the lower half or in bars, not the top corners of a tall display.
- G-I2 Platform conventions over web/Android patterns (bottom sheets vs system sheets, hamburger menus vs tab bars).

## Order of a general pass

1. Structure first (G-N, G-L2): is the screen built from system containers that will adapt?
2. Safe areas and reach (G-L1, G-I1).
3. Type and color (G-T, G-C) — measured from the JSON.
4. Accessibility (G-A).
5. Components (G-S, G-B, G-M).
6. Then the Duo pass (`duo-design-rules.md`).

## What this checklist does not do

- It does not enforce a project's own tokens, spacing scale or icon set — that is the project's design-system process.
- It does not judge visual taste, branding or copy.
- It does not claim runtime behavior (Dynamic Type scaling, VoiceOver order, animations); those go to "Not checkable from a mockup".
