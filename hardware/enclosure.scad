// ═════════════════════════════════════════════════════════════════════════════
//  Aqua Milk Detect — enclosure, Rev C
//  Companion to docs/enclosure.md and docs/wiring.md.
//
//  A single squircle tower, 126 × 136 × 220, with a telescoping column. 3.8 L
//  against Rev B's 12.4 — seventy percent smaller — because the electronics went
//  UNDER the cup instead of beside it, which also deleted the two-shell split
//  and with it every seam that ran up the sides.
//
//  ── What is open to the outside, exhaustively ──────────────────────────────
//    · the pour dish on the column cap            engraved MILK
//    · the tank neck on the top plate             engraved DISTILLED WATER
//    · the drawer aperture on the front
//    · one USB-C port, centred on the rear
//    · intake slots, underside only
//  That is the whole list. Everything else visible in an OpenSCAD PREVIEW —
//  ledges, bosses, ribs, interiors showing green — is internal structure seen
//  through the translucent fascia mock. Press F6 (or export an STL) and the body
//  is a closed shell.
//
//  ── The mechanism, and why it has to exist ─────────────────────────────────
//  The probes hang into the cup, so the cup cannot slide out horizontally past
//  them: something must separate vertically first. The column is therefore its
//  own piston, sliding 55 mm in a socket in the top plate. Lift it, the cup is
//  free; pull the drawer, dump it, push it back, drop the column.
//  The column is mechanically isolated from the load cell — if it ever binds it
//  cannot put a gram into the reading.
//
//  The cup rides ON the drawer plate. Closing the drawer walks the cup up a
//  1.5 mm chamfer onto the platform, so at rest the cup touches only the load
//  cell, and the plate's ⌀78 hole clears it by 4 mm all round.
//
//  ── One pump ───────────────────────────────────────────────────────────────
//  Fill only. Distilled water from the internal tank, over the probes, into the
//  cup — its job is rinsing the sensors, not emptying the machine. You empty the
//  machine by pulling the drawer. No drain pump, no dip tube, and no vent hole:
//  the pour dish vents.
//
//  ── Print notes ─────────────────────────────────────────────────────────────
//   part          orientation             supports  notes
//   body          as rendered (open up)   no        needs 220 mm Z
//   top_plate     as rendered (flat)      no        carries both engravings
//   shelf         as rendered (flat)      no        load-cell datum: 6 perimeters,
//                                                   60% infill, no less
//   column        as rendered (tube up)   no
//   column_cap    UPSIDE DOWN (dish down) no        duct then prints upward
//   drawer        as rendered (open up)   no
//   cup           as rendered (open up)   no        5 perimeters — it holds liquid
//   tank          as rendered (open up)   no        5 perimeters, and a silicone
//                                                   bead on the lid seam or it
//                                                   weeps into the electronics
//   tank_lid      as rendered (flat)      no
//   platform      as rendered (flat)      no        6 perimeters, 60% infill
//   riser         as rendered (flat)      no
//
//  Finish: 0.10–0.12 mm layers. Matte PETG, not PLA — PLA creeps under a bolted
//  load cell and does not survive repeated cleaning. A squircle only reads as a
//  squircle when the layer lines disappear into the curve.
//
//  Not printed: the load cell, the smoked acrylic fascia, the colour window,
//  magnets, silicone tube, four M4 bolts.
// ═════════════════════════════════════════════════════════════════════════════

part = "assembly";  // "assembly" | "body" | "top_plate" | "shelf" | "column" | "column_cap" | "drawer" | "cup" | "tank" | "tank_lid" | "platform" | "riser"

column_lifted = false;   // true previews the column raised, cup clear of probes
section       = false;   // true cuts the assembly on the centreline, so you can
                         // see the milk path and where the probes actually sit

$fn = 72;

// ─────────────────────────────────────────────────────────────────────────────
//  1. Print / fit
// ─────────────────────────────────────────────────────────────────────────────
wall          = 3.0;
floor_t       = 4.0;
clr           = 0.3;
eps           = 0.02;
merge         = 1.0;    // every feature sinks this far into its parent, so
                        // unions share volume instead of touching on a tangent
reveal        = 0.45;   // uniform seam gap; below this a 0.4 nozzle bridges it

// ─────────────────────────────────────────────────────────────────────────────
//  2. The squircle
// ─────────────────────────────────────────────────────────────────────────────
sq_n          = 5;
sq_steps      = 96;
shoulder      = 6;      // G2 top-edge blend
shoulder_n    = 3;
shoulder_step = 16;

// ─────────────────────────────────────────────────────────────────────────────
//  3. Envelope
// ─────────────────────────────────────────────────────────────────────────────
body_w        = 126;
body_d        = 136;
body_h        = 220;
base_inset    = 3;      // undercut, so the tower floats
base_h        = 6;

