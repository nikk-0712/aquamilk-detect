# Enclosure — bench instrument

Model: [`hardware/enclosure-lab.scad`](../hardware/enclosure-lab.scad). This is a separate
file and a separate design; it does not replace `hardware/enclosure.scad`.

**140 W × 200 D × 320 H mm.** One prism, superellipse corners, a control facet cut off the
front-top edge at 30°, and three labelled things you touch.

---

## Where everything goes

Every point you interact with is engraved into the surface beside it, so the machine tells
you what it wants without a manual.

| Label | Where | What goes there |
|---|---|---|
| **MILK** | Front, middle band — the big drawer | The sample cup. Pull the drawer out, stand the cup in the round pocket, fill it, push it back in |
| **DISTILLED WATER** | Top surface, behind the round carriage | The flush tank, ~450 mL. Unscrew the cap marked WATER and pour in |
| **WASTE** | Front, bottom band — the shallow tray | Nothing goes *in*. Pull it out and empty it when the rinse water builds up |

Nothing else on the outside opens. The rear carries the power jack and the USB port on one
centreline; the sides carry one vent band each; the underside is the air intake.

**The screen** sits behind the dark panel on the angled facet, with the touch pad below it
behind the same panel. Both are invisible until the display lights. The facet is angled
because a bench instrument is read from above, and the ST7735 is a TN panel — mounted
vertical it washes out at exactly the angle you stand at.

---

## The one thing that isn't obvious

**Lift the round carriage on top before you pull the drawer.**

The probes hang about 100 mm down into the cup. The cup physically cannot slide out past
them, so something has to separate vertically first. The carriage is a plug that slides
straight up in its socket: down, it sits flush and the machine is a closed box; up, the
probes clear the cup and the drawer is free.

If the drawer feels stuck, the carriage is still down. It is the only interlock in the
machine, and it is a mechanical one.

---

## Running a test

1. **Lift** the carriage on top.
2. **Pull** the MILK drawer out.
3. **Stand the cup** in the pocket and fill it with your sample. Fill past the weir hole in
   the cup wall — the excess runs out, and that overflow is what makes the volume
   repeatable. `MAX 175 mL` is engraved on the drawer beside the pocket.
4. **Push** the drawer in. The cup rides up a 2 mm chamfer onto the platform and settles
   there, touching the load cell and nothing else. That isolation is the entire reason the
   density reading works.
5. **Lower** the carriage. The probes enter the sample to a fixed depth.
6. **Tap** the pad. Read the verdict.
7. **Lift, pull, take the cup out, empty and rinse it by hand.**
8. **Push the empty drawer back in, lower the carriage, run the rinse.** Water from the tank
   runs over the probes and falls through the drawer's drain into the WASTE tray.

The rinse is a **probe rinse, not a cup flush** — you wash the cup at the sink. That is
deliberate: a cup that cannot drain can only be diluted, and 5 s of pumping removes about
5 % of the milk in it. Washing by hand removes 100 %.

---

## Cleaning

- **Between samples** — hand-wash the cup, run one probe rinse.
- **Daily** — lift the carriage right out and wash the probes properly. Milk leaves a protein
  and fat film that water alone will not lift, and it lands on the turbidity body's optical
  gap and the pH bulb, where it stops being hygiene and becomes sensor drift. Wipe the colour
  window in the left wall. Empty and rinse the WASTE tray.
- **Idle** — cap the pH bulb in storage solution. It must never dry out.

> **Never clean with detergent unless you can prove you rinsed it out.** Detergent is one of
> the four classes this device exists to detect, and a residue film reads as a
> detergent-adulterated sample — convincingly.

**Check your own cleaning with the instrument.** Fill the cup with distilled water and run a
normal test: TDS should fall to its distilled baseline, turbidity to clear, pH near 7 and
settling quickly rather than crawling. If not, something is still dirty.

---

## Parts and printing

Nine printed parts, largest footprint 140 × 200 — a 220 mm bed covers all of them, and none
needs supports.

| Part | Orientation |
|---|---|
| `base` | as rendered, open side up |
| `bay` | as rendered — its front is open by design, the drawer face fills it |
| `head` | **upside down**, so the facet prints as a receding wall |
| `carriage` | as rendered |
| `sample_drawer`, `waste_tray` | as rendered, open side up |
| `platform`, `riser` | flat. 6 perimeters, 60 % infill — these carry the weighing |
| `tank_cap` | flat |

```bash
openscad -o head.stl -D 'part="head"' hardware/enclosure-lab.scad
```

Engravings are recessed 0.5 mm, never raised: raised text wears at the high points and traps
milk in its corners, while a recess just holds a shadow line and wipes clean. Cap height is
5.5 mm, the smallest a 0.4 mm nozzle holds cleanly.

Not printed: the cup (acrylic tube, ⌀70 ID × 105, with a ⌀6 weir hole drilled 45.5 mm above
the inside of its floor), the load cell, the dark facet panel, the colour window, magnets,
silicone tube, fasteners.

---

## Still open

- **The rinse pump is not in the firmware.** Nothing sequences it; the tank, pump and nozzle
  are enclosure features only.
- **`turb_body_d` is the riskiest number in the model.** Measure your turbidity sensor before
  printing: it sets the cup bore, the bore sets the cup, and the cup sets the width of the
  whole instrument.
- **The carriage has no detent yet.** It slides and seats, but nothing holds it up while you
  work — today you hold it, or rest it at the top of its travel.
