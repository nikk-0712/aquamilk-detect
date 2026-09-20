# AGENT PROMPT 7 — Enclosure (3D-printed) for Aqua Milk Detect

**Read `PROJECT_CONTEXT.md` first** (hardware §2, pin map §3, design language §9). This brief adds everything mechanical. **Act as a professional product + mechanical design engineer** — Apple-grade industrial design, but manufacturable on a home FDM printer with no screws. Do not cut corners; **do not miss anything below**; and **run the Self-Review checklist (§13) and fix all issues before you ship.**

---

## 0. Deliverable format
Produce a **parametric model in CadQuery (Python)** — preferred, because you can run it, parameterise every dimension, and export automatically. (OpenSCAD acceptable if you justify it.) Output:
- One parametric source file per part + a shared `params.py` (all key dimensions/tolerances as named variables).
- **Print-ready `STL` per part** and a `STEP` of the full assembly.
- An **exploded-view render (PNG)** and an assembled render.
- `ASSEMBLY.md` (snap order, magnet placement, cable routing) and `PRINT.md` (orientation, supports, bed mapping, material).
- A **printed-parts BOM** and a **hardware BOM** (magnets, tubing, drop-in cup, drop-in bottle, heat-shrink).
Everything must be regenerable by running the code.

---

## 1. What the device is (so the mechanics make sense)
A benchtop milk-purity tester. A user pulls out a **drawer**, drops milk into a **removable cup** up to an **etched fill line**, pushes the drawer in, and taps to weigh. A **bayonet sensor head** above the well is then **pushed and rotated 90°** so all probes plunge into the milk; a second tap reads the sensors; the ESP32 classifies. After the test the user raises the head, pulls the drawer, empties the cup, reinserts it, and a single pump squirts distilled water to rinse the probe tips. See PROJECT_CONTEXT §7/§8 for the electronics.

---

## 2. Industrial design language
- **Form:** low rectangular lab-instrument block, calm and seamless. Gentle **2–3 mm fillets** on all outer vertical edges; crisp but not sharp.
- **Colour:** **space-grey body** with **dark-blue accents** (NOT aqua). **Accents live ONLY on the top-most surfaces/top layer** (the angled front bezel edge + the recessed logo) so a single-extruder printer does at most **one filament swap near the end** — or deliver it **single-colour** (space-grey only) as an equally acceptable option. Never require mid-print swaps on internal layers.
- **Surface finish:** apply a **fine matte micro-texture** to all show surfaces (e.g. a subtle fuzzy/stipple or a shallow horizontal brush grain modeled into the faces, or specify a print texture) so it reads as a finished product, not a raw print. Chamfer/round every visible edge. **Recessed, debossed logo + "Aqua Milk Detect" wordmark + tagline "Milk purity in seconds"** on the top.
- **No transparent parts anywhere.** The TFT's own glass is the only "window" (it sits flush in a cutout). No added clear covers.
- **No screws anywhere.** Assembly is **snap-fit cantilever clips + alignment keys/dovetails**, with **embedded magnets** only on the two frequently-opened parts (rear reservoir door, cup lid if used).
- Hidden seams; all fasteners/joints concealed. **No visible wires** — everything routes in internal channels.

---

## 3. Overall envelope & the hard constraints
- **Printer bed: 250 × 250 × 250 mm.** Every single part must fit within that. Split the shell into snap-together modules accordingly.
- **Perfboard to house: 150 × 89 mm** (the 9×15 cm board), ~1.6 mm thick, with modules standing up to ~18 mm tall on top and connectors on its front edge. Provide a bay with **≥4 mm clearance around the board**, standoff bosses, and cable room above.
- **pH probe: 16 cm of rigid body** ending in the glass bulb — this sets the vertical stack. Head-up must clear the cup; head-down must submerge the bulb. Budget ~**180–200 mm** of vertical travel space for the probe + plunge + cup.
- **Target overall size (you refine):** roughly **W 150 × D 210 × H 240 mm**, staying ≤ 250 mm in every axis. If any part would exceed 250 mm, split it with a hidden snap joint.

---

## 4. Part breakdown (all snap-fit, each ≤ 250 mm)
Design at least these modules; add alignment keys so they self-locate:
- **A. Base chassis / tub** — feet, houses the electronics bay + rear utility bay; drawer rails.
- **B. Electronics bay** (inside A) — perfboard cradle + vents.
- **C. Rear utility bay** — removable distilled-water reservoir + pump mount, magnet door.
- **D. Drawer** — carries the removable cup, the load cell + HX711 satellite; slides on rails; hard-seat detent; interlock catch.
- **E. Removable cup + cradle** — the milk vessel + its locating cradle on the load cell.
- **F. Sensor-head assembly** — bayonet collar + head carriage holding all probes + flush nozzle + cable service loop + interlock tab.
- **G. Angled front bezel** — flush TFT cutout + hidden touch pad + logo (accent colour lives here).
- **H. Top lid** — closes the top, carries the head tower/bayonet mount and the pour access.

