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

## Getting Started

1. Implement the `LiveView` trait on a class
2. Register routes via `Router` and freeze with `Router.build()`
3. Create a `PubSub` instance
4. Start a `Listener` with your routes and PubSub

See the examples directory for working applications.
"""
