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
    this._firstRender = true;
    this._events = null;

    this._socket = new Socket({
      url: opts.url,
      WebSocket: opts.WebSocket,
      onMessage: (msg) => this._handleMessage(msg),
      onOpen: () => {
        this._events = setupEventDelegation(this._target, (event, payload) => {
          this._socket.send(encodeEvent(event, payload));
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

  _handleMessage(msg) {
    switch (msg.type) {
      case "render":
        if (this._firstRender && !this._target.firstElementChild) {
          this._target.innerHTML = msg.html;
        } else {
          morphdom(this._target.firstElementChild, msg.html);
        }
        this._firstRender = false;
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
