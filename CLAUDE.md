# Livery

Server-side Pony library for building interactive LiveView UIs over WebSocket. Sends full HTML on each state change; the JS client (separate repo) patches the DOM with morphdom.

## Building

```
make test ssl=openssl_3.0.x
```

The `ssl` flag is required because mare (WebSocket transport) depends on the ssl package transitively. On machines with OpenSSL 3.x, use `ssl=openssl_3.0.x`.

Targets: `make test` (build + run tests + build examples), `make unit-tests` (tests only), `make examples` (examples only), `make clean`.

## Dependencies

| Package | Version | Use path | Role |
|---------|---------|----------|------|
| mare | 0.1.1 | `"mare"` | WebSocket server (connection actor implements `WebSocketServerActor`) |
| templates | 0.3.0 | `"templates"` | HTML rendering (`HtmlTemplate` auto-escapes by default) |
| json-ng | 0.3.0 | `"json"` | Wire protocol serialization (persistent `JsonObject`/`JsonArray`) |
| lori | (transitive via mare) | `"lori"` | TCP networking, idle timeout |

## Architecture

### Public API

- `LiveView` trait — user implements `mount`, `handle_event`, `handle_info`, `render`
- `Assigns` — key-value store with dirty tracking, backed by `TemplateValues`
- `Socket` — user-facing handle passed to lifecycle methods; provides `self()`, `subscribe(topic)`, `unsubscribe(topic)`
- `Factory` — `interface val` for creating `LiveView` instances (lambdas work via structural typing)
- `Router` / `Routes` — mutable builder freezes into immutable `Routes val`
- `InfoReceiver` — `interface tag` handle for sending messages to a connection from external actors
- `PubSub` — actor for topic-based publish-subscribe across connections
- `Listener` — actor wrapping lori's `TCPListenerActor`

### Internal

- `_Connection` — one actor per client, implements `WebSocketServerActor`. Two-phase init: view is `None` until `on_open` delivers the URI for route lookup. Has `info` behavior for external message delivery; cleans up PubSub subscriptions in `on_closed`.
- `_WireProtocol` — JSON encode/decode for the client-server wire format.
- `_Unreachable` — panic primitive for impossible code paths.

### Wire Protocol (JSON over WebSocket)

Client → Server: `{"t":"event","e":"name","p":{...}}`, `{"t":"heartbeat"}`
Server → Client: `{"t":"render","html":"..."}`, `{"t":"heartbeat_ack"}`, `{"t":"push","e":"name","p":{...}}`, `{"t":"error","reason":"..."}`

## File Layout

```
livery/           # Library package (also the test compilation target)
  livery.pony     # Package docstring
  live_view.pony  # LiveView trait
  assigns.pony    # Assigns class
  socket.pony     # Socket class
  factory.pony    # Factory interface
  info_receiver.pony # InfoReceiver interface
  pub_sub.pony    # PubSub actor
  router.pony     # Router + Routes
  listener.pony   # Listener actor
  _connection.pony # Connection actor (internal)
  _wire_protocol.pony # Wire protocol (internal)
  _unreachable.pony   # Panic primitive (internal)
  _test.pony      # All tests (single runner)
examples/
  counter/        # Increment/decrement counter
  ticker/         # PubSub-driven ticker (server push)
```

## Conventions

- Qualified imports in library code: `use json = "json"`, `use mare = "mare"`, etc.
- Single test runner in `livery/_test.pony` with `Main is TestList`.
- `\nodoc\` on all test types.
- Property-based tests (PonyCheck) for Assigns; example-based for wire protocol, router, socket, PubSub.
