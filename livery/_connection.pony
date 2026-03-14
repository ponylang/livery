use mare = "mare"
use lori = "lori"
use json = "json"

actor _Connection is mare.WebSocketServerActor
  """
  One actor per connected client. Owns the LiveView instance, assigns, and
  socket for a single connection.

  Two-phase initialization: created by the listener on TCP accept, but the
  LiveView is not instantiated until the WebSocket handshake completes and
  `on_open` delivers the request URI for route lookup.
  """
  var _ws: mare.WebSocketServer = mare.WebSocketServer.none()
  var _view: (LiveView ref | None) = None
  let _assigns: Assigns ref
  let _pending_events: Array[(String val, json.JsonValue)] ref
  let _socket: Socket ref
  var _last_html: String val = ""
  let _router: Routes val
  let _pub_sub: PubSub tag
  let _components: _ComponentRegistry ref
  let _render_sink: _RenderSink ref = _RenderSink

  new create(auth: lori.TCPServerAuth, fd: U32,
    config: mare.WebSocketConfig val, routes: Routes val,
    pub_sub: PubSub tag)
  =>
    _assigns = Assigns
    _pending_events = Array[(String val, json.JsonValue)]
    _pub_sub = pub_sub
    _components = _ComponentRegistry(_pending_events)
    _socket = Socket(_assigns, _pending_events, this, _pub_sub, _components)
    _router = routes
    _ws = mare.WebSocketServer(auth, fd, this, config)

  fun ref _websocket(): mare.WebSocketServer =>
    _ws

  fun ref on_open(request: mare.UpgradeRequest val) =>
    let factory = match _router(request.uri)
      | let f: Factory => f
      | None =>
        _ws.send_text(_WireProtocol.encode_error("no_route"))
        _ws.close()
        return
      end

    let view = try factory()?
      else
        _ws.send_text(_WireProtocol.encode_error("factory_failed"))
        _ws.close()
        return
      end

    view.mount(_socket)
    _components.render_all()
    for err in _components.flush_render_errors().values() do
      _ws.send_text(_WireProtocol.encode_error(err))
    end
    _components.populate_component_html(_assigns)

    if not _try_split_render(view) then
      try
        let html = view.render(_assigns)?
        _last_html = html
        _ws.send_text(_WireProtocol.encode_render(html))
      else
        _ws.send_text(_WireProtocol.encode_error("render_failed"))
        _ws.close()
        return
      end
    end
    _assigns.clear_changes()
    _assigns._clear_component_html()

    _view = view

    match lori.MakeIdleTimeout(60_000)
    | let t: lori.IdleTimeout => _connection().idle_timeout(t)
    end

  fun ref on_text_message(data: String val) =>
    match _view
    | let v: LiveView ref =>
      match _WireProtocol.decode_client_message(data)
      | let msg: _EventMessage =>
        match msg.target
        | let component_id: String =>
          if not _components.handle_event(component_id, msg.event,
            msg.payload)
          then
            _ws.send_text(
              _WireProtocol.encode_error("unknown_component"))
            return
          end
        | None =>
          v.handle_event(msg.event, msg.payload, _socket)
        end
        _maybe_rerender(v)
      | _HeartbeatMessage =>
        _ws.send_text(_WireProtocol.encode_heartbeat_ack())
      | let err: _WireError =>
        _ws.send_text(_WireProtocol.encode_error(err.reason))
      end
    end

  be info(message: Any val) =>
    """
    Deliver an external message to the LiveView via handle_info.
    Silently dropped if the view has not been mounted yet.
    """
    match _view
    | let v: LiveView ref =>
      v.handle_info(message, _socket)
      _maybe_rerender(v)
    end

  fun ref _maybe_rerender(v: LiveView ref) =>
    let components_changed = _components.render_all()
    for err in _components.flush_render_errors().values() do
      _ws.send_text(_WireProtocol.encode_error(err))
    end
    if _assigns.changed() or components_changed then
      _components.populate_component_html(_assigns)
      if not _try_split_render(v) then
        _render_sink.clear()
        try
          let html = v.render(_assigns)?
          _last_html = html
          _ws.send_text(_WireProtocol.encode_render(html))
        else
          _ws.send_text(_WireProtocol.encode_error("render_failed"))
        end
      end
      _assigns.clear_changes()
      _assigns._clear_component_html()
    end
    _flush_pending_events()

  fun ref _try_split_render(v: LiveView ref): Bool =>
    """
    Attempt a split render. Returns true if the split path handled rendering
    (even if the diff was _NoChange). Returns false if the view doesn't
    support split rendering, meaning the caller should fall back to render().
    """
    _render_sink.begin()
    if v.render_parts(_assigns, _render_sink) then
      match _render_sink.result()
      | let full: _FullRender =>
        _last_html = _render_sink.full_html()
        _ws.send_text(
          _WireProtocol.encode_render_full(full.statics, full.dynamics))
      | let diff: _SlotDiff =>
        _last_html = _render_sink.full_html()
        _ws.send_text(
          _WireProtocol.encode_render_diff(diff.changes))
      | _NoChange => None
      end
      true
    else
      _render_sink.abandon()
      false
    end

  fun ref _flush_pending_events() =>
    for (event, payload) in _pending_events.values() do
      _ws.send_text(_WireProtocol.encode_push_event(event, payload))
    end
    _pending_events.clear()

  fun ref on_idle_timeout() =>
    _ws.close(mare.CloseGoingAway, "idle timeout")

  fun ref on_closed(close_status: mare.CloseStatus,
    close_reason: String val)
  =>
    _pub_sub.unsubscribe_all(this)
