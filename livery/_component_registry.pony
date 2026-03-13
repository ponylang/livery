use "collections"
use templates = "templates"
use json = "json"

class _ComponentRegistry
  """
  Per-connection registry of stateful components.

  Manages component lifecycle (mount, update, render), event routing,
  and resource limits. Owned by `_Connection`.
  """
  let _entries: Map[String, _ComponentEntry ref] ref
  let _max_components: USize
  let _pending_events: Array[(String val, json.JsonValue)] ref
  var _render_errors: Array[String val] ref

  new create(
    pending_events: Array[(String val, json.JsonValue)] ref,
    max_components: USize = 256)
  =>
    _entries = Map[String, _ComponentEntry ref]
    _max_components = max_components
    _pending_events = pending_events
    _render_errors = Array[String val]

  fun ref register(id: String, component: LiveComponent ref): Bool =>
    """
    Register a component and call its `mount`. Returns false if the
    component limit is reached. Registering a duplicate ID replaces the
    existing component without counting against the limit.

    If the component's initial render fails, the component is still
    registered (with empty cached HTML) and a `component_render_failed`
    error is queued. The next render cycle will retry.
    """
    if (_entries.size() >= _max_components)
      and (not _entries.contains(id))
    then
      return false
    end
    let assigns = Assigns
    let socket = ComponentSocket(assigns, _pending_events)
    component.mount(socket)
    let entry = _ComponentEntry(component, assigns)
    try
      entry.last_html = component.render(assigns)?
    else
      _render_errors.push("component_render_failed:" + id)
    end
    assigns.clear_changes()
    _entries(id) = entry
    true

  fun ref unregister(id: String) =>
    """
    Remove a component from the registry.
    """
    try _entries.remove(id)? end

  fun ref update(id: String,
    data: Array[(String, (String | templates.TemplateValue))] val)
  =>
    """
    Update a component's assigns with new data from the parent, then
    call the component's `update` callback.
    """
    try
      let entry = _entries(id)?
      for (key, value) in data.values() do
        entry.assigns.update(key, value)
      end
      let socket = ComponentSocket(entry.assigns, _pending_events)
      entry.component.update(socket)
    end

  fun ref handle_event(id: String, event: String val,
    payload: json.JsonValue): Bool
  =>
    """
    Route an event to a component. Returns false if the component ID
    is not found.
    """
    try
      let entry = _entries(id)?
      let socket = ComponentSocket(entry.assigns, _pending_events)
      entry.component.handle_event(event, payload, socket)
      true
    else
      false
    end

  fun ref render_all(): Bool =>
    """
    Render all components that have changed assigns. Updates cached HTML.
    Returns true if any component was re-rendered.

    Unchanged components keep their cached HTML. This avoids redundant
    template evaluation while producing identical final output. Render
    failures are collected in `_render_errors` for the caller to send
    to the client.
    """
    var any_changed = false
    for (id, entry) in _entries.pairs() do
      if entry.assigns.changed() then
        try
          entry.last_html = entry.component.render(entry.assigns)?
        else
          entry.last_html = ""
          _render_errors.push("component_render_failed:" + id)
        end
        entry.assigns.clear_changes()
        any_changed = true
      end
    end
    any_changed

  fun ref flush_render_errors(): Array[String val] ref^ =>
    """
    Return and clear any component render error messages accumulated
    during `register` or `render_all`. The caller sends these to the
    client as error wire messages.
    """
    let errors = _render_errors = Array[String val]
    errors

  fun box component_html(id: String): String val ? =>
    """
    Look up a component's cached rendered HTML.
    """
    _entries(id)?.last_html

  fun box has(id: String): Bool =>
    """
    Check whether a component ID is registered.
    """
    _entries.contains(id)

  fun box size(): USize =>
    """
    Number of registered components.
    """
    _entries.size()

  fun box populate_component_html(assigns: Assigns ref) =>
    """
    Write all component HTML into the assigns' component HTML map.
    Called by `_Connection` before the parent's render so component
    output is accessible via `assigns.component_html(id)`.

    Uses a dedicated component HTML namespace on Assigns -- separate
    from user assign values -- to prevent name collisions.
    """
    for (id, entry) in _entries.pairs() do
      assigns._set_component_html(id, entry.last_html)
    end


class _ComponentEntry
  """
  Internal state for a registered component: the component instance,
  its assigns, and its last rendered HTML.
  """
  let component: LiveComponent ref
  let assigns: Assigns ref
  var last_html: String val

  new create(component': LiveComponent ref, assigns': Assigns ref) =>
    component = component'
    assigns = assigns'
    last_html = ""
