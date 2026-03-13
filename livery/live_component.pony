use json = "json"

trait LiveComponent
  """
  A stateful component embedded within a LiveView.

  Components have their own assigns, lifecycle, and event handling. They
  render independently and their output is composed into the parent view's
  HTML.

  Create components in the parent view's `mount` or `handle_event` and
  register them with `Socket.register_component`. Target events to
  components with the `lv-target` attribute in HTML.

  Components render through `HtmlTemplate` for auto-escaping, same as
  views. The parent inserts component output as unescaped HTML -- this is
  safe because the component's template already escaped all dynamic values.
  """
  fun ref mount(socket: ComponentSocket ref)
    """
    Called once when the component is first registered via
    `Socket.register_component`. Use `socket.assign()` to set initial state.
    """

  fun ref update(socket: ComponentSocket ref) =>
    """
    Called when the parent passes new data via `Socket.update_component`.
    The framework applies the new data to the component's assigns before
    calling this method, so `socket.get_assign()` reflects the updated
    values.

    Default implementation does nothing. Override to react to data changes
    from the parent (e.g., recompute derived state).
    """
    None

  fun ref handle_event(event: String val, payload: json.JsonValue,
    socket: ComponentSocket ref)
    """
    Called when the client sends an event targeted at this component
    (via `lv-target`). Use `socket.assign()` to update state -- the
    framework re-renders automatically if any assigns changed.
    """

  fun box render(assigns: Assigns box): String ?
    """
    Return the component's HTML. Same contract as `LiveView.render`:
    partial, `box` receiver, auto-escape with `HtmlTemplate`.
    """
