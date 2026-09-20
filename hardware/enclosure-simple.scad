// ═════════════════════════════════════════════════════════════════════════════
//  Aqua Milk Detect — working enclosure
//  New file. Does not touch hardware/enclosure.scad or enclosure-lab.scad.
//
//  Built to the answers settled in the design interview. No styling, no
//  mechanism: a stepped two-bay tray, two lids, and the two load-cell parts.
//  Five printed pieces; the body prints in one go on a 220 bed.
//
//  ── Layout ──────────────────────────────────────────────────────────────────
//      WET BAY (left, tall)              DRY BAY (right, low)
//      cup on the load cell              pump on the floor
//      HX711 beside the cell             perfboard on rails above it
//      rinse nozzle on the rear wall     TFT + touch pad in the front wall
//      floor is the drip tray            USB + 12 V jack in the rear wall
//
//  A full-height partition separates them. Only four wires cross it (VCC, GND,
//  DT, SCK) plus the feed tube, and every crossing is HIGH on the wall — a
//  spilled 175 mL sample pools about 11 mm deep in the wet bay, and nothing at
//  that height can reach the electronics.
//
//  ── Why the walls differ ────────────────────────────────────────────────────
//  Wet bay 3.0 mm, dry bay and lids 2.4 mm. The load cell reacts against the
//  wet bay's frame, and a box that flexes shows up as tare drift in the density
//  reading. Nothing on the dry side cares, so those walls are thinner and
//  faster. Outer faces stay flush; the dry bay is simply 1.2 mm roomier inside.
//
//  ── Print notes ─────────────────────────────────────────────────────────────
//   part       orientation         supports  notes
//   body       as rendered         no        212 × 178 footprint
//   wet_lid    as rendered (flat)  no        parking feet print upward
//   dry_lid    as rendered (flat)  no
//   platform   as rendered (flat)  no        6 perimeters, 60% infill
//   riser      as rendered (flat)  no        6 perimeters, 60% infill
//
//  Not printed: the cup (acrylic tube), the load cell, the HX711, the perfboard,
//  the pump, silicone tube, fasteners.
// ═════════════════════════════════════════════════════════════════════════════

part = "assembly";  // "assembly" | "body" | "wet_lid" | "dry_lid" | "platform" | "riser"

$fn = 48;
eps = 0.02;

// ─────────────────────────────────────────────────────────────────────────────
//  1. Shell
//     Origin is the front-left-bottom OUTER corner. X right, Y back, Z up.
// ─────────────────────────────────────────────────────────────────────────────
w_wall  = 3.0;    // wet bay walls and the partition — the load path
d_wall  = 2.4;    // dry bay walls and both lids
floor_t = 3.0;

// Sized for a HAND, not for the cup. At 92 the cup had 8 mm of clearance per
// side and could not be gripped — you cannot lift a full cup of milk out of a
// slot that tight, and the cup comes out on every single test. 112 gives 18 mm
// per side, which is what fingers actually need.
wet_in_w = 112;
dry_in_w = 112;   // perfboard 102 + 5 mm each side
out_d    = 178;
wet_h    = 161;   // outer
dry_h    = 95;    // outer

wet_out_w = w_wall + wet_in_w + w_wall;          // 98, partition included
out_w     = wet_out_w + dry_in_w + d_wall;       // 212.4
wet_in_d  = out_d - 2*w_wall;                    // 172
dry_in_d  = out_d - 2*d_wall;                    // 173.2
part_x0   = w_wall + wet_in_w;                   // 95, partition inner face
part_x1   = wet_out_w;                           // 98, partition outer face

