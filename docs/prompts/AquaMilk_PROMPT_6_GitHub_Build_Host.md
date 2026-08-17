# AGENT PROMPT 6 — GitHub Repo, Auto-Build & Hosting (`.github/`, repo)

**Read `PROJECT_CONTEXT.md` first (repo layout §10, conventions §11). This wires everything together so the user's connected GitHub account builds the firmware `.bin`s and hosts the web app automatically.**

## Your task
Create the repository **`aquamilk-detect`** under the user's connected GitHub account with the layout in §10, an MIT license, a great README, and **GitHub Actions** that (a) compile the three Arduino sketches to `.bin` and (b) deploy the web app to **GitHub Pages** — so browser-flashing and the hosted UI "just work."

## Repo setup
- Create repo `aquamilk-detect` (public, MIT). Add `PROJECT_CONTEXT.md` at root (from this project). Folders per §10.
- `README.md`: project intro + tagline, the **wiring guide** (pin map §3 as a table + a note on the ADC dividers §3 and the **IRF520 2N2222 level-shift** §4), power diagram, the three-stage workflow, how to flash from the web app, how to collect data, how to train, and how to run the deployed device (SoftAP/`aquamilk.local`). Generate a simple wiring diagram (Mermaid or an SVG in `docs/`).

## Workflow A — build firmware (`.github/workflows/build-firmware.yml`)
- Trigger on push to `main` touching `01_*`, `02_*`, `03_*`, or manual `workflow_dispatch`.
- Use **`arduino-cli`**: install core `esp32:esp32` (pin a known-good version), install the libraries listed in the firmware prompts (ArduinoJson, Adafruit_TCS34725, Adafruit_GFX, Adafruit_ST7735 or TFT_eSPI, OneWire, DallasTemperature, HX711, DFRobot GravityTDS, ESPAsyncWebServer, AsyncTCP; pin versions).
- Compile each sketch (`arduino-cli compile --fqbn esp32:esp32:esp32 --output-dir ...`) and copy the merged `.bin` into `web/firmware/` as `calibration.bin`, `collection.bin`, `deployment.bin`.
- Generate/refresh **ESP Web Tools manifests** `web/firmware/<name>-manifest.json` (correct chipFamily `ESP32`, offset, path).
- Commit the built bins back (or pass them as artifacts into the Pages job). Fail loudly if any sketch doesn't compile.

## Workflow B — deploy web (`.github/workflows/deploy-web.yml`)
- Trigger on push touching `web/` (and after Workflow A). Build the web app (if it uses a bundler: `npm ci && npm run build`), then **deploy to GitHub Pages** (`actions/deploy-pages`). Ensure `web/firmware/*` (bins + manifests) are included in the published site so ESP Web Tools can fetch them from HTTPS.
- Output the Pages URL in the job summary.

## Notes / quality bar
- Everything must end up served over **HTTPS** (GitHub Pages) — required for Web Serial + ESP Web Tools.
- Pin all tool/core/library versions for reproducible builds; cache where sensible.
- Keep `model.h`/`scaler.h` as committed stubs so `03_deployment` compiles in CI before training; document that the user replaces them after running the trainer, which re-triggers the firmware build.
- Add a `CONTRIBUTING`/short dev note and badges (build passing, Pages) in the README.

## Deliverables
The created repo with `.github/workflows/build-firmware.yml`, `.github/workflows/deploy-web.yml`, `LICENSE` (MIT), root `README.md` with wiring + workflow, `docs/` wiring diagram, and confirmation that both workflows pass and the Pages site is live. Report the final **Pages URL** and the three firmware manifest URLs.
