// ═════════════════════════════════════════════════════════════════════════════
//  Aqua Milk Detect — bench instrument
//  New file. Does not replace hardware/enclosure.scad; nothing here reads it.
//
//  ── What this is ────────────────────────────────────────────────────────────
//  A 140 × 200 × 320 monolith with three things you touch, each labelled in the
//  surface itself:
//
//      MILK              the sample drawer, middle of the front
//      DISTILLED WATER   the tank neck, top surface
//      WASTE             the tray, bottom of the front
//
//  The control surface is a facet cut off the front-top edge at 30°, because a
//  bench instrument is read from above and an ST7735 is a TN panel — vertical,
//  it washes out at exactly the angle you stand at. Display and touch pad live
//  behind one dark panel set into that facet.
//
//  ── The mechanism, and why it exists ────────────────────────────────────────
//  The probes hang ~100 mm down into the cup, so the cup cannot leave sideways
//  past them: something has to separate vertically first. The probe carriage is
//  therefore a plug that slides straight up in its socket. Down, its top face is
//  flush and the machine is a closed prism. Up, the cup is free and the drawer
//  opens.
//
//  The cup rides ON the drawer. Closing the drawer walks it up a 2 mm chamfer
//  onto the platform, so at rest the cup touches only the load cell and the
//  drawer clears it by 3 mm all round. That isolation is the whole reason the
//  density feature works.
//
//  ── One pump ────────────────────────────────────────────────────────────────
//  Fill only, from the internal tank. It is a PROBE RINSE, not a cup flush: the
//  cup is washed by hand, so water only ever has to run over the probes and fall
//  through the drawer's drain into the waste tray. A cup that cannot drain can
//  only dilute — 5 s of pumping removes about 5% of the milk in it — which is
//  why nothing here tries to flush a full cup.
//
//  ── Print notes ─────────────────────────────────────────────────────────────
//   part           orientation           supports  notes
//   base           as rendered (open up) no        140 × 200 — needs a 220 bed
//   bay            as rendered (open up) no        front is open by design
//   head           UPSIDE DOWN           no        facet then prints as a
//                                                  receding wall
//   carriage       as rendered           no
//   sample_drawer  as rendered (open up) no
//   waste_tray     as rendered (open up) no
//   platform       as rendered (flat)    no        6 perimeters, 60% infill
//   riser          as rendered (flat)    no        6 perimeters, 60% infill
//   tank_cap       as rendered (flat)    no
//
//  Engravings are RECESSED, never raised: raised text wears at the high points
//  and traps milk in its corners, while a 0.5 mm recess just holds a shadow.
//
//  Not printed: the cup (acrylic tube), the load cell, the dark facet panel, the
//  colour window, magnets, silicone tube, fasteners.
// ═════════════════════════════════════════════════════════════════════════════

part = "assembly";  // "assembly" | "base" | "bay" | "head" | "carriage" | "sample_drawer" | "waste_tray" | "platform" | "riser" | "tank_cap"

$fn = 64;

// ─────────────────────────────────────────────────────────────────────────────
//  1. Print / fit
// ─────────────────────────────────────────────────────────────────────────────
wall     = 3.0;
floor_t  = 3.0;
shelf_t  = 5.0;    // the load cell reacts against this
clr      = 0.35;   // sliding fits
eps      = 0.02;
merge    = 1.0;    // features sink this far into their parent, so unions share
                   // volume instead of touching on a tangent (the usual source
                   // of non-manifold geometry)

// ─────────────────────────────────────────────────────────────────────────────
//  2. The body
//     X width, Y depth (−Y is the front), Z up. Origin at the plan centre.
// ─────────────────────────────────────────────────────────────────────────────
body_w   = 140;
body_d   = 200;
base_h   = 125;    // tank feed, pump, boards, waste tray, load-cell shelf
bay_h    = 120;    // the loading bay: drawer, cup, water tank behind it
head_h   =  75;    // facet, display, carriage socket, tank neck
body_h   = base_h + bay_h + head_h;   // 320

in_w     = body_w - 2*wall;
in_d     = body_d - 2*wall;
y_front  = -in_d/2;
y_back   =  in_d/2;

// ─────────────────────────────────────────────────────────────────────────────
//  3. Surface language
// ─────────────────────────────────────────────────────────────────────────────
corner_r  = 12;    // superellipse corner size
sq_n      =  5;    // 2 is a circle; 5 is the continuous corner
sq_steps  = 20;

