# Agent Master Task — FR970 clean-room running Data Field

## Objective

Create a Garmin Connect IQ **Data Field** for **Forerunner 970 (`fr970`)** that recreates the useful information density and visual hierarchy of this reference app, while using an independent implementation and assets:

Reference URL:
https://apps.garmin.com/apps/018ddb22-b93e-403a-a07c-4bbae0d8f50c

Working name: **RunDash 970**.

Do not decompile, patch, extract, bypass licensing, or reuse the original PRG/source/branding. Screenshots and public behavior are only visual/functional references.

---

## Hard target / constraints

- Device: Garmin Forerunner 970
- Product id: `fr970`
- App type: `datafield`
- Primary layout: **1 Field / full screen / 454×454 round AMOLED**
- Data Field memory budget: **128 KiB (131072 bytes)**
- Min SDK: 5.2.2 (chosen because V1 uses `onTimerLap2`; only `fr970` is targeted)
- Rendering: prefer primitives/text; no large background bitmaps
- Null-safe for every `Activity.Info` field
- Do not assume `compute()` runs before `onUpdate()`
- Preserve at least ~15% memory headroom if feasible; report actual peak/runtime/compiler memory rather than guessing
- Do not hard-code Simon's training HR zones or race paces. User-configurable settings only.

---

## Phase 0 — Capture the public reference accurately

Use a real browser with JS enabled.

1. Open the exact reference URL.
2. Capture/save every public gallery image at the highest available resolution.
3. Capture App Info, settings/description, changelog/version, and compatible-device information that materially explains fields.
4. Create `reference/REFERENCE_NOTES.md` containing:
   - image filename
   - native dimensions
   - visible labels
   - inferred field only when evidence exists
   - unknown labels marked `UNKNOWN`; **do not invent semantics**
5. The already-known public preview has:
   - black background
   - white large numeric typography
   - gray labels
   - green separator lines
   - top HR + colored HR-zone bar + cadence
   - very large center primary number
   - three stacked right-side values labelled `L`, `C`, `A`
   - large lower distance-like value
   - compact bottom timer/lap-like row
6. Do not copy the reference logo, app name, icon artwork, bitmap assets or proprietary fonts.

If the full gallery cannot be fetched, **do not block**. Continue from the starter and record the visual-parity blocker in `BUILD_REPORT.md`.

---

## Phase 1 — Environment audit; minimize user intervention

Check first; install/fix only what is missing.

Required:
- VS Code
- Garmin Monkey C extension
- Java 11+
- Connect IQ SDK 4.0.6+
- current SDK device files for `fr970`
- `monkeyc`, `monkeydo`, Connect IQ simulator

Commands to inspect where useful:

```bash
java -version
which monkeyc || command -v monkeyc
which monkeydo || command -v monkeydo
monkeyc --help
```

Do not repeatedly ask the user to confirm routine local development steps. Only stop for things the Agent truly cannot do safely itself, such as an account login challenge, physical watch interaction, or selecting an existing private signing key whose location cannot be determined.

### Signing key rules

- Reuse an existing Connect IQ developer key if one belongs to this project/user and is safely available.
- If none exists, generate one through `Monkey C: Generate Developer Key` or Garmin's documented RSA process.
- **Never overwrite an existing key silently.**
- **Never commit, print, upload or expose the private key.**
- The same key must be preserved for future Store updates.

---

## Phase 2 — Use and validate this starter project

Project tree:

```text
RunDash970/
├── AGENT_TASK.md
├── README.md
├── manifest.xml
├── monkey.jungle
├── .gitignore
├── source/
│   ├── RunDash970App.mc
│   ├── RunDash970View.mc
│   └── Metrics.mc
├── resources/
│   ├── properties.xml
│   ├── settings/
│   │   └── settings.xml
│   └── strings/
│       └── strings.xml
├── scripts/
│   ├── build.sh
│   └── run-sim.sh
└── bin/
```

First compile the starter unchanged and collect diagnostics. Fix actual SDK/type/API errors before redesigning.

Expected command shape:

```bash
monkeyc -d fr970 -f monkey.jungle \
  -o bin/RunDash970-fr970.prg \
  -y /absolute/path/developer_key.der -w
```

Start the simulator using the SDK/VS Code, then:

```bash
monkeydo bin/RunDash970-fr970.prg fr970
```

If the current SDK prefers VS Code commands, use:
- `Monkey C: Verify Installation`
- `Monkey C: Build Current Project`
- `Monkey C: Build for Device`
- `Monkey C: Export Project`

Do not claim the starter compiles until you have actually built it with a Garmin SDK.

---

## Phase 3 — Functional V1

Implement and verify these data sources and derived values:

| Display | Primary source / formula | Required behavior |
|---|---|---|
| HR | `Activity.Info.currentHeartRate` | nullable |
| Avg HR | `averageHeartRate` | nullable |
| Cadence | `currentCadence` | validate FR970 running semantics vs native Garmin screen |
| Current pace | `1000 / currentSpeed` | speed in m/s → sec/km; protect zero/null |
| Avg pace | `1000 / averageSpeed` | nullable |
| Distance | `elapsedDistance` | meters → km display |
| Timer | `timerTime` | ms → MM:SS / H:MM:SS |
| Elapsed | `elapsedTime` | same formatting |
| Lap pace | `(timerTime-lapStartTime)/(distance-lapStartDistance)` | reset on lap |
| Lap distance | `distance-lapStartDistance` | reset on lap |
| HR zone | user max-HR based V1 placeholder | later replace if reference behavior is proven |
| Virtual pacer | `actual timer - expected time at target pace` | negative=ahead, positive=behind |
| Clock | `System.getClockTime()` | display-only |