in_w          = body_w - 2*wall;    // 120
in_d          = body_d - 2*wall;    // 130

// ─────────────────────────────────────────────────────────────────────────────
//  4. Chamber, cup and dose
//
//  The bore is set by the probes, never by the volume. The turbidity body sits
//  in the sample and the pH probe sits beside it, and both need real plastic
//  between them:
//      bore >= turb_body_d + 2*(ph_probe_d + 2*probe_gap + 2*rib_min)
//        67 >= 35 + 2*(12 + 1.2 + 2.4)
//  ⌀62 is the arithmetic minimum and leaves 0.3 mm of rib. Not buildable.
// ─────────────────────────────────────────────────────────────────────────────
turb_body_d   = 35;     // measured
ph_probe_d    = 12;
tds_probe_d   = 10;
ds18b20_d     =  6;
probe_gap     =  0.6;
rib_min       =  1.2;
feed_tube_d   =  8;

bore          = 67;
cup_wall      = 2.5;
cup_od        = bore + 2*cup_wall;      // 72
cup_h         = 55;
cup_base_d    = 80;                     // sits on the drawer plate
cup_base_t    = 3;
dose_ml       = 85;
ph_tip_gap    =  5;
fill_mm       = dose_ml * 1000 / (PI * pow(bore/2, 2));

platform_d    = 70;
platform_t    = 5;
plate_hole_d  = platform_d + 8;         // 78 — 4 mm clear of the platform
lift_step     = 1.5;                    // how far the platform lifts the cup off
                                        // the drawer; also the chamfer that does it

probe_r       = bore/2 - ph_probe_d/2 - probe_gap - rib_min;   // 25.8
probe_a       = [90, 162, 234, 306, 18];    // pH, TDS, DS18B20, feed, fill slot
fill_w        = 13;
fill_arc      = 26;
dish_w        = 30;
dish_depth    = 10;
chute_wall    =  1.6;   // inboard wall of the fill chute; the column wall is the
                        // outboard side, so the chute costs almost no diameter

// ─────────────────────────────────────────────────────────────────────────────
//  5. Vertical stack — every level derived, so one change moves the rest
// ─────────────────────────────────────────────────────────────────────────────
base_top      = 75;                     // tank, pump, boards live below this
shelf_t       =  8;
ped_h         = 10;
lc_w          = 12.7;
lc_h          = 12.7;
lc_len        = 80;
lc_pitch      = 15;
lc_span       = 55;
lc_hole_d     =  4.5;
lc_nut_af     =  8.1;
riser_h       = 12;

shelf_z       = base_top;                              // 75
bar_z         = shelf_z + shelf_t + ped_h;             // 93    bar underside
plat_z        = bar_z + lc_h + riser_h;                // 117.7 platform underside
plate_z       = plat_z + platform_t - lift_step - 4;   // drawer plate underside
cup_z         = plat_z + platform_t;                   // cup floor, seated
rim_z         = cup_z + cup_h;
socket_z      = rim_z + 2;                             // column rim, closed

col_od        = cup_od;                 // the column continues the cup's line
col_wall      = 3;
col_h         = 100;
col_travel    = 55;
socket_h      = body_h - socket_z;
cap_t         = 6;

// ─────────────────────────────────────────────────────────────────────────────
//  6. Water tank — a slab against the rear wall, filled through the top plate
// ─────────────────────────────────────────────────────────────────────────────
tank_w        = 108;
tank_d        =  30;
tank_h        = 150;
tank_wall     =   2;
neck_d        =  26;
neck_x        =  body_w/2;
neck_y        =  body_d - wall - tank_d/2;

// ─────────────────────────────────────────────────────────────────────────────
//  7. Front face, IO, engraving
// ─────────────────────────────────────────────────────────────────────────────
// Everything on the front face shares ONE width and ONE reveal. Three different
// widths stacked up a face — fascia one size, drawer another, body a third — is
// what makes a product look unresolved, and it was the first thing wrong here.
front_w       = 110;
front_x0      = (body_w - front_w)/2;

fascia_x0     = front_x0;
fascia_x1     = front_x0 + front_w;
fascia_z0     = 18;
fascia_z1     = 96;
fascia_t      = 2.0;
fascia_back   = 2.0;

