# livery

A library for building interactive, server-rendered LiveView UIs over WebSocket in Pony.

## Status

Livery is beta quality software that will change frequently. Expect breaking changes. That said, you should feel comfortable using it in your projects.

## Installation

* Install [corral](https://github.com/ponylang/corral)
* `corral add github.com/ponylang/livery.git --version 0.1.2`
* `corral fetch` to fetch your dependencies
* `use "livery"` to include this package
* `corral run -- ponyc` to compile your application

Note: livery depends on the [ssl](https://github.com/ponylang/ssl) package transitively through [mare](https://github.com/ponylang/mare). See the [ssl installation instructions](https://github.com/ponylang/ssl#installation) for OpenSSL setup, and pass the appropriate `-D` flag when compiling (e.g., `corral run -- ponyc -Dopenssl_3.0.x`).

## Usage

Define a `LiveView` class, register routes, and start a listener:

```pony
use "templates"
use "json"
use lori = "lori"
use "livery"

class CounterView is LiveView
  let _template: HtmlTemplate val

  new create() ? =>
    _template = HtmlTemplate.parse(
      """
      <div>
        <h1>Count: {{ count }}</h1>
        <button lv-click="increment">+</button>
      </div>
      """)?

  fun ref mount(socket: Socket ref) =>
    socket.assign("count", "0")

  fun ref handle_event(event: String val, payload: JsonValue,
    socket: Socket ref)
  =>
    try
      let current = socket.get_assign("count")?.string()?.i64()?
      if event == "increment" then
        socket.assign("count", (current + 1).string())
      end
    end

  fun box render(assigns: Assigns box): String ? =>
    _template.render(assigns.template_values())?

actor Main
  new create(env: Env) =>
    let router = Router
    router.route("/counter",
      {(): LiveView ref^ ? => CounterView.create()?} val)

    Listener(lori.TCPListenAuth(env.root), "0.0.0.0", "8081",
      router.build(), env.err)
```

See the [examples](examples/) directory for more.

## API Documentation

[https://ponylang.github.io/livery](https://ponylang.github.io/livery)
