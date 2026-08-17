# AGENT PROMPT 4 — Web App (`web/`, GitHub Pages)

**Read `PROJECT_CONTEXT.md` first (design §9, protocol §8, schema §5, conventions §11). USE THE INSTALLED APPLE DESIGN SKILL for the entire UI — this is the showpiece; it must look genuinely Apple-grade. Also use any other fitting skills.**

## Your task
Build a single, elegant **static single-page web app** (no backend) hosted on GitHub Pages that does three jobs over **USB Web Serial** + one launcher. It must be beautiful, calm, production-grade — not a dev tool.

## Tech
- Plain HTML/CSS/JS or a light framework (React+Vite or Svelte are fine) that builds to **static files** in `web/dist` (or `web/`). No server. Must work as static hosting.
- Use the **Web Serial API** (`navigator.serial`) for Calibrate/Collect, and **ESP Web Tools** (`esp-web-tools` `<esp-web-install-button>`) for Flash. Both require **desktop Chrome/Edge + HTTPS** — detect and show a friendly notice if unsupported (and on mobile).
- Implement the JSON line protocol from §8 (a small `serial.js` that connects, reads newline JSON, writes commands, auto-reconnects).
- **No localStorage for critical data**; keep session state in memory. (CSV is downloaded, not stored.)

## Structure — one app, top nav: **Home · Flash · Calibrate · Collect · Run**
1. **Home:** hero with the **minimal aqua-teal logo mark**, title "Aqua Milk Detect", tagline "Milk purity in seconds", a one-line what-it-does, and four large cards linking to the sections. Show a subtle "Desktop Chrome/Edge required for Flash/Calibrate/Collect" hint.
2. **Flash:** three tidy cards — Calibration / Collection / Deployment firmware — each with an ESP Web Tools install button pointing at its manifest in `web/firmware/<name>-manifest.json`. Show connect state + progress. Brief "how to enter bootloader if needed" note.
3. **Calibrate:** a "Connect device" button (Web Serial) → then a clean panel per sensor showing **live values** with big readouts, plus calibration actions: pH (capture pH 7, capture pH 4, or a "use raw / skip" toggle), TDS (calibrate/keep default), Turbidity (set clear-water zero), Colour (set white reference), Density (Tare, then "set span with known weight" input), and a **"Test all sensors"** live grid to sanity-check wiring. Reflect stored constants returned by the device. A "Flush test" button.
4. **Collect:** "Connect device" → a **label form** (milk type ∈ cow/buffalo/toned · adulterant ∈ pure/water/detergent/starch · level % · **source** free-text) using SF-style segmented controls + inputs. A big **Capture** button that sends `{"cmd":"capture"}`, waits for the device's `sample`, prepends the labels + ISO timestamp, appends a row to an in-memory table (schema §5), shows a **live samples table**, **per-class counts** (so the user sees when the dataset is balanced), and **Export CSV** (client-side download). Live sensor values shown while preparing. Guard the button during flush.
5. **Run:** a launcher card explaining the finished tester is standalone: "Power the device, join its **AquaMilk-XXXX** Wi-Fi (password on the screen), open **http://192.168.4.1**" with a copy-link button and a note about optional `aquamilk.local`. Explain (kindly) why Run isn't embedded here (device is HTTP; this page is HTTPS → browsers block mixed content), so the dashboard lives on the device.

## Design requirements (Apple)
- Follow design §9 exactly: system fonts, **light+dark auto (default light)**, aqua-teal `#0FB5C9` accent, result colors green/red/amber, 16–20 px radii, soft shadows, frosted surfaces where tasteful, 8-pt grid, 200–300 ms transitions, gentle spring on state changes, large tap targets, generous whitespace. Circular confidence ring component available for reuse by the device dashboard.
- Fully responsive; keyboard accessible; reduced-motion respected.
- Provide the logo mark as inline SVG and reuse it on the device dashboard for consistency.

## Deliverables
Everything under `web/` building to static output, a shared `serial.js`, a `design/tokens.css` (the shared design variables also used by the device dashboard), the logo SVG, and `web/README.md`. Placeholder manifests + a note that CI fills `web/firmware/` with real `.bin`s. Ensure it runs when served over HTTPS (GitHub Pages).
