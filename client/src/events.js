/**
 * Collect all named form fields into a plain object.
 *
 * @param {HTMLFormElement} form
 * @returns {object} { fieldName: value, ... }
 */
function collectFormData(form) {
  const payload = {};
  for (const [key, value] of new FormData(form)) {
    payload[key] = value;
  }
  return payload;
}

/**
 * Walk up the DOM from `el` to find an ancestor (or self) that has
 * the given attribute, stopping before exiting `root`.
 *
 * @param {HTMLElement} el - Starting element
 * @param {HTMLElement} root - Boundary (exclusive)
 * @param {string} attr - Attribute name to search for
 * @returns {HTMLElement|null}
 */
function findAncestorWithAttr(el, root, attr) {
  while (el && el !== root.parentNode) {
    if (el.hasAttribute && el.hasAttribute(attr)) {
      return el;
    }
    el = el.parentNode;
  }
  return null;
}

/**
 * Walk up the DOM from `el` to find the nearest `lv-target` attribute,
 * stopping before exiting `root`.
 *
 * @param {HTMLElement} el - Starting element
 * @param {HTMLElement} root - Boundary (exclusive)
 * @returns {string|null} Target ID or null
 */
function findTarget(el, root) {
  while (el && el !== root.parentNode) {
    if (el.hasAttribute && el.hasAttribute("lv-target")) {
      return el.getAttribute("lv-target");
    }
    el = el.parentNode;
  }
  return null;
}

/**
 * Set up event delegation on a root element.
 *
 * Listens for clicks, form input changes, and form submissions. Walks up
 * the DOM from the target to find elements with `lv-click`, `lv-change`,
 * or `lv-submit` attributes. When `lv-target` is present on the element
 * or an ancestor, the target ID is included in the event callback.
 *
 * - `lv-click`: collects `lv-value-*` attributes into the payload
 * - `lv-change`: collects all named form fields into the payload
 * - `lv-submit`: prevents default submission, collects all named form fields
 *
 * @param {HTMLElement} root - Container element for delegation
 * @param {function(string, object, string|null): void} sendEvent - Called with (eventName, payload, target)
 * @returns {{ destroy: function }} Cleanup handle
 */
export function setupEventDelegation(root, sendEvent) {
  function handleClick(event) {
    let el = event.target;
    while (el && el !== root.parentNode) {
      if (el.hasAttribute && el.hasAttribute("lv-click")) {
        const eventName = el.getAttribute("lv-click");
        const payload = {};
        for (const attr of el.attributes) {
          if (attr.name.startsWith("lv-value-")) {
            const key = attr.name.slice("lv-value-".length);
            payload[key] = attr.value;
          }
        }
        const target = findTarget(el, root);
        sendEvent(eventName, payload, target);
        return;
      }
      el = el.parentNode;
    }
  }

  function handleInput(event) {
    const form = findAncestorWithAttr(event.target, root, "lv-change");
    if (form) {
      const target = findTarget(form, root);
      sendEvent(form.getAttribute("lv-change"), collectFormData(form), target);
    }
  }

  function handleSubmit(event) {
    const form = findAncestorWithAttr(event.target, root, "lv-submit");
    if (form) {
      event.preventDefault();
      const target = findTarget(form, root);
      sendEvent(form.getAttribute("lv-submit"), collectFormData(form), target);
    }
  }

  root.addEventListener("click", handleClick);
  root.addEventListener("input", handleInput);
  root.addEventListener("submit", handleSubmit);

  return {
    destroy() {
      root.removeEventListener("click", handleClick);
      root.removeEventListener("input", handleInput);
      root.removeEventListener("submit", handleSubmit);
    },
  };
}
