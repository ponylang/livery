import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { Socket } from "../src/socket.js";

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

describe("Socket", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    MockWebSocket.instances = [];
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  function createSocket(overrides = {}) {
    return new Socket({
      url: "ws://localhost:8081/test",
      onMessage: overrides.onMessage || vi.fn(),
      onOpen: overrides.onOpen || vi.fn(),
      onClose: overrides.onClose || vi.fn(),
      WebSocket: MockWebSocket,
    });
  }

  it("creates WebSocket with the given URL", () => {
    const socket = createSocket();
    socket.connect();

    expect(MockWebSocket.instances).toHaveLength(1);
    expect(MockWebSocket.instances[0].url).toBe("ws://localhost:8081/test");
  });

  it("calls ws.send with data", () => {
    const socket = createSocket();
    socket.connect();
    MockWebSocket.instances[0].simulateOpen();

    socket.send("hello");

    expect(MockWebSocket.instances[0].sent).toContain("hello");
  });

  it("calls onOpen on ws.onopen", () => {
    const onOpen = vi.fn();
    const socket = createSocket({ onOpen });
    socket.connect();

    MockWebSocket.instances[0].simulateOpen();

    expect(onOpen).toHaveBeenCalledOnce();
  });

  it("calls onMessage with decoded message on ws.onmessage", () => {
    const onMessage = vi.fn();
    const socket = createSocket({ onMessage });
    socket.connect();
    MockWebSocket.instances[0].simulateOpen();

    MockWebSocket.instances[0].simulateMessage('{"t":"render","html":"<div>hi</div>"}');

    expect(onMessage).toHaveBeenCalledWith({ type: "render", html: "<div>hi</div>" });
  });

  it("schedules reconnection on unexpected close", () => {
    const socket = createSocket();
    socket.connect();
    MockWebSocket.instances[0].simulateOpen();
    MockWebSocket.instances[0].simulateClose();

    expect(MockWebSocket.instances).toHaveLength(1);

    // Advance past backoff + max jitter
    vi.advanceTimersByTime(2000);

    expect(MockWebSocket.instances).toHaveLength(2);
  });

  it("applies exponential backoff on repeated failures", () => {
    // Seed Math.random to 0 for deterministic jitter
    vi.spyOn(Math, "random").mockReturnValue(0);

    const socket = createSocket();
    socket.connect();
    MockWebSocket.instances[0].simulateOpen();
    MockWebSocket.instances[0].simulateClose();

    // First retry: 1000ms base + 0 jitter
    vi.advanceTimersByTime(999);
    expect(MockWebSocket.instances).toHaveLength(1);
    vi.advanceTimersByTime(1);
    expect(MockWebSocket.instances).toHaveLength(2);

    // Second failure
    MockWebSocket.instances[1].simulateClose();

    // Second retry: 2000ms base + 0 jitter
    vi.advanceTimersByTime(1999);
    expect(MockWebSocket.instances).toHaveLength(2);
    vi.advanceTimersByTime(1);
    expect(MockWebSocket.instances).toHaveLength(3);

    // Third failure
    MockWebSocket.instances[2].simulateClose();

    // Third retry: 4000ms base + 0 jitter
    vi.advanceTimersByTime(3999);
    expect(MockWebSocket.instances).toHaveLength(3);
    vi.advanceTimersByTime(1);
    expect(MockWebSocket.instances).toHaveLength(4);

    Math.random.mockRestore();
  });

  it("caps backoff at 30 seconds", () => {
    vi.spyOn(Math, "random").mockReturnValue(0);

    const socket = createSocket();
    socket.connect();

    // Fail enough times to exceed the cap: 1, 2, 4, 8, 16, 32 -> capped at 30
    for (let i = 0; i < 5; i++) {
      MockWebSocket.instances[MockWebSocket.instances.length - 1].simulateOpen();
      MockWebSocket.instances[MockWebSocket.instances.length - 1].simulateClose();
      vi.advanceTimersByTime(60000);
    }

    const countBefore = MockWebSocket.instances.length;
    MockWebSocket.instances[MockWebSocket.instances.length - 1].simulateOpen();
    MockWebSocket.instances[MockWebSocket.instances.length - 1].simulateClose();

    // Should reconnect at 30s, not 32s
    vi.advanceTimersByTime(30000);
    expect(MockWebSocket.instances).toHaveLength(countBefore + 1);

    Math.random.mockRestore();
  });

  it("resets backoff on successful reconnection", () => {
    vi.spyOn(Math, "random").mockReturnValue(0);

    const socket = createSocket();
    socket.connect();
    MockWebSocket.instances[0].simulateOpen();
    MockWebSocket.instances[0].simulateClose();

    // Wait for first reconnect (1s)
    vi.advanceTimersByTime(1000);
    expect(MockWebSocket.instances).toHaveLength(2);

    // Successful connection resets backoff
    MockWebSocket.instances[1].simulateOpen();
    MockWebSocket.instances[1].simulateClose();

    // Next reconnect should be 1s again, not 2s
    vi.advanceTimersByTime(1000);
    expect(MockWebSocket.instances).toHaveLength(3);

    Math.random.mockRestore();
  });

  it("does not reconnect after intentional disconnect", () => {
    const socket = createSocket();
    socket.connect();
    MockWebSocket.instances[0].simulateOpen();

    socket.disconnect();

    vi.advanceTimersByTime(60000);
    expect(MockWebSocket.instances).toHaveLength(1);
  });

  it("sends heartbeat after 30 seconds", () => {
    const socket = createSocket();
    socket.connect();
    MockWebSocket.instances[0].simulateOpen();

    vi.advanceTimersByTime(30000);

    const sent = MockWebSocket.instances[0].sent;
    expect(sent).toContain('{"t":"heartbeat"}');
  });

  it("closes socket when heartbeat ack not received within 10 seconds", () => {
    const socket = createSocket();
    socket.connect();
    const ws = MockWebSocket.instances[0];
    ws.simulateOpen();

    // Trigger heartbeat send
    vi.advanceTimersByTime(30000);

    // Advance 10s without ack
    vi.advanceTimersByTime(10000);

    expect(ws.readyState).toBe(3);
  });

  it("clears heartbeat timeout when ack received", () => {
    const socket = createSocket();
    socket.connect();
    const ws = MockWebSocket.instances[0];
    ws.simulateOpen();

    // Trigger heartbeat send
    vi.advanceTimersByTime(30000);

    // Receive ack
    ws.simulateMessage('{"t":"heartbeat_ack"}');

    // Advance 10s — socket should still be open
    vi.advanceTimersByTime(10000);

    expect(ws.readyState).toBe(1);
  });
});
