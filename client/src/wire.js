/**
 * Encode a client event message.
 *
 * @param {string} event - Event name (e.g., "increment")
 * @param {object} payload - Event payload
 * @param {string|null} [target] - Component target ID, if any
 * @returns {string} JSON string
 */
export function encodeEvent(event, payload, target) {
  const msg = { t: "event", e: event, p: payload };
  if (target != null) {
    msg.c = target;
  }
  return JSON.stringify(msg);
}

/**
 * Encode a client heartbeat message.
 *
 * @returns {string} JSON string
 */
export function encodeHeartbeat() {
  return JSON.stringify({ t: "heartbeat" });
}

/**
 * Decode a server message from JSON.
 *
 * @param {string} data - Raw JSON string from server
 * @returns {{ type: "render", html: string }
 *          | { type: "render_full", statics: string[], dynamics: string[] }
 *          | { type: "render_diff", dynamics: Object<string, string> }
 *          | { type: "heartbeat_ack" }
 *          | { type: "push", event: string, payload: * }
 *          | { type: "error", reason: string }
 *          | { type: "unknown" }}
 */
export function decodeServerMessage(data) {
  let obj;
  try {
    obj = JSON.parse(data);
  } catch {
    return { type: "unknown" };
  }

  switch (obj.t) {
    case "render":
      return { type: "render", html: obj.html };
    case "render_full":
      return { type: "render_full", statics: obj.s, dynamics: obj.d };
    case "render_diff":
      return { type: "render_diff", dynamics: obj.d };
    case "heartbeat_ack":
      return { type: "heartbeat_ack" };
    case "push":
      return { type: "push", event: obj.e, payload: obj.p };
    case "error":
      return { type: "error", reason: obj.reason };
    default:
      return { type: "unknown" };
  }
}