### Critical cadence validation

Garmin's API documents cadence in RPM. Do **not** blindly multiply by two or assume the number equals Garmin's displayed running SPM on FR970. Perform a real-device or simulator/native-screen comparison and document the result. Fix only from evidence.

### Lap handling

- Use `onTimerLap2(trigger)` on FR970.
- Return `true` after handling so the legacy callback is not double-applied.
- Keep `onTimerLap()` as a defensive fallback where appropriate.
- Verify manual Lap, Auto Lap, workout interval lap behavior if the device exposes them.

---

## Phase 4 — Visual implementation

The source preview is reference **only for hierarchy**, not an instruction to copy copyrighted artwork.

V1 visual goals:

1. Black background.
2. White high-contrast numbers.
3. Gray secondary labels.
4. Green separators/accent. (2026-10-07 用户确认改为中性灰 #3A3A3A（v4 设计）；分隔线不再使用绿色。)
5. HR zone segmented strip near top.
6. Primary pace value is largest.
7. Distance is second-largest.
8. Right stacked compact values for Lap / Current / Average pace until public evidence proves another mapping.
9. Bottom row for Timer / Lap distance; pacer can occupy bottom-center status.
10. Respect the round-screen obscured corners/edges; do not place critical digits close to the circle edge.

After Phase-0 images are obtained:
- build a pixel-coordinate table for the 454×454 target;
- compare simulator screenshot to reference at 1:1 scale;
- adjust baselines/font choice/spacing;
- prefer `Graphics.FONT_*`, vector fonts, lines and rectangles over bitmaps;
- do not waste memory chasing non-functional decorative parity.

If exact source semantics conflict with this starter layout, preserve the verified source semantics and update `REFERENCE_NOTES.md`.

---

## Phase 5 — Settings

At minimum:

- `targetPaceSecPerKm` — numeric, default 300 (5:00/km)
- `maxHeartRate` — numeric, default 180; generic placeholder only
- `showPacer` — boolean

Do not insert the user's personal HR/maxHR/target pace unless explicitly requested for this app. Settings must remain generic and portable.

Possible V2 after V1 passes:
- target pace entered as min/sec UI rather than raw sec/km
- configurable HR-zone boundaries/method
- metric/imperial unit support
- user-selectable right column fields
- pace smoothing mode
- workout-step/interval mode

---

## Phase 6 — Test matrix

### Simulator

Test at minimum:

- app loaded before activity starts
- no GPS / `currentSpeed == null`
- stationary / zero speed
- HR missing then appears
- cadence missing then appears
- start
- pause
- resume
- stop
- reset
- manual lap
- repeated laps
- timer > 60 minutes
- distance around 0 m, 999 m, 1 km, 10 km, 42.195 km
- pace around 2:30/km through 10:00/km
- target pacer ahead and behind
- full-screen 454×454
- non-full-screen fallback doesn't crash

### Real FR970

Sideload PRG and run one short test activity. Compare against Garmin native fields for:

- HR
- cadence
- distance
- timer
- current pace trend
- average pace
- lap reset

Do not declare release-ready until real-device cadence and lap behavior are checked.

---

## Acceptance criteria

All must be true:

- [ ] `manifest.xml` targets only `fr970` in V1
- [ ] app type is `datafield`
- [ ] build completes with 0 errors
- [ ] warnings reviewed; no ignored correctness warning
- [ ] simulator launches and renders
- [ ] no crash when any `Activity.Info` value is null
- [ ] current/avg pace formula validated with deterministic examples
- [ ] lap pace resets correctly
- [ ] pause/resume/reset behavior correct
- [ ] full-screen UI has no critical clipping
- [ ] memory stays under 131072-byte Data Field limit, with measured report
- [ ] private developer key is not in repo/artifacts
- [ ] real FR970 sideload test completed, or explicitly marked pending physical-device interaction
- [ ] cadence semantics compared against FR970 native screen
- [ ] `BUILD_REPORT.md` and `TEST_REPORT.md` created

---

## Required final deliverables

Agent must leave in the project:

```text
bin/RunDash970-fr970.prg
BUILD_REPORT.md
TEST_REPORT.md
reference/REFERENCE_NOTES.md
```

If Store publication is requested later, additionally export an `.iq` package with `Monkey C: Export Project`; do not publish without explicit user instruction.

### BUILD_REPORT.md must include

- OS
- Java version
- Connect IQ SDK version
- `fr970` device support version/status
- exact build command
- compiler warnings/errors fixed
- measured app/Data Field memory result
- PRG path and hash
- signing-key path redacted (show only that one was used, never its contents)

### TEST_REPORT.md must include

- simulator tests and result
- screenshots
- real-device tests and result
- cadence validation result
- lap event validation result
- known differences from source reference
- remaining blockers

---

## Agent autonomy rule

Continue autonomously through environment check → compile → simulator → fixes → report. Do not stop merely because the first compile fails. Diagnose and fix build issues. Ask the user only when blocked by credentials/account approval, a physical FR970 action, or a genuinely ambiguous product choice that changes requirements.