---

## 5. Drawer + cup + weighing (sub-assembly D & E)
- **Removable cup:** for hygiene and leak-safety, **do NOT rely on a bare FDM print as the milk-contact surface** (porous, hard to clean). Design the cup as a **printed cradle that holds a drop-in food-safe vessel** (a small ~60 ml stainless/glass shot-style cup) OR a printed cup **with a smooth food-safe interior** — recommend the drop-in insert and list it in the hardware BOM. Target usable volume **50–60 ml**; model a crisp **etched/embossed fill line** at ~50 ml.
- **One dedicated cup** — fixed tare & volume (firmware calibrates it once). The cradle must locate it repeatably (keyed seat) so it lands in the same spot every time.
- **Load cell** sits **in the drawer under the cup cradle**, on a rigid mount, with the cradle as its floating platform — **mechanically isolated** so only the cup's weight loads it (nothing else touches the platform). **HX711 mounts right next to the load cell in the drawer** (satellite); route only its 4 digital wires back to the board through a **strain-relieved service loop** that flexes with drawer travel (§9).
- **Drawer slide:** printed rails with a **hard stop + detent** at the fully-in position (so the platform is stable for weighing — no wobble). Smooth pull; add a finger recess (no visible handle hardware).
- **Interlock:** when the head is locked down (§6), a **tab physically blocks the drawer from sliding out**. Raising the head releases it. Model both the tab on the head and the catch slot on the drawer/chassis.

---

## 6. Bayonet sensor head (sub-assembly F) — the critical part
Carries, on one head, **all five probes + the flush nozzle**, and must place every tip correctly in the milk:
- **Probes on the head:** pH electrode (Ø~12 mm × 16 cm rigid, held near its top so the bulb hangs down), TDS probe, turbidity sensor, DS18B20 tip, **TCS34725 (potted/conformal-coated, aimed at the milk body just below the fill line)**, plus the **flush nozzle** (tube from the pump) aimed at the probe tips.
- **Immersion geometry (get this exactly right):** when the head is **locked DOWN** and the cup is filled to the line, **every tip sits ~12–18 mm below the milk surface** — pH bulb fully submerged, TDS electrodes submerged, turbidity window submerged, DS18B20 tip submerged, colour sensor just below the surface facing the milk. Parameterise each probe's Z-offset in `params.py`. Add a **hard depth-stop** so the fragile **pH glass bulb never touches the cup bottom** (leave ≥ 5 mm clearance to the bottom).
- **Bayonet action:** **push down + rotate 90° to lock** at the **correct final orientation** (probes arranged to clear each other and the cup wall); rotate back 90° + lift to raise. The locked angle is the "correct/straight" position — design the slot so it can only lock at that one angle. Include a light detent so it stays down hands-free during the test, and enough clearance that raising it is smooth.
- **Alignment:** the drawer's cup must land **precisely under the head** (keyed seat + drawer hard-stop) so the plunging probes never hit the cup wall.
- **Cable service loop:** all head cables (pH 80 cm, TDS 80 cm, temp 95 cm, turbidity sensor lead, colour) are **bundled in heat-shrink** and routed as a **service loop/light spiral anchored above the head** that absorbs the vertical plunge **and** the 90° twist without fatigue. Provide an anchor boss + a strain relief; leave generous slack.
- **Splash:** keep the bayonet mechanism and cable exit **above** the wet zone; add a small drip lip so rinse water can't wick up into the head.

---

## 7. Fluidics (single pump, no valves, no waste bottle)
- **One 6 V peristaltic pump** in the rear bay. Its only job: pull distilled water from the **internal reservoir** and push it through the head's **flush nozzle** to rinse the probe tips (head down, empty cup). The user empties the cup by hand — **there is NO waste bottle and NO valve**.
- **Reservoir:** a **removable ~500 ml distilled-water container** in the rear bay behind a **magnet door**; friction-fit / quick-pull tube to the pump. Recommend a **drop-in bottle** in a printed cradle (leak-free) rather than a printed tank. Pickup tube reaches the bottom.
- Route the pump→nozzle tube internally; model tube clips/channels so nothing dangles.

---

