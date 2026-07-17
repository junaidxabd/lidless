Continue Lidless (macOS keep-awake app, this repo: github.com/junaidxabd/lidless). This is a
DESIGN session — taste-first UI rethink. No Swift until mockups are approved.

Session-start ritual (files are the source of truth):
1. Read Docs/orchestration/progress.md and decisions.md (state, direction, pending decisions)
2. Read ARCHITECTURE.md briefly; skim your memory notes
3. Look at Docs/orchestration/design-direction-v4.png and its source build/mockups/mock4-armed.html
4. Baseline check: git status && make test (green; local signing errors → rm -rf build/DerivedData)

Where things stand — be honest with yourself about this:
- The KEPT parts: the Kare Happy-Mac-face-on-an-open-MacBook-screen mascot concept, the dark
  glowing mood, and the panel structure (header / machine hero / big countdown / slide-switch /
  stat well) are all fine.
- The REJECTED part: the visual execution. Junaid's verdict on v4: "it feels like the type of
  app that was cheaply made to look expensive." Glow-and-gradient theatrics are not polish.
  Real polish = restraint, perfect spacing/optics, true materials, correct light. Do not
  defend v4; outdo it.

Step 1 — TASTE BOARD (do this before any designing):
Open Chrome via the chrome-devtools MCP (persistent profile, already logged into Junaid's
Threads). Navigate to https://www.threads.com/saved, then HAND CONTROL TO JUNAID: he scrolls
his saved posts himself. When he says "look" (or similar), take_screenshot, Read it, and
analyze what's on screen as a design reference — extract WHY it feels high-quality (spacing,
materials, restraint, type, color discipline), not just what it looks like. Repeat until he
says he's done. Keep a running taste-board summary; save screenshots under build/research/taste/.

Step 2 — RETHINK the panel's visual execution against that taste board. Structure may stay;
presentation is open. Then produce mockups (write HTML → navigate file:// in Chrome →
resize_page → take_screenshot → READ your own render and judge it hard → iterate) and send
them with SendUserFile for approval. Expect rapid mid-turn feedback; fold it in. ultracode is
his standing opt-in — research/critique agent fleets are proven here (see progress.md), and
critics must MEASURE against references, not opine.

Step 3 — only after approval: implement in SwiftUI (mascot as an animatable Shape view —
blinks awake on arm, morphs asleep/hot/low-battery; all existing logic and the helper safety
code untouched; stay Swift 6.0-compatible — CI runs Xcode 16.4 while local is 26.5). Then
make screenshots, update README imagery, commit and push.

End every session by appending to Docs/orchestration/progress.md (done / in-progress /
blockers / next up) per the ritual in that file.
