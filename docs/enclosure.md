# Enclosure

> **Note:** the load cell and its density feature were removed from the electronics. The
> cup now just rests on the platform (a passive shelf); the weighing, tare and
> specific-gravity passages below are historical and no longer apply.

The enclosure is not a box to hide the wiring in. Two of the features the model uses —
colour and turbidity — are really *mechanical* measurements, and the enclosure is what
makes them repeatable. Get the light shrouding wrong and no amount of retraining fixes it.

The printable model is [`hardware/enclosure.scad`](../hardware/enclosure.scad). Every number
below is a variable at the top of that file, and the file is the one to trust if the two ever
disagree. Render a part with:

```bash
openscad -o body.stl -D 'part="body"' hardware/enclosure.scad
```

---

## 1. Form

**A single squircle tower with a telescoping column — 126 × 136 × 220 mm, 286 mm to the top
of the cap.** That is 3.8 L against the previous revision's 12.4: seventy percent smaller,
because the electronics moved *under* the cup instead of sitting beside it. That change also
deleted the two-shell split, and with it every seam that used to run up the sides.

Every external profile is a superellipse — `|x/a|⁵ + |y/b|⁵ = 1` — not a circular fillet.
This is the whole difference between a squircle and a rounded rectangle: a circular fillet is
only G1 continuous, so curvature jumps from zero to 1/r at the tangent point, and that
discontinuity shows up as a hard line in the highlight. A superellipse's curvature varies
continuously, so the highlight sweeps across the corner without a break. The top plate carries
the same treatment vertically — a G2 shoulder built from a superelliptic profile in Z — so the
flat top meets the side wall the way the corners do.

The fascia recess and the drawer front are squircles too. A rounded-rectangle window cut into
a squircle body is the tell of a language copied rather than understood.

### What is open to the outside — the complete list

| Opening | Where | Label |
|---|---|---|
| Pour dish | top of the column cap | **MILK**, engraved 0.4 mm |
| Tank neck | top plate, rear | **DISTILLED WATER**, engraved 0.4 mm |
| Drawer aperture | front | — |
| USB-C | rear, centred | — |
| Intake slots | underside only | — |

That is everything. No screw appears on any exterior surface: four magnets hold the top
plate, three hold the cap, and a locating lip does the aligning.

> **If the preview looks full of holes, it is the preview.** OpenSCAD's F5 view shows
> backfaces in green and draws the fascia mock as a translucent panel, so you are looking
> straight through the front at the ribs, bosses and ledges behind it. Press F6, or export an
> STL, and the body is a closed shell.

Engravings are recessed rather than embossed: raised text wears at the high points and traps
milk in its corners, while a 0.4 mm recess just holds a shadow line and wipes clean.

---

## 2. The vertical stack

```
      ╭───────╮   286   cap · MILK dish
      │COLUMN │        lifts 55 mm — it is its own piston
      │ probes│
  ┌───┴───────┴───┐  220   top plate · DISTILLED WATER neck · G2 shoulder
  │   cup 85 mL   │  178   cup rim
  │───────────────│  121   drawer plate — pull, dump, push back
  │  load cell    │
  │───────────────│   75   drop-in shelf, the load-cell datum
  │ tank · pump   │        486 mL tank against the rear wall
  │ boards · USB  │
  └───────────────┘    0   undercut base, 6 mm tall, stepped in 3 mm
   ◄───── 126 ─────►
```

---

## 3. Cup, bore and dose

**The bore is set by the probes, never by the volume.** The turbidity body has to sit *in* the
sample, and the pH probe has to fit the annulus beside it, with real plastic between them:

```
bore ≥ turb_body_d + 2 × (ph_probe_d + 2×probe_gap + 2×rib_min)
 67  ≥ 35         + 2 × (12         + 1.2         + 2.4)
```

⌀62 is the arithmetic minimum and leaves 0.3 mm of rib. It is not buildable. At **⌀67** the
ribs come out at 1.6 mm inside and 1.2 mm outside, and the script echoes both on every render.

**Dose 85 mL** → 24.1 mm of fill → **19.1 mm of pH immersion**. That is deliberately near the
floor: most pH probes only strictly need the bulb and reference junction covered. It is the
one number in this design with no margin, so check pH settling time during calibration before
committing to it.

(The cup volume no longer feeds any measurement — density was removed — so the exact
fill level only matters for keeping the probes submerged.)

---

## 4. How you use it

1. Pour the sample into the **MILK** dish on the cap. It runs down a duct into the cup.
2. Single tap.
3. After the verdict: lift the column, pull the drawer, tip the cup out, push it back. The
   pump then rinses the probes with distilled water.

Pushing the drawer home walks the cup up a 1.5 mm chamfer onto the load-cell platform, so at
rest it touches nothing but the cell, with 4 mm of clearance all round.

