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