// Display. The module mounts from INSIDE: its PCB drops into a locating pocket
// and its glass — which stands ~1 mm proud of the PCB — pokes forward into the
// window, so it ends up about 2 mm behind the acrylic. Standoffs would push it
// back into a tunnel and the window would vignette off-axis.
// Window is deliberately larger than the 35 × 28 active area. A tight window
// plus any standoff depth makes a tunnel that vignettes off-axis; the smoked
// fascia hides the oversize opening, so only lit pixels ever show.
tft_win_w     = 40;
tft_win_h     = 32;
tft_pcb_w     = 56;     // module PCB, +clearance added below
tft_pcb_h     = 34;
tft_pcb_t     =  1.6;
tft_pocket_d  =  0.8;   // locating pocket depth; the PCB is screwed, not buried
tft_hole_x    = 51;     // 4 × ⌀2.2 corner pattern — MEASURE YOURS
tft_hole_y    = 29;
tft_pilot_d   =  1.7;   // M2 self-tapping into PETG
tft_pilot_h   =  3.5;   // stops short of the outer surface — 4 mm breaks through
tft_pad_t     =  2;     // extra stock behind the rib, so the pilots have meat
pad_w         = 20;
pad_h         = 16;
pad_wall      = 1.2;

// ── The angled console ───────────────────────────────────────────────────────
// The ST7735 is a TN panel with a narrow vertical viewing cone. On a 220 mm
// tower standing on a bench you look DOWN at it, which is exactly the angle
// where it washes out and inverts. A vertical screen here was the worst
// available orientation, so the front carries a sloped console instead — the
// same move a benchtop analyser makes, for the same reason.
//
// It costs nothing to print: the face RECEDES as it rises, so every layer sits
// on the one below, and the underside returns at 45°, which is self-supporting
// too. Nothing inside the body moves — the console is added in front of the
// existing wall, so the cup, tank, shelf and drawer keep their positions.
//
// Display and touch pad both sit on this one plane: one control surface, not a
// screen on one face and a button on another.
console_out   = 22;     // how far the console stands proud at its widest point
console_z1    = 100;    // where it rejoins the vertical face
console_ang   = atan(console_out / (console_z1 - base_h - console_out));
console_len   = sqrt(pow(console_out, 2) + pow(console_z1 - base_h - console_out, 2));

// Positions on the console are measured UP THE SLOPE from its foot, not in Z.
tft_cs        = 46;     // window centre
pad_cs        = 15;     // touch target, below the screen on the same plane
tft_seat      =  7;     // how deep the PCB sits below the console face. Must
                        // clear fascia_t + the skin, and stay inside the
                        // console's thickness at tft_cs — the echo checks it.
fascia_cs0    = 5;
fascia_cs1    = console_len - 5;
fascia_w      = front_w - 8;

// Stock available behind the window, measured perpendicular to the sloped face.
// The PCB seat plus its pocket has to fit inside this or the display mount
// surfaces through the front of the console.
function console_stock(s) = (wall - (-console_out + s*sin(console_ang))) * cos(console_ang);

usb_w         = 9.4;    // USB-C + fit. The only port.
usb_h         = 3.6;
usb_z         = 34;
usb_relief    = 1.2;

label_depth   = 0.4;    // recessed, not embossed: an embossed label wears and
label_size    = 5.0;    // catches dirt, a recessed one just holds a shadow
label_font    = "Liberation Sans:style=Bold";

drawer_h      = 40;
dw_plate_t    =  4;
dw_w          = front_w - 2*4;   // so the drawer FRONT lands on front_w exactly
dw_d          =  96;
dw_front_t    =  4;
dw_pull       = 44;

magnet_d      = 6.3;
magnet_h      = 3.2;
boss_d        = 12;

// Deliberately NOT equally spaced. Three magnets at 120° would let the cap seat
// in three orientations, and only one of them puts the pour duct over the fill
// slot. An asymmetric triangle keys it to one position with no extra parts.
cap_magnet_a  = [0, 105, 215];
vent_slot_w   = 3;

col_win       = 20;     // colour sensor window through the side wall
col_rebate    = 24;
col_rebate_t  = 1.5;

function cup_y() = wall + 8 + cup_base_d/2;   // cup centre, forward of the tank

echo(str("Body            : ", body_w, " x ", body_d, " x ", body_h,
         " mm; closed height ", socket_z + col_h + cap_t));
echo(str("Volume vs Rev B : ", 100 * body_w*body_d*body_h / (242*165*311), "%"));
echo(str("Bore / dose     : ", bore, " mm, ", dose_ml, " mL -> ", fill_mm, " mm fill"));
echo(str("pH immersion    : ", fill_mm - ph_tip_gap, " mm"));
echo(str("Probe ribs      : ", probe_r - ph_probe_d/2 - probe_gap - turb_body_d/2,
         " inner / ", bore/2 - probe_r - ph_probe_d/2 - probe_gap, " outer mm (want > 0.8)"));
echo(str("Column travel   : ", col_travel, " mm; needs ",
         rim_z - (cup_z + cup_base_t + ph_tip_gap) + 5, " mm to clear the cup"));
