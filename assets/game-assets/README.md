# Dice Game Assets

Drop this whole `game-assets` folder into your project as `/assets/game/`.

## dice/
dice-1.svg ... dice-6.svg — white die faces, black pips (red center pip on odd faces), rounded corners, drop shadow. Use these for: the mini result icons at top-left, the big reveal dice, and the history log rows.

## chips/
chip-10.svg   (blue)
chip-100.svg  (purple)
chip-1k.svg   (gold, label "1K")
chip-10k.svg  (red, label "10K")
Use these for: the bottom denomination selector bar, and the stacked chip piles shown inside each betting panel (stack multiple copies with slight random offset/rotation to form a "pile").

## ui/
cup-closed.svg   — closed dice cup/bell, used during idle + "shaking" (betting locked) states. Animate with a small rotate/translate shake loop.
cup-dome.svg     — glass dome revealing 3 dice on green felt, used for the "reveal" state after shake ends.
panel-bg.svg     — reusable green felt rounded panel background for Small/Big/Triple betting zones.
table-bg.svg     — full green table + top/bottom wood rail background for the whole game screen.

## Notes for implementation
- All betting-zone panels should stack: panel-bg.svg behind, pool-total number on top, chip-pile (using chip-*.svg) in the middle, player-stake number at the bottom.
- Highlight the winning zone post-reveal with a yellow glow outline (add a CSS box-shadow / SVG filter, not baked into the asset).
- Keep vector (SVG) so they scale crisply on all screen sizes; convert to PNG only if your engine (e.g. Unity/Flutter) needs raster sprites.
