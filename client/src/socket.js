import { encodeHeartbeat, decodeServerMessage } from "./wire.js";

const HEARTBEAT_INTERVAL_MS = 30000;
const HEARTBEAT_TIMEOUT_MS = 10000;
const BACKOFF_BASE_MS = 1000;
const BACKOFF_MULTIPLIER = 2;
const BACKOFF_CAP_MS = 30000;
const JITTER_MAX_MS = 1000;

/**
 * WebSocket wrapper with heartbeat and reconnection.
 */
export class Socket {
  /**
   * @param {object} opts
   * @param {string} opts.url - WebSocket URL
   * @param {function} opts.onMessage - Called with decoded server messages
   * @param {function} opts.onOpen - Called when connection opens
   * @param {function} opts.onClose - Called when connection closes
   * @param {function} [opts.WebSocket] - Constructor override for testing
   */
  constructor(opts) {
    this._url = opts.url;
    this._onMessage = opts.onMessage;
    this._onOpen = opts.onOpen;
    this._onClose = opts.onClose;
    this._WS = opts.WebSocket || globalThis.WebSocket;

    this._ws = null;
    this._heartbeatInterval = null;
    this._heartbeatTimeout = null;
    this._reconnectTimer = null;
    this._backoff = BACKOFF_BASE_MS;
    this._intentionalClose = false;
  }

  /** Open the WebSocket connection. */
  connect() {
    this._intentionalClose = false;
    this._ws = new this._WS(this._url);

    this._ws.onopen = () => {
      this._backoff = BACKOFF_BASE_MS;
      this._startHeartbeat();
      this._onOpen();
    };

    this._ws.onmessage = (event) => {
      const msg = decodeServerMessage(event.data);
      if (msg.type === "heartbeat_ack") {
        this._clearHeartbeatTimeout();
        return;
      }
      this._onMessage(msg);
    };

    this._ws.onclose = () => {
      this._stopHeartbeat();
      this._onClose();
      if (!this._intentionalClose) {
        this._scheduleReconnect();
      }
    };
  }

  /** Close the WebSocket without reconnecting. */
  disconnect() {
    this._intentionalClose = true;
    clearTimeout(this._reconnectTimer);
    this._stopHeartbeat();
    if (this._ws) {
      this._ws.close();
    }
  }

  /**
   * Send raw data over the WebSocket.
   *
   * @param {string} data
   */
  send(data) {
    if (this._ws && this._ws.readyState === 1) {
      this._ws.send(data);
    }
  }

  _startHeartbeat() {
    this._heartbeatInterval = setInterval(() => {
      this.send(encodeHeartbeat());
      this._heartbeatTimeout = setTimeout(() => {
        if (this._ws) {
          this._ws.close();
        }
      }, HEARTBEAT_TIMEOUT_MS);
    }, HEARTBEAT_INTERVAL_MS);
  }

  _stopHeartbeat() {
    clearInterval(this._heartbeatInterval);
    this._clearHeartbeatTimeout();
  }

  _clearHeartbeatTimeout() {
    clearTimeout(this._heartbeatTimeout);
    this._heartbeatTimeout = null;
  }

  _scheduleReconnect() {
    const jitter = Math.random() * JITTER_MAX_MS;
    const delay = this._backoff + jitter;
    this._reconnectTimer = setTimeout(() => {
      this.connect();
    }, delay);
    this._backoff = Math.min(this._backoff * BACKOFF_MULTIPLIER, BACKOFF_CAP_MS);
  }
}
