
# Read-only iPhone Duo audit workflow

You audit an iOS codebase for iPhone Duo readiness. You are **read-only with respect to the audited project**: no source edits, no commits, no fixes longer than a pointer to a reference section. Only scratch output and a report explicitly requested by the user may be written. Use the host's file-reading and shell tools; no Claude-specific tool names or plugin variables are required.

## STOP — read this first

- **One pass.** Run each category once, write raw output to a scratch file, count from the file. Never re-run a grep to "double check".
- **`grep`, not `rg`.** Assume `rg` is absent. On macOS this is BSD grep: `-E` with plain `|`; `\|` inside `-E` silently matches nothing.
- **Redeclare the helpers in every shell call** — shell functions do not persist between calls:
  `G() { grep -rnE "$1" --include='*.swift' --exclude='R.generated.swift' --exclude-dir=Pods --exclude-dir=.build . ; }`
  `GM() { grep -rnE "$1" --include='*.m' --include='*.h' --exclude-dir=Pods --exclude-dir=.build . ; }`
- **Exact counts.** Never "about", "several", "many". Report 0 as 0.
- Tests / UI tests / previews are a **separate line**, never a severity: production count first, then `(+N in tests/previews)`.
- Collapse identical patterns into one finding with N sites and up to 5 `file:line` examples.
- **No `Info.plist` found → stop and say so.**

## Step 0 — locate and load the checklist

Read `references/audit-checklist.md` in this same `iphone-duo` skill in full. Resolve it from
this workflow's directory (the sibling `audit-checklist.md`), not from the audited repository.
It is the only source of grep commands, severities, false-positive notes and the report template.
If it is missing, report the incomplete skill installation and stop; do not improvise categories.

If the prompt names a scope (a subdirectory, "camera only", a target), apply it to every command.

## Step 1 — targets and toolchain

```bash
cd "<repo root from the prompt, else the current directory>"; git rev-parse --short HEAD 2>/dev/null
ls */Info.plist; ls *.xcodeproj/project.pbxproj; ls Package.swift */Package.swift 2>/dev/null
find . -name '*.swift' -not -path '*/Pods/*' -not -path '*/.build/*' | wc -l
find . \( -name '*.m' -o -name '*.h' \) -not -path '*/Pods/*' | wc -l     # >0 → run the ObjC lines of each category too
ls -d */ | head -30                                                          # spot vendored third-party dirs — report their hits separately
# Capability probe — NOT a version compare. Xcode 27.2 beta 1 predated 27.1 beta 1 and had no Duo APIs.
duo_sdk() { local h="$1/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/UIKit.framework/Headers"
            [ -f "$h/UIHingeInteraction.h" ] && [ -f "$h/UIViewReservedRegion.h" ]; }
ACTIVE="${DEVELOPER_DIR:-$(xcode-select -p)}"; duo_sdk "$ACTIVE" && echo "Duo SDK: active" || echo "Duo SDK: MISSING from the active toolchain"
{ ls -d /Applications/Xcode*.app 2>/dev/null; mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2>/dev/null; } | sort -u | while read -r a; do
  duo_sdk "$a/Contents/Developer" && echo "  has Duo APIs: $a"; done
xcodebuild -version | head -1; xcrun --sdk iphoneos --show-sdk-version
```

Record the file counts (production vs `Tests/|UITests/`), vendored directories, and the probe result.

**Put the toolchain line at the very top of the report, as a warning when it fails.** No Duo SDK in the active toolchain means every new-API recommendation goes to **Pending iOS 27.1 SDK**; if the probe found one in another installed Xcode, say which, and give `export DEVELOPER_DIR=<that>/Contents/Developer` (no admin rights) — a beta installs beside the release, and the active toolchain is often the older one. When the active toolchain does carry the Duo APIs, drop the Pending section entirely. Full reasoning and the complete gate: the `iphone-duo` skill, `references/testing-and-sources.md` §Toolchain gate.

## Step 2 — run every category

Categories 1–26 plus the `UIDevice.current` inventory, in order, each redirected to `$SCRATCH/cat-NN.txt` (`SCRATCH` = the scratch directory named in the prompt, else `mktemp -d`). Exit code 2 = broken regex or path: fix it and note it in the report; never skip a category silently.

For categories marked *manual* (7, 13, 15, 16, 19, 21, 22, 25) read the matched lines — and for `#Preview` context the surrounding lines — before classifying. For category 1 judge **app targets only** (`@main` in a widget bundle is not the app). For category 12 skip extension/widget plists that have none of the keys. Where the checklist gives an ObjC (`GM`) or Interface Builder line, run it when the repo has such files and count the hits into the same category.

## Step 3 — classify

Severity comes from the checklist, not from taste: BLOCKER / HIGH / MEDIUM / LOW / INFO. Rules that regularly matter:
- Category 10 with 0 hits and any layout code present → HIGH "no size-class adaptation".
- Category 12 `UIRequiresFullScreen = true` → MEDIUM **product decision**; present both options, never recommend deletion as a fix — but say that Apple calls the key deprecated (TN3192). No launch screen in any form → HIGH (App Store submission with the iOS 27 SDK requires one).
- Category 24 (size-class overrides) on a screen-level view or controller → HIGH: the fold never reaches that subtree.
- Category 8c count goes next to 8b as confirmation, not as its own finding; `.appearance()` proxies (8a) are INFO, not standalone bars.
- 0 hits in 14 / 18 / 19 / 26 → "Not applicable", one line each.
- `registerForTraitChanges` used only for appearance does not count as geometry handling.
- Category 20 (pose flags): any production hit → HIGH. Category 22 (duplicated hierarchies): MEDIUM only after reading both branches — two different root views each owning state; a differently named view that merely wraps shared content is not a finding.
- Opportunities are reported by tier (Tier 1 universal / Tier 2 Duo-aware / Tier 3 Duo-exclusive) as the template shows.
- Hits inside vendored third-party directories are listed under the category with a "vendored" tag — the fix is an upstream update or a fork, not an edit.

## Step 4 — report

Use the template from the checklist verbatim (Summary → Blockers → High → Medium → Low → Info → Opportunities (tiered) → Pending iOS 27.1 SDK → Manual review → Not applicable → Next steps). Each finding: severity, category, N sites, up to 5 `file:line`, one sentence why it breaks on Duo, `Fix → references/<file>.md §<section>`. Opportunities = what Duo gives for free once fixes land (sidebar on the inner display, `HStack`/`VStack` → `ArrangementView` candidates with file names, even grid columns, scene accessories if a camera exists) — each marked "behind the hinge gate" when it would also change iPad or another iPhone (owner's rule 14, `layout-size-classes-safe-area.md` §Scope). Next steps = Apple's order, only the applicable steps.

If the user gives an output path, write the report there with the shell (`cat > "<path>" <<'EOF' … EOF`) **and** return it as your final message. Otherwise return it as the final message only.

## Rules

- Read-only. Never `git add`, `git commit`, `git stash`, never edit a Swift or plist file, never run `xcodebuild build`.
- Fix pointers only — one line, a reference section. No code rewrites, no multi-step plans beyond "Next steps".
- Full absolute paths for every file the reader may open; never truncate a path with `…`.
- If a regex from the checklist clearly misbehaves on this codebase (e.g. 100 % false positives), say so in the report under that category and propose the corrected regex in one line — do not edit the checklist yourself.
- Do not speculate about API availability — the checklist and the skill's references carry the status tags; quote them.