cut       = 1.2;   // the sharp cut on every visible edge
base_lift =   6;   // undercut band, so the body floats
base_in   =   3;
reveal    = 0.8;   // hairline between zones

facet_a   = 30;    // degrees from vertical — a bench is read from above
facet_h   = 62;    // measured up the slope
panel_t   = 2.0;   // dark panel set into the facet
panel_in  = 10;    // its inset from the facet edges

magnet_d  = 6.3;
magnet_h  = 3.2;

// ─────────────────────────────────────────────────────────────────────────────
//  4. Engraving
// ─────────────────────────────────────────────────────────────────────────────
eng_depth = 0.5;   // deep enough to hold a shadow, shallow enough to wipe clean
eng_size  = 5.5;   // cap height. Below ~4 mm a 0.4 nozzle cannot hold the stroke
eng_font  = "Liberation Sans:style=Bold";

// ─────────────────────────────────────────────────────────────────────────────
//  5. The cup (acrylic tube)
//     Specific gravity is grams / chamber_ml, so the dose only has to be
//     REPEATABLE. The weir enforces it: fill past it and the excess leaves.
// ─────────────────────────────────────────────────────────────────────────────
cup_id    = 70;
cup_wall  =  3;
cup_h     = 105;
dose_ml   = 175;
weir_d    =  6;

cup_od    = cup_id + 2*cup_wall;                          // 76
fill_mm   = dose_ml * 1000 / (PI * pow(cup_id/2, 2));     // 45.5
cup_x     = 0;
cup_y     = 15;    // rear of centre: the facet needs the front

// ─────────────────────────────────────────────────────────────────────────────
//  6. Probes and the carriage
//     The bore is set by the probes, not the volume: the turbidity body sits IN
//     the sample and the pH probe needs the annulus beside it.
//         cup_id >= turb_body_d + 2*(ph_probe_d + 2*probe_gap)
// ─────────────────────────────────────────────────────────────────────────────
turb_body_d = 38;  // MEASURE YOURS — it sets the bore, and the bore sets the cup
ph_probe_d  = 12;
tds_probe_d = 10;
ds18b20_d   =  6;
probe_gap   = 0.6;
probe_r     = 27;
ph_tip_gap  =  6;  // immersion = fill_mm - ph_tip_gap
feed_d      =  8;  // rinse nozzle
probe_a     = [90, 210, 330, 30, 150];   // pH, TDS, DS18B20, feed, spare
probe_d     = [ph_probe_d, tds_probe_d, ds18b20_d, feed_d, ds18b20_d];

car_d       = 95;  // carriage plug diameter
car_plate   =  6;
car_lift    = 60;  // how far it rises — must clear the probes from the cup
car_grip    = 26;  // finger relief in the top face

// ─────────────────────────────────────────────────────────────────────────────
//  7. Load cell (3 kg bar, TAL220 pattern)
// ─────────────────────────────────────────────────────────────────────────────
lc_len    = 80;
lc_w      = 12.7;
lc_h      = 12.7;
lc_pitch  = 15;
lc_span   = 55;
lc_hole_d = 4.5;
lc_nut_af = 8.1;
ped_h     = 15;
shelf_z   = 85;                       // top of the load-cell shelf, inside base
lc_free_z = shelf_z + ped_h + lc_h;   // top of the bar
plat_t    = 6;
plat_z    = 127;                      // platform underside
plat_top  = plat_z + plat_t;          // 133 — the cup's datum
plat_d    = cup_od - 8;               // pushes up THROUGH the drawer's pocket

// ─────────────────────────────────────────────────────────────────────────────
//  8. Drawers
// ─────────────────────────────────────────────────────────────────────────────
dr_w      = in_w - 6;
dr_d      = 170;
dr_h      = 22;      // tray depth; the cup stands proud of it
dr_floor  = 3;
dr_z      = 128;     // drawer floor top — 5 below the cup datum
dr_pocket = cup_od + 6;    // clears the cup by 3 mm all round at rest
dr_ramp   = 2;       // the chamfer that walks the cup onto the platform

wt_w  = in_w - 10;   // waste tray
wt_d  = 150;
wt_h  =  60;
wt_z  =  10;

