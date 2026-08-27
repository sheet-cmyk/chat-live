# Prompt to paste into Claude (in VS Code / Claude Code)

Copy everything below the line into your Claude Code chat, inside your Flutter project.

---

I want you to build a complete Egyptian-themed slot machine game inside my existing Flutter app, called **"Ra's Gaze"**. I have already generated the art assets as SVG files — they are located in `assets/rasgaze/symbols/`, `assets/rasgaze/ui/`, and `assets/rasgaze/backgrounds/`. Use `flutter_svg` to render them. Please register all of these paths in `pubspec.yaml` under `flutter/assets`.

## Asset inventory (already provided, do not regenerate)

**Symbols** (`assets/rasgaze/symbols/`):
- `wild_eye_of_ra.svg` — WILD. Expands to fill the whole reel it lands on and substitutes for every symbol except the scatter.
- `scatter_temple_gate.svg` — SCATTER. 3+ anywhere triggers Free Spins.
- `high1_ra_falcon.svg`, `high2_anubis_jackal.svg`, `high3_bennu_bird.svg`, `high4_scarab.svg` — high-value symbols.
- `mid1_ankh_pair.svg`, `mid2_lotus_pair.svg` — mid-value symbols.
- `low_A.svg`, `low_K.svg`, `low_Q.svg`, `low_J.svg` — low-value card-royal symbols.

**UI** (`assets/rasgaze/ui/`):
- `logo.svg` — game logo/title, shown at the top of the game screen.
- `sun_mascot_icon.svg` — small animated sun mascot icon, top-left corner.
- `button_spin.svg` — the spin button graphic.
- `bet_arrow_up.svg`, `bet_arrow_down.svg` — bet stepper controls.
- `freespins_banner.svg` — full-screen banner shown when free spins are triggered.

**Backgrounds** (`assets/rasgaze/backgrounds/`):
- `background_reels.svg` — main game background behind the reel grid.
- `background_menu.svg` — background for a menu/attract screen (optional, if we build one).

## Reel grid & core mechanics

- 5 reels × 3 visible rows (5×3 grid), 10 fixed paylines (standard left-to-right slot paylines — implement the classic 10-line pattern: 3 straight lines top/middle/bottom, plus zig-zag/V-shape lines).
- Paytable (matches per line, 3/4/5 of a kind), all values in **credits**:

| Symbol | 3-of-a-kind | 4-of-a-kind | 5-of-a-kind |
|---|---|---|---|
| Wild (Eye of Ra) | 34,000 | 85,000 | 170,000 |
| Scatter (Temple Gate) | 6,800 | 68,000 | 170,000 |
| Falcon (Ra) | 17,000 | 68,000 | 136,000 |
| Jackal (Anubis) | 6,800 | 42,500 | 102,000 |
| Scarab | 6,800 | 34,000 | 85,000 |
| Ankh pair | 3,400 | 17,000 | 68,000 |
| Lotus pair | 3,400 | 17,000 | 68,000 |
| A / K / Q / J | 1,700 | 6,800 | 34,000 |

- **Wild behavior:** when a Wild lands anywhere on a reel, it expands to cover all 3 positions on that reel for that spin, and substitutes for all symbols except the Scatter.
- **Scatter / Free Spins trigger:** landing 3 or more Scatters anywhere on the grid (not limited to a payline) awards **15 Free Spins** and shows the `freespins_banner.svg` full-screen overlay before free spins begin.
- **Free spins upgrade mechanic:** during free spins, each spin randomly "upgrades" one of the low/mid symbol classes to award higher-tier prizes for the remainder of the free spins round (mirror the escalating-symbol-upgrade mechanic common in Egyptian-themed slots: start with low symbols upgrading to mid, then mid to high, so payouts trend upward as the round progresses). Show a small indicator/animation when an upgrade happens.
- Free spins can be retriggered by landing 3+ Scatters again during the free spins round (add 15 more spins).
- After free spins end, return to the base game and show a total-win summary screen.

## Bet selection (as specified)

- Add a bet selector UI (using `bet_arrow_up.svg` / `bet_arrow_down.svg`) that lets the user increase or decrease the stake per spin.
- Valid bet amounts, in this exact order, wrapping at the ends (does not go below min or above max): **5,000 → 10,000 → 15,000 → 25,000 → 30,000**.
- Display the currently selected bet amount prominently near the spin button, and update it live as the user taps the arrows.
- The displayed "balance" or "win" number should animate (count up/down) rather than snap instantly when it changes.

## Screens / widgets to build

1. **GameScreen** (main) — background (`background_reels.svg`), 5×3 reel grid, logo top-center, sun mascot icon top-left, balance display, bet stepper, spin button, win display.
2. **ReelWidget** — individual reel that can spin (vertical scroll/blur animation), stop on a result, and support the Wild expand-to-fill-reel animation (symbol scales/stretches to cover all 3 cells with a golden glow flash).
3. **PaylineOverlay** — draws the winning payline(s) over the grid when a win lands, with a brief highlight animation and sequential reveal if multiple lines win.
4. **FreeSpinsBannerOverlay** — full-screen transition using `freespins_banner.svg`, animated in/out, showing "15 FREE SPINS" before the free spins round starts, and a summary ("You won X credits in Free Spins!") when it ends.
5. **BetSelector** — the increase/decrease control described above.
6. **WinCounter** — animated number widget for balance/win amounts.

## Animation details

- Reels spin downward with motion blur, staggered stop timing (reel 1 stops first, reel 5 stops last, ~150–200ms stagger).
- Winning symbols pulse/glow gold briefly after the reels stop.
- Wild expansion: smooth scale + glow animation as it fills its reel.
- Free spins banner: fade/scale in, hold, fade out before revealing the reels.
- Use `AnimationController`/`Tween` (or `flutter_animate` if already a dependency) — don't add heavy new dependencies unless necessary; prefer `flutter_svg` as the one new dependency if not already present.

## State management

- Use whatever state management this project already uses (check `pubspec.yaml`/existing providers — Provider, Riverpod, Bloc, or plain `setState`) and follow that existing pattern rather than introducing a new one.
- Keep game logic (RNG, paytable evaluation, free-spins state machine) in a separate `RasGazeGameController`/service class, decoupled from widgets, so it's testable.

## Deliverables I expect from you

1. Updated `pubspec.yaml` with all asset paths and `flutter_svg` dependency.
2. A `lib/rasgaze/` folder containing: models (symbols, paytable, paylines), the game controller/state machine, and all widgets listed above.
3. Wire it into the existing app's navigation so I can open it from [tell Claude Code where — e.g. "the games list screen" / "a new route named /rasgaze"].
4. Make sure it runs with `flutter run` with no analyzer errors.

Please start by reading my existing project structure (`lib/`, `pubspec.yaml`) to match conventions already in use, then implement this feature end-to-end.
