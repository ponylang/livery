use templates = "templates"
use json = "json"

class Socket
  """
  User-facing API passed to `LiveView` lifecycle methods.

  Wraps assigns and provides framework actions like pushing server-initiated
  events to the client, subscribing to PubSub topics, obtaining a shareable
  connection reference, and managing stateful components.
  """
  let _assigns: Assigns ref
  let _pending_events: Array[(String val, json.JsonValue)] ref
  let _self: InfoReceiver tag
  let _pub_sub: (PubSub tag | None)
  let _connected: Bool
  let _components: _ComponentRegistry ref

  new create(assigns: Assigns ref,
    pending_events: Array[(String val, json.JsonValue)] ref,
    self': InfoReceiver tag, pub_sub: PubSub tag,
    components: _ComponentRegistry ref)
  =>
    _assigns = assigns
    _pending_events = pending_events
    _self = self'
    _pub_sub = pub_sub
    _connected = true
    _components = components

  new _for_render(assigns: Assigns ref,
    pending_events: Array[(String val, json.JsonValue)] ref)
  =>
    _assigns = assigns
    _pending_events = pending_events
    _self = _NullInfoReceiver
    _pub_sub = None
    _connected = false
    _components = _ComponentRegistry(pending_events)

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

  fun ref register_component(id: String,
    component: LiveComponent ref): Bool
  =>
    """
    Register a stateful component with the given ID. Returns false if the
    per-connection component limit is reached.

    The component's `mount` is called immediately. The ID must be unique
    within this connection -- registering a duplicate ID replaces the
    existing component (the old component is discarded).
    """
    _components.register(id, component)

  fun ref unregister_component(id: String) =>
    """
    Remove a stateful component. Its state is discarded and events
    targeting this ID will produce errors.
    """
    _components.unregister(id)

  fun ref update_component(id: String,
    data: Array[(String, (String | templates.TemplateValue))] val)
  =>
    """
    Update a component's assigns with new data and call its `update`
    callback. Use this to pass data from the parent view to a component.
    """
    _components.update(id, data)

  fun ref _prepare_render() =>
    """
    Render registered components and populate their HTML into assigns.
    Called by PageRenderer after mount, before the parent's render.
    Component render errors are silently discarded in the PageRenderer
    path (no WebSocket to send them to).
    """
    _components.render_all()
    _components.flush_render_errors()
    _components.populate_component_html(_assigns)
