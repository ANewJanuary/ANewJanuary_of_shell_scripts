# Marathon wallpaper shaders — reference guide

Reference for working on the animated wallpapers in this folder (written mainly
for an LLM assistant picking this up cold). All of them are original procedural
pieces in the graphic style of Bungie's *Marathon* (2025): lime / electric blue
on near-black, microtext, hard-edged UI graphics. The reference wallpapers live
in `~/Vshrd/Projects/Visual/backgrounds/cyber_green/`.

## Running them

- `../wallshader.sh` runs a shader with **shaderbg** on every niri output.
  - `wallshader.sh` cycles to the next `*.frag` in this folder (alphabetical).
  - `wallshader.sh <name>` switches to `<name>.frag`.
  - `wallshader.sh --restore` restarts the last one (used at login).
  - `wallshader.sh --list` lists the shaders.
  - Only `shaders/*.frag` is picked up; subfolders (like `tools/`) are ignored.
- The first line `// fps: N` overrides the default 144 fps. All shaders here use
  `// fps: 30` (they are slow-moving and 30 fps keeps GPU use low).
- Main monitor: DP-1, 2560x1440 @ 144 Hz, niri scale 1.25. "px" in this guide
  means physical pixels on that monitor unless stated otherwise.

### shaderbg API

Shadertoy-style: write `void mainImage(out vec4 fragColor, in vec2 fragCoord)`.
shaderbg prepends `#version 450` and these uniforms, and appends a `main()`:

```glsl
uniform vec3 iResolution; uniform float iTime; uniform float iTimeDelta;
uniform int iFrame; uniform vec4 iMouse;
uniform sampler2D iBufferA..iBufferD;   // multipass buffers (--shaderA..D), unused so far
```

There is no `iChannel`/texture input; everything is procedural. Multipass
buffers exist (`--shaderA` etc.) if a real bloom/blur pass is ever wanted, but
`wallshader.sh` does not pass them yet.

### Previewing without touching the desktop

`tools/preview.sh shader.frag out.png [t1,t2,...] [WxH]` renders headless on the
GPU (moderngl via EGL inside `nix shell`), with the same header shaderbg uses.
It saves a half-size PNG per time and prints the average GPU ms/frame at the
chosen resolution (default 2560x1440). Use it to check compile errors, look at
frames, and keep cost in check before switching the live wallpaper. Crop with
`magick in.png -crop WxH+X+Y -resize 200% out.png` to inspect detail.

Current cost at 1440p: signal ~1.4 ms, slabs ~0.7, city ~3.3, corridor ~1.4,
conduit ~3.2, attach ~2.7. Anything under ~5 ms is fine at 30 fps.

## Shared conventions

### Text: `tools/gentext.py`

All microtext uses a baked 5x7 pixel font. In a shader:

```glsl
// @text
// NAME   TEXT OF THE LINE
// TICK   NN STABILITY [FAILING]      //~~~~~~
// @endtext
// @gen
// @endgen
```

Run `tools/gentext.py file.frag` after editing the `@text` block. It rewrites
the `@gen` … `@endgen` block with `FONT[]`, `TXT[]`, `#define T_NAME` (start index)
/ `N_NAME` (length) per line, and two helpers:

- `float glyphPix(vec2 q, int g)` — one glyph, `q` in font pixels (cell 6x7).
- `float textLine(vec2 p, int start, int len)` — a line, `p` in font pixels,
  origin at bottom-left, advance 6 px per character. Returns 0/1.

Rules and gotchas:
- Upper case only; supported: `A-Z 0-9` and ` !#%()*+,-./:<=>?[]_|`. No `@`.
- Something on this system trims trailing whitespace from saved files, so
  trailing spaces in a line vanish. Use `~` for a space that must survive
  (gentext turns `~` into a space).
- Never edit the `@gen` block by hand; it is regenerated.
- Several shaders keep `const int LS[] / LN[]` arrays built from `T_*/N_*` so
  they can pick a line by index; add new lines there too when extending them.
