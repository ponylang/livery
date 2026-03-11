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

  new create(auth: lori.TCPServerAuth, fd: U32,
    config: mare.WebSocketConfig val, routes: Routes val)
  =>
    _assigns = Assigns
    _pending_events = Array[(String val, json.JsonValue)]
    _socket = Socket(_assigns, _pending_events)
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

    try
      let html = view.render(_assigns)?
      _last_html = html
      _ws.send_text(_WireProtocol.encode_render(html))
    else
      _ws.send_text(_WireProtocol.encode_error("render_failed"))
      _ws.close()
      return
    end

    _view = view

    match lori.MakeIdleTimeout(60_000)
    | let t: lori.IdleTimeout => _connection().idle_timeout(t)
    end

  fun ref on_text_message(data: String val) =>
    match _view
    | let v: LiveView ref =>
      match _WireProtocol.decode_client_message(data)
      | let msg: _EventMessage =>
        v.handle_event(msg.event, msg.payload, _socket)
        _maybe_rerender(v)
      | _HeartbeatMessage =>
        _ws.send_text(_WireProtocol.encode_heartbeat_ack())
      | let err: _WireError =>
        _ws.send_text(_WireProtocol.encode_error(err.reason))
      end
    end

  fun ref _maybe_rerender(v: LiveView ref) =>
    if _assigns.changed() then
      try
        let html = v.render(_assigns)?
        _last_html = html
        _ws.send_text(_WireProtocol.encode_render(html))
      else
        _ws.send_text(_WireProtocol.encode_error("render_failed"))
      end
      _assigns.clear_changes()
    end
    _flush_pending_events()

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
    None