// ─────────────────────────────────────────────────────────────────────────────
//  2. Cup and load cell
//     Bore is set by the probes, not the volume: the turbidity body sits IN the
//     sample and the pH probe needs the annulus beside it.
//     Specific gravity is grams / chamber_ml, so the dose only has to be
//     REPEATABLE — that is what the weir does. Drill it at fill_mm above the
//     inside of the cup floor.
// ─────────────────────────────────────────────────────────────────────────────
cup_id   = 70;
cup_wall = 3;
// 70, not 105. The probes hang from the lid, and only the pH probe is long
// enough to reach down a tall cup: a 50 mm DS18B20 and a 60 mm TDS probe cannot
// span from the lid to the liquid at the bottom of a 105 mm cup. The fix is to
// bring the liquid UP to the lid instead — short cup, tall pedestal. See the
// reach echo below; it is the check that matters most in this file.
cup_h    = 70;
dose_ml  = 175;
cup_od   = cup_id + 2*cup_wall;                        // 76
fill_mm  = dose_ml * 1000 / (PI * pow(cup_id/2, 2));   // 45.5

cup_x = w_wall + wet_in_w/2;      // 49
cup_y = w_wall + 60;              // 63 — forward, leaving the rear for HX711

lc_len    = 80;    // 3 kg bar, TAL220 pattern
lc_w      = 12.7;
lc_h      = 12.7;
lc_pitch  = 15;    // hole-to-hole within one end
lc_span   = 55;    // centre of one hole pair to the other
lc_hole_d = 4.5;
lc_nut_af = 8.1;
ped_h     = 49.5;  // tall on purpose — it lifts the liquid into probe reach
ped_d     = 28;
ped_y     = cup_y + lc_span;                    // 118, fixed end
bar_z     = floor_t + ped_h;
plat_t    = 5;
plat_top  = floor_t + ped_h + lc_h + 12.3 + plat_t;   // 82.5, the cup's datum
riser_h   = plat_top - plat_t - (bar_z + lc_h); // 12.3
plat_d    = 80;    // cup ⌀76 plus a 2 mm locating ring; any bigger and it
                   // crowds the bay walls for no gain

hx_y = w_wall + 140;   // HX711 behind the cell, coated, bridge wires short
col_z = plat_top + cup_wall + fill_mm/2;   // colour sensor at mid-liquid

// ─────────────────────────────────────────────────────────────────────────────
//  3. Probes — carried by the wet lid
// ─────────────────────────────────────────────────────────────────────────────
// Turbidity sensor, from its datasheet: ⌀30 base plane, 34 tall overall, two
// arms 22 across with a 5.7 optical gap between them, photo-transistor and LED
// near the TOP of those arms, 3 pins on the base.
//
// The part is designed to mount in a tank floor with the arms pointing up. It
// cannot be used that way here: anything fixed to the cup is a force path into
// the weighed assembly. So it hangs INVERTED from the lid — arms down in the
// milk, pins up and dry — held in a printed collar that drops it far enough for
// the optical gap to submerge.
turb_body_d  = 30;   // base plane ⌀ — this is what sets the cup bore
turb_h       = 34;
turb_arm_w   = 22;
turb_optics  = 7;    // gap centre, measured up from the arm tips
turb_drop    = 15;   // how far the collar carries it below the lid
turb_lip     = 2;    // catches the ⌀30 base; the 22 mm arms pass through
ph_probe_d  = 12;
tds_probe_d = 10;
ds18b20_d   =  6;
probe_gap   = 0.6;
probe_r     = 27;
ph_tip_gap  =  6;   // immersion = fill_mm - ph_tip_gap
spare_d     =  8;   // spare gland

// ─────────────────────────────────────────────────────────────────────────────
//  4. Dry bay contents
// ─────────────────────────────────────────────────────────────────────────────
pb_w   = 102;   // perfboard, measured
pb_d   = 152;
pb_t   = 1.8;
pb_z   = 50;    // rail top — 7 mm over the pump, which varies between units
pb_y0  = 14;    // leaves room for the display in front of it

pump_w = 95;    // 6 V peristaltic, on the floor under the board
pump_d = 40;
pump_h = 40;

clip_w   = 16;  // corner clips that trap the board — no screws, no board holes
clip_t   = 3;
clip_lip = 2.5;

// ─────────────────────────────────────────────────────────────────────────────
//  5. Panel features
// ─────────────────────────────────────────────────────────────────────────────
tft_win_w  = 36.5;   // window for a 35.0 × 28.0 active area
tft_win_h  = 29.5;
tft_pcb_w  = 58;
tft_pcb_h  = 36;
tft_rebate = 1.5;
tft_hole_x = 51;     // 4 × M2 insert pattern
tft_hole_y = 29;
tft_x      = part_x1 + 42;
tft_z      = 68;

