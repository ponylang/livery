/**
 * Set up event delegation on a root element.
 *
 * Listens for clicks and walks up the DOM from the target to find
 * elements with `lv-click` attributes. Collects `lv-value-*` attributes
 * from the matched element into a payload object.
 *
 * @param {HTMLElement} root - Container element for delegation
 * @param {function(string, object): void} sendEvent - Called with (eventName, payload)
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
        sendEvent(eventName, payload);
        return;
      }
      el = el.parentNode;
    }
  }

  root.addEventListener("click", handleClick);

  return {
    destroy() {
      root.removeEventListener("click", handleClick);
    },
  };
}
