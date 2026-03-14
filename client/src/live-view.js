import morphdom from "morphdom";
import { Socket } from "./socket.js";
import { setupEventDelegation } from "./events.js";
import { encodeEvent } from "./wire.js";

/**
 * LiveView client — connects to a Livery server over WebSocket, patches the
 * DOM with morphdom on render messages, and delegates user interactions back
 * to the server.
 */
export class LiveView {
  /**
   * @param {object} opts
   * @param {string} opts.url - WebSocket URL (e.g., "ws://localhost:8081/counter")
   * @param {HTMLElement} opts.target - Container element for rendered HTML
   * @param {function} [opts.WebSocket] - Constructor override for testing
   */
  constructor(opts) {
    this._target = opts.target;
    this._pushHandlers = {};
    this._events = null;
    this._statics = null;
    this._dynamics = null;

    this._socket = new Socket({
      url: opts.url,
      WebSocket: opts.WebSocket,
      onMessage: (msg) => this._handleMessage(msg),
      onOpen: () => {
        // Reset split state on reconnect
        this._statics = null;
        this._dynamics = null;
        this._events = setupEventDelegation(this._target, (event, payload, target) => {
          this._socket.send(encodeEvent(event, payload, target));
        });
      },
      onClose: () => {
        if (this._events) {
          this._events.destroy();
          this._events = null;
        }
      },
    });
  }

  /** Open the WebSocket connection and begin receiving renders. */
  connect() {
    this._socket.connect();
    return this;
  }

  /** Close the connection and clean up event delegation. */
  disconnect() {
    this._socket.disconnect();
    if (this._events) {
      this._events.destroy();
      this._events = null;
    }
  }

  /**
   * Register a handler for server-pushed events.
   *
   * @param {string} event - Event name to listen for
   * @param {function(*): void} callback - Called with the event payload
   */
  on(event, callback) {
    this._pushHandlers[event] = callback;
  }

  _applyHtml(html) {
    if (this._target.firstElementChild) {
      morphdom(this._target.firstElementChild, html);
    } else {
      this._target.innerHTML = html;
    }
  }

  _assembleHtml(statics, dynamics) {
    let html = "";
    for (let i = 0; i < dynamics.length; i++) {
      html += statics[i] + dynamics[i];
    }
    html += statics[dynamics.length];
    return html;
  }

  _handleMessage(msg) {
    switch (msg.type) {
      case "render_full":
        this._statics = msg.statics;
        this._dynamics = [...msg.dynamics];
        this._applyHtml(this._assembleHtml(this._statics, this._dynamics));
        break;
      case "render_diff":
        if (!this._statics || !this._dynamics) break;
        for (const [idx, val] of Object.entries(msg.dynamics)) {
          const i = parseInt(idx, 10);
          if (i >= 0 && i < this._dynamics.length) {
            this._dynamics[i] = val;
          }
        }
        this._applyHtml(this._assembleHtml(this._statics, this._dynamics));
        break;
      case "render":
        // Full-HTML fallback -- clear split state
        this._statics = null;
        this._dynamics = null;
        this._applyHtml(msg.html);
        break;
      case "push": {
        const handler = this._pushHandlers[msg.event];
        if (handler) {
          handler(msg.payload);
        }
        break;
      }
      case "error":
        console.error("LiveView server error:", msg.reason);
        break;
    }
  }
}
