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

- **Accurate physics**, ported value-for-value from the Chromium source:
  speed-scaled jump velocity, variable jump height (release early / speed-drop
  with DOWN in mid-air), gravity 0.6, ducking, and the original collision
  boxes for the T-Rex, cacti, and pterodactyls.
- **Original obstacle rules**: small/large cacti in groups of 1–3
  (speed-gated), pterodactyls at 3 heights (jump / duck / fly-over) once speed
  passes 8.5, the original gap formula (`width*speed + minGap*0.6 .. *1.5`),
  and the max-2-duplicate-in-a-row rule.
- **Speed ramp** 6 → 13 (+0.001/frame) and **score** at the original rate
  (1 point per 40 world px), 5-digit display, persistent HI score, a 100-point
  ding + flash.
- **Day/night cycle**: palette inversion every 700 points, lasting 350 points
  so day and night alternate evenly regardless of speed; a stationary
  crescent moon and twinkling stars, with clouds drifting past in front.
- **Title screen, pause/resume, game-over panel** with a restart icon copied
  pixel-for-pixel from Chrome's own sprite sheet.
- **Sound**: jump blip, 100-point ding, crash, plus a 4-channel chiptune
  (pulse lead + harmony, triangle bass, noise drums) for the title, gameplay,
  and game-over themes.

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
