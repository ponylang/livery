import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { LiveView } from "../src/live-view.js";

class MockWebSocket {
  static instances = [];

  constructor(url) {
    this.url = url;
    this.sent = [];
    this.onopen = null;
    this.onmessage = null;
    this.onclose = null;
    this.readyState = 0;
    MockWebSocket.instances.push(this);
  }

  send(data) {
    this.sent.push(data);
  }

  close() {
    this.readyState = 3;
    if (this.onclose) {
      this.onclose();
    }
  }

  simulateOpen() {
    this.readyState = 1;
    if (this.onopen) {
      this.onopen();
    }
  }

  simulateMessage(data) {
    if (this.onmessage) {
      this.onmessage({ data });
    }
  }

  simulateClose() {
    this.readyState = 3;
    if (this.onclose) {
      this.onclose();
    }
  }
}

describe("LiveView", () => {
  let target;

  beforeEach(() => {
    vi.useFakeTimers();
    MockWebSocket.instances = [];
    target = document.createElement("div");
    target.id = "lv-root";
    document.body.appendChild(target);
  });

  afterEach(() => {
    vi.useRealTimers();
    target.remove();
  });

  function createLiveView() {
    return new LiveView({
      url: "ws://localhost:8081/counter",
      target,
      WebSocket: MockWebSocket,
    });
  }

  function ws() {
    return MockWebSocket.instances[MockWebSocket.instances.length - 1];
  }

  it("renders HTML into target on first render message", () => {
    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    ws().simulateMessage('{"t":"render","html":"<div>hello</div>"}');

    expect(target.innerHTML).toBe("<div>hello</div>");
  });

  it("morphs DOM on subsequent render messages", () => {
    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    ws().simulateMessage('{"t":"render","html":"<div id=\\"app\\"><span>1</span></div>"}');
    const div = target.querySelector("#app");

    ws().simulateMessage('{"t":"render","html":"<div id=\\"app\\"><span>2</span></div>"}');

    // Same DOM node — morphdom patched it, didn't replace it
    expect(target.querySelector("#app")).toBe(div);
    expect(target.querySelector("span").textContent).toBe("2");
  });

  it("sends encoded event on lv-click", () => {
    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    ws().simulateMessage('{"t":"render","html":"<div><button lv-click=\\"increment\\">+</button></div>"}');
    target.querySelector("button").click();

    const sent = JSON.parse(ws().sent[0]);
    expect(sent).toEqual({ t: "event", e: "increment", p: {} });
  });

  it("includes lv-value-* attributes in event payload", () => {
    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    ws().simulateMessage(
      '{"t":"render","html":"<div><button lv-click=\\"delete\\" lv-value-id=\\"7\\">X</button></div>"}'
    );
    target.querySelector("button").click();

    const sent = JSON.parse(ws().sent[0]);
    expect(sent).toEqual({ t: "event", e: "delete", p: { id: "7" } });
  });

  it("dispatches push events to registered handlers", () => {
    const lv = createLiveView();
    const handler = vi.fn();
    lv.on("tick", handler);
    lv.connect();
    ws().simulateOpen();

    ws().simulateMessage('{"t":"push","e":"tick","p":{"count":42}}');

    expect(handler).toHaveBeenCalledWith({ count: 42 });
  });

  it("does not throw on push with no handler registered", () => {
    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    expect(() => {
      ws().simulateMessage('{"t":"push","e":"unknown","p":{"x":1}}');
    }).not.toThrow();
  });

  it("fires push handler registered after connect", () => {
    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    const handler = vi.fn();
    lv.on("late", handler);

    ws().simulateMessage('{"t":"push","e":"late","p":{"val":"ok"}}');

    expect(handler).toHaveBeenCalledWith({ val: "ok" });
  });

  it("dispatches multiple sequential push events to correct handlers", () => {
    const lv = createLiveView();
    const tickHandler = vi.fn();
    const alertHandler = vi.fn();
    lv.on("tick", tickHandler);
    lv.on("alert", alertHandler);
    lv.connect();
    ws().simulateOpen();

    ws().simulateMessage('{"t":"push","e":"tick","p":{"n":1}}');
    ws().simulateMessage('{"t":"push","e":"alert","p":{"msg":"hi"}}');
    ws().simulateMessage('{"t":"push","e":"tick","p":{"n":2}}');

    expect(tickHandler).toHaveBeenCalledTimes(2);
    expect(tickHandler).toHaveBeenNthCalledWith(1, { n: 1 });
    expect(tickHandler).toHaveBeenNthCalledWith(2, { n: 2 });
    expect(alertHandler).toHaveBeenCalledTimes(1);
    expect(alertHandler).toHaveBeenCalledWith({ msg: "hi" });
  });

  it("overwrites previous handler when on() is called for same event", () => {
    const lv = createLiveView();
    const first = vi.fn();
    const second = vi.fn();
    lv.on("tick", first);
    lv.on("tick", second);
    lv.connect();
    ws().simulateOpen();

    ws().simulateMessage('{"t":"push","e":"tick","p":{"n":1}}');

    expect(first).not.toHaveBeenCalled();
    expect(second).toHaveBeenCalledWith({ n: 1 });
  });

  it("preserves push handlers across reconnection", () => {
    vi.spyOn(Math, "random").mockReturnValue(0);

    const lv = createLiveView();
    const handler = vi.fn();
    lv.on("tick", handler);
    lv.connect();
    ws().simulateOpen();

    ws().simulateMessage('{"t":"push","e":"tick","p":{"n":1}}');
    expect(handler).toHaveBeenCalledTimes(1);

    // Simulate unexpected close and reconnect
    ws().simulateClose();
    vi.advanceTimersByTime(1000);

    expect(MockWebSocket.instances).toHaveLength(2);
    ws().simulateOpen();
    ws().simulateMessage('{"t":"push","e":"tick","p":{"n":2}}');

    expect(handler).toHaveBeenCalledTimes(2);
    expect(handler).toHaveBeenNthCalledWith(2, { n: 2 });

    Math.random.mockRestore();
  });

  it("uses morphdom for first render when target has pre-rendered content", () => {
    // Simulate pre-rendered HTML already in the target
    target.innerHTML = '<div id="app"><h1>Count: 0</h1></div>';
    const preRenderedDiv = target.querySelector("#app");

    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    // First render — same HTML as pre-rendered, should morphdom (not innerHTML)
    ws().simulateMessage('{"t":"render","html":"<div id=\\"app\\"><h1>Count: 0</h1></div>"}');

    // The original DOM node should be preserved (morphdom patched, not replaced)
    expect(target.querySelector("#app")).toBe(preRenderedDiv);
  });

  it("uses innerHTML for first render when target is empty", () => {
    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    ws().simulateMessage('{"t":"render","html":"<div>hello</div>"}');

    expect(target.innerHTML).toBe("<div>hello</div>");
  });

  it("uses morphdom for subsequent renders after pre-rendered takeover", () => {
    // Pre-rendered content
    target.innerHTML = '<div id="app"><h1>Count: 0</h1></div>';

    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    // First render — takeover via morphdom
    ws().simulateMessage('{"t":"render","html":"<div id=\\"app\\"><h1>Count: 0</h1></div>"}');
    const div = target.querySelector("#app");

    // Second render — still morphdom
    ws().simulateMessage('{"t":"render","html":"<div id=\\"app\\"><h1>Count: 1</h1></div>"}');

    expect(target.querySelector("#app")).toBe(div);
    expect(target.querySelector("h1").textContent).toBe("Count: 1");
  });

  it("morphs correctly after reconnection with pre-rendered content", () => {
    vi.spyOn(Math, "random").mockReturnValue(0);

    // Pre-rendered content
    target.innerHTML = '<div id="app"><h1>Count: 0</h1></div>';

    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    // First render — takeover via morphdom
    ws().simulateMessage('{"t":"render","html":"<div id=\\"app\\"><h1>Count: 0</h1></div>"}');
    const div = target.querySelector("#app");

    // Simulate unexpected close and reconnect
    ws().simulateClose();
    vi.advanceTimersByTime(1000);

    expect(MockWebSocket.instances).toHaveLength(2);
    ws().simulateOpen();

    // Server mounts fresh view and sends initial render
    ws().simulateMessage('{"t":"render","html":"<div id=\\"app\\"><h1>Count: 0</h1></div>"}');

    // Same DOM node preserved through reconnection
    expect(target.querySelector("#app")).toBe(div);
    expect(target.querySelector("h1").textContent).toBe("Count: 0");

    // Subsequent update after reconnect works
    ws().simulateMessage('{"t":"render","html":"<div id=\\"app\\"><h1>Count: 5</h1></div>"}');
    expect(target.querySelector("#app")).toBe(div);
    expect(target.querySelector("h1").textContent).toBe("Count: 5");

    Math.random.mockRestore();
  });

  it("renders HTML from render_full message", () => {
    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    ws().simulateMessage(
      '{"t":"render_full","s":["<div>","</div>"],"d":["hello"]}'
    );

    expect(target.innerHTML).toBe("<div>hello</div>");
  });

  it("renders render_full with empty dynamics (static-only template)", () => {
    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    ws().simulateMessage(
      '{"t":"render_full","s":["<p>static</p>"],"d":[]}'
    );

    expect(target.innerHTML).toBe("<p>static</p>");
  });

  it("patches only changed dynamics on render_diff", () => {
    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    // First: full render with two dynamics
    ws().simulateMessage(
      '{"t":"render_full","s":["<div><span>","</span><span>","</span></div>"],"d":["a","b"]}'
    );
    expect(target.querySelector("div")).toBeTruthy();
    const spans = target.querySelectorAll("span");
    expect(spans[0].textContent).toBe("a");
    expect(spans[1].textContent).toBe("b");

    const div = target.querySelector("div");

    // Second: diff only slot 0
    ws().simulateMessage('{"t":"render_diff","d":{"0":"changed"}}');

    // Same DOM node preserved
    expect(target.querySelector("div")).toBe(div);
    const updatedSpans = target.querySelectorAll("span");
    expect(updatedSpans[0].textContent).toBe("changed");
    expect(updatedSpans[1].textContent).toBe("b");
  });

  it("ignores render_diff before render_full", () => {
    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    // No render_full yet — diff should be silently dropped
    ws().simulateMessage('{"t":"render_diff","d":{"0":"x"}}');

    expect(target.innerHTML).toBe("");
  });

  it("resets split state on reconnect", () => {
    vi.spyOn(Math, "random").mockReturnValue(0);

    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    ws().simulateMessage(
      '{"t":"render_full","s":["<div>","</div>"],"d":["first"]}'
    );
    expect(target.innerHTML).toBe("<div>first</div>");

    // Disconnect and reconnect
    ws().simulateClose();
    vi.advanceTimersByTime(1000);
    ws().simulateOpen();

    // After reconnect, render_diff without render_full should be dropped
    ws().simulateMessage('{"t":"render_diff","d":{"0":"stale"}}');
    // Content should still be from the first render_full
    expect(target.querySelector("div").textContent).toBe("first");

    // New render_full works after reconnect
    ws().simulateMessage(
      '{"t":"render_full","s":["<div>","</div>"],"d":["reconnected"]}'
    );
    expect(target.querySelector("div").textContent).toBe("reconnected");

    Math.random.mockRestore();
  });

  it("legacy render clears split state", () => {
    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    // Start with split rendering
    ws().simulateMessage(
      '{"t":"render_full","s":["<div>","</div>"],"d":["split"]}'
    );
    expect(target.querySelector("div").textContent).toBe("split");

    // Switch to legacy full-HTML render
    ws().simulateMessage('{"t":"render","html":"<div>legacy</div>"}');
    expect(target.querySelector("div").textContent).toBe("legacy");

    // render_diff should be ignored now (split state cleared)
    ws().simulateMessage('{"t":"render_diff","d":{"0":"stale"}}');
    expect(target.querySelector("div").textContent).toBe("legacy");
  });

  it("uses morphdom for split render with pre-rendered content", () => {
    // Pre-rendered content
    target.innerHTML = '<div id="app">Count: 0</div>';
    const preRenderedDiv = target.querySelector("#app");

    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    // Server sends render_full matching pre-rendered content
    ws().simulateMessage(
      '{"t":"render_full","s":["<div id=\\"app\\">Count: ","</div>"],"d":["0"]}'
    );

    // morphdom should preserve the original DOM node
    expect(target.querySelector("#app")).toBe(preRenderedDiv);
  });

  it("ignores out-of-bounds diff indices", () => {
    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    // 1 dynamic slot
    ws().simulateMessage(
      '{"t":"render_full","s":["<div>","</div>"],"d":["ok"]}'
    );

    // Diff with out-of-bounds index should not crash
    ws().simulateMessage('{"t":"render_diff","d":{"5":"bad"}}');
    expect(target.querySelector("div").textContent).toBe("ok");
  });

  it("does not throw on error messages", () => {
    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    expect(() => {
      ws().simulateMessage('{"t":"error","reason":"something broke"}');
    }).not.toThrow();
  });

  it("cleans up event delegation and closes socket on disconnect", () => {
    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();

    ws().simulateMessage('{"t":"render","html":"<div><button lv-click=\\"test\\">T</button></div>"}');
    lv.disconnect();

    // Click should not send anything — event delegation destroyed
    target.querySelector("button").click();
    expect(ws().sent).toHaveLength(0);
  });

  it("updates DOM after reconnection", () => {
    vi.spyOn(Math, "random").mockReturnValue(0);

    const lv = createLiveView();
    lv.connect();
    ws().simulateOpen();
    ws().simulateMessage('{"t":"render","html":"<div>first</div>"}');

    // Simulate unexpected close and reconnect
    ws().simulateClose();
    vi.advanceTimersByTime(1000);

    // New WebSocket instance
    expect(MockWebSocket.instances).toHaveLength(2);
    ws().simulateOpen();
    ws().simulateMessage('{"t":"render","html":"<div>reconnected</div>"}');

    expect(target.querySelector("div").textContent).toBe("reconnected");

    Math.random.mockRestore();
  });
});
