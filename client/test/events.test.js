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

  it("lv-change fires sendEvent with form field values on input", () => {
    const root = createRoot(
      '<form lv-change="validate"><input name="username" value="alice" /></form>'
    );
    const sendEvent = vi.fn();
    setupEventDelegation(root, sendEvent);

    root.querySelector("input").dispatchEvent(
      new Event("input", { bubbles: true })
    );

    expect(sendEvent).toHaveBeenCalledWith("validate", { username: "alice" });
  });

  it("lv-change collects all named fields in the form", () => {
    const root = createRoot(
      '<form lv-change="validate">' +
        '<input name="username" value="bob" />' +
        '<input name="email" value="bob@test.com" />' +
      "</form>"
    );
    const sendEvent = vi.fn();
    setupEventDelegation(root, sendEvent);

    root.querySelector('input[name="username"]').dispatchEvent(
      new Event("input", { bubbles: true })
    );

    expect(sendEvent).toHaveBeenCalledWith("validate", {
      username: "bob",
      email: "bob@test.com",
    });
  });

  it("lv-change does not fire for inputs outside a form with lv-change", () => {
    const root = createRoot(
      '<form><input name="field" value="x" /></form>'
    );
    const sendEvent = vi.fn();
    setupEventDelegation(root, sendEvent);

    root.querySelector("input").dispatchEvent(
      new Event("input", { bubbles: true })
    );

    expect(sendEvent).not.toHaveBeenCalled();
  });

  it("lv-submit fires sendEvent with all form data", () => {
    const root = createRoot(
      '<form lv-submit="register">' +
        '<input name="username" value="alice" />' +
        '<input name="email" value="alice@test.com" />' +
      "</form>"
    );
    const sendEvent = vi.fn();
    setupEventDelegation(root, sendEvent);

    root.querySelector("form").dispatchEvent(
      new Event("submit", { bubbles: true, cancelable: true })
    );

    expect(sendEvent).toHaveBeenCalledWith("register", {
      username: "alice",
      email: "alice@test.com",
    });
  });

  it("lv-submit prevents default form submission", () => {
    const root = createRoot(
      '<form lv-submit="register"><input name="f" value="v" /></form>'
    );
    const sendEvent = vi.fn();
    setupEventDelegation(root, sendEvent);

    const event = new Event("submit", { bubbles: true, cancelable: true });
    const preventSpy = vi.spyOn(event, "preventDefault");
    root.querySelector("form").dispatchEvent(event);

    expect(preventSpy).toHaveBeenCalled();
  });

  it("lv-submit does not fire for forms without lv-submit", () => {
    const root = createRoot(
      '<form><input name="f" value="v" /></form>'
    );
    const sendEvent = vi.fn();
    setupEventDelegation(root, sendEvent);

    root.querySelector("form").dispatchEvent(
      new Event("submit", { bubbles: true, cancelable: true })
    );

    expect(sendEvent).not.toHaveBeenCalled();
  });

  it("destroy removes change and submit listeners along with click", () => {
    const root = createRoot(
      '<form lv-change="validate" lv-submit="register">' +
        '<input name="f" value="v" />' +
        '<button lv-click="btn">Click</button>' +
      "</form>"
    );
    const sendEvent = vi.fn();
    const { destroy } = setupEventDelegation(root, sendEvent);

    destroy();

    root.querySelector("input").dispatchEvent(
      new Event("input", { bubbles: true })
    );
    root.querySelector("form").dispatchEvent(
      new Event("submit", { bubbles: true, cancelable: true })
    );
    root.querySelector("button").click();

    expect(sendEvent).not.toHaveBeenCalled();
  });
});
