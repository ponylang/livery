"""
# Livery

A library for building interactive, server-rendered LiveView UIs over
WebSocket.

Define server-side view logic by implementing the `LiveView` trait:

- `mount` initializes state on the `Socket`
- `handle_event` responds to client interactions
- `handle_info` receives server-push messages from external actors
- `render` produces HTML from the current `Assigns`

Use `HtmlTemplate` from the templates library for rendering — it auto-escapes
dynamic values by default.

## Components

Compose UIs from stateful `LiveComponent` instances embedded within a
`LiveView`. Each component has its own assigns, lifecycle, and event handling.

Register components through `Socket`:

- `Socket.register_component(id, component)` — register and mount a component
- `Socket.update_component(id, data)` — pass data from the parent to a component
- `Socket.unregister_component(id)` — remove a component

Components render independently through `HtmlTemplate`. The parent accesses
component output in `render` via `assigns.component_html(id)` and inserts it
as unescaped HTML (safe because the component's own template already escaped
all dynamic values). Use `assigns.render_values()` to create a writable child
scope of the template values for overlaying component HTML.

Target events to specific components with the `lv-target` attribute in HTML.
Events without `lv-target` route to the parent `LiveView`.

Stateless components are a convention, not a framework feature — just
primitives or classes with a render function that takes data and returns HTML.

## Server Push

External actors can send messages to a connection through `PubSub` or
directly via `InfoReceiver`. Messages arrive at `LiveView.handle_info`,
where the view can update assigns and trigger a re-render.

- Call `Socket.self()` in a lifecycle method to get a shareable
  `InfoReceiver` handle
- Call `Socket.subscribe(topic)` to receive messages from a PubSub topic
- Subscriptions are automatically cleaned up when the connection closes

## Forms

Form handling works through the existing `handle_event` API — no additional
library types are needed. The JavaScript client sends form field data as a
JSON object payload via `lv-change` (fires on every keystroke for real-time
validation) and `lv-submit` (fires on form submission).

On the server, extract fields with `JsonNav` and validate:

```pony
fun ref handle_event(event: String val, payload: json.JsonValue,
  socket: Socket ref)
=>
  let nav = json.JsonNav(payload)
  try
    let username = nav("username").as_string()?
    let email = nav("email").as_string()?
    // validate and assign errors
  end
```

Store field values and error messages as assigns so the template renders both
the current input values and per-field feedback.

## Server-Rendered First Paint

Eliminate the empty-page flash on initial load by rendering the LiveView to
HTML at HTTP request time. The browser receives a fully populated page, then
the JS client silently takes over when the WebSocket connects.

Use `PageRenderer` to render a view without a WebSocket connection:

```pony
let factory: Factory = {(): LiveView ref^ ? => MyView?} val
match PageRenderer.render(factory)
| let html: String val =>
  // Embed html in the HTTP response inside the lv-root container
| let err: PageRenderFactoryFailed =>
  // Factory failed to create the view
| let err: PageRenderFailed =>
  // View's render method failed
end
```

The rendered view sees a disconnected socket — `connected()` returns false,
PubSub operations are no-ops, and push events are silently dropped. Check
`socket.connected()` in `mount` to vary behavior between HTTP render and
WebSocket.

When the JS client opens the WebSocket, the server mounts a fresh view
(producing identical initial HTML), and morphdom silently patches the
pre-rendered DOM with no visible change.

## Getting Started

1. Implement the `LiveView` trait on a class
2. Register routes via `Router` and freeze with `Router.build()`
3. Create a `PubSub` instance
4. Start a `Listener` with your routes and PubSub

See the examples directory for working applications.
"""
