---
name: foldsim
description: Drive iOS simulators from the command line to check an app's layout in every pose — fold, unfold and rotate an iPhone Duo simulator (closed, tent, book, open, table), rotate an iPhone or iPad simulator, tap, press or swipe on any display including the Duo's inner one, capture each display, and tour all poses with screenshots and state. Use whenever you verify UI on an iPhone Duo, iPhone or iPad simulator, need a specific pose or orientation, need to touch the unfolded Duo (AXe, idb and similar tools only reach the cover), check an app's supported orientations or hinge gate, or capture what each display shows.
---

# foldsim — every pose of a simulator, from the command line

## Flags — answer and stop

Interpret flags only when the user's skill request consists solely of `-h`, `--help`, `-v`,
or `--version`. Claude Code may append that request as `ARGUMENTS: …`; Codex supplies it in the
user message after the skill mention (`$iphone-duo:foldsim` in a plugin install, `$foldsim` in a
skills-only install). For a flag-only request, print only the corresponding block and stop.

**`-v` / `--version`** — answer in one line, from the literal below:

> `foldsim 1.4.0` · Xcode 27.2 RC or later on Apple silicon · measured 2026-10-30 on the Duo runtimes 24B91014 (27.2 RC) and 24A94425 (27.1), iPhone 18 Pro Max and iPad Pro 13-inch (M5) on 24B114

<!-- skill-version: 1.4.0 — kept equal to both plugin manifests by .github/workflows/version-consistency.yml -->

**`-h` / `--help`** — print this, verbatim:

> **foldsim** — put a simulator into any pose and look at what the app shows there.
>
> **iPhone Duo:** fold and unfold to any angle, the poses closed, tent, book, open and table, rotation of whichever display is active, taps and swipes on the inner display, screenshots of both displays. **iPhone and iPad:** rotation, taps, screenshots.
>
> **Checks with it:** a `tour` through every pose with screenshots and state, whether the app turns to landscape where it should and stays portrait where it should (exit code 3 means the app refused), and whether Duo-only UI appears only on the Duo. What to look for in each pose: `references/pose-checks.md`.
>
> **Needs** Xcode 27.2 RC or later on Apple silicon and a booted simulator. The first run compiles two small Swift programs with that Xcode (a few seconds to a minute). Hinge, Duo rotation and touches use private simulator interfaces that any Xcode update can change; `doctor` says whether they still work, and Device Hub is the manual fallback.

## Running it

The command is `scripts/foldsim` in this skill's directory. Call it by its absolute path — the
base directory of this skill plus `scripts/foldsim` — since the working directory is the user's
project. If the file lost its executable bit (some copies do), run it as `sh <path>/scripts/foldsim`.

- **Which simulator:** `-d <udid>` or `FOLDSIM_DEVICE`. Without them foldsim takes the only booted
  simulator and refuses to choose between several (exit 2, with the list). Other sessions and tools
  boot their own simulators: always pass `-d` for the simulator you created, and never shut down,
  erase or reboot one you did not create. foldsim itself never boots or shuts anything down.
- **First call:** `foldsim build` (allow 3 minutes), then `foldsim -d <udid> doctor`. The build is
  cached in `~/Library/Caches/foldsim`, or `FOLDSIM_CACHE_DIR`.
- **Sandboxes.** The simulator commands talk to CoreSimulatorService, which Codex's `workspace-write`
  sandbox blocks ("not connected to CoreSimulatorService"): run them with permission to leave the
  sandbox, and ask the user to approve the command. `--version`, `build` and `selftest` work inside it;
  when the cache is not writable the build goes to `$TMPDIR/foldsim-cache`. A Claude Code sandbox that
  blocks the service needs the same.
- **Read the result, do not assume it.** Every command that changes something prints the state
  afterwards; `--json` gives one object per command, `{"ok": false, "error": {…}}` on failure.

