# iPhone Duo plugin for Claude Code and Codex

[![Agent Skills](https://skills.sh/b/anatoliykant/iphone-duo-plugin)](https://skills.sh/anatoliykant/iphone-duo-plugin)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Adapt, audit and design-review iOS apps for **iPhone Duo** — Apple's foldable iPhone (announced
2026-09-09, shipped 2026-10-23 on iOS 27.1). The Duo APIs are newer than any current model's training data, so an
agent asked about them invents plausible symbol names. This plugin replaces that guesswork with
references that carry a provenance tag on every symbol.

Four components:

| Component | Kind | What it does |
|---|---|---|
| `iphone-duo` | skill | Adapting Swift apps (UIKit + SwiftUI): size classes, vertical bars, reserved regions, `ArrangementView`, hinge, multiple scenes, dual front cameras, Split View, adaptive layout, state continuity. 8 reference files + Apple's 13-step migration order. |
| Readiness audit | shared workflow + Claude agent | Runs a 26-category grep checklist and returns a severity-ranked report with `file:line` and a fix pointer per finding. Claude Code uses `iphone-duo-audit`; Codex and skills-only installs run the same workflow through `iphone-duo`. Never edits source code. |
| `hig-design-review` | skill | Reviews Figma or Sketch mockups against the Human Interface Guidelines *before* implementation — general iOS rules plus the Duo rules D1–D32, with live HIG citations and a Ready / Not ready verdict. |
| `foldsim` | skill + bundled CLI | Puts a simulator into every pose from the command line: folds, opens and rotates an iPhone Duo (closed, tent, book, open, table), rotates an iPhone or iPad, taps and swipes on any display — the Duo's inner one too — captures each display, and tours all poses with screenshots and state. Says what to check in each pose. |

## Requirements

- **Claude Code or Codex** for a native plugin install (options 2 and 3). Codex packaging and skill
  discovery were checked with **Codex CLI 0.157.1**. The skills also work through the Agent Skills
  CLI in Claude Code, Cursor, Codex and other supported hosts — see option 1.
- **macOS with Xcode Command Line Tools** for the toolchain gate (`xcodebuild -version`,
  `xcrun --sdk iphoneos --show-sdk-version`). The grep audit itself runs anywhere; the toolchain gate
  is what decides whether iOS 27.1 APIs may be written yet. **Xcode 27.2 RC or later**, with its iOS 27.2
  simulator runtimes, is required for Duo work: it carries the Duo APIs, the iPhone Duo simulator and
  Apple's App Resizability agent skill, and fixes simulator bugs of Xcode 27.1, which the plugin no
  longer supports. Without it the skills do the resizability work and defer the Duo-only APIs.
- **For `foldsim`: Apple silicon and Xcode 27.2 RC or later** with its simulator runtimes. Its first run compiles
  two small Swift programs with that Xcode and caches them in `~/Library/Caches/foldsim`. The hinge, the Duo's
  rotation and touches use private simulator interfaces that an Xcode update can change; `foldsim doctor`
  checks them, and Device Hub stays the manual fallback.
- **`jq`** — reading Figma JSON and SDK dumps without loading them into context.
- **`python3`** — a few reference snippets use it for plist and geometry math.
- **Network access** — the design review fetches HIG pages live (their JSON twins) rather than
  quoting them from memory.
- **Figma MCP server** for the Figma intake path only:
  ```bash
  # Claude Code
  claude mcp add figma -- npx -y mcp-figma mcp
  # Codex
  codex mcp add figma -- npx -y mcp-figma mcp
  ```
  Set a Figma personal access token as that server requires. The tool names in the references
  (`mcp__figma__get_file`, …) follow the **server name** you register — if you register it under a
  different name, the `mcp__<server>__` prefix changes with it. Sketch / PNG / PDF exports need no MCP.

## Install

### 1. Skills only, via the Agent Skills CLI (Claude Code, Cursor, Codex, …)

```bash
npx skills add anatoliykant/iphone-duo-plugin
```

This installs the three skills, including the complete read-only audit workflow and the foldsim CLI; `agents/` is ignored
by that CLI. Select Codex when prompted to install for Codex. To get the Claude audit agent as well, copy
`agents/iphone-duo-audit.md` into `~/.claude/agents/` **or** install the plugin (option 2) — not
both: a user-scope agent overrides the plugin one, and you end up maintaining two copies.

### 2. As a Claude Code plugin (skills + agent, pinned versions)

```bash
claude plugin marketplace add anatoliykant/iphone-duo-plugin
claude plugin install iphone-duo@anatoliykant-plugins
```

Then `/reload-plugins` if Claude Code asks for it. Behind an SSH-less setup use the explicit URL:

```bash
claude plugin marketplace add https://github.com/anatoliykant/iphone-duo-plugin.git
# or: CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1 claude plugin marketplace add anatoliykant/iphone-duo-plugin
```

Installed copies are pinned to the `version` in `.claude-plugin/plugin.json`, so a new release is a
version bump plus a tag — run `claude plugin update iphone-duo@anatoliykant-plugins` to move to it.
`CHANGELOG.md` lists what changed in each one.

### 3. As a Codex plugin (skills + shared audit workflow)

```bash
codex plugin marketplace add anatoliykant/iphone-duo-plugin
codex plugin add iphone-duo@anatoliykant-plugins
```

Start a new Codex session after installation. For a local checkout, including changes that have
not been published yet, replace the first command with:

```bash
codex plugin marketplace add /absolute/path/to/iphone-duo-plugin
codex plugin add iphone-duo@anatoliykant-plugins
```

The portable root `plugin.json` declares the Agent Plugins format; Codex discovers all three skills
under `skills/`. `.agents/plugins/marketplace.json` points to this repository's root. The Claude
manifest stays in `.claude-plugin/`, and both manifests carry the same version.

To refresh a Git-backed marketplace, run `codex plugin marketplace upgrade anatoliykant-plugins`,
then `codex plugin add iphone-duo@anatoliykant-plugins` and start a new session. A local marketplace
reads from its checkout; keep that directory available.
Use `codex plugin list --marketplace anatoliykant-plugins` to inspect the plugin.
Clients without `codex plugin add` can use the plugin
directory UI described in the [OpenAI plugin documentation](https://developers.openai.com/plugins/build/plugins)
or the skills-only install above.

### 4. From the Claude community marketplace

The public `claude-community` catalog did not list this plugin when checked on **2026-09-30**.
This does not indicate whether a submission was received; publication is managed by Anthropic.
Once the entry is published:

```
/plugin marketplace add anthropics/claude-plugins-community
/plugin install iphone-duo@claude-community
```

### 5. By hand

Copy `skills/iphone-duo`, `skills/hig-design-review` and `skills/foldsim` into `~/.claude/skills/` (or a project's
`.claude/skills/`), and `agents/iphone-duo-audit.md` into `~/.claude/agents/`.

For Codex skills-only installation, copy the three **whole skill directories**, including their
`references/` and `scripts/` (keep `scripts/foldsim` executable), into `~/.agents/skills/` (user scope) or `.agents/skills/` in the app project
(repo scope). Start a new session. No Claude agent file or Codex custom-role configuration is needed.

## Usage

The skills load on their own when a request matches. Typical triggers: *"is this app ready for
iPhone Duo"*, *"what breaks on the foldable"*, *"add vertical toolbar support"*, *"reserved regions"*,
*"review this Figma against the HIG"*, *"check this screen in every pose of the Duo simulator"*.

Invoke them explicitly in Claude Code with their scoped names:

```
/iphone-duo:iphone-duo           # adaptation work
/iphone-duo:hig-design-review    # mockup review
/iphone-duo:foldsim              # poses, rotation and touches on a simulator
```

In Codex, select the installed skill from the `$` picker, or use its full plugin name:

```text
$iphone-duo:iphone-duo Audit this repository for iPhone Duo readiness. Do not change source files.
$iphone-duo:hig-design-review Review this Figma mockup against the HIG: <Figma URL>
$iphone-duo:foldsim Tour the booted iPhone Duo simulator and check the settings screen in every pose.
```

Skills-only installs use `$iphone-duo`, `$hig-design-review` and `$foldsim` instead. All three accept
`--help` and `--version` as standalone requests, for example `$iphone-duo:iphone-duo --version`.

### Readiness audit

Ask for an audit in plain language. In Codex the `iphone-duo` skill runs the shared
`references/audit-workflow.md`; it also works when subagents are unavailable. In Claude Code the
skill delegates to the audit agent when installed, or runs the same workflow directly. You can
also call the Claude agent explicitly:

```
Agent(subagent_type: "iphone-duo:iphone-duo-audit",
      prompt: "Repo root: /path/to/app. Scratch dir: /tmp/duo-audit. Write the report to /tmp/duo-audit/report.md. Skip Pods and the widget extension.")
```

The report comes back in a fixed shape:

```markdown
# iPhone Duo readiness audit — <app> (<git rev>, <date>)

## Summary
<launches? resizes? adapts?> · Toolchain: <SDK> · Swift files scanned: N (production N, tests N)

## Findings
| # | Severity | Category | Sites | Example | Fix |
|---|---|---|---|---|---|
```

Severities run BLOCKER (will not launch on the iOS 27 SDK) → HIGH → MEDIUM → LOW → INFO, and every
finding points at the reference section that fixes it. Audits leave the source code unchanged;
only scratch output and a report you explicitly request may be written. These are workflow
instructions; filesystem enforcement depends on the host's permissions and sandbox configuration.

### Design review

Give it a Figma URL (`…/design/<fileKey>/<name>?node-id=12-345`), a file key, or Sketch/PNG/PDF
exports. It returns findings with HIG citations, a severity per finding, and a verdict. It posts
comments on Figma nodes only when you explicitly ask, and never edits a file.

## What's inside

```
plugin.json                  portable Codex / Agent Plugins manifest
.agents/plugins/             Codex marketplace
.claude-plugin/              Claude Code manifest + marketplace
skills/iphone-duo/            SKILL.md + 8 references (includes the shared audit workflow)
skills/hig-design-review/     SKILL.md + 4 references
skills/foldsim/               SKILL.md + 1 reference + scripts/ (the foldsim CLI, Swift sources)
tests/foldsim-probe/          probe app and the simulator checks behind foldsim (development only)
agents/iphone-duo-audit.md    Claude Code adapter for the shared audit workflow
scripts/validate-plugin.py   package and version checks used by CI
```

| Reference | Read when |
|---|---|
| `iphone-duo/references/device-and-platform.md` | Display and size-class facts, SDK tiers, Split View, `UIRequiresFullScreen`, StandBy and widgets, timeline, App Store badge and April 2027 requirements, the unverified list |
| `iphone-duo/references/audit-workflow.md` | Shared read-only audit procedure, scope, scratch output, classification and report delivery |
| `iphone-duo/references/audit-checklist.md` | Running or interpreting the audit: 26 grep categories, severities, report template, Apple's 13 migration steps |
| `iphone-duo/references/layout-size-classes-safe-area.md` | Size classes, replacing `UIScreen.main`, width caches, state continuity, scene lifecycle, windows, safe area, the adaptive toolbox |
| `iphone-duo/references/bars-and-toolbars.md` | Vertical bars: opt-in, order, axis behavior, badges, edge detection, compression, overflow, priority, opt-out |
| `iphone-duo/references/arrangements-and-reserved-regions.md` | Reserved regions, displacement, `ArrangementView` / `UIArrangementViewController`, split vs overlay, anti-patterns |
| `iphone-duo/references/hinge-scenes-camera.md` | `onHingeChange`, multiple scenes, scene accessories, virtual front camera, direction and rotation coordinators, motion and heading per display |
| `iphone-duo/references/testing-and-sources.md` | Toolchain gate, Device Hub poses, SDK symbol verification, freshness checks, source URLs |
| `hig-design-review/references/intake-figma-sketch.md` | Pulling frames, sizes, renders and comments out of Figma via MCP; Sketch exports; size-class mapping |
| `hig-design-review/references/duo-design-rules.md` | The Duo design checklist D1–D32 with a source per rule |
| `hig-design-review/references/hig-general-checklist.md` | General iOS checks per area + how to fetch and cite the live HIG JSON pages |
| `hig-design-review/references/report-template.md` | Report shape, severity rows, verdict block, Figma comment format |
| `foldsim/references/pose-checks.md` | What to look for in each pose: both displays, the hinge gate, the orientation mask, render-test windows |

## Status and freshness

Every new symbol in the references carries a provenance tag — where the name came from, and whether
it has been confirmed against a real SDK:

| Tag | Meaning |
|---|---|
| **VERBATIM** | Copied from an Apple Code section of a tech talk, or from a developer article — spell it exactly like this |
| **PROSE** | Named in Apple's text but never written as code — the references say so where one is still unconfirmed |
| **CAPTION** | Seen only in auto-generated captions — never use; the references list the known mis-spellings |
| **EXISTING(iOS xx)** | A pre-Duo API that already ships — gate it at its own availability, not at 27.1 |
| **SDK(27.1)** | Found in the released iOS 27.1 SDK with an availability annotation |

Research date **2026-09-10**; first SDK check 2026-09-21 against **Xcode 27.1 beta 1** (27A9269);
**re-verified 2026-10-28** against the released **Xcode 27.1** (27A9275) and **Xcode 27.2 RC** (27B48).
Every Duo declaration is unchanged from beta 1, and the documentation pages no longer say "beta". One
capability the HIG describes — collapsing an overlay arrangement's secondary view — still has no API,
and the references say so instead of guessing a name.

Also folded in on that date: Apple's developer article
"[Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)",
the camera articles for AVKit and AVFoundation, the September 2026 `documentation/updates` sections,
the Xcode 27.1 beta release notes, and the first two iPhone Duo Group Labs (Meet with Apple 285 and
286). The third, 287 (2026-10-13), followed on 2026-10-20, together with the bar-minimization API it
pointed to, typechecked against the same SDK. On 2026-10-28: the fourth lab (288), Apple's DTS summary
of the labs on the forums, the three 2026-09-23 forum Q&As, the "Three steps to make your app shine on
iPhone Duo" page, the Xcode 27.1 / 27.2 RC and iOS 27.2 release notes, TN3192, and the App Store news
of 2026-10-05 (the "optimized for iPhone Duo" badge and the April 2027 screenshot requirement). On 2026-10-29
Xcode 27.2 RC became the required toolchain, and three sarunw.com articles were folded in after every claim
was re-measured on the Duo simulator. The re-measurement corrected the inner display to 669 × 951 pt. On 2026-10-30, findings from two DMV sessions fixing
Duo QA bugs were re-measured and folded in, and the foldsim skill was added with its own probe-app checks. Labs are
transcribed from Apple's own captions and are cited for guidance, never for API spellings.

`skills/iphone-duo/references/testing-and-sources.md` §Freshness lists what is still open and the
machine-checkable signals: new labs, the Xcode 27.2 release, silent HIG or article edits.

The plugin has no bundled MCP servers or hooks. Its one executable is the foldsim CLI: a shell launcher
that compiles the Swift sources next to it with your Xcode on first use, runs only `xcrun simctl` and
`xcrun devicectl` on the Mac, and runs its helper inside the simulator you name. It never boots, shuts down
or erases a simulator. Everything else runs as instructions with your configured tools and permissions. Design review fetches live sources and can use your
Figma MCP connection; audits write scratch output and an explicitly requested report.

## Development checks

```bash
python3 scripts/validate-plugin.py
claude plugin validate .
git diff --check
skills/foldsim/scripts/foldsim selftest   # foldsim's geometry, no simulator needed
tests/foldsim-probe/run.sh                # foldsim against a probe app on throwaway simulators
```

The validator checks both manifests and marketplaces, skill version answers, bundled references,
and release tags, plus that the foldsim launcher is executable and its sources never shut down or
erase a simulator. Run it before publishing a version. See [CHANGELOG.md](CHANGELOG.md) for changes.

## Release destinations

Update both plugin manifests and both skill version literals together. Push `main` and a matching
`v<version>` tag, wait for CI, then create the GitHub Release with notes from the changelog.

| Destination | How the update reaches users |
|---|---|
| GitHub Releases | Publish the release for the matching version tag; source archives are generated by GitHub. |
| `anatoliykant-plugins` for Claude Code and Codex | Both catalogs live in this repository and update with `main`; no separate marketplace upload. |
| Agent Skills CLI / skills.sh | The CLI reads this GitHub repository. Verify with `npx skills add anatoliykant/iphone-duo-plugin --list`; the skills.sh website indexes it separately and may lag. |
| Anthropic community | Submission/publication is managed through Anthropic's form, not by pushing to its catalog mirror. Verify the public entry before claiming a community release. |

## Credits

- Apple Inc. for the iPhone Duo tech talks (111461–111466), WWDC26 session 278 and the Human
  Interface Guidelines — quoted material stays © Apple, see [`NOTICE.md`](NOTICE.md).
- [FloWritesCode/fwc-swiftui-skills](https://github.com/FloWritesCode/fwc-swiftui-skills) (MIT) for
  the tiered-migration and state-continuity framing.
- [artemnovichkov/hinge](https://github.com/artemnovichkov/hinge) (MIT), which first documented Device Hub's
  hinge event and reading the angle from CoreMotion, and [skarol/duoctl](https://github.com/skarol/duoctl)
  (MIT), which documented touching the inner display through a virtual touchscreen. foldsim is written
  from those descriptions and Apple's open-source headers; no code was taken from either project.

## License

MIT — see [`LICENSE`](LICENSE). Apple material quoted in the references is excluded; see
[`NOTICE.md`](NOTICE.md).
