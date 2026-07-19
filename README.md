# T-Rex Runner — Chrome Dino, on an actual NES

A from-scratch port of Chrome's offline dinosaur game to the Nintendo
Entertainment System, written in 6502 assembly. Same physics, same obstacle
rules, same scoring — running on 1985 hardware: a 1.79 MHz 6502, 2 KB of RAM,
and a PPU that can't scroll two things at different speeds without a trick.

Ported from the Chromium source:
[`components/neterror/resources/dino_game/`](https://source.chromium.org/chromium/chromium/src/+/main:components/neterror/resources/dino_game/).

![gameplay demo](media/demo.gif)

## Screenshots

| Title | Gameplay | Night mode | Game over |
|---|---|---|---|
| ![title screen](media/title.png) | ![jumping over a cactus](media/gameplay.png) | ![night mode with moon and stars](media/night.png) | ![game over screen](media/gameover.png) |

## Features

- **Physics ported value-for-value from the Chromium source** (see the
  fidelity table below): speed-scaled jump velocity, variable jump height
  (release early / speed-drop with DOWN in mid-air), gravity, ducking, and
  the original collision boxes for the T-Rex, cacti, and pterodactyls.
- **Original obstacle rules**: small/large cacti in groups of 1–3
  (speed-gated), pterodactyls at 3 heights (jump / duck / fly-over) once speed
  passes 8.5, the original gap formula (`width*speed + minGap*0.6 .. *1.5`),
  and the max-2-duplicate-in-a-row rule.
- **Speed ramp** 6 → 13 and **score** at the original rate (1 point per 40
  world px), 5-digit display, persistent HI score, a 100-point ding + flash.
- **Day/night cycle**: palette inversion every 700 points; a stationary
  crescent moon and twinkling stars, with clouds drifting past in front.
- **Title screen, pause/resume, game-over panel** with a restart icon copied
  pixel-for-pixel from Chrome's own sprite sheet.
- **Sound**: jump blip, 100-point ding, crash, plus a 4-channel chiptune
  (pulse lead + harmony, triangle bass, noise drums) for the title, gameplay,
  and game-over themes.

## Fidelity

Every gameplay constant was checked against the Chromium `dino_game` source.
Identical values:

| Parameter | Value (both) | Chromium source |
|---|---|---|
| Jump velocity | −10 − speed/10 | `trex.ts` `startJump` |
| Gravity | 0.6 / frame | `trex.ts` `normalJumpConfig` |
| Min/max jump height | 30 / 30 (end-jump at y<30) | `trex.ts` `normalJumpConfig` |
| Drop velocity (early release) | −5 | `trex.ts` `dropVelocity` |
| Speed-drop coefficient | ×3 fall, vy := 1 | `trex.ts` `setSpeedDrop` |
| T-Rex position / size | x 50, 44×47, duck 59×25 | `trex.ts` config |
| Collision boxes (all 9 + duck) | identical | `trex.ts`, `offline_sprite_definitions.ts` |
| Cacti | w 17/25, y 105/90, multipleSpeed 4/7, minGap 120 | `offline_sprite_definitions.ts` |
| Pterodactyl | w 46, y {100, 75, 50}, minSpeed 8.5, speed ±0.8, 6 fps flap | `offline_sprite_definitions.ts` |
| Gap formula | `round(w·speed + minGap·0.6)` … ×1.5, uniform | `obstacle.ts` `getGap` |
| Speed range | 6 → 13 | `offline.ts` |
| Obstacle-free grace | 3000 ms (180 frames) | `offline.ts` `clearTime` |
| Score rate | distance × 0.025 | `distance_meter.ts` |
| Night trigger | every 700 points | `offline.ts` `invertDistance` |

Known deviations (all deliberate or inherent to the hardware):

- **Speed ramp**: +1/256 every 4 frames ≈ 0.000977/frame vs the original's
  0.001/frame — about 2% slower to reach max speed.
- **8.8 fixed point**: gravity is stored as 154/256 ≈ 0.6016; the original
  also rounds the T-Rex's y to whole pixels every frame while the port keeps
  sub-pixel precision, so jump arcs can differ by a fraction of a pixel.
- **Night duration**: 350 points (half the cycle) instead of the original's
  fixed 12 s, so day and night stay evenly split at any speed.
- **Obstacle spawn x**: 640 instead of 600 (the NES streams cacti into the
  scrolling background ahead of the visible edge); the spawn *threshold*
  moved with it, so obstacle spacing — the thing that matters — is identical.
- **Frame-locked timing**: the original scales physics by real elapsed time;
  the NES steps once per video frame (60 fps NTSC — on a PAL console
  everything runs proportionally slower, as was traditional).

## Controls

| Button | Action |
|---|---|
| START | start game · pause / resume · restart |
| A or ↑ | jump (hold for a higher jump) |
| ↓ | duck while running · fast-fall in mid-air |

## Build

Requires only [cc65](https://cc65.github.io/) (`ca65` + `ld65`):

```sh
make            # -> build/trex.nes
make run        # open in Mesen (macOS, /Applications/Mesen.app)
```

`build/trex.chr` (the compiled tile/sprite data) ships pre-built, so no other
tooling is needed to go from source to ROM. Load `build/trex.nes` in any NES
emulator, or on real hardware via a flash cart.

## Why an NES port of a web game is harder than it sounds

The original game simulates in a continuous 600×150 coordinate space and
scrolls one uniform background. The NES gives you a 256×240 tile grid, 64
sprites total, no per-pixel background scroll speed control, and a CPU that
has to finish all of that math, collision, and rendering setup in the ~2,270
cycles between one video frame and the next. A few of the tricks this port
leans on:

- **World simulation stays in the original 600×150 units** (8.8 fixed point),
  converted to NES screen space only at render time (`×109/256` horizontal,
  `×174/256` vertical) — so the physics constants are lifted straight from
  Chromium instead of being re-derived and re-tuned.
- **Cacti are background tiles, not sprites.** They're streamed into the
  scrolling nametable one column at a time as the world scrolls, so even a
  wall of three large cacti costs **zero** sprites. Only the T-Rex,
  pterodactyls, and clouds use sprites — worst case 6 per scanline, safely
  under the NES's 8-sprite limit by construction, so there's no flicker.
- **The score line doesn't scroll — the ground does**, on the same
  nametable. That split is done with a sprite-zero-hit trick: an invisible
  marker sprite fires mid-frame, and the NMI handler swaps the PPU's scroll
  register the instant it does, so the HUD band and the playfield can scroll
  at different rates on hardware that only has one scroll register.
- **Decimal score with manual BCD**, 16-bit RNG and gap math, and a
  fixed-point jump arc — all in 6502 assembly with no floating point.

## Project structure

```
src/            6502 source (ca65 syntax)
  main.asm        iNES header, segment layout, includes
  reset.asm       startup, NMI handler, main loop
  game.asm        state machine, physics, input, scoring
  world.asm       obstacles, clouds, collision, RNG, night sky
  render.asm      sprite/OAM composition, UI panels, HUD
  ppu.asm         VRAM buffer, palettes, nametable setup
  audio.asm       APU driver, music sequencer, sound effects
  input.asm       joypad reading
  data.asm        lookup tables, strings, palettes, collision boxes
  nes.inc         hardware registers, constants, zeropage map
  chr_map.inc     tile index constants (matches build/trex.chr)
build/
  trex.chr        pre-built CHR-ROM (tile + sprite pattern data)
nes.cfg         ld65 linker config (NROM-256, vertical mirroring)
Makefile
```

## Credits

- Original game design, art, and physics: the Chromium project —
  [`components/neterror/resources/dino_game/`](https://source.chromium.org/chromium/chromium/src/+/main:components/neterror/resources/dino_game/)
  (BSD-licensed).
- NES port: [atonamy](https://github.com/atonamy), 2026.
