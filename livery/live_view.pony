use json = "json"

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
    Called when the WebSocket connection is established. Use
    `socket.assign()` to set initial state.
    """

  fun ref handle_event(event: String val, payload: json.JsonValue,
    socket: Socket ref)
    """
    Called when the client sends a UI event (e.g., a button click). Use
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
    """