| Command | What it does |
|---|---|
| `devices` | booted simulators and their kind: duo, iphone, ipad |
| `state` | each display: active or not, interface orientation, size in points; the hinge angle on a Duo |
| `pose <closed-portrait\|closed-landscape\|tent\|book\|open-landscape\|open-portrait\|table>` | Duo: reaches the pose the way a hand would and checks which display shows it |
| `hinge <degrees\|closed\|half\|open> [--duration s] [--tolerance °]` | Duo: moves the hinge at 60° a second (never an instant jump), waits until CoreMotion agrees |
| `rotate <portrait\|landscape-left\|landscape-right\|portrait-upside-down>` | turns the active display's interface; names as in `UIInterfaceOrientation` |
| `tap x y` · `press x y [--duration s]` · `swipe x1 y1 x2 y2 [--duration s]` | interface points of the active display, as the app sees them |
| `screenshot -o file.png [--display active\|cover\|inner\|both]` | `both` writes `file-cover.png` and `file-inner.png` |
| `tour [--out dir]` | Duo: every pose and back to the start; iPhone: portrait and both landscapes; iPad: all four. Screenshots of every display, `tour.json`, `tour.md` |
| `doctor` | the toolchain and every private interface of the booted runtime |

| Exit code | Meaning |
|---|---|
| 0 | done, and read back |
| 1 | tool or runtime failure — a private interface is missing or changed (see `doctor`) |
| 2 | usage or device: wrong arguments, no or several booted simulators, a hinge on a phone |
| 3 | refused: the interface stayed where it was — the app's supported orientations, or a system rule such as no portrait upside down on an iPhone |
| 4 | did not settle: the hinge or the display did not end where asked |

## The Duo in the simulator — what foldsim relies on

Measured with the probe app in `tests/foldsim-probe` of the plugin repository (Xcode 27.2 RC):

- **Displays.** The cover is 466 × 678 pt, the inner display 669 × 951 pt. `screenshot` uses
  `simctl io … --display=<id>` (1 = cover, 3 = inner); the inactive display comes out black.
- **Which display is active depends on how the hinge got there.** One continuous move switches
  displays between about 75° and 90°, either way and at any pace: opening from closed keeps the cover
  to 75° and shows the inner display by 90°; folding from open keeps the inner display to 90° and shows
  the cover by 80°. Stop on the way and the active display stays: opened in steps, the cover held to
  about 120°; folded in steps, the inner display held to 20°. `UIHinge.status` follows the same
  history, not the angle: it read `.closed` at 123° after an opening in steps and `.partiallyOpen` at
  21° after a fold in steps. So `pose book` and `pose table` open fully first and fold to 110° in one
  move; `pose tent` closes the Duo, lets it rest two seconds and opens it to 75° in one smooth move,
  which keeps the cover.
- **Opening a landscape Duo into a tent turns the cover's interface over** (landscape-left becomes
  landscape-right), and `pose tent` keeps it so. In a tent the device orientations reach the cover half
  a turn off; `rotate` reads back where the display ended instead of trusting its table. Right after
  the hinge moves, devicectl can report the other display as active for a moment — foldsim waits for
  it to settle.
- **Rotation.** The Duo ignores `devicectl device orientation set`; foldsim sends Device Hub's own
  event. iPhone and iPad use devicectl. The inner display shows portrait upside down; an iPhone,
  and the Duo's cover, never do.
- **Touches.** AXe, idb and similar tools only reach the cover. foldsim creates a virtual touchscreen
  for the active display, so taps land on the inner display too, within a point of where you asked.
  A tap reaches what a finger would: on an iPhone in portrait the status bar takes one at (30, 30), and
  a point outside a rounded display corner, such as (12, 12) on an iPhone 18 Pro Max, reaches nothing.
  foldsim exits 0 either way — check what the app did.
- **iOS 27.1 runtime.** An instant jump between closed and open can leave a Duo unable to switch
  displays until it is recreated. foldsim always sweeps, so this does not happen through it.

## Checking an app

1. Boot your own simulator, install and launch the app, then `foldsim -d <udid> tour --out <dir>`.
2. Open every screenshot in `<dir>` — a pose that "settled" can still show a broken layout, and a
   Duo screenshot can be black for a few minutes after boot.
3. Go through `references/pose-checks.md`: both displays per pose, the hinge gate, the orientation
   mask, render-test windows.
4. Report per pose: what was checked, what was seen, the file of the screenshot.

When `doctor` reports a missing interface, say that the private simulator interface changed with
this Xcode and fall back to Device Hub: its buttons fold, open and rotate the Duo by hand.
