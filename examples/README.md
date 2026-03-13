# Examples

Each subdirectory is a self-contained Pony program demonstrating a different part of the livery library. The counter, ticker, and form examples each include an `index.html` file that connects to the running server via the JavaScript client. The ssr example dynamically renders its HTML via an HTTP server using `PageRenderer`.

## Running examples

1. Build the JavaScript client:

```sh
cd client && npm install && npm run build
```

1. Compile the examples:

```sh
make ssl=openssl_3.0.x examples
```

1. Start the Pony server for the example you want to run:

| Example | Command | WebSocket port | HTTP port |
|---------|---------|----------------|-----------|
| counter | `./build/release/counter` | 8081 | — |
| ticker | `./build/release/ticker` | 8082 | — |
| form | `./build/release/form` | 8083 | — |
| ssr | `./build/release/ssr` | 8084 | 8085 |

1. For the counter, ticker, and form examples, serve the repo root with a static file server (the HTML shells use relative paths to load the JS client bundle):

```sh
python3 -m http.server 8080
```

Then visit the example in your browser:

- Counter: `http://localhost:8080/examples/counter/index.html`
- Ticker: `http://localhost:8080/examples/ticker/index.html`
- Form: `http://localhost:8080/examples/form/index.html`
- SSR: `http://localhost:8085/` (served directly by hobby, no static file server needed)

## [counter](counter/)

Implements a simple increment/decrement counter as a `LiveView`. Registers a single route, parses a template with `HtmlTemplate`, and updates an integer assign in response to `"increment"` and `"decrement"` click events. Demonstrates the core lifecycle: `mount`, `handle_event`, and `render` with the `Router`/`Listener` setup. Start here if you're new to the library.

## [ticker](ticker/)

Demonstrates server push via `PubSub` and `handle_info`. A `Ticker` actor publishes to the `"tick"` topic every second. The `TickerView` subscribes in `mount` and increments a counter each time `handle_info` fires — this drives a re-render via assigns. It also calls `push_event` to send the raw tick count to the client, where a JavaScript `on()` handler updates a separate DOM element outside the LiveView container. Shows the two complementary push mechanisms: server-rendered DOM updates (assigns + re-render) and client-side event handling (`push_event` + `on()`).

## [form](form/)

Demonstrates form handling with live validation. A registration form uses `lv-change` for real-time field validation as the user types and `lv-submit` for full validation on submit. Field values and error messages are stored as assigns — the template renders both the current input values and per-field error messages. Shows how the existing `handle_event` API handles form data without any additional library types: the client serializes form fields as a JSON payload, and the server extracts them with `JsonNav`.

## [ssr](ssr/)

Demonstrates server-rendered first paint with a dynamic HTTP handler. A hobby HTTP server on port 8085 calls `PageRenderer.render(factory)` to produce the counter's initial HTML at request time, embeds it in a full page, and serves it along with the JS client bundle. When the browser loads the page, the user sees the counter immediately — no empty-page flash. The JS client then connects to the WebSocket server on port 8084, morphdom takes over the pre-rendered DOM, and the counter becomes interactive. Compare with the counter example to see what server-rendered first paint adds.
