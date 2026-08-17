// app.js — Aqua Milk Detect web app: routing, Calibrate and Collect.
// Protocol + CSV schema: PROJECT_CONTEXT.md §8 and §5. State is in memory only.
import { SerialLink, supported } from "./serial.js";

const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const SECTIONS = ["home", "flash", "calibrate", "collect", "run"];
const fmt = (v, d = 0) => (v == null || Number.isNaN(Number(v)) ? "–" : Number(v).toFixed(d));
// The source field is free text the user types, and it gets rendered into a table
// via innerHTML — escape it so a stray "<" cannot rewrite the page.
const esc = s => String(s).replace(/[&<>"']/g, c =>
  ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

// --------------------------------------------------------------------- routing
function route() {
  const id = (location.hash || "#home").slice(1);
  const at = SECTIONS.includes(id) ? id : "home";
  SECTIONS.forEach(s => ($("#" + s).hidden = s !== at));
  $$("nav a").forEach(a => {
    if (a.hash === "#" + at) a.setAttribute("aria-current", "page");
    else a.removeAttribute("aria-current");
  });
  scrollTo({ top: 0 });
  moveNavPill();
}
addEventListener("hashchange", route);
route();

// ------------------------------------------------------------ browser support
if (!supported()) {
  const n = $("#compat");
  n.hidden = false;
  n.innerHTML = /Mobi|Android|iPhone/i.test(navigator.userAgent)
    ? "<b>Phone or tablet?</b> Flashing and the Calibrate/Collect pages need a desktop browser. The finished tester itself works fine from a phone — see <a href='#run'>Run</a>."
    : "<b>This browser cannot talk to the device.</b> Web Serial and browser flashing exist only in desktop Chrome and Edge. Everything else on this site still works.";
}

// ponytail: no JS for scroll reveal. It is CSS `animation-timeline: view()` in app.css —
// no observer to construct, no class bookkeeping, and nothing can leave content hidden if
// the script fails, which an opacity:0-until-JS approach can.

// ----------------------------------------------------------- micro-interactions
// CSS cannot read the pointer, so feed it in. Everything below writes custom properties
// only — no classes, no layout thrash — and it is all skipped under reduced motion.
const MOTION_OK = !matchMedia("(prefers-reduced-motion: reduce)").matches;

if (MOTION_OK) {
  addEventListener("pointermove", e => {
    // glass surfaces: the specular bloom follows the cursor and the card leans into it
    const card = e.target.closest?.(".card, .glass");
    if (card) {
      const r = card.getBoundingClientRect();
      const px = (e.clientX - r.left) / r.width;
      const py = (e.clientY - r.top) / r.height;
      card.style.setProperty("--mx", `${px * 100}%`);
      card.style.setProperty("--my", `${py * 100}%`);
      card.style.setProperty("--ry", `${(px - .5) * 4}deg`);   // 2 degrees max
      card.style.setProperty("--rx", `${(.5 - py) * 4}deg`);
      // Rotate the rim gradient so its hot spot faces the cursor: the light source
      // moves, the way it does on a real pane tilted under a lamp.
      const deg = (Math.atan2(py - .5, px - .5) * 180) / Math.PI + 270;
      card.style.setProperty("--rim-angle", `${deg}deg`);
    }
    // buttons drift a few pixels toward the cursor
    const btn = e.target.closest?.("button, .btn");
    if (btn) {
      const r = btn.getBoundingClientRect();
      btn.style.setProperty("--bx", `${((e.clientX - r.left) / r.width - .5) * 6}px`);
      btn.style.setProperty("--by", `${((e.clientY - r.top) / r.height - .5) * 4}px`);
    }
  }, { passive: true });

  // Release cleanly, or a card stays cocked at an angle after the pointer leaves.
  addEventListener("pointerout", e => {
    const el = e.target.closest?.(".card, .glass, button, .btn");
    if (!el || el.contains(e.relatedTarget)) return;
    for (const p of ["--rx", "--ry", "--bx", "--by", "--rim-angle"]) el.style.removeProperty(p);
  }, { passive: true });
}

// ---------------------------------------------------------------------- theme
// Explicit light/dark choice, remembered. With no choice stored the page follows the
// system, which is why the attribute is only ever set when the user actually picks.
// localStorage holds a display preference, not data — the no-storage rule in
// PROJECT_CONTEXT §? is about collected samples, which still never touch disk.
const THEME_KEY = "amd-theme";
function applyTheme(mode) {
  if (mode === "light" || mode === "dark") document.documentElement.dataset.theme = mode;
  else delete document.documentElement.dataset.theme;
}
try { applyTheme(localStorage.getItem(THEME_KEY)); } catch {}

$("#theme")?.addEventListener("click", () => {
  const current = document.documentElement.dataset.theme
    || (matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark");
  const next = current === "light" ? "dark" : "light";
  applyTheme(next);
  try { localStorage.setItem(THEME_KEY, next); } catch {}
});

// The nav pill: one object that slides and resizes between links, instead of four
// backgrounds switching on and off.
function moveNavPill() {
  const links = $(".links");
  const active = $("nav a[aria-current='page']");
  if (!links || !active) return;
  links.style.setProperty("--nx", `${active.offsetLeft}px`);
  links.style.setProperty("--nw", `${active.offsetWidth}px`);
  links.style.setProperty("--nvis", "1");
}
addEventListener("resize", moveNavPill, { passive: true });

// ------------------------------------------------------- flashing availability
// esp-web-tools is vendored (web/vendor/esp-web-tools) so there is no CDN to fail,
// but the module can still be blocked by an extension or fail to parse in an older
// browser. app.css hides the install buttons until the element upgrades, so without
// this notice the Flash page would just look empty.
setTimeout(() => {
  if (customElements.get("esp-web-install-button")) return;
  const n = $("#flashFallback");
  n.hidden = false;
  n.innerHTML = "<b>The flashing tool did not load.</b> A browser extension may be " +
    "blocking scripts on this page, or this browser is too old for it. Try desktop " +
    "Chrome or Edge with shields off — or flash from a clone:<br>" +
    '<code class="mono">arduino-cli upload -p YOUR_PORT ' +
    "--fqbn esp32:esp32:esp32:PartitionScheme=huge_app 01_calibration</code>";
}, 5000);

// ---------------------------------------------------------- shared link logic
// Two pages, two independent links — you connect on whichever page you are using.
function makeLink(key, onMessage) {
  const link = new SerialLink();
  const dot = $(`[data-dot="${key}"]`);
  const status = $(`[data-status="${key}"]`);
  const panel = $(`[data-needs-link="${key}"]`);
  const btn = $(`[data-connect="${key}"]`);
  const off = $(`[data-disconnect="${key}"]`);

  link.onState = ok => {
    dot.classList.toggle("on", ok);
    status.textContent = ok ? "Connected · 115200 baud" : "Not connected";
    panel.hidden = !ok;
    btn.hidden = ok;
    off.hidden = !ok;
  };
  btn.onclick = async () => {
    try { await link.connect(); } catch (e) { status.textContent = e.message || String(e); }
  };
  off.onclick = () => link.disconnect();
  link.on("*", onMessage);
  return link;
}

function metric(k, v, unit = "") {
  return `<div class="metric"><div class="k">${k}</div><div class="v">${v}${unit ? ` <small>${unit}</small>` : ""}</div></div>`;
}

// =============================================================== CALIBRATE ===
const calLink = makeLink("cal", msg => {
  if (msg.t === "reading") renderCalLive(msg);
  else if (msg.t === "cal") renderCalTable(msg);
  else if (msg.t === "ack") $("#selftestOut").textContent = `${msg.cmd}: ${msg.msg}`;
  else if (msg.t === "selftest") {
    const bad = ["analog", "ds18b20", "tcs34725", "hx711"].filter(k => !msg[k]);
    $("#selftestOut").innerHTML = msg.ok
      ? '<span class="ok">All sensors responding</span>'
      : `<span class="bad">Not responding: ${bad.join(", ")}</span>`;
  }
});

function renderCalLive(r) {
  const c = r.calc || {};
  $("#calLive").innerHTML =
    metric("pH", c.ph == null ? fmt(r.ph) : fmt(c.ph, 2), c.ph == null ? "mV raw" : "pH") +
    metric("TDS", fmt(c.ppm), "ppm") +
    metric("Turbidity", fmt(c.ntu), "NTU") +
    metric("Temperature", fmt(r.temp, 1), "°C") +
    metric("Weight", fmt(r.dens, 1), "g") +
    metric("Specific gravity", fmt(c.sg, 3)) +
    metric("Colour R/G/B", `${r.r}/${r.g}/${r.b}`) +
    metric("Clear", r.c);
}

function renderCalTable(c) {
  const rows = [
    ["pH mode", c.ph_raw_mode ? "raw millivolts" : "calibrated"],
    ["pH 7.0 point", c.ph_mv7 == null ? "not captured" : fmt(c.ph_mv7) + " mV"],
    ["pH 4.0 point", c.ph_mv4 == null ? "not captured" : fmt(c.ph_mv4) + " mV"],
    ["pH slope / offset", `${fmt(c.ph_slope, 5)} / ${fmt(c.ph_offset, 2)}`],
    ["TDS K factor", fmt(c.tds_k, 3)],
    ["Turbidity clear zero", fmt(c.turb_clear_mv) + " mV"],
    ["Colour white ref", (c.col_w || []).map(v => fmt(v)).join(" / ")],
    ["Load cell offset / scale", `${fmt(c.hx_offset)} / ${fmt(c.hx_scale, 2)} counts per g`],
    ["Divider ratios pH/TDS/turb", `${fmt(c.div_ph, 2)} / ${fmt(c.div_tds, 2)} / ${fmt(c.div_turb, 2)}`],
    ["Oversample", c.oversample],
    ["Average window", c.avg_ms + " ms"],
    ["Flush duration", c.flush_ms + " ms"],
    ["Chamber volume", fmt(c.chamber_ml, 1) + " mL"],
    ["Confidence threshold", fmt(c.conf_thr, 2)],
  ];
  $("#calTable tbody").innerHTML = rows.map(([k, v]) => `<tr><td class="muted">${k}</td><td>${v}</td></tr>`).join("");
  $("#chamberMl").value = c.chamber_ml;
  $$("[data-ph-mode]").forEach(b =>
    b.setAttribute("aria-pressed", String((b.dataset.phMode === "raw") === !!c.ph_raw_mode)));
}

$$("[data-cal-ph]").forEach(b => b.onclick = () =>
  calLink.send({ cmd: "calibrate", sensor: "ph", point: Number(b.dataset.calPh) }));
$$("[data-ph-mode]").forEach(b => b.onclick = () =>
  calLink.send({ cmd: "set", key: "ph_mode", val: b.dataset.phMode }));
$("#calTds").onclick = () =>
  calLink.send({ cmd: "calibrate", sensor: "tds", known_ppm: Number($("#tdsPpm").value) || 0 });
$("#calTurb").onclick = () => calLink.send({ cmd: "calibrate", sensor: "turbidity", point: "clear" });
$("#calWhite").onclick = () => calLink.send({ cmd: "calibrate", sensor: "color", point: "white" });
$("#tare").onclick = () => calLink.send({ cmd: "tare" });
$("#calSpan").onclick = () =>
  calLink.send({ cmd: "calibrate", sensor: "density", known_g: Number($("#knownG").value) || 0 });
$("#saveChamber").onclick = () =>
  calLink.send({ cmd: "set", key: "chamber_ml", val: Number($("#chamberMl").value) || 100 });
$("#selftest").onclick = () => { $("#selftestOut").textContent = "running…"; calLink.send({ cmd: "selftest" }); };
$("#calFlush").onclick = () => calLink.send({ cmd: "flush" });
$("#factory").onclick = () => {
  if (confirm("Erase every calibration constant on the device?")) calLink.send({ cmd: "factory_reset" });
};

// ================================================================= COLLECT ===
const COLUMNS = ["timestamp_iso", "milk_type", "adulterant", "level_pct", "source",
  "temp_c", "ph_raw_mv", "tds_raw_mv", "turbidity_raw_mv", "density_g",
  "color_r", "color_g", "color_b", "color_clear"];
const rows = [];
let busy = false;

const colLink = makeLink("col", msg => {
  if (msg.t === "reading") renderColLive(msg);
  else if (msg.t === "sample") addRow(msg);
  else if (msg.t === "flush_done") { busy = false; setColStatus("Ready"); }
  else if (msg.t === "ack") {
    if (msg.cmd === "capture" && msg.ok) { busy = true; setColStatus("Capturing…"); }
    else if (!msg.ok) { busy = false; setColStatus(msg.msg); }
    else setColStatus(msg.msg);
  }
});

function setColStatus(text) {
  $("#colStatus").textContent = text;
  $("#capture").disabled = busy;
  $("#colFlush").disabled = busy;
  $("#colTare").disabled = busy;
}

function renderColLive(r) {
  $("#colLive").innerHTML =
    metric("pH", fmt(r.ph), "mV") +
    metric("TDS", fmt(r.tds), "mV") +
    metric("Turbidity", fmt(r.turb), "mV") +
    metric("Temperature", fmt(r.temp, 1), "°C") +
    metric("Weight", fmt(r.dens, 1), "g") +
    metric("Colour R/G/B", `${r.r}/${r.g}/${r.b}`) +
    metric("Clear", r.c) +
    metric("On device", r.count ?? 0, "captures");
}

const pickedMilk = () => $('[data-milk][aria-pressed="true"]')?.dataset.milk || "cow";
const pickedAdu = () => $('[data-adu][aria-pressed="true"]')?.dataset.adu || "pure";

$$("[data-milk],[data-adu]").forEach(b => b.onclick = () => {
  const attr = b.dataset.milk ? "data-milk" : "data-adu";
  $$(`[${attr}]`).forEach(x => x.setAttribute("aria-pressed", String(x === b)));
  if (attr === "data-adu" && b.dataset.adu === "pure") $("#level").value = 0;
});

function addRow(s) {
  rows.push({
    timestamp_iso: new Date().toISOString(),
    milk_type: pickedMilk(),
    adulterant: pickedAdu(),
    level_pct: Number($("#level").value) || 0,
    source: ($("#source").value || "").trim(),
    temp_c: s.temp_c, ph_raw_mv: s.ph_raw_mv, tds_raw_mv: s.tds_raw_mv,
    turbidity_raw_mv: s.turbidity_raw_mv, density_g: s.density_g,
    color_r: s.color_r, color_g: s.color_g, color_b: s.color_b, color_clear: s.color_clear,
    _sd: s,   // kept only for the noisy-capture hint; never exported
  });
  renderRows();
  setColStatus(`Captured (n=${s.n}) · flushing…`);
}

function renderRows() {
  $("#rowCount").textContent = rows.length;
  $("#rows tbody").innerHTML = rows.slice().reverse().slice(0, 60).map(r => {
    const noisy = r._sd && (r._sd.density_sd > 1 || r._sd.turbidity_sd > 60);
    return `<tr${noisy ? ' style="color:var(--uncertain)" title="high variance during capture — consider retaking"' : ""}>
      <td>${r.timestamp_iso.slice(11, 19)}</td><td>${r.milk_type}</td><td>${r.adulterant}</td>
      <td>${r.level_pct}</td><td>${r.source ? esc(r.source) : "–"}</td><td>${fmt(r.temp_c, 1)}</td>
      <td>${fmt(r.ph_raw_mv)}</td><td>${fmt(r.tds_raw_mv)}</td><td>${fmt(r.turbidity_raw_mv)}</td>
      <td>${fmt(r.density_g, 1)}</td><td>${r.color_r}</td><td>${r.color_g}</td><td>${r.color_b}</td><td>${r.color_clear}</td></tr>`;
  }).join("");

  const classes = ["pure", "water", "detergent", "starch"];
  const n = classes.map(c => rows.filter(r => r.adulterant === c).length);
  const max = Math.max(1, ...n);
  $("#counts").innerHTML = classes.map((c, i) =>
    `<span class="pill"${n[i] < max / 2 ? ' style="border:1px solid var(--uncertain)"' : ""}>${c} <b>${n[i]}</b></span>`
  ).join("") + '<span class="pill muted">balance the classes before training</span>';
}

$("#capture").onclick = () => { if (!busy) colLink.send({ cmd: "capture" }); };
$("#colFlush").onclick = () => colLink.send({ cmd: "flush" });
$("#colTare").onclick = () => colLink.send({ cmd: "tare" });
$("#undoRow").onclick = () => { rows.pop(); renderRows(); };
$("#clearRows").onclick = () => { if (confirm("Discard every row in this session?")) { rows.length = 0; renderRows(); } };

$("#exportCsv").onclick = () => {
  if (!rows.length) { alert("No rows to export yet."); return; }
  const csvEsc = v => (typeof v === "string" && /[",\n]/.test(v) ? `"${v.replace(/"/g, '""')}"` : v);
  const csv = [COLUMNS.join(",")]
    .concat(rows.map(r => COLUMNS.map(c => csvEsc(r[c] ?? "")).join(",")))
    .join("\n");
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([csv], { type: "text/csv" }));
  a.download = `aquamilk-${new Date().toISOString().slice(0, 19).replace(/[:T-]/g, "")}.csv`;
  a.click();
  URL.revokeObjectURL(a.href);
};

renderRows();

// ===================================================================== RUN ===
$("#copyIp").onclick = async () => {
  try {
    await navigator.clipboard.writeText("http://192.168.4.1");
    $("#copyOut").textContent = "Copied";
  } catch {
    $("#copyOut").textContent = "Copy failed — the address is http://192.168.4.1";
  }
  setTimeout(() => ($("#copyOut").textContent = ""), 2500);
};