pad_w    = 20;       // TTP223 blind pocket — never a through hole
pad_h    = 16;
pad_wall = 1.2;      // plastic left in front of the pad
pad_x    = part_x1 + 92;
pad_z    = tft_z;

usb_w  = 15;         // panel-mount micro-USB, because the ESP32 is landlocked
usb_h  = 11;
usb_x  = part_x1 + 50;
jack_d = 8.2;
jack_x = part_x1 + 92;
port_z = 25;

vent_w     = 2.5;
vent_l     = 26;
vent_n     = 7;
vent_pitch = 6;

// Crossings sit in a window: high enough to clear a spill on the wet floor
// (a full 175 mL sample pools ~11 mm deep), but BELOW the dry bay's ceiling —
// the partition keeps rising past the dry bay to full wet height, so anything
// above dry_h opens into free air instead of into the electronics bay.
// One gland is oversized: the pH probe's cable ends in a BNC plug (~15 mm across
// the knurl) and the plug has to pass if you ever want to disconnect at the
// board rather than unthread the probe from the lid.
gland_z = 75;
glands  = [[w_wall + 128, 20], [w_wall + 150, 16]];

// TCS34725 — the colour sensor. It reads through the cup wall from the wet side
// of the partition; the closed wet bay is its dark box, so it needs no hood.
// Sits at mid-liquid height. R, G, B and Clear are four of the model's features,
// so this is not optional.
col_pitch = 17;    // breakout mounting holes — MEASURE YOURS
col_boss  = 4;     // With the wider bay there is 18 mm between partition and
                   // cup, so the board can stand off properly. It must still
                   // never be touched by the cup — that would be a force path
                   // into the load cell, the one thing that must never happen.
col_pilot = 1.7;   // M2 self-tap
m2_pilot  = 1.7;   // every M2 self-tapping boss in the box

foot_pad_d = 16;   // foot.stl — printed separately and stuck on, because a pad
foot_pad_h = 3;    // modelled under the floor destroys the first layer

intake_n     = 11; // side-wall intake, replacing the old floor grille
intake_w     = 3;
intake_l     = 26;
intake_pitch = 6;

tie_w = 12;        // cable tie bridges — 1 m of probe lead per sensor has to go
tie_g = 4;         // somewhere, and it must never end up touching the cup
feed_d  = 10;        // feed tube crossing, pump side to nozzle side
feed_z  = 68;
feed_y  = w_wall + 165;
bottle_d = 10;       // distilled-water line entering the dry bay from outside.
bottle_x_off = 100;  // Kept clear of the vent band (x_off 34 ± 18) and of the
bottle_z = 60;       // port row at port_z — everything on the rear wall has to
                     // miss everything else on the rear wall.

// Tube RESTRAINT, not the outlet. A wall-mounted nozzle cannot work here: the
// cup fills the bay to within 8 mm of each side wall, and only 8.5 mm separates
// its rim from the lid — so there is no wall position that is actually over the
// cup, and anything cantilevered out to reach would foul either the cup rim or
// the lid's locating rim. Water leaving a wall nozzle lands on the floor.
// The outlet is therefore in the LID (see wet_lid), and this boss just stops the
// tube flapping on its way up. That reverses the earlier wall-vs-lid decision —
// the geometry made it, not preference.
noz_d = 8;
noz_z = plat_top + cup_wall + fill_mm + 10;

snap_l = 16;         // dry lid quick release
snap_t = 1.2;
snap_h = 3;
snap_z = dry_h - 8;

lid_t   = 4;         // wet lid plate
lid_lip = 5;
lid_clr = 0.4;
// Lift rails: the lid's handles, and its parking feet when inverted. MOULDED
// ONTO THE LID, not separate parts. This lid is already printed and in hand —
// do not split these off again.
rail_w  = 5;
rail_h  = 14;