### Why the column has to move

The probes hang *into* the cup, so the cup cannot slide out horizontally past them —
something has to separate vertically first. Making the column its own piston is the smallest
mechanism that does it: one sliding part, no linkage, and it is mechanically isolated from the
load cell, so if it ever binds it cannot put a gram into the reading.

The cap is keyed by three magnets on a deliberately **asymmetric** triangle. Three magnets at
120° would let it seat three ways, and only one of those puts the pour duct over the fill slot.

---

## 5. Water, waste and cleaning

**One pump, fill only.** It draws from the 486 mL internal tank and discharges over the probes
into the cup. Its job is rinsing the sensors, not emptying the machine — you empty the machine
by pulling the drawer. There is no drain pump, no dip tube and no vent hole, because the pour
dish vents.

**Between samples:** tip the cup, then one pump rinse. Because you dump the cup rather than
diluting it, a rinse only has to clear films off the probes — about 60 mL, so a tank lasts
roughly eight tests. (Diluting instead of dumping is what makes flushing expensive: a chamber
that cannot empty clears as `C₀·e^(−V/vol)`, needing three volumes of water to reach 5 %.)

**Daily:** cup out, warm water and a soft brush. Milk leaves a protein and fat film water
alone will not lift, and that film sits on the turbidity body's optical gap and on the pH
bulb, where it stops being hygiene and becomes sensor drift. Wipe both, plus the colour
window.

> **Never clean with detergent unless you can prove you rinsed it out.** Detergent is one of
> the four classes this device exists to detect, and a residue film reads as a
> detergent-adulterated sample — convincingly.

**The blank check.** Fill with distilled water and run a normal test. TDS should fall back to
its distilled baseline and turbidity to clear; pH should sit near 7 and settle quickly rather
than crawling. The sensors are the honest instrument for judging your own cleaning.

**Idle:** the pH bulb must never dry out. Lift the column off and cap the probe in storage
solution.

---

## 6. The rules that actually matter

1. The cup touches **only** the platform when seated. The drawer's ⌀78 hole clears the ⌀70
   platform by 4 mm all round; anything bridging that gap — a wire, a drip of dried milk — is
   read as grams and therefore as density.
2. The load cell is bolted, not clipped. Four M4 bolts through the shelf into a printed-in
   pedestal, nuts trapped underneath. A snap-fit anywhere on the measurement path is
   compliance, and compliance reads as tare drift. Every one of those bolts is internal.
3. Print the shelf at 6 perimeters and 60 % infill. It is the datum.
4. Four rubber feet, level bench, re-tare after moving. A bar cell is tilt-sensitive.
5. The colour sensor stays dry, behind a glued acrylic window in the side wall, looking at the
   cup through a hood. Paint the interior matt black — ambient light landing on it rides
   straight into four of the model's features and changes with the time of day.

---

## 7. Power

One port means USB-C, and USB-C means a decision. Wi-Fi peaks near 500 mA on 3V3 and the pump
adds a few hundred more, so plain 5 V from a laptop port is marginal. Use a **USB-C PD trigger
board (≈₹150) set to 9 V**, feeding one LM2596 at 6 V for the pump and a second at 5 V for
logic. **Set both converters before assembly** — their trimpots are no longer reachable, which
is the price of a clean rear face.

---

## 8. Materials

Matte PETG. Not PLA — it creeps under a bolted load cell and does not survive repeated
cleaning. Print visible faces at 0.10–0.12 mm: a squircle only reads as a squircle when the
layer lines disappear into the curve.

The cup and the tank hold liquid — 5 perimeters each, and run a silicone bead on the tank's
lid seam. An unsealed printed tank weeps, quietly, into the electronics beneath it.

Bought separately: ⌀6 × 3 N35 magnets (7), 2 mm smoked acrylic for the fascia (~102 × 78), a
small acrylic offcut for the colour window, four M4 bolts and nuts, silicone tube.

---

## 9. Assembly order

1. Print and dry-fit the body, shelf and drawer. Check the drawer runs freely and the cup
   walks onto the platform as it closes.
2. Mount the load cell, riser and platform. Tare, then press on the body in a few places — the
   reading should return to zero. If it drifts, the shelf is not seated on its ledge.
3. Base: tank and lid sealed and leak-tested with water **before** anything electrical goes
   near them. Then pump, converters, PD trigger.
4. Boards on the shelf, display and touch pad behind the fascia, USB-C aligned to its cutout.
   Confirm stage-1 firmware boots before adding sensors one at a time, per
   [wiring.md](wiring.md).
5. Probes into the column carrier, cables down through the cable exit, with a service loop
   long enough for 55 mm of column travel.
6. Fill the tank, run *Flush test* dry, then with water, and check nothing wets the shelf.
