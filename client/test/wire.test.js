import { describe, it, expect } from "vitest";
import { encodeEvent, encodeHeartbeat, decodeServerMessage } from "../src/wire.js";

describe("encodeEvent", () => {
  it("produces correct JSON with t, e, p fields", () => {
    const result = JSON.parse(encodeEvent("increment", { id: "5" }));
    expect(result).toEqual({ t: "event", e: "increment", p: { id: "5" } });
  });

  it("produces empty payload object when none provided", () => {
    const result = JSON.parse(encodeEvent("click", {}));
    expect(result).toEqual({ t: "event", e: "click", p: {} });
  });
});

describe("encodeHeartbeat", () => {
  it("produces heartbeat JSON", () => {
    const result = JSON.parse(encodeHeartbeat());
    expect(result).toEqual({ t: "heartbeat" });
  });
});

describe("decodeServerMessage", () => {
  it("parses render message", () => {
    const msg = decodeServerMessage('{"t":"render","html":"<div>hi</div>"}');
    expect(msg).toEqual({ type: "render", html: "<div>hi</div>" });
  });

  it("parses heartbeat_ack", () => {
    const msg = decodeServerMessage('{"t":"heartbeat_ack"}');
    expect(msg).toEqual({ type: "heartbeat_ack" });
  });

  it("parses push message with event and payload", () => {
    const msg = decodeServerMessage('{"t":"push","e":"tick","p":{"count":1}}');
    expect(msg).toEqual({ type: "push", event: "tick", payload: { count: 1 } });
  });

  it("parses error message with reason", () => {
    const msg = decodeServerMessage('{"t":"error","reason":"not found"}');
    expect(msg).toEqual({ type: "error", reason: "not found" });
  });

  it("returns unknown for unrecognized t values", () => {
    const msg = decodeServerMessage('{"t":"foo"}');
    expect(msg).toEqual({ type: "unknown" });
  });

  it("returns unknown for invalid JSON", () => {
    const msg = decodeServerMessage("not json");
    expect(msg).toEqual({ type: "unknown" });
  });
});
