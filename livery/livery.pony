"""
# Livery

A library for building interactive, server-rendered LiveView UIs over
WebSocket.

Define server-side view logic by implementing the `LiveView` trait:

- `mount` initializes state on the `Socket`
- `handle_event` responds to client interactions
- `render` produces HTML from the current `Assigns`

Use `HtmlTemplate` from the templates library for rendering — it auto-escapes
dynamic values by default.

## Getting Started

1. Implement the `LiveView` trait on a class
2. Register routes via `Router` and freeze with `Router.build()`
3. Start a `Listener` with your routes

See the examples directory for a working counter application.
"""
