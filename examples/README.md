# Examples

Each subdirectory is a self-contained Pony program demonstrating a different part of the livery library. Each example includes an `index.html` file that connects to the running server via the JavaScript client.

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

| Example | Command | Port |
|---------|---------|------|
| counter | `./build/release/counter` | 8081 |
| ticker | `./build/release/ticker` | 8082 |

1. Serve the repo root with a static file server (the HTML shells use relative paths to load the JS client bundle):

```sh
python3 -m http.server 8080
```

Then visit the example in your browser:

- Counter: `http://localhost:8080/examples/counter/index.html`
- Ticker: `http://localhost:8080/examples/ticker/index.html`

## [counter](counter/)

Implements a simple increment/decrement counter as a `LiveView`. Registers a single route, parses a template with `HtmlTemplate`, and updates an integer assign in response to `"increment"` and `"decrement"` click events. Demonstrates the core lifecycle: `mount`, `handle_event`, and `render` with the `Router`/`Listener` setup. Start here if you're new to the library.

## [ticker](ticker/)

Demonstrates server push via `PubSub` and `handle_info`. A `Ticker` actor publishes to the `"tick"` topic every second. The `TickerView` subscribes in `mount` and increments a counter each time `handle_info` fires — this drives a re-render via assigns. It also calls `push_event` to send the raw tick count to the client, where a JavaScript `on()` handler updates a separate DOM element outside the LiveView container. Shows the two complementary push mechanisms: server-rendered DOM updates (assigns + re-render) and client-side event handling (`push_event` + `on()`).
