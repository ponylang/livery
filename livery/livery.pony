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

## Getting Started

1. Implement the `LiveView` trait on a class
2. Register routes via `Router` and freeze with `Router.build()`
3. Create a `PubSub` instance
4. Start a `Listener` with your routes and PubSub

See the examples directory for working applications.
"""