// ─────────────────────────────────────────────────────────────────────────────
//  9. Water tank — behind the cup, filled from the top
// ─────────────────────────────────────────────────────────────────────────────
tank_y0  = cup_y + cup_od/2 + 8;     // starts clear of the cup
tank_w   = in_w - 8;
tank_h   = 100;
neck_d   = 34;
neck_y   = (tank_y0 + y_back)/2;

// ─────────────────────────────────────────────────────────────────────────────
//  10. Boards and ports
// ─────────────────────────────────────────────────────────────────────────────
tft_win_w = 36.5;   // window for a 35.0 × 28.0 active area
tft_win_h = 29.5;
pad_w   = 20;       // TTP223 blind pocket — never a through hole
pad_h   = 16;
pad_wall = 1.2;
pad_drop = 18;      // down the slope from the display centre. It has to stay
                    // inside the panel: display centre sits at facet_h/2 + 6,
                    // the panel spans panel_in .. facet_h - panel_in.

usb_w  = 13;
usb_h  =  8;
usb_x  = -34;
jack_d = 8.2;
jack_x =  34;
port_z =  34;       // rear ports share one centreline
gland_d = 12.5;
vent_w  = 2.4;      // one slot width for the whole product
vent_pitch = 5.5;
vent_len   = 30;

col_win   = 20;     // colour sensor looks at the cup from the left wall
col_hood  =  6;     // hood stops short of the cup — never touch it
col_z     = plat_top + 22;

// Derived ---------------------------------------------------------------------
ped_y      = cup_y + lc_span;
lc_riser_h = plat_z - lc_free_z;
facet_run  = facet_h * sin(facet_a);
facet_rise = facet_h * cos(facet_a);

echo(str("Body            : ", body_w, " x ", body_d, " x ", body_h, " mm"));
echo(str("Fill height     : ", fill_mm, " mm for ", dose_ml, " mL in a ", cup_id, " mm bore"));
echo(str("pH immersion    : ", fill_mm - ph_tip_gap, " mm (want >= 30)"));
echo(str("Cup rim         : ", plat_top + cup_h, " mm; bay tops out at ", base_h + bay_h));
echo(str("Riser height    : ", lc_riser_h, " mm (want > 6)"));
echo(str("Tank capacity   : ", tank_w * (y_back - tank_y0) * tank_h / 1000, " mL"));
echo(str("Facet           : ", facet_a, " deg, ", facet_h, " mm slope, eats ",
         facet_run, " mm of depth"));
echo(str("Pedestal margin : ", y_back - (ped_y + (lc_pitch + 16)/2), " mm (want > 0)"));

// ═════════════════════════════════════════════════════════════════════════════
//  PRIMITIVES
// ═════════════════════════════════════════════════════════════════════════════

// One quadrant of a superellipse corner.
function sq_q(w, d, r, n) =
    [ for (i = [0 : sq_steps]) let (t = i * 90 / sq_steps)
        [ w/2 - r + r * pow(cos(t), 2/n), d/2 - r + r * pow(sin(t), 2/n) ] ];

// Rounded rectangle whose corners are superellipses, not arcs. A fillet meets a
// flat wall at a tangent break you can see under a highlight; this does not.
module squircle(w, d, r = corner_r, n = sq_n) {
    q = sq_q(w, d, r, n);
    polygon(concat(q,
        [ for (i = [sq_steps : -1 : 0]) [-q[i][0],  q[i][1]] ],
        [ for (i = [0 : sq_steps])      [-q[i][0], -q[i][1]] ],
        [ for (i = [sq_steps : -1 : 0]) [ q[i][0], -q[i][1]] ]));
}

module sq_prism(w, d, h, r = corner_r) { linear_extrude(h) squircle(w, d, r); }

module sq_shell(h, f = floor_t) {
    difference() {
        sq_prism(body_w, body_d, h);
        translate([0, 0, f]) linear_extrude(h - f + eps) square([in_w, in_d], center = true);
    }
}

// 45° cut around a top edge — the sharp cut, subtracted.
module edge_cut(w, d, h, c, r = corner_r) {
    difference() {
        translate([0, 0, h - c]) sq_prism(w + 8, d + 8, c + eps, r + 4);
        hull() {
            translate([0, 0, h - c - eps]) linear_extrude(eps) squircle(w, d, r);
            translate([0, 0, h]) linear_extrude(eps) squircle(w - 2*c, d - 2*c, max(r - c, 1));
        }
    }
}

