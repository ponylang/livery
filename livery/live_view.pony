use json = "json"
use templates = "templates"

trait LiveView
  """
  Server-side view that manages state and renders HTML.

  Implement this trait to define a LiveView:

  - `mount` initializes assigns on the socket when the connection is
    established.
  - `handle_event` responds to client interactions (clicks, form submits)
    by updating assigns on the socket.
  - `render` produces HTML from the current assigns. This is a pure function
    of data — the `box` receiver prevents mutation during rendering.
  """
  fun ref mount(socket: Socket ref)
    """
    Called when a connection is established or when the view is rendered
    for HTTP response via `PageRenderer`. Use `socket.assign()` to set
    initial state.

    Check `socket.connected()` to distinguish WebSocket mount (true) from
    HTTP render (false) — for example, to skip subscribing to PubSub topics
    during HTTP render.
    """

  fun ref handle_event(event: String val, payload: json.JsonValue,
    socket: Socket ref)
    """
    Called when the client sends a UI event (e.g., a button click or form
    change/submission). Use
    `socket.assign()` to update state — the framework re-renders
    automatically if any assigns changed.
    """

  fun ref handle_info(message: Any val, socket: Socket ref) =>
    """
    Called when an external actor sends a message to this connection
    via PubSub or direct `InfoReceiver.info` calls.

    Default implementation does nothing. Override to handle server-push
    messages from timers, background jobs, or PubSub topics.
    """
    None

  fun box render(assigns: Assigns box): String ?
    """
    Return the full HTML for the current state. Partial because rendering
    may fail (e.g., missing template variable). On failure the framework
    keeps the last successfully rendered HTML and sends an error to the
    client.

    The returned HTML must have a single root element (e.g., wrapped in a
    `<div>`) for morphdom to work correctly during DOM patching.
    """

  fun box render_parts(assigns: Assigns box,
    sink: templates.TemplateSink ref): Bool
  =>
    """
    Drive the given sink with static/dynamic template output for efficient
    wire updates.

    When this returns true, the framework sends static template parts once
    per connection and only changed dynamic slot values on subsequent
    renders. When it returns false (the default), the framework falls back
    to `render()` and sends full HTML every time.

    Override this to enable split rendering. Typical implementation:

        fun box render_parts(assigns: Assigns box,
          sink: templates.TemplateSink ref): Bool
        =>
          try
            _template.render_to(sink, assigns.template_values())?
            true
          else
            false
          end
    """
    false