echo(str("Tank            : ", tank_w * tank_d * tank_h / 1000, " mL"));
echo(str("Cup rim / body  : ", rim_z, " / ", body_h));
echo(str("Console         : ", console_ang, " deg from vertical, ", console_len,
         " mm face, stands ", console_out, " mm proud"));
echo(str("Stock at window : ", console_stock(tft_cs), " mm (need ",
         tft_seat + tft_pocket_d, " for the display seat)"));

// ═════════════════════════════════════════════════════════════════════════════
//  PRIMITIVES
// ═════════════════════════════════════════════════════════════════════════════
function sq_x(t, a, n) = a * sign(cos(t)) * pow(abs(cos(t)), 2/n);
function sq_y(t, b, n) = b * sign(sin(t)) * pow(abs(sin(t)), 2/n);
function sq_pts(w, d, n, steps) =
    [ for (i = [0 : steps - 1]) let (t = 360 * i / steps)
        [w/2 + sq_x(t, w/2, n), d/2 + sq_y(t, d/2, n)] ];

module squircle(w, d, h, n = sq_n, steps = sq_steps) {
    linear_extrude(height = h) polygon(sq_pts(w, d, n, steps));
}

// The same profile stood up in X–Z, thickness t in +Y. Front-face features have
// to be squircles too; a rounded-rectangle window in a squircle body is the tell
// of a language copied rather than understood.
module squircle_panel(w, h, t, n = sq_n) {
    translate([0, t, 0]) rotate([90, 0, 0]) squircle(w, h, t, n);
}

// Flat top blended into the side wall by a superelliptic curve in Z, so the
// transition is curvature-continuous vertically as well as in plan. Without it
// the corners are G2 and the top edge is still a hard break.
module squircle_shouldered(w, d, h, sh = shoulder, n = sq_n) {
    squircle(w, d, h - sh, n);
    translate([0, 0, h - sh])
        for (i = [0 : shoulder_step - 1]) {
            u0 = i / shoulder_step;  u1 = (i + 1) / shoulder_step;
            in0 = sh * (1 - pow(1 - pow(u0, shoulder_n), 1/shoulder_n));
            in1 = sh * (1 - pow(1 - pow(u1, shoulder_n), 1/shoulder_n));
            hull() {
                translate([in0, in0, u0 * sh]) squircle(w - 2*in0, d - 2*in0, eps, n);
                translate([in1, in1, u1 * sh]) squircle(w - 2*in1, d - 2*in1, eps, n);
            }
        }
}

module arc_slot(r, a, sweep, w, h) {
    hull() for (s = [-1, 1])
        rotate([0, 0, a + s * sweep/2]) translate([r, 0, 0]) cylinder(d = w, h = h);
}

module vents(n, len, w = vent_slot_w, pitch = 7, thick = 20) {
    for (i = [0 : n - 1])
        translate([(i - (n - 1)/2) * pitch, 0, 0])
            translate([-w/2, -len/2, -thick/2]) cube([w, len, thick]);
}

// Recessed label. 0.4 mm is two layers at 0.2 — enough to hold a shadow line,
// shallow enough that it never collects milk.
module label(txt, size = label_size) {
    linear_extrude(label_depth + eps)
        text(txt, size = size, font = label_font, halign = "center", valign = "center");
}

// Magnet bosses sit well inboard, not in the corners. A squircle's corner curves
// away from where a rectangle's corner would be, so anything parked out there
// pushes through the outer surface.
boss_inset    = 16;
function boss_pos() =
    [ for (x = [wall + boss_inset, body_w - wall - boss_inset],
           y = [wall + boss_inset, body_d - wall - boss_inset]) [x, y] ];

// ── Console frame ────────────────────────────────────────────────────────────
// Origin sits at the foot of the sloped face, X across it, +Z up the slope and
// +Y into the material. Everything on the console is placed in here, so the
// angle is changed in one place and the display, pad and fascia all follow.
module on_console() {
    translate([body_w/2, -console_out, base_h + console_out])
        rotate([-console_ang, 0, 0]) children();
}

// One horizontal slice of the console: full front width, from y0 back to the
// body wall. Three of them hulled give the wedge — 45° underside, sloped face.
module console_rib(z, y0) {
    translate([body_w/2 - front_w/2, y0, z]) cube([front_w, wall - y0, 0.6]);
}

