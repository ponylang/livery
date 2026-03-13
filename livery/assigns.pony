use "collections"
use templates = "templates"

class Assigns
  """
  Key-value store with change tracking for LiveView state.

  Values are stored as `TemplateValue` via the templates library's
  `TemplateValues` container. Plain strings are automatically wrapped.

  The framework checks `changed()` after each event handler to determine
  whether a re-render is needed, and calls `clear_changes()` after rendering.
  """
  let _values: templates.TemplateValues ref
  var _dirty: Bool
  let _component_html: Map[String, String val] ref

  new create() =>
    _values = templates.TemplateValues
    _dirty = false
    _component_html = Map[String, String val]

  fun ref update(key: String, value: (String | templates.TemplateValue)) =>
    """
    Set a value and mark assigns as changed.
    """
    _values(key) = value
    _dirty = true

  fun box apply(key: String): templates.TemplateValue ? =>
    """
    Look up a value by key.
    """
    _values(key)?

  fun box changed(): Bool =>
    """
    True if any assign was modified since the last `clear_changes()`.
    """
    _dirty

  fun ref clear_changes() =>
    """
    Reset change tracking. Called by the framework after rendering.
    """
    _dirty = false

  fun box template_values(): templates.TemplateValues box =>
    """
    Return the backing TemplateValues for use with `HtmlTemplate.render()`.
    """
    _values

  fun box component_html(id: String): String val ? =>
    """
    Look up the rendered HTML for a registered component.

    Use this in `render()` to include component output in the parent's
    HTML. The returned string is already escaped by the component's own
    `HtmlTemplate` -- insert it as `TemplateValue.unescaped()` in the
    parent's template values.
    """
    _component_html(id)?

  fun ref _set_component_html(id: String, html: String val) =>
    """
    Store rendered HTML for a component. Called by the framework before
    the parent's render.
    """
    _component_html(id) = html

  fun ref _clear_component_html() =>
    """
    Clear all stored component HTML. Called by the framework after render
    to avoid stale data from unregistered components.
    """
    _component_html.clear()

  fun box render_values(): templates.TemplateValues =>
    """
    Create a writable child scope of the backing template values.

    Use this in `render()` to overlay component HTML or computed values
    onto the existing assigns without modifying the underlying state.
    The child scope falls through to the parent for lookups, so all
    existing assigns remain accessible.
    """
    _values.scope()