echo(str("Body            : ", out_w, " x ", out_d, " — wet ", wet_h, " tall, dry ", dry_h));
echo(str("Fill height     : ", fill_mm, " mm for ", dose_ml, " mL in a ", cup_id, " mm bore"));
echo(str("pH immersion    : ", fill_mm - ph_tip_gap, " mm (want >= 30)"));
echo(str("Cup top         : ", plat_top + cup_h, " mm, wet bay inside is ", wet_h - floor_t));
echo(str("Riser height    : ", riser_h, " mm (want > 6)"));
echo(str("Board over pump : ", pb_z - (floor_t + pump_h), " mm clear"));
echo(str("Dry headroom    : ", dry_h - (pb_z + pb_t), " mm above the board (asked for 35-40)"));
echo(str("Spill depth     : ", dose_ml * 1000 / (wet_in_w * wet_in_d),
         " mm on the floor; lowest crossing is at ", feed_z));
echo(str("Finger clear    : ", (wet_in_w - cup_od)/2,
         " mm each side of the cup (want >= 15 — you lift it out full)"));
echo(str("Lid park        : pH sticks up ", 150 - (wet_h - (plat_top + cup_wall + ph_tip_gap)),
         " mm; inverted on ", rail_h, " mm rails its tip lands at z=",
         wet_h + rail_h - (150 - (wet_h - (plat_top + cup_wall + ph_tip_gap))),
         " vs platform top ", plat_top));

// THE reach check. Probes hang from the lid; each must physically span from the
// lid's underside down into the liquid. MEASURE your probes and put the real
// numbers here — if any line says SHORT, raise ped_h (lifts the liquid) or
// shorten cup_h.
liq_bot = plat_top + cup_wall;
liq_top = liq_bot + fill_mm;
probes  = [["pH", 150, liq_bot + ph_tip_gap],
           ["TDS", 60, liq_top - 15],
           ["DS18B20", 50, liq_top - 15]];
for (p = probes)
    echo(str("Reach ", p[0], ": needs ", wet_h - p[2], " mm below the lid, probe is ", p[1],
             p[1] >= wet_h - p[2] ? "  OK" : str("  SHORT by ", wet_h - p[2] - p[1])));

// Turbidity is geometric, not a length comparison: the sensor hangs from a
// collar, and its optical gap must sit inside the liquid with margin.
turb_base = wet_h - turb_drop + turb_lip;   // its base plane, hanging inverted
turb_tip  = turb_base - turb_h;
turb_gap_z = turb_tip + turb_optics;
echo(str("Turbidity gap   : z=", turb_gap_z, " — liquid is ", liq_bot, "..", liq_top,
         (turb_gap_z > liq_bot + 5 && turb_gap_z < liq_top - 5)
           ? str("  OK, ", liq_top - turb_gap_z, " mm under the surface")
           : "  OUT OF LIQUID — adjust turb_drop"));
echo(str("Turbidity tips  : z=", turb_tip, " vs cup floor ", liq_bot,
         turb_tip > liq_bot + 3 ? "  OK" : "  TOO DEEP, it will foul the cup floor"));
echo(str("Board slot      : ", dry_in_w - 2*clip_t, " mm between rails for a ", pb_w,
         " mm board — ", (dry_in_w - 2*clip_t - pb_w)/2, " mm play each side"));
echo(str("Snap grip       : tabs leave ", dry_in_w - 2*clip_t - 2*clip_lip,
         " mm clear against a ", pb_w, " mm board, so each tab deflects ",
         (pb_w - (dry_in_w - 2*clip_t - 2*clip_lip))/2, " mm going in (want 0.3-1.0)"));

// ═════════════════════════════════════════════════════════════════════════════
//  BODY
// ═════════════════════════════════════════════════════════════════════════════
module vents(n, len, thick) {
    for (i = [0 : n-1])
        translate([(i - (n-1)/2) * vent_pitch, 0, 0])
            cube([vent_w, thick, len], center = true);
}

