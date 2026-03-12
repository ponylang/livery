import { describe, it, expect, vi } from "vitest";
import { setupEventDelegation } from "../src/events.js";

function createRoot(html) {
  const root = document.createElement("div");
  root.innerHTML = html;
  document.body.appendChild(root);
  return root;
}

describe("setupEventDelegation", () => {
  it("fires sendEvent on click with lv-click attribute", () => {
    const root = createRoot('<button lv-click="increment">+</button>');
    const sendEvent = vi.fn();
    setupEventDelegation(root, sendEvent);

    root.querySelector("button").click();

    expect(sendEvent).toHaveBeenCalledWith("increment", {});
  });

  it("bubbles up from child to find lv-click", () => {
    const root = createRoot('<div lv-click="click-me"><span id="child">text</span></div>');
    const sendEvent = vi.fn();
    setupEventDelegation(root, sendEvent);

    root.querySelector("#child").click();

    expect(sendEvent).toHaveBeenCalledWith("click-me", {});
  });

  it("collects lv-value-* attributes into payload", () => {
    const root = createRoot('<button lv-click="delete" lv-value-id="5">Delete</button>');
    const sendEvent = vi.fn();
    setupEventDelegation(root, sendEvent);

    root.querySelector("button").click();

    expect(sendEvent).toHaveBeenCalledWith("delete", { id: "5" });
  });

  it("collects multiple lv-value-* attributes", () => {
    const root = createRoot(
      '<button lv-click="update" lv-value-id="3" lv-value-name="foo">Update</button>'
    );
    const sendEvent = vi.fn();
    setupEventDelegation(root, sendEvent);

    root.querySelector("button").click();

    expect(sendEvent).toHaveBeenCalledWith("update", { id: "3", name: "foo" });
  });

  it("does not fire on click without lv-click", () => {
    const root = createRoot("<button>plain</button>");
    const sendEvent = vi.fn();
    setupEventDelegation(root, sendEvent);

    root.querySelector("button").click();

    expect(sendEvent).not.toHaveBeenCalled();
  });

  it("stops firing after destroy", () => {
    const root = createRoot('<button lv-click="test">Test</button>');
    const sendEvent = vi.fn();
    const { destroy } = setupEventDelegation(root, sendEvent);

    destroy();
    root.querySelector("button").click();

    expect(sendEvent).not.toHaveBeenCalled();
  });

  it("does not fire for lv-click outside the root", () => {
    const root = createRoot("<button>inside</button>");
    const outside = document.createElement("button");
    outside.setAttribute("lv-click", "outside-event");
    document.body.appendChild(outside);

    const sendEvent = vi.fn();
    setupEventDelegation(root, sendEvent);

    outside.click();

    expect(sendEvent).not.toHaveBeenCalled();
  });
});