- To draw text on a 3D surface, compute 2D surface coordinates, divide by a
  font size in world units (`fs`), `floor()`, and call `textLine`. If text
  reads mirrored, flip the axis that runs along the reading direction (see the
  `-stp.x` / `-sx` / `dn > 0.0 ? -u` tricks in corridor/attach).
- Typing animation: pass `min(len, shown)` as the length, where `shown` grows
  with time.

### Look and colour

- Palette is set as `const vec3` at the top of each file. Common names: `LIME`
  (#D4FF00 family), `BLUE` (electric blue ~#1A33FF), `GREEN`, `MOSS`, `NAVY`,
  `ICE`, `MINT`, `WHITE`, `ORANGE` (small accent lights only).
- Light colours in the 3D cities come from `lightCol(k)`: mostly ice/white,
  some mint, a few orange — deliberately *not* mostly lime.
- "Black mist" (`LOW_FOG*`): everything fades to near-black by **absolute
  height** with a drifting noise edge, so the bases of buildings are never
  visible. Present in slabs, city and corridor. `LOW_FOG_H` = how high it
  reaches, `LOW_FOG_POW` = how dark it stays as it rises.
- Hotspots (`HOT`, `HOT_SIZE`, `DENSITY`): a slow value-noise field decides
  where lights/text cluster, so density varies across the scene instead of
  being uniform. Probabilities are written as `(base + k * HOT) * DENSITY`.
- Heights are always whole multiples of a storey/step constant (the user
  wants proper multiples, never arbitrary heights).
- Every shader ends with a vignette and per-pixel grain (`GRAIN`).

### Technique notes

- Hashes: `h11(float)`, `h21(vec2)` (sin-fract), `vnoise(vec2)` value noise.
  All layout is deterministic from hashes, so a scene can be "re-rolled" by
  changing a hash constant (e.g. `lane * 4.4`).
- Anti-aliasing: SDF + `fill(d) = clamp(0.5 - d/PX, 0, 1)`, where `PX` is one
  screen pixel in the current coordinate space. **`fill` is 1 inside (d < 0).**
  If you pass a positive "distance from the edge inside the shape", you get the
  rim, not the interior (this exact inversion was a bug in attach once).
- In perspective shaders `PX` is recomputed per surface with
  `fwidth()` of the world coordinate (see `onPlane()` in conduit).
- Grid DDA through a heightfield is used for slabs (isometric), city and
  corridor (perspective). conduit and attach use analytic ray/plane, ray/box
  and ray/cylinder tests instead.
- Avoid big flat "glow painted over the screen" effects: the user wants fog to
  be distance-based so things behind stay visible.

## The shaders

### signal.frag — flat HUD (BRB / minimal_logo style)

2D only. Design space is 1080 units tall (`p = fragCoord / S`, `S = height/1080`),
width `W` depends on aspect; elements are anchored to corners/centre. Text is
drawn in **screen pixels** with an integer scale `FP = round(height/720)` so it
stays crisp (`txt()`, `num()`, `punct()`).

Elements (each is a `{ ... }` block in `mainImage`, easy to move or delete):
status block top-left (types out, loops every 24 s), dot icon + triangle + IDs,
big up-right arrow with a twitchy number row, centre keyhole `emblem()` with a
ticking ring and an occasional split glitch every 11 s, `noEntry()` + SYNC-WAY
list with cycling states, log blocks, segmented loading bar + hatched block,
crosshair coordinate, AB/YZ readout cluster, bottom ticker (`TICK` line).

Knobs: `BG`, `LIME`, `GREY`, `WHITE`, `GLITCH_EVERY` (band-shift glitches),
`TYPE_SPEED`, `GRAIN`. Dot grids: `dotField(col, p, lo, hi, step, seed, t)`.
The user removed the inverted lime glitch bars on purpose — don't re-add them.

### slabs.frag — isometric CyAc architecture (cyac_arch)

Parallel (isometric-style) projection; DDA over a unit grid in world x/y with z
up. World: lanes 2 units wide along x, no gaps; each lane cut into segments
of length `segLen(lane)` (2..5). Each segment = one block with
`storeys(lane, s)` × `HS` height (`HS = STEP_PX / UNIT`), 1..`MAX_STOREYS`.
Some blocks step up/down one storey over time (pulse in `storeys`).

- `panelType()` picks colour per segment; **`blueLane` threshold (0.47)
  controls the blue/green balance** — tuned to ~50/50 by pixel count.
- `topFace()`: sub-panels (no seams wanted elsewhere, but slabs keeps its
  seams), microtext along or across the lane, LED strips, dot clusters,
  barcode, edge light. `sideFace()`: storey lines, window grid, text, ribs,
  roof-edge light. Orange beacons are added in `mainImage`.
- Knobs: `UNIT` (horizontal scale), `STEP_PX` (storey height, ~100 px
  requested), `MAX_STOREYS`, `SPEED`, `DENSITY`, `HOT_SIZE`, `LOW_FOG_H`
  (in storeys), `LOW_FOG_POW`, palette.

### city.frag — perspective glass city (cyac_arch2 / custom_pattern)

Perspective camera above a city, gliding along +y. DDA grid cell = half a world
unit (`GS = 2`). Blocks are 9x9 cells: four 4x4-cell towers (all the same 2x2
unit footprint — the user does **not** want setbacks or stacked shapes) and a
1-cell street. `towerH()` gives three height classes (low/mid/tall) snapped to
`STEP_H`.

Rendering is layered, front to back, up to 3 towers deep (`trace()` DDA, then
an inner loop): front face (`shadeSide` / `shadeTop`) with alpha, then the
inside of the tower — floor slabs crossed, haze, optional solid core, back
wall — then continue into the towers behind. Wall alpha goes from
`SIDE_ALPHA` at the top to `BASE_ALPHA` at the street. Frosted glass jitters the
ray on entry (`FROST`) and adds a milky veil (`FROST_VEIL`).

- Colour choice: `vec3 base = kt < 0.34 ? GREEN : ...` and `blueSide` in
  `mainImage`. Accent storey bands in `shadeSide`.
- User preferences baked in: no roof sub-panel seams, no lines between storeys,
  text less dense (`TEXT_DENSITY 0.7`).
- Knobs: `MIRROR` (0/1/2 kaleidoscope), `SPEED`, `CAM_H`, `PITCH`, `FOV`,
  `STEP_H`, `DENSITY`, `TEXT_DENSITY`, `HOT_SIZE`, `SIDE_ALPHA`, `ROOF_ALPHA`,
  `BASE_ALPHA`, `INNER_PASS`, `FROST`, `FROST_VEIL`, `CORE_CHANCE`, `CORE_GLOW`,
  `CORE_BLUR` + `CORE_SAMPLES` (frosted blur of the core: several jittered rays
  from the glass entry point, so blur grows with the glass-to-core gap),
  `CORE_MILK` (haze between glass and core),
  `LOW_FOG_*`, `HMAX` (max tower height; keep below `CAM_H`).

### corridor.frag — street canyon of panel buildings (greenbox / redbox)

Perspective, eye at `EYE` walking +z along a street. DDA over a 1x1 x/z grid.
`bldH()` defines the city: street `|x| < NARROW`, cross streets every
`CROSS_P`, rows of buildings of depth `LANE_W - 1` with 1-cell alleys between
rows, each row cut into buildings of length 2..5 with an alley after each.
Rows further back are taller. `rawH()` gives raw heights; `bldH()` then moves
every other building so neighbours differ by at least `MIN_DH`.

- Facades: `panels()` — 2x2 macro cells of rounded panels in four layouts,
  indicator LED per panel, dark stencilled panels with codes, per-building hue
  (`PANEL` / `PANEL_A` greener / `PANEL_B` bluer).
- Sky: `farSky()` is a static backdrop that depends only on view direction:
  three hazy megastructures with hanging lights, five layers of distant towers
  with spires, sky bridges and lit windows, drifting specks.
- Fog is pure distance fog (`FOG_D`) toward a brighter far colour; then black
  mist by height. Dust motes are a screen-space overlay (`motes()`).
- Knobs: `THEME` (0 green/teal, 1 red/magenta — palette in `setTheme()`),
  `SPEED`, `EYE`, `NARROW`, `LANE_W`, `CROSS_P`, `CROSS_W`, `STEP`, `MIN_DH`,
  `HMAX`, `TMAX`, `FOG_D`, `LOW_FOG_*`. The front row starts at height 9 so its
  roofs stay above `EYE`; if you lower it, roofs become visible and need a
  texture (currently flat `GAP * 2.0`).

### conduit.frag — cables over a motherboard ("transistors")

Tilted pinhole camera (`TILT`, `CAM_H`, `FOCAL`) looking down at a floor,
scrolling along +y and drifting sideways. Everything is analytic:
`onPlane(h)` gives the world xy where the view ray meets height `h` and sets
`PX`. Layers, bottom to top:

1. Board (`boardCol`): base `MASK` (same grey as `BG`), routed traces with 45°
   jogs (`traces()` / `traceSeg()`), gold vias at trace ends, mounting holes,
   lime pulses on some traces, pads + silkscreen per part, part shadows,
   platform shadow.
2. Parts (`compAt` / `hitComp` / `shadeComp`), one per `CELL` at most, kept
   out of the spine area: chips, capacitors (cylinders), heatsinks, memory
   slots, SMD resistors. Density = the `r <` thresholds in `compAt` (currently
   ~27% of cells occupied; user asked twice for less density).
3. Spine platform: segmented boxes `|x| < PW`, height `PH`, pitch `PL`, gaps
   `PG`, with blue conduit rods bridging the gaps; deck graphics in
   `spineCol()`; modules (boxes, `MH` tall) on top.
4. Cables: 10 tubes, `cableAt(k)` / `cableH(k)` define draw order and height
   (150..400); cylinder lighting, printed labels/barcodes/icons, shadows from
   everything above via `shadowAt()`.
5. Wires: 14 thin green wires at 450..530 with travelling `SIGNAL` pulses and
   numbered nodes.
6. Big code numbers top-right in screen space.

Knobs: `SCROLL`, `CAM_H`, `TILT`, `FOCAL`, `LIGHT` (shadow offset per unit
height), `PULSE`, palette, `PW/PH/PL/PG/MH`, `CELL`, `HCOMP` (must be ≥ the
tallest part). Keep cables above the platform+modules and wires above cables,
or the layered draw order will look wrong.

### attach.frag — hall of glass panels (reveal cinematic still)

Perspective walk along +z through rows of standing panels (`panelAt(k, side)`),
`ROW` apart, either along the walkway or standing across it. Kinds: frosted
glass with prints, white printed board, teal pixel-mosaic screen
(`mosaic()`). `prints()` draws the `*ATTACH HERE` strip, crosses, hazard
stripes, label + barcode, corner marks. `traceHall()` composites panels front
to back (approximate order by row; no sorting) and returns the remaining
transmittance; the floor (`floorCol()`: zebra bands, chevrons, tiles, stencil
text, lime edge lines, grating) is shaded after, with a glossy reflection that
re-runs `traceHall` along the reflected ray.

Knobs: `SPEED`, `ROW`, `HALL`, `ROWS` (trace distance / cost), palette. Panel
mix: `P.kind = kk < 0.45 ? 0 : kk < 0.75 ? 1 : 2` in `panelAt`.

## Working with the user

- They give live feedback on the real monitor; switch the wallpaper with
  `wallshader.sh <name>` after a change, and check frames with
  `tools/preview.sh` first.
- Preferences so far: dense but not cluttered, hotspots instead of uniform
  density, varied light colours (not all lime), strong height contrast in
  whole steps, black mist at the bottom, true transparency and depth rather
  than overlays, no grid seams on sub-panels.
- Don't recreate Bungie's logos or characters; the style, palette and generic
  UI language are fine.
