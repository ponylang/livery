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

  new create() =>
    _values = templates.TemplateValues
    _dirty = false

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
