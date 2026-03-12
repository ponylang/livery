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
