// serial.js — Web Serial transport for the newline-JSON protocol (PROJECT_CONTEXT.md §8).
//
// Usage:
//   const link = new SerialLink();
//   link.on("reading", r => …);        // one handler per message type ("t" field)
//   link.on("*", msg => …);            // everything
//   link.onState = connected => …;
//   await link.connect();              // must be called from a user gesture
//   link.send({ cmd: "capture" });
//
// Desktop Chrome/Edge only, and only over HTTPS or localhost — that is a browser
// rule, not ours. Call supported() before showing any connect UI.

export const supported = () => "serial" in navigator;

export class SerialLink {
  constructor(baud = 115200) {
    this.baud = baud;
    this.port = null;
    this.reader = null;
    this.writer = null;
    this.buf = "";
    this.handlers = new Map();
    this.onState = () => {};
    this.connected = false;
    this._closing = false;
  }

  on(type, fn) {
    if (!this.handlers.has(type)) this.handlers.set(type, []);
    this.handlers.get(type).push(fn);
    return this;
  }

  _emit(msg) {
    for (const fn of this.handlers.get(msg.t) || []) fn(msg);
    for (const fn of this.handlers.get("*") || []) fn(msg);
  }

  async connect() {
    if (!supported()) throw new Error("Web Serial needs desktop Chrome or Edge");
    this.port = await navigator.serial.requestPort();       // user picks the device
    await this.port.open({ baudRate: this.baud });
    this.writer = this.port.writable.getWriter();
    this.connected = true;
    this._closing = false;
    this.onState(true);
    this._readLoop();                                       // fire and forget
    return this.port.getInfo();
  }

  async _readLoop() {
    const dec = new TextDecoder();
    try {
      while (this.port && this.port.readable && !this._closing) {
        this.reader = this.port.readable.getReader();
        try {
          while (true) {
            const { value, done } = await this.reader.read();
            if (done) break;
            this.buf += dec.decode(value, { stream: true });
            let nl;
            while ((nl = this.buf.indexOf("\n")) >= 0) {
              const line = this.buf.slice(0, nl).trim();
              this.buf = this.buf.slice(nl + 1);
              if (!line || line[0] === "#") continue;       // firmware banner lines
              try {
                this._emit(JSON.parse(line));
              } catch {
                /* a non-JSON line: ignore it rather than breaking the stream */
              }
            }
          }
        } finally {
          this.reader.releaseLock();
          this.reader = null;
        }
      }
    } catch (e) {
      if (!this._closing) this._emit({ t: "error", msg: String(e.message || e) });
    } finally {
      if (this.connected && !this._closing) {
        // Cable pulled or board reset: report it so the UI can offer Reconnect.
        this.connected = false;
        this.onState(false);
      }
    }
  }

  async send(obj) {
    if (!this.writer) throw new Error("not connected");
    const enc = new TextEncoder();
    await this.writer.write(enc.encode(JSON.stringify(obj) + "\n"));
  }

  async disconnect() {
    this._closing = true;
    try { await this.reader?.cancel(); } catch {}
    try { this.writer?.releaseLock(); } catch {}
    try { await this.port?.close(); } catch {}
    this.port = this.writer = null;
    this.connected = false;
    this.onState(false);
  }
}