// Undercut band at the base, so the body floats.
module base_cut() {
    difference() {
        translate([0, 0, -eps]) sq_prism(body_w + 8, body_d + 8, base_lift + eps, corner_r + 4);
        translate([0, 0, -2*eps]) sq_prism(body_w - 2*base_in, body_d - 2*base_in,
                                           base_lift + 4*eps, max(corner_r - base_in, 1));
    }
    edge_cut(body_w - 2*base_in, body_d - 2*base_in, base_lift, cut, max(corner_r - base_in, 1));
}

// Hairline reveal where two zones meet.
module reveal_cut(z) {
    difference() {
        translate([0, 0, z]) sq_prism(body_w + 8, body_d + 8, reveal, corner_r + 4);
        translate([0, 0, z - eps]) sq_prism(body_w - 2*reveal, body_d - 2*reveal,
                                            reveal + 2*eps, max(corner_r - reveal, 1));
    }
}

module tenon() {
    translate([0, 0, -merge]) linear_extrude(4 + merge) difference() {
        square([in_w + 3.2, in_d + 3.2], center = true);
        square([in_w, in_d], center = true);
    }
}

module mortise() {
    translate([0, 0, -eps]) linear_extrude(4 + clr + eps) difference() {
        square([in_w + 3.2 + 2*clr, in_d + 3.2 + 2*clr], center = true);
        square([in_w - 2*clr, in_d - 2*clr], center = true);
    }
}

// Recessed label. Cut into a surface, never raised.
module engrave(txt, size = eng_size, depth = eng_depth) {
    linear_extrude(depth + eps)
        text(txt, size = size, font = eng_font, halign = "center", valign = "center");
}

// One vent band. Every slot on the product is this width and this pitch.
module vents(n, len = vent_len, thick = 20) {
    for (i = [0 : n - 1])
        translate([0, (i - (n - 1)/2) * vent_pitch, 0])
            hull() for (s = [-1, 1])
                translate([0, 0, s * (len - vent_w)/2])
                    rotate([0, 90, 0]) cylinder(d = vent_w, h = thick, center = true);
}

module slot(l, h, thick = 20) {
    hull() for (s = [-1, 1])
        translate([s * (l - h)/2, 0, 0])
            rotate([90, 0, 0]) cylinder(d = h, h = thick, center = true);
}

