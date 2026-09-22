# Enclosure — the working box

> **Note:** the load cell and its density feature were removed from the electronics. The
> cup now just rests on the platform (a passive shelf); the weighing, tare and density
> passages below are historical and no longer apply.

Model: [`hardware/enclosure-simple.scad`](../hardware/enclosure-simple.scad). Separate file;
it does not replace `enclosure.scad` or `enclosure-lab.scad`.

**232 × 178 mm footprint. Wet bay 161 tall, dry bay 95.** Five printed parts, no supports,
body prints in one piece on a 256 bed.

The wet bay is 112 mm wide for a ⌀76 cup — **18 mm of finger clearance per side**. That is
not slack, it is the requirement: you lift a full cup of milk out of it on every test, and
with only the 8 mm the cup itself needs, you physically cannot grip it.

No styling and no mechanism — this exists to be built once, installed easily, and lived with.

---

## What goes where

```
   ┌──────────────┐
   │   WET BAY    │ 161 tall            ┌──────────────────┐
   │  cup on the  │                     │     DRY BAY      │ 95 tall
   │  load cell   │                     │ perfboard on     │
   │  HX711 behind│   ← partition →     │ rails, pump      │
   │  nozzle on   │                     │ underneath       │
   │  rear wall   │                     │ TFT + pad front  │
   │  floor = drip│                     │ USB + 12 V rear  │
   └──────────────┘                     └──────────────────┘
```

The partition is full height and solid. **Four wires cross it** (VCC, GND, DT, SCK) through
two ⌀16 glands at z = 75, plus the feed tube at z = 68.

Those heights are not arbitrary. A full 175 mL sample dumped on the wet floor pools about
**11 mm** deep, so every crossing sits far above it. They are also *below* the dry bay's
ceiling at 95 — the partition keeps rising past the dry bay to full wet height, so anything
placed higher would open into open air instead of into the electronics bay.

---

## The five files

| File | What it is |
|---|---|
| `body.stl` | The tray. Both bays, the partition, the load-cell pedestal, the perfboard rails, and every cutout. The only big print |
| `wet_lid.stl` | Probe carrier. Holds the four probes, lifts off by its two rails |
| `dry_lid.stl` | Cover over the electronics. Snaps on, no tools |
| `platform.stl` | The disc the cup stands on. Bolts to the load cell's free end |
| `riser.stl` | Spacer between the load cell bar and the platform |

`platform` and `riser` are the two parts in the load path — print them at 6 perimeters and
60 % infill. If they flex, it reads as drift in your density measurement.

## The stack, bottom to top

Heights are from the outside of the box's floor, so you can check them with a ruler:

```
   161  ── wet lid underside
   152.5── cup rim
   131  ── milk surface (175 mL)
    85.5── inside of the cup floor
    82.5── platform top          ← the cup stands here
    77.5── platform bottom       platform.stl, 5 thick
    65.2── riser top             riser.stl, 12.3 thick
    52.5── load cell bar top     bar is 12.7 thick
     3   ── pedestal base        printed into the floor, 49.5 tall
     0   ── bench
```

The pedestal is tall on purpose. The probes hang from the lid and only the pH probe is long
enough to reach far down, so the pedestal lifts the milk up to meet the short ones.

## Every fastener in the box

| Joint | Fastener | Notes |
|---|---|---|
| Load cell **fixed end** → pedestal | 2 × **M4 × 55**, from **underneath the box** | Heads recess into the hex pockets in the floor. 15 mm apart |
| Load cell **free end** → riser → platform | 2 × **M4 × 25**, from **above**, down through the platform | Counterbored so the heads sit below the cup floor. 15 mm apart |
| TFT | 4 × M2 × 6 self-tapping | Into the bosses behind the window |
| TCS34725 | 2 × M2 × 6 self-tapping | Into the two bosses on the partition |
| HX711 | 2 × M2 × 8 self-tapping | Into the two floor posts |
| Pump | 1 zip tie | Over the pump, through the two floor loops |
| Perfboard | **none** | Drops onto the rails; four snap tabs hold it |
| Dry lid | **none** | Four snaps |
| Wet lid | **none** | Drops into the opening |

Nine screws and one zip tie for the whole instrument.

## Installing it

1. **Load cell first.** Bolt the fixed end to the pedestal printed into the wet floor — M4
   through, head recessed in the hex pocket underneath. Then `riser`, then `platform` on the
   free end. Platform top lands at **z = 82.5**.

   That pedestal is deliberately tall. The probes hang from the lid, and only the pH probe is
   long enough to reach down a tall cup — a 50 mm DS18B20 cannot span from the lid to liquid
   sitting at the bottom of a 105 mm one. So the cup is short and the pedestal lifts the
   liquid up into probe reach instead.
2. **HX711** on the two stand-offs behind the cell. Coat it as you planned; keep the four
   bridge wires short and twisted, and run only the four digital/power wires through a
   partition gland.
3. **TCS34725** on the two M2 bosses on the wet face of the partition, at mid-liquid height,
   looking at the cup across a 4 mm air gap. No hood needed — the closed wet bay is its dark
   box. R, G, B and Clear are four of the model's features, so this one is not optional.
3. **Pump** on the dry bay floor, front-left. It lives *under* the board, with 7 mm of
   clearance over it.
