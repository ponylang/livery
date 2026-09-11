use mare = "mare"
use "net"

actor Listener is TCPListenerActor
  """
  WebSocket listener that routes incoming connections to LiveView instances.

  Create a `Router`, register paths with factories, then pass the frozen
  `Routes` to the listener.
  """
  var _tcp_listener: TCPListener = TCPListener.none()
  let _server_auth: TCPServerAuth
  let _config: mare.WebSocketConfig val
  let _routes: Routes val
  let _pub_sub: PubSub tag
  let _out: OutStream tag

  new create(
    auth: TCPListenAuth,
    host: String,
    port: String,
    routes: Routes val,
    pub_sub: PubSub tag,
    out: OutStream tag)
  =>
    _server_auth = TCPServerAuth(auth)
    _config = mare.WebSocketConfig(host, port)
    _routes = routes
    _pub_sub = pub_sub
    _out = out
    _tcp_listener = TCPListener(auth, host, port, this)

  fun ref _listener(): TCPListener =>
    _tcp_listener

  fun ref _on_accept(fd: U32): _Connection =>
    _Connection(_server_auth, fd, _config, _routes, _pub_sub)

  fun ref _on_listen_failure() =>
    _out.print("Listener: failed to bind to " + _config.host + ":" +
      _config.port)