// ═════════════════════════════════════════════════════════════════════════════
//  BASE — tank feed, pump, boards, power, the waste tray, and the shelf the
//  load cell reacts against.
// ═════════════════════════════════════════════════════════════════════════════
module base() {
    difference() {
        union() {
            sq_shell(base_h);
            translate([0, 0, base_h]) tenon();
            // load-cell shelf and its pedestal, printed in as one piece
            translate([0, cup_y + 12, shelf_z - shelf_t])
                linear_extrude(shelf_t) square([in_w, in_d/2 - 6], center = true);
            translate([-(lc_w + 12)/2, ped_y - (lc_pitch + 16)/2, shelf_z - merge])
                cube([lc_w + 12, lc_pitch + 16, ped_h + merge]);
            // tray runners
            for (x = [-(wt_w + 2*clr)/2 - 2, (wt_w + 2*clr)/2])
                translate([x, y_front, floor_t - merge]) cube([2, wt_d + 6, 4 + merge]);
        }
        base_cut();
        reveal_cut(base_h - reveal);

        // waste tray aperture
        translate([-(wt_w + 2*clr + 2*wall)/2, -body_d/2 - eps, wt_z])
            cube([wt_w + 2*clr + 2*wall, wall + 2*eps, wt_h + 2*clr]);

        // rear ports on one centreline
        translate([usb_x, body_d/2 - wall/2, port_z]) slot(usb_w, usb_h, wall + 2*eps);
        translate([jack_x, body_d/2 - wall/2, port_z])
            rotate([90, 0, 0]) cylinder(d = jack_d, h = wall + 2*eps, center = true);
        // intake, underside only
        translate([0, y_front + 40, floor_t/2]) rotate([0, 0, 90]) vents(11, 50, floor_t + 2);
        // load-cell fixed end: M4 through, nut trapped under the shelf
        for (y = [ped_y - lc_pitch/2, ped_y + lc_pitch/2]) {
            translate([0, y, shelf_z - shelf_t - eps])
                cylinder(d = lc_hole_d, h = shelf_t + ped_h + 2*eps);
            translate([0, y, shelf_z - shelf_t - eps])
                cylinder(d = lc_nut_af / cos(30), h = 4, $fn = 6);
        }
        // rinse water falls from the drawer's drain through here into the tray
        translate([0, cup_y - 46, shelf_z - shelf_t - eps]) cylinder(d = 26, h = shelf_t + 2*eps);
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  BAY — the loading bay. Its front is open by design: the drawer's own face
//  fills it, so the front of the product is three bands and no bezels.
// ═════════════════════════════════════════════════════════════════════════════
module bay() {
    hood_len = in_w/2 - cup_od/2 - col_hood;
    difference() {
        union() {
            difference() {
                sq_prism(body_w, body_d, bay_h);
                translate([0, 0, -eps]) linear_extrude(bay_h + 2*eps)
                    square([in_w, in_d], center = true);
                translate([-(in_w + 2*wall + 2)/2, -body_d/2 - eps, -eps])
                    cube([in_w + 2*wall + 2, wall + 2*eps, bay_h + 2*eps]);
            }
            translate([0, 0, bay_h]) tenon();
            // tank: a closed compartment against the back wall
            translate([0, (tank_y0 + y_back)/2, 0])
                linear_extrude(tank_h) difference() {
                    square([tank_w, y_back - tank_y0], center = true);
                    square([tank_w - 2*wall, y_back - tank_y0 - 2*wall], center = true);
                }
            // colour-sensor hood off the left wall, stopping short of the cup
            translate([-in_w/2 - merge, cup_y, col_z - base_h]) rotate([0, 90, 0])
                difference() {
                    translate([-(col_win + 2*wall)/2, -(col_win + 2*wall)/2, 0])
                        cube([col_win + 2*wall, col_win + 2*wall, hood_len + merge]);
                    translate([-col_win/2, -col_win/2, -eps])
                        cube([col_win, col_win, hood_len + merge + 2*eps]);
                }
        }
        mortise();
        reveal_cut(bay_h - reveal);
        // colour window through the left wall
        translate([-body_w/2 + wall/2, cup_y, col_z - base_h])
            cube([wall + 2*eps, col_win, col_win], center = true);
        // side vents, one band per side
        for (sx = [-1, 1])
            translate([sx * (body_w/2 - wall/2), y_back - 30, bay_h - 26])
                vents(7, 24, wall + 2*eps);
        // lead crossings down to the base
        for (x = [-40, 40])
            translate([x, y_back - wall/2, 10]) rotate([90, 0, 0])
                cylinder(d = gland_d, h = wall + 2*eps, center = true);
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HEAD — the facet, the display behind it, the carriage socket, and the tank
//  neck. DISTILLED WATER is engraved on the top surface beside the neck.
// ═════════════════════════════════════════════════════════════════════════════
// `over` widens the cutting wedge in X only. It must NOT move the plane, or
// every feature measured against the facet ends up buried inside the material.
module facet_solid(over = 0) {
    translate([0, y_front - wall, head_h - facet_rise])
        rotate([-facet_a, 0, 0])
            translate([-body_w/2 - over, -300, 0]) cube([body_w + 2*over, 300, 300]);
}

module head() {
    difference() {
        union() {
            sq_prism(body_w, body_d, head_h);
            translate([0, 0, -4]) linear_extrude(4 + eps) difference() {
                square([in_w - 2*clr, in_d - 2*clr], center = true);
                square([in_w - 16, in_d - 16], center = true);
            }
        }
        facet_solid(6);
        // Hollow the head, but keep a wall behind the facet. The facet's inward
        // normal is (0, cos a, −sin a), so shifting the cutting wedge that far
        // and subtracting it from the hollow leaves exactly `wall` of material
        // on the slope — otherwise the interior cut eats the control surface.
        difference() {
            translate([0, 0, -eps]) linear_extrude(head_h - 6)
                square([in_w, in_d], center = true);
            translate([0, wall*cos(facet_a), -wall*sin(facet_a)]) facet_solid(6);
        }
        edge_cut(body_w, body_d, head_h, cut);

        // carriage socket
        translate([cup_x, cup_y, -eps]) cylinder(d = car_d + 2*clr, h = head_h + 2*eps);

        // tank neck and its cap seat
        translate([0, neck_y, -eps]) cylinder(d = neck_d, h = head_h + 2*eps);
        translate([0, neck_y, head_h - 3]) cylinder(d = neck_d + 9 + 2*clr, h = 3 + eps);

        // DISTILLED WATER, on the top surface behind the neck
        translate([0, neck_y + 27, head_h - eng_depth]) engrave("DISTILLED WATER", 5.0);

        // Everything on the control surface, measured up the slope from the
        // facet's lower edge. Local +Y is into the material, so every cut
        // extrudes that way.
        translate([0, y_front - wall, head_h - facet_rise]) rotate([-facet_a, 0, 0]) {
            // recess for the dark panel
            translate([0, -eps, facet_h/2]) rotate([-90, 0, 0])
                linear_extrude(panel_t + eps)
                    offset(r = 3) offset(delta = -3)
                        square([body_w - 2*panel_in, facet_h - 2*panel_in], center = true);
            // display window, through the wall behind the panel
            translate([0, -eps, facet_h/2 + 6]) rotate([-90, 0, 0])
                linear_extrude(panel_t + wall + 2*eps)
                    square([tft_win_w, tft_win_h], center = true);
            // TTP223 blind pocket. A through hole here is a leak and a dead pad —
            // the pad reads through the plastic that is left.
            translate([0, panel_t - eps, facet_h/2 + 6 - pad_drop]) rotate([-90, 0, 0])
                linear_extrude(wall - pad_wall + eps)
                    square([pad_w, pad_h], center = true);
        }
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  CARRIAGE — the probes, and the one gesture that opens the machine. Flush
//  when down; lift it and the cup is free.
// ═════════════════════════════════════════════════════════════════════════════
module carriage() {
    plug_h = head_h;
    difference() {
        cylinder(d = car_d, h = plug_h);
        // hollow, so the probe bodies and their leads live inside
        translate([0, 0, car_plate]) cylinder(d = car_d - 2*wall, h = plug_h - 2*car_plate);
        // finger relief in the top face, so there is something to lift
        translate([0, 0, plug_h - 4]) cylinder(d = car_grip, h = 4 + eps);
        // probes, 60° apart on the bolt circle
        for (i = [0 : 4])
            translate([probe_r*cos(probe_a[i]), probe_r*sin(probe_a[i]), -eps])
                cylinder(d = probe_d[i] + 2*probe_gap, h = car_plate + 2*eps);
        // turbidity body down the centre — it must be in the sample to read
        translate([0, 0, -eps]) cylinder(d = turb_body_d + 2*probe_gap, h = car_plate + 2*eps);
        // lead exit
        translate([18, 0, plug_h - car_plate - eps]) cylinder(d = 16, h = car_plate + 2*eps);
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SAMPLE DRAWER — carries the cup in and out. MILK on the face, MAX beside the
//  pocket. The platform's chamfer walks the cup off it as the drawer closes.
// ═════════════════════════════════════════════════════════════════════════════
module sample_drawer() {
    face_h  = bay_h - 2*clr;
    pocket_y = cup_y - (y_front + wall);   // cup position in drawer coordinates
    difference() {
        union() {
            difference() {
                translate([-dr_w/2, 0, 0]) cube([dr_w, dr_d, dr_h]);
                translate([-dr_w/2 + wall, wall, dr_floor])
                    cube([dr_w - 2*wall, dr_d, dr_h]);
            }
            translate([0, -wall, -(dr_z - base_h) + clr]) rotate([90, 0, 0])
                linear_extrude(wall) offset(r = 4) offset(delta = -4)
                    translate([0, face_h/2]) square([body_w - 2*clr, face_h], center = true);
        }
        // cup pocket: the platform rises through it, so the cup lands on the
        // load cell and the drawer clears it by 3 mm all round
        translate([0, pocket_y, -eps]) cylinder(d = dr_pocket, h = dr_floor + 2*eps);
        // drain, so a rinse runs straight through to the waste tray
        translate([0, pocket_y - 46, -eps]) cylinder(d = 22, h = dr_floor + 2*eps);
        // MILK, on the face
        translate([0, -wall - eng_depth + eps, -(dr_z - base_h) + clr + face_h/2])
            rotate([90, 0, 0]) engrave("MILK", 8);
        // MAX, on the tray top beside the pocket — readable when it is open
        translate([0, pocket_y + dr_pocket/2 + 9, dr_h - eng_depth]) engrave("MAX 175 mL", 4.5);
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  WASTE TRAY
// ═════════════════════════════════════════════════════════════════════════════
module waste_tray() {
    difference() {
        union() {
            difference() {
                translate([-wt_w/2, 0, 0]) cube([wt_w, wt_d, wt_h]);
                translate([-wt_w/2 + 2, 2, 2]) cube([wt_w - 4, wt_d, wt_h]);
            }
            translate([0, -wall, 0]) rotate([90, 0, 0]) linear_extrude(wall)
                offset(r = 3) offset(delta = -3)
                    translate([0, (wt_h + 2*clr)/2])
                        square([wt_w + 2*wall + 2*clr, wt_h + 2*clr], center = true);
        }
        translate([0, -wall - eng_depth + eps, (wt_h + 2*clr)/2]) rotate([90, 0, 0])
            engrave("WASTE", 6);
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PLATFORM and RISER — the only things the cup touches.
// ═════════════════════════════════════════════════════════════════════════════
module platform() {
    difference() {
        union() {
            cylinder(d = plat_d, h = plat_t);
            // lead-in chamfer: the cup rides up this as the drawer shuts
            translate([0, 0, plat_t - eps])
                cylinder(d1 = plat_d, d2 = plat_d - 2*dr_ramp, h = dr_ramp);
        }
        for (y = [-lc_pitch/2, lc_pitch/2]) {
            translate([0, y, -eps]) cylinder(d = lc_hole_d, h = plat_t + 2*eps);
            translate([0, y, plat_t - 3.5]) cylinder(d = 8, h = 3.5 + eps);
        }
    }
}

module riser() {
    difference() {
        translate([-(lc_w + 10)/2, -(lc_pitch + 18)/2, 0])
            cube([lc_w + 10, lc_pitch + 18, lc_riser_h]);
        for (y = [-lc_pitch/2, lc_pitch/2])
            translate([0, y, -eps]) cylinder(d = lc_hole_d, h = lc_riser_h + 2*eps);
    }
}

module tank_cap() {
    difference() {
        union() {
            cylinder(d = neck_d + 9, h = 3);
            translate([0, 0, -6]) cylinder(d = neck_d - 2*clr, h = 6 + eps);
        }
        translate([0, 0, 3 - eng_depth]) engrave("WATER", 4.5);
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
            cylinder(d = weir_d, h = cup_od + eps, center = true);
    }
    color("Ivory", 0.6) translate([0, 0, cup_wall]) cylinder(d = cup_id - 0.4, h = fill_mm);
}

module assembly() {
    color("Gainsboro")  base();
    color("WhiteSmoke") translate([0, 0, base_h]) bay();
    color("Gainsboro")  translate([0, 0, base_h + bay_h]) head();
    color("Silver")     translate([cup_x, cup_y, base_h + bay_h]) carriage();
    color("Silver")     translate([0, neck_y, body_h - 3]) tank_cap();

    translate([cup_x, cup_y, 0]) {
        color("Silver")   translate([-lc_w/2, -lc_len/2 + lc_span/2, shelf_z + ped_h])
            cube([lc_w, lc_len, lc_h]);
        color("DarkGray") translate([0, 0, lc_free_z]) riser();
        color("Silver")   translate([0, 0, plat_z]) platform();
        translate([0, 0, plat_top]) cup_mock();
    }

    color("DarkSlateGray") translate([0, y_front + wall, dr_z]) sample_drawer();
    color("DimGray")       translate([0, y_front + wall, wt_z]) waste_tray();
}

// ═════════════════════════════════════════════════════════════════════════════
//  RENDER
// ═════════════════════════════════════════════════════════════════════════════
if      (part == "assembly")      assembly();
else if (part == "base")          base();
else if (part == "bay")           bay();
else if (part == "head")          head();
else if (part == "carriage")      carriage();
else if (part == "sample_drawer") sample_drawer();
else if (part == "waste_tray")    waste_tray();
else if (part == "platform")      platform();
else if (part == "riser")         riser();
else if (part == "tank_cap")      tank_cap();
else echo(str("Unknown part: ", part));
