# iPhone Duo plugin for Claude Code

[![Agent Skills](https://skills.sh/b/anatoliykant/iphone-duo-plugin)](https://skills.sh/anatoliykant/iphone-duo-plugin)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Adapt, audit and design-review iOS apps for **iPhone Duo** — Apple's foldable iPhone (announced
2026-09-09, ships on iOS 27.1). The Duo APIs are newer than any current model's training data, so an
agent asked about them invents plausible symbol names. This plugin replaces that guesswork with
references that carry a provenance tag on every symbol.

Three components:

| Component | Kind | What it does |
|---|---|---|
| `iphone-duo` | skill | Adapting Swift apps (UIKit + SwiftUI): size classes, vertical bars, reserved regions, `ArrangementView`, hinge, multiple scenes, dual front cameras, Split View, adaptive layout, state continuity. 7 reference files + Apple's 13-step migration order. |
| `iphone-duo-audit` | agent | Read-only readiness audit: runs a 23-category grep checklist over a codebase and returns a severity-ranked report with `file:line` and a fix pointer per finding. Never edits code. |
| `hig-design-review` | skill | Reviews Figma or Sketch mockups against the Human Interface Guidelines *before* implementation — general iOS rules plus the Duo rules D1–D29, with live HIG citations and a Ready / Not ready verdict. |

## Requirements

- **Claude Code** for the plugin install (option 2); the skills alone also work in Claude Code,
  Cursor, Codex and other Agent Skills hosts — see Install option 1.
- **macOS with Xcode Command Line Tools** for the toolchain gate (`xcodebuild -version`,
  `xcrun --sdk iphoneos --show-sdk-version`). The grep audit itself runs anywhere; the toolchain gate
  is what decides whether iOS 27.1 APIs may be written yet. **Xcode 27.1** (beta since 2026-09-18) is
  what ships the iOS 27.1 SDK, the iPhone Duo simulator and Apple's App Resizability agent skill;
  without it the skills do the resizability work and defer the Duo-only APIs.
- **`jq`** — reading Figma JSON and SDK dumps without loading them into context.
- **`python3`** — a few reference snippets use it for plist and geometry math.
- **Network access** — the design review fetches HIG pages live (their JSON twins) rather than
  quoting them from memory.
- **Figma MCP server** for the Figma intake path only:
  ```bash
  claude mcp add figma -- npx -y mcp-figma mcp
  ```
  Set a Figma personal access token as that server requires. The tool names in the references
  (`mcp__figma__get_file`, …) follow the **server name** you register — if you register it under a
  different name, the `mcp__<server>__` prefix changes with it. Sketch / PNG / PDF exports need no MCP.

## Install

### 1. Skills only, via the Agent Skills CLI (Claude Code, Cursor, Codex, …)

```bash
npx skills add anatoliykant/iphone-duo-plugin
```

This installs the two skills; `agents/` is ignored by that CLI. To get the audit agent as well, copy
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

### 3. From the Claude community marketplace

Once the submission is approved:

```
/plugin marketplace add anthropics/claude-plugins-community
/plugin install iphone-duo@claude-community
```

### 4. By hand

Copy `skills/iphone-duo` and `skills/hig-design-review` into `~/.claude/skills/` (or a project's
`.claude/skills/`), and `agents/iphone-duo-audit.md` into `~/.claude/agents/`.

## Usage

Both skills load on their own when a request matches. Typical triggers: *"is this app ready for
iPhone Duo"*, *"what breaks on the foldable"*, *"add vertical toolbar support"*, *"reserved regions"*,
*"review this Figma against the HIG"*.

Invoke them explicitly with their scoped names:

```
/iphone-duo:iphone-duo           # adaptation work
/iphone-duo:hig-design-review    # mockup review
```

### Readiness audit

Ask for an audit in plain language and the skill delegates to the agent, or call it directly:

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
finding points at the reference section that fixes it. The agent is read-only: it never edits code.

### Design review

Give it a Figma URL (`…/design/<fileKey>/<name>?node-id=12-345`), a file key, or Sketch/PNG/PDF
exports. It returns findings with HIG citations, a severity per finding, and a verdict. It posts
comments on Figma nodes only when you explicitly ask, and never edits a file.

## What's inside

```
skills/iphone-duo/            SKILL.md + 7 references
skills/hig-design-review/     SKILL.md + 4 references
agents/iphone-duo-audit.md    read-only audit agent
```

| Reference | Read when |
|---|---|
| `iphone-duo/references/device-and-platform.md` | Display and size-class facts, SDK tiers, Split View, `UIRequiresFullScreen`, timeline, App Store, the unverified list |
| `iphone-duo/references/audit-checklist.md` | Running or interpreting the audit: 23 grep categories, severities, report template, Apple's 13 migration steps |
| `iphone-duo/references/layout-size-classes-safe-area.md` | Size classes, replacing `UIScreen.main`, width caches, state continuity, scene lifecycle, windows, safe area, the adaptive toolbox |
| `iphone-duo/references/bars-and-toolbars.md` | Vertical bars: opt-in, order, axis behavior, badges, edge detection, compression, overflow, priority, opt-out |
| `iphone-duo/references/arrangements-and-reserved-regions.md` | Reserved regions, displacement, `ArrangementView` / `UIArrangementViewController`, split vs overlay, anti-patterns |
| `iphone-duo/references/hinge-scenes-camera.md` | `onHingeChange`, multiple scenes, scene accessories, virtual front camera, direction and rotation coordinators |
| `iphone-duo/references/testing-and-sources.md` | Toolchain gate, Device Hub poses, SDK symbol verification, freshness checks, source URLs |
| `hig-design-review/references/intake-figma-sketch.md` | Pulling frames, sizes, renders and comments out of Figma via MCP; Sketch exports; size-class mapping |
| `hig-design-review/references/duo-design-rules.md` | The Duo design checklist D1–D29 with a source per rule |
| `hig-design-review/references/hig-general-checklist.md` | General iOS checks per area + how to fetch and cite the live HIG JSON pages |
| `hig-design-review/references/report-template.md` | Report shape, severity rows, verdict block, Figma comment format |

## Status and freshness

Every new symbol in the references carries a provenance tag — where the name came from, and whether
it has been confirmed against a real SDK:

| Tag | Meaning |
|---|---|
| **VERBATIM** | Copied from an Apple Code section of a tech talk, or from a developer article — spell it exactly like this |
| **PROSE** | Named in Apple's text but never written as code — the references say so where one is still unconfirmed |
| **CAPTION** | Seen only in auto-generated captions — never use; the references list the known mis-spellings |
| **EXISTING(iOS xx)** | A pre-Duo API that already ships — gate it at its own availability, not at 27.1 |
| **SDK(27.1 β1)** | Found in the shipping iOS 27.1 SDK with an availability annotation |

Research date **2026-09-10**; **SDK-verified 2026-09-21** against the iOS 27.1 SDK in **Xcode 27.1
beta 1** (27A9269). Every Duo symbol in the references now carries a real annotation. One capability
the HIG describes — collapsing an overlay arrangement's secondary view — has no API in that SDK, and
the references say so instead of guessing a name.

Also folded in on that date: Apple's developer article
"[Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)",
the camera articles for AVKit and AVFoundation, the September 2026 `documentation/updates` sections,
the Xcode 27.1 beta release notes, and both iPhone Duo Group Labs (Meet with Apple 285 and 286).
Labs are transcribed from Apple's own captions and are cited for guidance, never for API spellings.

Re-check after **2026-10-23** (ship date), or sooner if an iOS 27.1 RC appears: the availability
annotations still read `iOS 27.1 beta`, so re-run the SDK symbol grep in
`skills/iphone-duo/references/testing-and-sources.md` §Verify symbols and retag. That file's
§Freshness lists the machine-checkable signals.

Nothing in this repository talks to a network service on its own, stores credentials, or writes
outside the directory you point it at. The audit agent is read-only by construction.

## Credits

- Apple Inc. for the iPhone Duo tech talks (111461–111466), WWDC26 session 278 and the Human
  Interface Guidelines — quoted material stays © Apple, see [`NOTICE.md`](NOTICE.md).
- [FloWritesCode/fwc-swiftui-skills](https://github.com/FloWritesCode/fwc-swiftui-skills) (MIT) for
  the tiered-migration and state-continuity framing.

## License

MIT — see [`LICENSE`](LICENSE). Apple material quoted in the references is excluded; see
[`NOTICE.md`](NOTICE.md).
