# Livery

Server-side Pony library for building interactive LiveView UIs over WebSocket. Sends full HTML on each state change; the JS client (in `client/`) patches the DOM with morphdom.

## Building

```
make test ssl=openssl_3.0.x
```

The `ssl` flag is required because mare (WebSocket transport) depends on the ssl package transitively. On machines with OpenSSL 3.x, use `ssl=openssl_3.0.x`.

Targets: `make test` (build + run tests + build examples), `make unit-tests` (tests only), `make examples` (examples only), `make clean`. JS client targets: `make client-test`, `make client-build`.

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
- `Socket` — user-facing handle passed to lifecycle methods; provides `connected()`, `self()`, `subscribe(topic)`, `unsubscribe(topic)`
- `Factory` — `interface val` for creating `LiveView` instances (lambdas work via structural typing)
- `Router` / `Routes` — mutable builder freezes into immutable `Routes val`
- `InfoReceiver` — `interface tag` handle for sending messages to a connection from external actors
- `PubSub` — actor for topic-based publish-subscribe across connections
- `Listener` — actor wrapping lori's `TCPListenerActor`
- `PageRenderer` — primitive that renders a LiveView to HTML without a WebSocket (for server-rendered first paint)
- `PageRenderFactoryFailed` / `PageRenderFailed` — error primitives returned by `PageRenderer.render()`

### Internal

- `_Connection` — one actor per client, implements `WebSocketServerActor`. Two-phase init: view is `None` until `on_open` delivers the URI for route lookup. Has `info` behavior for external message delivery; cleans up PubSub subscriptions in `on_closed`.
- `_WireProtocol` — JSON encode/decode for the client-server wire format.
- `_NullInfoReceiver` — no-op actor satisfying `InfoReceiver` for disconnected sockets.
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
  page_renderer.pony # PageRenderer primitive + error types
  info_receiver.pony # InfoReceiver interface
  _null_info_receiver.pony # No-op InfoReceiver (internal)
  pub_sub.pony    # PubSub actor
  router.pony     # Router + Routes
  listener.pony   # Listener actor
  _connection.pony # Connection actor (internal)
  _wire_protocol.pony # Wire protocol (internal)
  _unreachable.pony   # Panic primitive (internal)
  _test.pony      # All tests (single runner)
examples/
  counter/        # Increment/decrement counter
  ticker/         # PubSub-driven ticker (server push via re-render + push_event)
  form/           # Registration form with live validation (lv-change + lv-submit)
  ssr/            # Server-rendered first paint (pre-rendered counter)
client/           # JavaScript client library
  src/            # Source modules (wire, events, socket, live-view)
  test/           # vitest tests
  dist/           # Build output (gitignored)
```

## JavaScript Client

The JS client lives in `client/` and connects to the Livery server over WebSocket, patching the DOM with morphdom on render messages.

### Building and testing

```
cd client && npm install && npm test    # Run tests
cd client && npm run build              # Build ESM + IIFE bundles to dist/
```

Docker-based (no local Node.js required):
```
make client-test
make client-build
```

### Architecture

| Module | Role |
|--------|------|
| `src/wire.js` | Wire protocol encode/decode, mirrors `_wire_protocol.pony` |
| `src/events.js` | Event delegation (`lv-click`, `lv-value-*`, `lv-change`, `lv-submit`) via single root listener |
| `src/socket.js` | WebSocket wrapper with heartbeat (30s interval, 10s ack timeout) and reconnection (exponential backoff, 30s cap) |
| `src/live-view.js` | Main orchestrator — connects Socket, morphdom, and event delegation |
| `src/index.js` | Entry point, re-exports `LiveView` |

### Distribution

- `dist/livery.esm.js` — ES module
- `dist/livery.iife.js` — IIFE bundle exposing `window.LiveView` for `<script>` tags

### Dependencies

| Package | Version | Role |
|---------|---------|------|
| morphdom | ^2.7.4 | DOM diffing/patching |
| esbuild | ^0.25 | Bundler (dev) |
| vitest | ^3 | Test framework (dev) |
| jsdom | ^26 | DOM environment for tests (dev, via vitest) |

## Conventions

- Qualified imports in library code: `use json = "json"`, `use mare = "mare"`, etc.
- Single test runner in `livery/_test.pony` with `Main is TestList`.
- `\nodoc\` on all test types.
- Property-based tests (PonyCheck) for Assigns; example-based for wire protocol, router, socket, PubSub.