module console_solid() {
    intersection() {
        hull() {
            console_rib(base_h, 0);                       // foot, flush
            console_rib(base_h + console_out, -console_out);   // widest point
            console_rib(console_z1, 0);                   // rejoins the face
        }
        // rounds the console's side edges into the same language as the body
        translate([body_w/2, 0, 0]) linear_extrude(body_h)
            offset(r = 6) offset(delta = -6) square([front_w, 240], center = true);
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  BODY — one piece, floor to top plate. No vertical seam anywhere on it.
// ═════════════════════════════════════════════════════════════════════════════
module body() {
    difference() {
        // Every internal rib, ledge and boss is clipped to the outer profile.
        // Internal structure is laid out on the interior RECTANGLE; the outer
        // surface is a superellipse that curves inside that rectangle near the
        // corners, so without this clip the ledges surface as scars on the sides.
        union() {
        intersection() {
        squircle(body_w, body_d, body_h);
        union() {
            difference() {
                squircle(body_w, body_d, body_h);
                translate([wall, wall, floor_t]) cube([in_w, in_d, body_h]);
                difference() {   // undercut base band, so the tower floats
                    translate([-10, -10, -eps]) cube([body_w + 20, body_d + 20, base_h + eps]);
                    translate([base_inset, base_inset, -1])
                        squircle(body_w - 2*base_inset, body_d - 2*base_inset, base_h + 2);
                }
            }
            // continuous seat for the load-cell shelf
            translate([wall - merge, wall - merge, shelf_z - 4])
                difference() {
                    cube([in_w + 2*merge, in_d + 2*merge, 4]);
                    translate([wall + 5, wall + 5, -eps]) cube([in_w - 16, in_d - 16, 4 + 2*eps]);
                }
            // drawer runners
            translate([wall - merge, wall - merge, plate_z - 3])
                difference() {
                    cube([in_w + 2*merge, in_d + 2*merge, 3]);
                    translate([wall + 3, wall + 3, -eps]) cube([in_w - 12, in_d - 12, 3 + 2*eps]);
                }
            // magnet bosses for the top plate
            for (p = boss_pos()) translate([p[0], p[1], body_h - 20]) cylinder(d = boss_d, h = 20);
            // fascia backing rib, and a local pad of stock behind the display so
            // the mounting pilots have something to bite into
            translate([wall, wall, fascia_z0]) cube([in_w, fascia_back, fascia_z1 - fascia_z0]);
        }
        }
        console_solid();
        }
        for (p = boss_pos())
            translate([p[0], p[1], body_h - magnet_h]) cylinder(d = magnet_d, h = magnet_h + eps);

        // drawer aperture
        translate([(body_w - (dw_w + 2*reveal))/2, -eps, plate_z - dw_front_t - reveal])
            cube([dw_w + 2*reveal, wall + 2*eps, drawer_h + 2*reveal]);

        // ── everything below is cut in the console frame, on the sloped face ──
        on_console() {
            // fascia recess: the acrylic sits ON the slope, and it is also what
            // hides the layer stair-stepping an angled printed surface would
            // otherwise show. Angle it, then cover it.
            translate([-fascia_w/2, -eps, fascia_cs0])
                squircle_panel(fascia_w, fascia_cs1 - fascia_cs0, fascia_t + eps);

            // window, straight through the console into the interior
            translate([-tft_win_w/2, -eps, tft_cs - tft_win_h/2])
                cube([tft_win_w, 60, tft_win_h]);

            // PCB locating pocket and its four pilots. The module is screwed
            // from behind — M2 × 6 self-tapping — so it lands parallel to the
            // face and its glass looks up at you, not off into the room.
            translate([0, tft_seat + tft_pocket_d/2, tft_cs])
                cube([tft_pcb_w + 2*clr, tft_pocket_d, tft_pcb_h + 2*clr], center = true);
            for (x = [-tft_hole_x/2, tft_hole_x/2], z = [-tft_hole_y/2, tft_hole_y/2])
                translate([x, tft_seat + tft_pocket_d - eps, tft_cs + z])
                    rotate([-90, 0, 0]) cylinder(d = tft_pilot_d, h = tft_pilot_h + eps);

            // TTP223 blind pocket, measured from the BOTTOM of the fascia
            // recess. Measure from the original face instead and this becomes a
            // through hole: a leak, and a pad that never fires.
            translate([-pad_w/2, fascia_t + pad_wall, pad_cs - pad_h/2])
                cube([pad_w, 8, pad_h]);
        }

        // ── the one port ──
        translate([body_w/2, body_d - wall/2, usb_z]) {
            hull() for (s = [-1, 1])
                translate([s*(usb_w - usb_h)/2, 0, 0])
                    rotate([90, 0, 0]) cylinder(d = usb_h, h = wall + 2*eps, center = true);
            translate([0, wall/2 - usb_relief/2 + eps, 0])
                hull() for (s = [-1, 1])
                    translate([s*(usb_w - usb_h)/2, 0, 0])
                        rotate([90, 0, 0]) cylinder(d = usb_h + 2.4, h = usb_relief, center = true);
        }

        // colour sensor: window through the side wall, board stays dry behind it
        translate([wall/2, cup_y(), cup_z + 18])
            cube([wall + 2*eps, col_win, col_win], center = true);
        translate([wall - col_rebate_t/2 + eps, cup_y(), cup_z + 18])
            cube([col_rebate_t + eps, col_rebate, col_rebate], center = true);

        // intake, underside only
        translate([body_w/2, body_d/2, floor_t/2]) vents(9, 60, 4, 9, floor_t + 2);
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  TOP PLATE — closes the body, carries the column socket, the tank neck and
//  both engravings. Held by four magnets: nothing on this face is a fastener.
// ═════════════════════════════════════════════════════════════════════════════
module top_plate() {
    plate_t = shoulder + 4;
    difference() {
        union() {
            squircle_shouldered(body_w, body_d, plate_t, shoulder);
            translate([wall + 1.6 + clr, wall + 1.6 + clr, -4])
                difference() {   // locating lip into the body
                    cube([in_w - 3.2 - 2*clr, in_d - 3.2 - 2*clr, 4 + eps]);
                    translate([1.6, 1.6, -eps])
                        cube([in_w - 6.4 - 2*clr, in_d - 6.4 - 2*clr, 4 + 3*eps]);
                }
            // column socket, hanging into the body
            translate([body_w/2, cup_y(), -socket_h])
                cylinder(d = col_od + 2*clr + 2*wall, h = socket_h + plate_t);
            // tank neck
            translate([neck_x, neck_y, -14]) cylinder(d = neck_d + 2*wall, h = 14 + plate_t);
        }
        for (p = boss_pos()) translate([p[0], p[1], -eps]) cylinder(d = magnet_d, h = magnet_h + eps);
        translate([body_w/2, cup_y(), -socket_h - eps]) cylinder(d = col_od + 2*clr, h = 300);
        translate([neck_x, neck_y, -14 - eps]) cylinder(d = neck_d, h = 300);

        // ── engraving ──
        translate([neck_x, neck_y - neck_d/2 - wall - 7, plate_t - label_depth])
            label("DISTILLED WATER", 4.4);
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHELF — drop-in, and the load cell's datum. The pedestal is printed into it:
//  a bolted cell wants one stiff piece of plastic, not a stack of them.
// ═════════════════════════════════════════════════════════════════════════════
module shelf() {
    ped_y = cup_y() + lc_span;
    difference() {
        union() {
            translate([wall + clr, wall + clr, 0]) cube([in_w - 2*clr, in_d - 2*clr, shelf_t]);
            translate([body_w/2 - (lc_w + 12)/2, ped_y - (lc_pitch + 20)/2, shelf_t - merge])
                cube([lc_w + 12, lc_pitch + 20, ped_h + merge]);
        }
        for (y = [ped_y - lc_pitch/2, ped_y + lc_pitch/2]) {
            translate([body_w/2, y, -eps]) cylinder(d = lc_hole_d, h = shelf_t + ped_h + 2*eps);
            translate([body_w/2, y, -eps]) cylinder(d = lc_nut_af / cos(30), h = 4, $fn = 6);
        }
        // the tank passes through, and cables route up the front corners
        translate([body_w/2 - tank_w/2 - clr, body_d - wall - tank_d - clr, -eps])
            cube([tank_w + 2*clr, tank_d + 2*clr, shelf_t + 2*eps]);
        for (x = [22, in_w - 22])
            translate([wall + x, wall + 14, -eps]) cylinder(d = 13, h = shelf_t + 2*eps);
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  COLUMN — its own piston. Lift 55 mm and the cup is free. The probes hang
//  from the carrier at its top; the pH probe's 150 mm body sets this length.
// ═════════════════════════════════════════════════════════════════════════════
module column() {
    difference() {
      union() {
        cylinder(d = col_od, h = col_h);
        // Fill chute. Without it the sample free-falls the whole length of the
        // column and splashes down the probe shafts on the way. This rib closes
        // the inboard side of the fill slot so the milk runs as a stream against
        // the column wall and is delivered at the cup rim instead.
        translate([0, 0, -eps]) difference() {
            arc_slot(probe_r, probe_a[4], fill_arc, fill_w + 2*chute_wall, col_h - 6 + eps);
            translate([0, 0, -eps])
                arc_slot(probe_r, probe_a[4], fill_arc, fill_w, col_h - 6 + 3*eps);
            // open the outboard side — the column wall is that side of the chute
            translate([0, 0, -2*eps]) rotate([0, 0, probe_a[4]])
                translate([probe_r, 0, 0])
                    cube([fill_w, fill_w + 4*chute_wall, col_h], center = true);
        }
      }
        translate([0, 0, -eps]) cylinder(d = col_od - 2*col_wall, h = col_h - 6 + eps);
        // carrier plate is the top 6 mm — the probes pass through it
        translate([0, 0, col_h - 6 - eps]) {
            cylinder(d = turb_body_d + 2*probe_gap, h = 6 + 2*eps);
            for (i = [0 : 3])
                translate([probe_r*cos(probe_a[i]), probe_r*sin(probe_a[i]), 0])
                    cylinder(d = [ph_probe_d, tds_probe_d, ds18b20_d, feed_tube_d][i]
                                 + (i < 3 ? 2*probe_gap : 0), h = 6 + 2*eps);
            arc_slot(probe_r, probe_a[4], fill_arc, fill_w, 6 + 2*eps);
        }
        // grip: two shallow scallops you can find without looking
        for (a = [0, 180])
            rotate([0, 0, a]) translate([col_od/2 + 2.2, 0, col_h - 40])
                cylinder(d = 10, h = 30);
        // cable exit under the cap
        rotate([0, 0, 200]) translate([col_od/2 - col_wall/2, 0, col_h - 12])
            rotate([90, 0, 0]) cylinder(d = 7, h = col_od, center = true);
        for (a = cap_magnet_a)
            translate([(col_od/2 - col_wall - 4)*cos(a), (col_od/2 - col_wall - 4)*sin(a),
                       col_h - magnet_h]) cylinder(d = magnet_d, h = magnet_h + eps);
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  COLUMN CAP — the top of the product, and the way milk gets in. Pour into the
//  dish, it runs down the duct into the cup. Engraved MILK.
// ═════════════════════════════════════════════════════════════════════════════
module column_cap() {
    duct_h = 10;
    difference() {
        union() {
            cylinder(d = col_od - 1.5, h = cap_t);
            translate([0, 0, -duct_h])
                arc_slot(probe_r, probe_a[4], fill_arc, fill_w + 3, duct_h + eps);
        }
        hull() {
            translate([0, 0, cap_t - eps]) arc_slot(probe_r, probe_a[4], fill_arc, dish_w, eps);
            translate([0, 0, cap_t - dish_depth])
                arc_slot(probe_r, probe_a[4], fill_arc, fill_w - 2*clr, eps);
        }
        translate([0, 0, -duct_h - eps])
            arc_slot(probe_r, probe_a[4], fill_arc, fill_w - 2*clr, duct_h + cap_t + 2*eps);
        for (a = cap_magnet_a)
            translate([(col_od/2 - col_wall - 4)*cos(a), (col_od/2 - col_wall - 4)*sin(a), -eps])
                cylinder(d = magnet_d, h = magnet_h + eps);
        // ── engraving, opposite the dish and reading horizontally from the
        //    front of the product; the cap can only seat one way, so it stays put
        translate([-16, 0, cap_t - label_depth]) label("MILK");
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  DRAWER and CUP — pull, dump, push back. The cup rides on the plate and the
//  platform lifts it clear as the drawer closes.
// ═════════════════════════════════════════════════════════════════════════════
module drawer() {
    difference() {
        union() {
            translate([(body_w - dw_w)/2, wall + clr, 0]) cube([dw_w, dw_d, dw_plate_t]);
            translate([(body_w - dw_w)/2 - dw_front_t, wall + clr - dw_front_t, -dw_front_t])
                squircle_panel(dw_w + 2*dw_front_t, drawer_h, dw_front_t + merge, sq_n);
        }
        translate([body_w/2, cup_y(), -eps]) cylinder(d = plate_hole_d, h = dw_plate_t + 2*eps);
        translate([(body_w - dw_pull)/2, wall + clr - dw_front_t - eps, drawer_h - dw_front_t - 10])
            cube([dw_pull, dw_front_t + 2*eps, 14]);
        // The three openings a user has to find are milk in, water in and waste
        // out. Two were engraved and this one was not, which is worse than
        // labelling none — an unlabelled aperture beside two labelled ones reads
        // as a slot you are not supposed to open.
        translate([body_w/2, wall + clr - dw_front_t + label_depth, drawer_h/2 - dw_front_t - 4])
            rotate([90, 0, 0]) label("WASTE");
    }
}

module cup() {
    difference() {
        union() {
            cylinder(d = cup_base_d, h = cup_base_t);
            cylinder(d = cup_od, h = cup_h);
        }
        translate([0, 0, cup_base_t]) cylinder(d = bore, h = cup_h);
        // the chamfer that walks the cup up onto the platform as the drawer shuts
        translate([0, 0, -eps])
            cylinder(d1 = platform_d + 2*lift_step, d2 = platform_d - 1, h = lift_step + eps);
    }
}

module platform() {
    difference() {
        union() {
            cylinder(d = platform_d, h = platform_t);
            translate([0, 0, platform_t - eps])
                cylinder(d1 = platform_d, d2 = platform_d - 2*lift_step, h = lift_step);
        }
        for (y = [-lc_pitch/2, lc_pitch/2]) {
            translate([0, y, -eps]) cylinder(d = lc_hole_d, h = platform_t + 2*eps);
            translate([0, y, platform_t - 3]) cylinder(d = 8, h = 3 + eps);
        }
    }
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
//  TANK — a slab against the rear wall, filled through the neck in the top
//  plate. Print at 5 perimeters and run a silicone bead on the lid seam; an
//  unsealed printed tank weeps, quietly, into the electronics underneath it.
// ═════════════════════════════════════════════════════════════════════════════
module tank() {
    difference() {
        cube([tank_w, tank_d, tank_h]);
        translate([tank_wall, tank_wall, tank_wall])
            cube([tank_w - 2*tank_wall, tank_d - 2*tank_wall, tank_h]);
        translate([12, tank_d/2, -eps]) cylinder(d = 6.4, h = tank_wall + 2*eps);  // pump pickup
    }
}

module tank_lid() {
    difference() {
        union() {
            cube([tank_w, tank_d, 3]);
            translate([tank_wall + clr, tank_wall + clr, -3])
                cube([tank_w - 2*tank_wall - 2*clr, tank_d - 2*tank_wall - 2*clr, 3 + eps]);
        }
        translate([tank_w/2, tank_d/2, -3 - eps]) cylinder(d = neck_d - 2, h = 6 + 2*eps);
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ASSEMBLY (mocks are not printed)
// ═════════════════════════════════════════════════════════════════════════════
module assembly() {
    if (section) difference() { assembly_solid(); translate([body_w/2, -50, -50]) cube([200, 300, 500]); }
    else assembly_solid();
}

// Probe mock — the real probes are bought parts, but without them on screen it
// is impossible to see that the sensors hang from the column INTO the cup.
module probe_mock(d, len) { color("DimGray") cylinder(d = d, h = len); }

module assembly_solid() {
    lift = column_lifted ? col_travel : 0;

    color("Gainsboro")  body();
    color("WhiteSmoke") translate([0, 0, shelf_z]) shelf();
    color("Gainsboro")  translate([0, 0, body_h]) top_plate();

    color("Silver")   translate([body_w/2, cup_y(), plat_z]) platform();
    color("DarkGray") translate([body_w/2, cup_y(), bar_z + lc_h]) riser();
    color("Silver")   translate([body_w/2 - lc_w/2, cup_y() - lc_len/2 + lc_span/2, bar_z])
        cube([lc_w, lc_len, lc_h]);

    color("LightGray") translate([0, 0, plate_z]) drawer();
    color("Gainsboro") translate([body_w/2, cup_y(), cup_z]) cup();

    color("Gainsboro") translate([body_w/2, cup_y(), socket_z + lift]) column();
    color("Silver")    translate([body_w/2, cup_y(), socket_z + lift + col_h]) column_cap();

    // Probes, hanging from the carrier at the top of the column down into the
    // cup. carrier_z is where they are clamped; the tips stop ph_tip_gap above
    // the cup floor.
    carrier_z = socket_z + lift + col_h - 6;
    tip_z     = cup_z + cup_base_t + ph_tip_gap + lift;
    translate([body_w/2, cup_y(), 0]) {
        translate([0, 0, tip_z]) probe_mock(turb_body_d, carrier_z - tip_z + 30);
        for (i = [0 : 2])
            translate([probe_r*cos(probe_a[i]), probe_r*sin(probe_a[i]), tip_z])
                probe_mock([ph_probe_d, tds_probe_d, ds18b20_d][i], carrier_z - tip_z + 24);
        // flush feed line, ending above the fill line
        translate([probe_r*cos(probe_a[3]), probe_r*sin(probe_a[3]), tip_z + 26])
            probe_mock(feed_tube_d, carrier_z - tip_z);
    }

    color("WhiteSmoke") translate([body_w/2 - tank_w/2, body_d - wall - tank_d, floor_t]) tank();

    // Opaque, because that is what smoked acrylic actually is. A translucent
    // mock here is why the preview looked full of holes.
    color("DimGray") on_console()
        translate([-fascia_w/2, 0, fascia_cs0])
            squircle_panel(fascia_w, fascia_cs1 - fascia_cs0, fascia_t);
}

// ═════════════════════════════════════════════════════════════════════════════
//  RENDER
// ═════════════════════════════════════════════════════════════════════════════
if      (part == "assembly")   assembly();
else if (part == "body")       body();
else if (part == "top_plate")  top_plate();
else if (part == "shelf")      shelf();
else if (part == "column")     column();
else if (part == "column_cap") column_cap();
else if (part == "drawer")     drawer();
else if (part == "cup")        cup();
else if (part == "tank")       tank();
else if (part == "tank_lid")   tank_lid();
else if (part == "platform")   platform();
else if (part == "riser")      riser();
else echo(str("Unknown part: ", part));
