# Report template

Write it in full, then return it as the final message (and to the file path given in the prompt, if any). Keep node ids and artboard names exactly as Figma / Sketch show them so the designer can jump to them.

```markdown
# HIG design review — <file / page name> (<date>)

Source: <Figma URL or Sketch file>; frames reviewed: N (compact N, regular N, Split View N); mode: measured (Figma JSON) | visual-only (exports)
HIG state: Duo page change log <date from JSON>; general pages fetched <date>
Points are derived @3x (466 × 678 outer, 626 × 890 inner, ~313 Split View half) — not Apple-stated.

## Verdict
<Ready | Ready with notes | Not ready> — <one sentence>. Per screen: <name>: <verdict> …

## Findings
| # | Sev | Screen (node id / artboard) | Rule | What is wrong | Source | Fix (which system component / HIG pattern) |
|---|---|---|---|---|---|---|
| 1 | BLOCKER | Home — inner (12:345) | D14 | Primary CTA centred on the fold line | HIG Duo "Don't … content and controls spanning the fold" | Anchor the CTA to the trailing region or the bottom bar |
…

## Implementation constraints (for the developer, when "Ready with notes")
- …

## Passed checks (worth recording — the designer should keep them)
- <rule ids and one line each: e.g. D3 no per-pose layouts; D15 even grid columns; G-C3 dark set exists>

## Frames outside the requested set
- <Duo / other-page frames you found and included, with node ids and sizes — or "none">

## Not checkable from a mockup
- Dynamic Type scaling, VoiceOver order, motion, haptics, actual fold / Split View behavior, overflow at runtime — owned by the implementation review (`iphone-duo` skill, audit agent).

## Existing designer comments referenced
- <comment id / author role> — <how the finding relates>

## Figma comments
Not posted | Posted N comments on: <node ids> (prefix `[HIG review]`)
```

## Rules for filling it in

- One row per finding; collapse identical issues across screens into one row listing the screens.
- `Rule` = D-id from `duo-design-rules.md` or an area id from `hig-general-checklist.md` (e.g. `G-A2`); `Source` = HIG anchor / quoted sentence or talk id + timecode. No source → severity ≤ SHOULD and say "reviewer judgment".
- `Fix` names the system component or HIG pattern, not a redesign ("system tab bar → sidebar on regular width", "`NavigationSplitView` list + detail").
- Numbers you measured (tap targets, type sizes, contrast) come with the value and the threshold ("38 × 38 pt < 44 × 44").
- Visual-only reviews mark measured checks "cannot verify from export".

## Figma comment format (step 7 of the procedure — only after confirmation or an explicit request)

`mcp__figma__post_comment(fileKey, message, client_meta: { node_id: "<id>", node_offset: { x: 0, y: 0 } })` — one per BLOCKER / MUST-FIX finding:

```
[HIG review] D14 BLOCKER — primary CTA sits on the fold line of the inner display.
Apple HIG, Designing for iPhone Duo: "content and controls that span the fold become harder to see." Move it to the trailing region or the bottom bar.
```

Never post NOTE items, never post twice for the same finding (check `get_comments` first), never resolve or delete others' comments.
