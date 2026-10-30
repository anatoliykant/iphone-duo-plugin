# NOTICE

## License of this work

Everything written for this plugin — the skill instructions, the audit checklist and its grep
patterns, the review procedure, the agent prompt and this documentation — is © 2026
Anatolii Podkladov and licensed under the MIT License (see `LICENSE`).

## Apple material

The reference files quote and paraphrase Apple Inc. documentation and developer sessions so that a
coding agent can use the APIs correctly:

- Code blocks marked **VERBATIM** are reproduced from Apple Code sections of the iPhone Duo tech
  talks 111461–111466 and WWDC26 session 278.
- Sentences quoted from the Human Interface Guidelines and from Apple developer documentation are
  marked as quotations at the point of use.

That material is **© Apple Inc., all rights reserved**. It is reproduced here for documentation,
commentary and interoperability purposes, is not covered by the MIT License above, and is not
redistributed as a substitute for Apple's own documentation. Read the originals at
<https://developer.apple.com>.

The point sizes used throughout (outer 466 × 678, inner 669 × 951) are the app windows **measured by the
author** on the iPhone Duo simulator (Xcode 27.2 RC); they equal Apple's App Store screenshot sizes divided
by 3. Apple states no point sizes, and the Split View half (≈ 334 / 475) is derived. Plugin versions
before 1.3.2 gave the inner display as 626 × 890 — the panel's pixels divided by 3 — which is wrong.

Apple, iPhone, iPhone Duo, iPad, iOS, iPadOS, watchOS, Xcode, SwiftUI, UIKit, Swift, App Store and
Human Interface Guidelines are trademarks of Apple Inc., registered in the U.S. and other countries.
Figma is a trademark of Figma, Inc. This project is an independent work: it is not affiliated with,
authorized, sponsored or endorsed by Apple Inc. or Figma, Inc.

## Third-party ideas

The tiered migration structure (Tier 1 universal / Tier 2 device-aware / Tier 3 device-exclusive) and
the "state survives the layout transition" framing were adapted from
[FloWritesCode/fwc-swiftui-skills](https://github.com/FloWritesCode/fwc-swiftui-skills) (MIT License).
No code or text was copied verbatim.

## foldsim and private simulator interfaces

The foldsim CLI in `skills/foldsim/scripts` is part of this work (© 2026 Anatolii Podkladov, MIT). Inside
the iOS Simulator only, it uses private, undocumented interfaces: the IOKit HID event system, the
`HIDVirtualEventService` class, CoreMotion's `CMAngleManager`, and the device-state event Xcode's Device
Hub sends. They are used for development and testing of your own apps, are not supported by Apple, and
can change with any Xcode or simulator runtime update.

Interface references, used for declarations and constants only — no code was copied:

- WebKit's open-source SPI declarations `Source/WebCore/PAL/pal/spi/ios/IOKitSPIIOS.h` and
  `Source/WebCore/PAL/pal/spi/mac/IOKitSPIMac.h`, and its touch synthesizer
  `Tools/WebKitTestRunner/ios/HIDEventGenerator.mm` (© Apple Inc., BSD license);
- the macOS SDK's public `IOKit/hidsystem` headers;
- IOHIDFamily's `HID/PrivateHeaders/HIDVirtualEventService.h` from Apple's open-source releases
  (Apple Public Source License 2.0).

The mechanisms were first described publicly by [artemnovichkov/hinge](https://github.com/artemnovichkov/hinge)
(MIT License; the device-state event and reading the angle from `CMAngleManager`) and
[skarol/duoctl](https://github.com/skarol/duoctl) (MIT License; touching the inner display through a
virtual touchscreen). foldsim was written independently from those descriptions; no code was taken from
either project.
