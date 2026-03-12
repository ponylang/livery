use templates = "templates"
use json = "json"

class Socket
  """
  User-facing API passed to `LiveView` lifecycle methods.

  Wraps assigns and provides framework actions like pushing server-initiated
  events to the client, subscribing to PubSub topics, and obtaining a
  shareable connection reference.
  """
  let _assigns: Assigns ref
  let _pending_events: Array[(String val, json.JsonValue)] ref
  let _self: InfoReceiver tag
  let _pub_sub: (PubSub tag | None)
  let _connected: Bool

  new create(assigns: Assigns ref,
    pending_events: Array[(String val, json.JsonValue)] ref,
    self': InfoReceiver tag, pub_sub: PubSub tag)
  =>
    _assigns = assigns
    _pending_events = pending_events
    _self = self'
    _pub_sub = pub_sub
    _connected = true

  new _for_render(assigns: Assigns ref,
    pending_events: Array[(String val, json.JsonValue)] ref)
  =>
    _assigns = assigns
    _pending_events = pending_events
    _self = _NullInfoReceiver
    _pub_sub = None
    _connected = false

  fun ref assign(key: String,
    value: (String | templates.TemplateValue))
  =>
    """
    Set an assign value. The framework re-renders after the current handler
    if any assigns changed.
    """
    _assigns.update(key, value)

  fun box get_assign(key: String): templates.TemplateValue ? =>
    """
    Read an assign value.
    """
    _assigns(key)?

  fun ref push_event(event: String val, payload: json.JsonValue) =>
    """
    Push a server-initiated event to the client. Events are queued and
    flushed after the current render cycle.
    """
    _pending_events.push((event, payload))

  fun box self(): InfoReceiver tag =>
    """
    Return a shareable reference to this connection.

    Pass this to external actors so they can send messages via
    `InfoReceiver.info`, which arrive at `LiveView.handle_info`.
    """
    _self

  fun box connected(): Bool =>
    """
    True when this socket is backed by a live WebSocket connection. False
    during HTTP rendering via `PageRenderer`, where PubSub operations are
    no-ops and push events are silently dropped.

    Check this in `mount` to distinguish the two contexts — for example,
    to skip subscribing to PubSub topics during HTTP render.
    """
    _connected

  fun ref subscribe(topic: String) =>
    """
    Subscribe this connection to a PubSub topic. Messages published to
    the topic will arrive via `LiveView.handle_info`. Subscriptions are
    automatically cleaned up when the connection closes.

    No-op on disconnected sockets (during HTTP rendering).
    """
    match _pub_sub
    | let ps: PubSub tag => ps.subscribe(topic, _self)
    end

  fun ref unsubscribe(topic: String) =>
    """
    Unsubscribe this connection from a PubSub topic.

    No-op on disconnected sockets (during HTTP rendering).
    """
    match _pub_sub
    | let ps: PubSub tag => ps.unsubscribe(topic, _self)
    end
