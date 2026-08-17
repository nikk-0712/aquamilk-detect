# web/ — the GitHub Pages app

Static single-page app: **Home · Flash · Calibrate · Collect · Run**. No build step, no
bundler, no backend — the files here are exactly what gets served.

```
web/
├── index.html                 all five sections
├── app.js                     routing + Calibrate/Collect logic
├── serial.js                  Web Serial transport for the §8 JSON protocol
├── app.css                    the app's styles
├── design/tokens.css          shared design variables (the device dashboard mirrors these)
├── logo.svg                   the mark
└── firmware/                  .bin files + ESP Web Tools manifests (CI fills these)
```

## Run it locally

Web Serial and browser flashing need a **secure context**, and `localhost` counts:

```bash
python -m http.server 8000 --directory web
```

Then open <http://localhost:8000>. Opening `index.html` as a `file://` URL will not work —
ES modules and Web Serial both refuse that.

## What needs what

| Page | Needs |
|---|---|
| Home, Run | Any browser, any device |
| Flash | Desktop Chrome/Edge + HTTPS (or localhost) — ESP Web Tools |
| Calibrate, Collect | Desktop Chrome/Edge + HTTPS (or localhost) — Web Serial |

The app detects a missing Web Serial API and says so on the Home page rather than
failing silently when you click Connect.

## firmware/

`*-manifest.json` point at `calibration.bin`, `collection.bin`, `deployment.bin`. The
[build-and-deploy workflow](../.github/workflows/build-and-deploy.yml) compiles all three
sketches, drops the **merged** binaries here (merged = bootloader + partition table + app
in one image, which is why the manifest offset is 0), stamps the real version into the
manifests, and ships the folder to Pages as an artifact.

The `.bin` files are deliberately **not in git** — each is 4 MB of padded flash image, so
committing them cost ~12 MB per CI run. That means a fresh clone has manifests pointing at
binaries that only exist on the deployed site: serving `web/` locally will show the Flash
buttons, but they cannot install until you either run the workflow or build locally and
copy the merged `.bin`s in yourself.

## Notes on the code

- **No localStorage.** Collected rows live in a JavaScript array and leave via the
  Export CSV button. Reloading the tab loses unexported rows — that is deliberate;
  half-finished datasets silently resurrecting is worse.
- **CSV columns** are built in `app.js:COLUMNS`, matching `PROJECT_CONTEXT.md` §5 exactly
  so the Python trainer can read the file with no massaging.
- **Two independent serial links**, one per page. Calibrate and Collect run different
  firmwares, so there is no case where both are connected to the same device at once.
- **esp-web-tools is vendored**, not loaded from a CDN: `web/vendor/esp-web-tools/`
  holds v10.4.0's bundled `dist/web` (Apache-2.0, `LICENSE` included). It started as a
  pinned unpkg URL, which broke the Flash page twice over — the pinned version did not
  exist, and a CDN fetch is blockable by extensions. Nothing external is fetched now.
  To update: `npm pack esp-web-tools@<version>`, then copy `dist/web/*.js` + `LICENSE`
  into that folder.
- **The Run page is a launcher, not a dashboard.** This site is HTTPS; the device serves
  plain HTTP on a private IP, and browsers block that mix. So the live dashboard lives on
  the device (`03_deployment/dashboard.html`) and shares this app's design tokens.