## 8. Electronics bay (sub-assembly B) + front bezel (G)
- **Perfboard cradle:** snap-in standoffs for the 150 × 89 mm board, oriented so its **front connector edge faces the cable channels**; ≥4 mm clearance all around; ≥15 mm headroom above for tall modules. Access to the ESP32's USB port from outside via a **hidden/edge slot** (for flashing/serial) — recessed, no flap needed.
- **Cable channels & clips** from the head loom and the drawer loom to the board's front edge — fully concealed, strain-relieved, no crossing over the board.
- **Angled front bezel (~18–22° tilt):** **TFT flush** in a precise cutout (its own glass is the surface — model to the TFT's exact bezel so the glass sits flush, no added cover). The **single TTP223 pad mounts BEHIND the opaque bezel** just below the display — no cutout (capacitive reads through ~2 mm plastic); mark its location with a **subtle debossed ring**. Recess for the TFT PCB behind. Accent (dark-blue) colour lives on this bezel's top edge + the logo.

---

## 9. Cable management (nothing visible)
- **Head loom:** heat-shrink bundle + service loop (see §6).
- **Drawer loom:** the HX711's 4 digital wires in a **flat service loop** that flexes with drawer travel; strain-relieved at both ends.
- Internal **channels, clips and pass-throughs** for every wire so the exterior is clean. Provide grommeted or filleted pass-throughs (no sharp edges on wire paths).

---

## 10. Thermal / vents
- Provide **convection venting** for the LM2596, the pump, and the ESP32: **low intake vents** near the base + **high exhaust vents** near the top-rear, positioned for natural airflow across the power corner. Style them as **tasteful fine louvre slits** (≤ 2 mm) that read as design, not holes — keep them on less-visible faces (rear/underside) where possible. Ensure vent slits are printable without supports (bridging-friendly orientation).

---

## 11. Tolerances & materials (state these in `params.py`)
- **Sliding fits** (drawer rails, bayonet): **0.30–0.40 mm** clearance per side. Not tight, not sloppy — smooth glide with a light detent.
- **Snap-fit clips:** cantilever arms ~6–8 mm long, ~1.5–2 mm thick at root, **~0.3 mm** engagement; design for repeated open/close on the doors.
- **Press/friction fits** (standoffs, tube ports): **0.10–0.15 mm** interference.
- **Magnet pockets:** pocket = magnet Ø **+0.15 mm**, depth = magnet + 0.4 mm (press or glue); pair polarity noted.
- **Walls:** **2.5–3 mm** typical; **3 mm** on any water/milk-adjacent or structural part.
- **Material:** recommend **PETG** for the shell and all wet/warm parts (moisture + mild heat from the pump/regulator; better layer adhesion than PLA). PLA acceptable for the outer shell only. **Milk-contact = the drop-in food-safe cup, not raw print.** Note all of this in `PRINT.md`.
- Design all overhangs **> 45°** or add chamfers so most parts print **support-free**; call out any part that needs supports.

---

## 12. Print strategy (`PRINT.md`)
- Map **each part to a print orientation** that minimises supports and puts layer lines across (not along) load paths, especially the snap clips and the bayonet.
- Confirm **every part ≤ 250 mm** in all axes; if not, split with a hidden snap joint + alignment key.
- Note the **single accent swap** (dark-blue, top layers only) or the single-colour option.
- Suggested settings: 0.2 mm layer, 3+ walls, 20–30% infill (higher at clips/rails), PETG temps.

---

## 13. SELF-REVIEW — run before you ship (mandatory)
Do NOT deliver until every item passes; fix and re-check:
1. **Fit checks in CAD:** no interference between any parts in the assembled STEP; drawer slides fully; bayonet rotates and locks; head raises and lowers freely.
2. **Probe immersion:** with the cup filled to the line and head locked down, verify (in the model, with the parameterised Z-offsets) that **all five tips sit 12–18 mm below the surface** and the **pH bulb clears the cup bottom by ≥ 5 mm**.
3. **Interlock:** confirm the drawer is physically blocked when the head is down and free when up.
4. **Perfboard fit:** the 150 × 89 mm board + tall modules + connectors fit the bay with the stated clearances; USB reachable.
5. **Bed fit:** every STL ≤ 250 mm in X, Y, Z.
6. **No-screws / no-transparent / accent-top-only:** confirm assembly uses only snaps + magnets, no clear parts, and the accent colour appears only on top-layer surfaces.
7. **Tolerances:** slides 0.3–0.4 mm, snaps ~0.3 mm, presses ~0.1–0.15 mm — sane and consistent.
8. **Cable paths:** head loom takes plunge + 90° twist; drawer loom flexes; nothing visible outside; nothing pinched.
9. **Vents:** intake-low / exhaust-high present over the power corner; printable.
10. **Wall thickness / watertightness / support-free** checks pass.
Write a short **`REVIEW.md`** listing each check and its result.

---

## 14. Deliverables recap
Parametric source (+`params.py`), per-part **STLs**, assembly **STEP**, exploded + assembled **renders**, `ASSEMBLY.md`, `PRINT.md`, `REVIEW.md`, printed-parts BOM, hardware BOM (magnets, tubing, drop-in food-safe cup, drop-in reservoir bottle, heat-shrink). Everything regenerable by running the code. Match the design language in PROJECT_CONTEXT §9 (with the enclosure accent overridden to **dark blue, top-layer only**).