module body() {
    difference() {
        union() {
            // wet shell — its right wall IS the partition
            difference() {
                cube([wet_out_w, out_d, wet_h]);
                translate([w_wall, w_wall, floor_t])
                    cube([wet_in_w, wet_in_d, wet_h - floor_t + eps]);
            }
            // dry shell — no left wall of its own, it shares the partition
            difference() {
                translate([part_x1, 0, 0]) cube([dry_in_w + d_wall, out_d, dry_h]);
                translate([part_x1, d_wall, floor_t])
                    cube([dry_in_w, dry_in_d, dry_h - floor_t + eps]);
            }

            // load-cell pedestal, printed into the wet floor
            translate([cup_x - (lc_w + 12)/2, ped_y - ped_d/2, floor_t - eps])
                cube([lc_w + 12, ped_d, ped_h + eps]);

            // HX711 stand-offs, with pilots — solid posts give a screw nothing
            // to go into, and this board must not be free to move: it is what
            // the load cell's millivolts arrive at.
            for (x = [cup_x - 15, cup_x + 15])
                translate([x, hx_y, floor_t - eps]) difference() {
                    cylinder(d = 7, h = 6 + eps);
                    translate([0, 0, 1]) cylinder(d = m2_pilot, h = 6);
                }

            // Pump tie-downs. A loose 95 mm pump wandering around the dry bay
            // will eventually pull its own tubing off; a zip tie through these
            // two loops holds it to the floor whatever its flange pattern is.
            for (y = [d_wall + 2, d_wall + pump_d + 6])
                translate([part_x1 + 6 + pump_w/2, y, floor_t - eps])
                    difference() {
                        translate([-9, -2, 0]) cube([18, 4, tie_g + 3]);
                        translate([-tie_w/2, -2 - eps, 2]) cube([tie_w, 4 + 2*eps, tie_g]);
                    }

            // Colour sensor, facing the cup across a short air gap
            for (y = [cup_y - col_pitch/2, cup_y + col_pitch/2])
                translate([part_x0 + 1, y, col_z]) rotate([0, -90, 0])
                    difference() {
                        cylinder(d = 6, h = col_boss + 1);
                        translate([0, 0, -eps]) cylinder(d = col_pilot, h = col_boss + 1 + 2*eps);
                    }

            // No feet here. Pads below z=0 make the FIRST LAYER four small discs
            // — ~800 mm² of disconnected islands — and then ask the whole
            // 232 × 178 floor to begin 3 mm up in mid-air on top of them. That
            // is unprintable, not merely hard to stick. Feet are foot.stl now,
            // stuck on afterwards. The load-cell bolt heads recess 1.3 mm below
            // the floor anyway, so the box still sits flat without them.

            // Cable tie bridges. Two in the wet bay for the probe leads, two in
            // the dry bay. The arch bridges tie_w, which prints without support.
            for (t = [[cup_x - 25, w_wall + 1, 120], [cup_x + 25, w_wall + 1, 120],
                      [part_x1 + 30, out_d - d_wall - 5, 80],
                      [part_x1 + 80, out_d - d_wall - 5, 80]])
                translate(t) difference() {
                    translate([-tie_w/2 - 3, 0, -3]) cube([tie_w + 6, 4, tie_g + 6]);
                    translate([-tie_w/2, -eps, 0]) cube([tie_w, 4 + 2*eps, tie_g]);
                }

            // rinse nozzle guide — the tube threads through and points at the cup
            translate([cup_x, w_wall + wet_in_d - 6, noz_z])
                difference() {
                    cube([16, 12, 14], center = true);
                    cylinder(d = noz_d, h = 20, center = true);
                }

            // perfboard rails, and the four clips that trap it
            for (sx = [0, 1]) {
                x = sx == 0 ? part_x1 : part_x1 + dry_in_w - clip_t;
                translate([x, pb_y0, floor_t]) cube([clip_t, pb_d, pb_z - floor_t]);
                // Snap tabs, not plain lips. A lip that clears the board on the
                // way in can only overlap it by the slide clearance, which is
                // not enough to hold anything. These project past the board and
                // taper upward, so you push the board down, the tabs deflect,
                // and they spring back over its top face.
                for (y = [pb_y0 + 8, pb_y0 + pb_d - 8 - clip_w])
                    hull() {
                        translate([x + (sx == 0 ? clip_t : -clip_lip), y, pb_z + pb_t])
                            cube([clip_lip, clip_w, 0.8]);
                        translate([x + (sx == 0 ? clip_t : -0.8), y, pb_z + pb_t + 0.8])
                            cube([0.8, clip_w, 2.6]);
                    }
            }
            // front and back board stops
            for (y = [pb_y0 - clip_t, pb_y0 + pb_d])
                translate([part_x1 + 6, y, floor_t])
                    cube([dry_in_w - 12, clip_t, pb_z - floor_t + 4]);

            // display bosses
            for (x = [-tft_hole_x/2, tft_hole_x/2], z = [-tft_hole_y/2, tft_hole_y/2])
                translate([tft_x + x, d_wall + tft_rebate - eps, tft_z + z])
                    rotate([-90, 0, 0]) difference() {
                        cylinder(d = 6, h = 5);
                        // 1.7 for an M2 self-tapper. The ST7735's mounting holes
                        // are ~2 mm; a 4 mm bore gives the screw nothing to bite.
                        translate([0, 0, -eps]) cylinder(d = m2_pilot, h = 5 + 2*eps);
                    }
        }

        // ── wet bay ──────────────────────────────────────────────────────────
        // load-cell fixed end: M4 through, nut trapped underneath
        for (y = [ped_y - lc_pitch/2, ped_y + lc_pitch/2]) {
            translate([cup_x, y, -eps]) cylinder(d = lc_hole_d, h = floor_t + ped_h + 2*eps);
            // 4.5 deep, not 3: an M4 head is 3.2 thick, and a head standing
            // 0.2 mm proud makes the whole instrument rock on two bolts
            translate([cup_x, y, -eps]) cylinder(d = lc_nut_af / cos(30), h = 4.5, $fn = 6);
        }
        // Water path: bottle outside → dry bay rear wall → pump → across the
        // partition at feed_z → up to the nozzle guide. Nothing enters the wet
        // bay from outside.
        translate([part_x1 + bottle_x_off, out_d - d_wall/2, bottle_z])
            rotate([90, 0, 0]) cylinder(d = bottle_d, h = d_wall + 2*eps, center = true);

        // ── partition crossings, all high above any spill ────────────────────
        for (g = glands)
            translate([part_x0 + w_wall/2, g[0], gland_z])
                rotate([0, 90, 0]) cylinder(d = g[1], h = w_wall + 2*eps, center = true);
        translate([part_x0 + w_wall/2, feed_y, feed_z])
            rotate([0, 90, 0]) cylinder(d = feed_d, h = w_wall + 2*eps, center = true);

        // ── dry bay front: display and touch pad ─────────────────────────────
        translate([tft_x, d_wall/2, tft_z])
            cube([tft_win_w, d_wall + 2*eps, tft_win_h], center = true);
        translate([tft_x, d_wall + tft_rebate/2, tft_z])
            cube([tft_pcb_w, tft_rebate + eps, tft_pcb_h], center = true);
        // blind pocket only: a through hole here is a leak and a dead pad
        translate([pad_x, d_wall - (d_wall - pad_wall)/2 + eps, pad_z])
            cube([pad_w, d_wall - pad_wall + eps, pad_h], center = true);
        // ...and a shallow dimple OUTSIDE, so there is something to aim at.
        // The pad is invisible otherwise, which makes a touch target you have
        // to remember the position of.
        translate([pad_x, -eps, pad_z]) rotate([-90, 0, 0]) cylinder(d = 22, h = 0.6 + eps);

        // ── dry bay rear: ports and exhaust ──────────────────────────────────
        translate([usb_x, out_d - d_wall/2, port_z])
            cube([usb_w, d_wall + 2*eps, usb_h], center = true);
        translate([jack_x, out_d - d_wall/2, port_z])
            rotate([90, 0, 0]) cylinder(d = jack_d, h = d_wall + 2*eps, center = true);
        translate([part_x1 + 34, out_d - d_wall/2, dry_h - 34])
            vents(vent_n, vent_l, d_wall + 2*eps);
        // Intake: right wall, low down. It used to be a grille in the floor,
        // which cost first-layer area on the one face that has to stick. On a
        // vertical wall the slots run vertically too, so there is nothing to
        // bridge. Air enters here and leaves through the rear band up at
        // dry_h-34, which gives a diagonal sweep across the board.
        for (i = [0 : intake_n - 1])
            translate([out_w - d_wall/2,
                       dry_in_d/2 + d_wall - (intake_n - 1)*intake_pitch/2 + i*intake_pitch,
                       floor_t + 5 + intake_l/2])
                cube([d_wall + 2*eps, intake_w, intake_l], center = true);

        // ── dry lid snap pockets ─────────────────────────────────────────────
        // Snap pockets must be cut INTO the walls. Cutting at the interior face
        // just removes air and leaves the lid nothing to latch against.
        for (y = [d_wall + 40, d_wall + dry_in_d - 40 - snap_l])
            for (x = [part_x0 + w_wall - snap_t, part_x1 + dry_in_w])
                translate([x, y, snap_z]) cube([snap_t + eps, snap_l, snap_h]);
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  WET LID — carries the probes. Drops into the opening, lifts off with one
//  hand, parks upside down on its feet with the probes standing clear.
// ═════════════════════════════════════════════════════════════════════════════
module wet_lid() {
    difference() {
        union() {
            cube([wet_out_w, out_d, lid_t]);
            // Locating lip as a RIM, not a slab. It only has to find the
            // opening; a solid plug would add 5 mm of plastic across the whole
            // bay for nothing.
            translate([0, 0, -lid_lip]) linear_extrude(lid_lip + eps) difference() {
                translate([w_wall + lid_clr, w_wall + lid_clr])
                    square([wet_in_w - 2*lid_clr, wet_in_d - 2*lid_clr]);
                translate([w_wall + lid_clr + 4, w_wall + lid_clr + 4])
                    square([wet_in_w - 2*lid_clr - 8, wet_in_d - 2*lid_clr - 8]);
            }
            // Two rails, not four feet: they are the handles you lift the lid
            // by, and inverted they land on the box's left wall and partition so
            // the lid parks across the open bay with the probes pointing up.
            for (x = [0, wet_out_w - rail_w])
                translate([x, 0, lid_t - eps]) cube([rail_w, out_d, rail_h + eps]);
            // turbidity collar — drops the sensor to where its gap submerges
            translate([cup_x, cup_y, -turb_drop])
                cylinder(d = turb_body_d + 2*probe_gap + 2*3, h = turb_drop + eps);
        }
        // Sensor drops in from above, arms first; its base lands on the lip.
        translate([cup_x, cup_y, -turb_drop + turb_lip])
            cylinder(d = turb_body_d + 2*probe_gap, h = turb_drop + lid_t + 2*eps);
        translate([cup_x, cup_y, -turb_drop - eps])
            cylinder(d = turb_arm_w + 3, h = turb_lip + 2*eps);
        // Probes on the bolt circle, plus the rinse nozzle at 30°. The tube
        // pushes into that hole from above and comes away with the lid on a
        // service loop — leave enough slack to park the lid beside the box.
        for (p = [[90, ph_probe_d], [210, tds_probe_d], [330, ds18b20_d], [30, spare_d]])
            translate([cup_x + probe_r*cos(p[0]), cup_y + probe_r*sin(p[0]), -lid_lip - eps])
                cylinder(d = p[1] + 2*probe_gap, h = lid_t + lid_lip + 2*eps);
        // No finger notch: it was a through hole straight into the wet bay,
        // letting rinse spray out and dust in. The lift rails are the grip.

    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  DRY LID — quick release. Four snaps, no tools.
// ═════════════════════════════════════════════════════════════════════════════
module dry_lid() {
    difference() {
        union() {
            translate([part_x1, 0, 0]) cube([dry_in_w + d_wall, out_d, d_wall]);
            // rim, not a slab — same reason as the wet lid
            translate([0, 0, -lid_lip]) linear_extrude(lid_lip + eps) difference() {
                translate([part_x1 + lid_clr, d_wall + lid_clr])
                    square([dry_in_w - 2*lid_clr, dry_in_d - 2*lid_clr]);
                translate([part_x1 + lid_clr + 4, d_wall + lid_clr + 4])
                    square([dry_in_w - 2*lid_clr - 8, dry_in_d - 2*lid_clr - 8]);
            }
            for (y = [d_wall + 40, d_wall + dry_in_d - 40 - snap_l])
                for (sx = [0, 1])
                    translate([sx == 0 ? part_x1 - snap_t + lid_clr
                                       : part_x1 + dry_in_w - lid_clr, y, -lid_lip + 1])
                        cube([snap_t, snap_l, snap_h]);
        }
        translate([part_x1 + dry_in_w/2, out_d - 8, d_wall/2])
            cube([40, 12, d_wall + 2*eps], center = true);
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PLATFORM and RISER — the only things the cup touches.
// ═════════════════════════════════════════════════════════════════════════════
module platform() {
    difference() {
        union() {
            cylinder(d = plat_d, h = plat_t);
            // locating ring, so the cup cannot walk off
            difference() {
                cylinder(d = plat_d, h = plat_t + 2.5);
                translate([0, 0, plat_t]) cylinder(d = cup_od + 0.8, h = 2.5 + eps);
            }
        }
        for (y = [-lc_pitch/2, lc_pitch/2]) {
            translate([0, y, -eps]) cylinder(d = lc_hole_d, h = plat_t + 2*eps);
            translate([0, y, plat_t - 3]) cylinder(d = 8, h = 3 + eps);
        }
    }
}

// One foot. Print four, stick them near the corners of the underside. Rubber
// self-adhesive feet are better if you have them — they damp bench vibration,
// which a load cell notices — but these work.
module foot() {
    cylinder(d = foot_pad_d, h = foot_pad_h);
}

module riser() {
    difference() {
        translate([-(lc_w + 10)/2, -(lc_pitch + 18)/2, 0])
            cube([lc_w + 10, lc_pitch + 18, riser_h]);
        for (y = [-lc_pitch/2, lc_pitch/2])
            translate([0, y, -eps]) cylinder(d = lc_hole_d, h = riser_h + 2*eps);
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ASSEMBLY (visual only — mocks are not printed)
// ═════════════════════════════════════════════════════════════════════════════
module cup_mock() {
    color("SkyBlue", 0.25) difference() {
        cylinder(d = cup_od, h = cup_h);
        translate([0, 0, cup_wall]) cylinder(d = cup_id, h = cup_h);
        translate([0, 0, cup_wall + fill_mm]) rotate([0, 90, 0])
            cylinder(d = 6, h = cup_od + eps, center = true);
    }
    color("Ivory", 0.6) translate([0, 0, cup_wall]) cylinder(d = cup_id - 0.4, h = fill_mm);
}

module assembly() {
    color("Gainsboro")  body();
    color("WhiteSmoke") translate([0, 0, wet_h]) wet_lid();
    color("WhiteSmoke") translate([0, 0, dry_h]) dry_lid();

    translate([cup_x, cup_y, 0]) {
        color("Silver")   translate([-lc_w/2, -lc_len/2 + lc_span/2, bar_z])
            cube([lc_w, lc_len, lc_h]);
        color("DarkGray") translate([0, 0, bar_z + lc_h]) riser();
        color("Silver")   translate([0, 0, plat_top - plat_t]) platform();
        translate([0, 0, plat_top]) cup_mock();
    }

    color("DarkGreen", 0.7)
        translate([part_x1 + (dry_in_w - pb_w)/2, pb_y0, pb_z]) cube([pb_w, pb_d, pb_t]);
    color("DimGray")
        translate([part_x1 + 6, d_wall + 6, floor_t]) cube([pump_w, pump_d, pump_h]);
}

// ═════════════════════════════════════════════════════════════════════════════
//  RENDER
// ═════════════════════════════════════════════════════════════════════════════
// The lids export exactly as they were printed — do not add orientation
// transforms here; the parts in hand came from these coordinates.
if      (part == "assembly") assembly();
else if (part == "body")     body();
else if (part == "wet_lid")  wet_lid();
else if (part == "dry_lid")  dry_lid();
else if (part == "platform") platform();
else if (part == "riser")    riser();
else if (part == "foot")     foot();
else echo(str("Unknown part: ", part));
