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

  it("includes c field when target is provided", () => {
    const result = JSON.parse(encodeEvent("toggle", {}, "todo-3"));
    expect(result).toEqual({ t: "event", e: "toggle", p: {}, c: "todo-3" });
  });

  it("omits c field when target is null", () => {
    const result = JSON.parse(encodeEvent("click", {}, null));
    expect(result).toEqual({ t: "event", e: "click", p: {} });
    expect(result).not.toHaveProperty("c");
  });

  it("omits c field when target is undefined", () => {
    const result = JSON.parse(encodeEvent("click", {}));
    expect(result).toEqual({ t: "event", e: "click", p: {} });
    expect(result).not.toHaveProperty("c");
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

  it("parses render_full message with statics and dynamics", () => {
    const msg = decodeServerMessage(
      '{"t":"render_full","s":["<div>","</div>"],"d":["42"]}'
    );
    expect(msg).toEqual({
      type: "render_full",
      statics: ["<div>", "</div>"],
      dynamics: ["42"],
    });
  });

  it("parses render_diff message with dynamics object", () => {
    const msg = decodeServerMessage(
      '{"t":"render_diff","d":{"0":"43","2":"new"}}'
    );
    expect(msg).toEqual({
      type: "render_diff",
      dynamics: { "0": "43", "2": "new" },
    });
  });

  it("parses render_full with empty dynamics", () => {
    const msg = decodeServerMessage(
      '{"t":"render_full","s":["<p>static</p>"],"d":[]}'
    );
    expect(msg).toEqual({
      type: "render_full",
      statics: ["<p>static</p>"],
      dynamics: [],
    });
  });

  it("parses render_diff with multiple changed slots", () => {
    const msg = decodeServerMessage(
      '{"t":"render_diff","d":{"0":"a","1":"b","3":"c"}}'
    );
    expect(msg).toEqual({
      type: "render_diff",
      dynamics: { "0": "a", "1": "b", "3": "c" },
    });
  });
});
