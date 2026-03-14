use "time"
use "templates"
use "json"
use lori = "lori"
use "../../livery"

class TickerView is LiveView
  """
  A LiveView that displays a count incremented by an external ticker.

  Subscribes to the `"tick"` PubSub topic in `mount`. Each time the
  `Ticker` actor publishes to that topic, `handle_info` fires,
  increments the counter (triggering a re-render via assigns), and calls
  `push_event` to send the raw tick count to the client. This
  demonstrates both push mechanisms: server-rendered DOM updates and
  client-side event handling via `on()`.
  """
  let _template: HtmlTemplate val

  new create() ? =>
    _template = HtmlTemplate.parse(
      """
      <div>
        <h1>Ticks: {{ count }}</h1>
        <p>Count updates automatically every second.</p>
      </div>
      """)?

  fun ref mount(socket: Socket ref) =>
    socket.assign("count", "0")
    socket.subscribe("tick")

  fun ref handle_event(event: String val, payload: JsonValue,
    socket: Socket ref)
  =>
    None

  fun ref handle_info(message: Any val, socket: Socket ref) =>
    try
      let current = socket.get_assign("count")?.string()?.i64()?
      socket.assign("count", (current + 1).string())
    end
    match message
    | let n: U64 =>
      socket.push_event("tick", JsonObject.update("timer_count", n.i64()))
    end

  fun box render(assigns: Assigns box): String ? =>
    _template.render(assigns.template_values())?

  fun box render_parts(assigns: Assigns box,
    sink: TemplateSink ref): Bool
  =>
    try
      _template.render_to(sink, assigns.template_values())?
      true
    else
      false
    end

actor Ticker
  """
  Publishes a message to the `"tick"` PubSub topic every second.
  """
  let _pub_sub: PubSub tag
  let _timers: Timers

  new create(pub_sub: PubSub tag) =>
    _pub_sub = pub_sub
    _timers = Timers
    let timer = Timer(_TickNotify(pub_sub), 1_000_000_000, 1_000_000_000)
    _timers(consume timer)

class _TickNotify is TimerNotify
  let _pub_sub: PubSub tag

  new iso create(pub_sub: PubSub tag) =>
    _pub_sub = pub_sub

  fun ref apply(timer: Timer, count: U64): Bool =>
    _pub_sub.publish("tick", count)
    true

actor Main
  new create(env: Env) =>
    let pub_sub = PubSub
    Ticker(pub_sub)

    let router = Router
    router.route("/ticker",
      {(): LiveView ref^ ? => TickerView.create()?} val)

    Listener(lori.TCPListenAuth(env.root), "0.0.0.0", "8082",
      router.build(), pub_sub, env.err)