4. **Perfboard** drops in from above onto the rails at z = 50 and is trapped by four corner
   clips. No screws, and no mounting holes needed in the board. Front and rear stops locate it.
5. **TFT** onto the four M2 bosses behind the front window; the touch pad goes behind the
   blind pocket beside it — there is a shallow dimple on the outside so you can find it.
6. **Ports**: panel micro-USB and the 12 V jack in the rear wall of the dry bay. The
   distilled-water line enters the rear wall too, runs to the pump, crosses the partition, is
   restrained by the boss on the wet bay's rear wall, and **plugs into the nozzle hole in the
   wet lid** at the 30° position.

   That outlet is in the lid, not the wall, and it had to be: the cup fills the bay to within
   8 mm of each side wall and its rim clears the lid by only 8.5 mm, so no wall position is
   actually over the cup — water from a wall nozzle lands on the floor. Leave a service loop
   long enough to set the lid down beside the box with the tube still attached, and tie it off
   at the wall boss so the loop never pulls on anything.
7. **Probes** into the wet lid: turbidity down the centre, pH / TDS / DS18B20 on the 27 mm
   bolt circle, one spare ⌀8 gland.

**Nothing may touch the cup.** That is the whole requirement for the density reading — the cup
sits on the platform and is otherwise surrounded by air. Clip the probe leads to the lid and
to the box, never to the cup.

---

## Using it

1. Lift the wet lid off by its two rails — no fasteners. **Park it inverted across the open
   wet bay**: the rails land on the box's own left wall and partition, and the probes point
   safely up. Do not lay it on the bench — 80 mm of pH probe sticks up above the plate, so on
   a flat surface the lid balances on that one probe.
2. **Lift the cup out and fill it at the sink**, to the weir. Overfilling is the point — the
   weir sets the volume, and that is what makes density comparable between samples. Fill it
   outside the box and the overflow goes down the drain instead of onto the bay floor.
3. Cup back in, lid on. Tap. Read.
4. Lid off, cup out, dump the milk, cup back, lid on.
5. Tap. It pumps distilled water over the probes and into the cup.
6. Lid off, cup out, dump the water, cup back, lid on. Ready.

There is **no waste plumbing anywhere** — you dump the cup by hand, which is why one pump is
enough, and why the rinse actually cleans instead of diluting.

---

## Printing

| Part | Orientation |
|---|---|
| `body` | as rendered — 212 × 178 × 161 |
| `wet_lid` | flat, feet upward |
| `dry_lid` | flat |
| `platform`, `riser` | flat, 6 perimeters, 60 % infill — these carry the weighing |

```bash
openscad -o body.stl -D 'part="body"' hardware/enclosure-simple.scad
```

Walls are **3.0 mm on the wet bay and 2.4 mm on the dry bay and lids**. The load cell reacts
against the wet frame and a box that flexes shows up as tare drift; nothing on the dry side
cares. Outer faces stay flush — the dry bay is simply 1.2 mm roomier inside.

Not printed: the cup (acrylic tube **⌀70 ID / ⌀76 OD × 70 tall**, ⌀6 weir hole drilled 45.5 mm
above the inside of its floor), load cell, HX711, TCS34725, perfboard, pump, tube, fasteners.

---

## Before you print

- **Measure every probe's length, and read the reach check.** This is the most important check
  in the file. Each probe hangs from the lid and has to physically span down into the liquid;
  the script prints one line per probe, and all four currently pass:

  ```
  Reach pH:      needs 69.5 mm below the lid, probe is 150  OK
  Reach TDS:     needs 45.0 mm below the lid, probe is  60  OK
  Reach DS18B20: needs 45.0 mm below the lid, probe is  50  OK
  Turbidity gap: z=121 — liquid is 85.5..131.0  OK, 10.0 mm under the surface
  Turbidity tips: z=114 vs cup floor 85.5  OK
  ```

  Put your measured lengths into the `probes` list. If a line says SHORT, raise `ped_h` — it
  lifts the liquid toward the lid — but keep the cup rim under 155. Never solve it by letting
  a probe hang on its cable: a probe that can swing into the cup wall puts a force path into
  the weighed assembly and destroys the density reading.

- **The turbidity sensor hangs inverted, and that is deliberate.** Per its datasheet it is
  ⌀30 at the base, 34 tall, with two arms 22 mm across and a 5.7 mm optical gap between them,
  and it is designed to mount in a tank floor with those arms pointing *up*. It cannot be used
  that way here — anything fastened to the cup is a force path into the load cell. So it drops
  into a printed collar under the lid, arms down in the milk, **pins up and dry**, positioned
  so the optical gap sits 10 mm below the surface. `turb_drop` is the adjustment.

  Its ⌀30 base is also what sets the minimum cup bore: `cup_id ≥ 30 + 2 × (12 + 1.2) = 56.4`.
  At ⌀70 there is plenty of margin, so the box is not bore-limited.
- **Confirm the perfboard.** Modelled at 152 × 102 with 5 mm clearance each side.
- **Your build uses a 3.3 V relay**, not the IRF520 + 2N2222 in the BOM. The enclosure doesn't
  care, but [`docs/wiring.md`](wiring.md) is now wrong for your hardware on that point, and
  relay modules are commonly **active-LOW** — which is exactly what `PUMP_ACTIVE_LOW` in
  [`sensors.h`](../libs/AquaMilkSensors/src/sensors.h) exists for. Check it before the first
  flush test.
