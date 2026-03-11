use "templates"
use "json"
use lori = "lori"
use "../../livery"

class CounterView is LiveView
  let _template: HtmlTemplate val

  new create() ? =>
    _template = HtmlTemplate.parse(
      """
      <div>
        <h1>Count: {{ count }}</h1>
        <button lv-click="increment">+</button>
        <button lv-click="decrement">-</button>
      </div>
      """)?

  fun ref mount(socket: Socket ref) =>
    socket.assign("count", "0")

  fun ref handle_event(event: String val, payload: JsonValue,
    socket: Socket ref)
  =>
    try
      let current = socket.get_assign("count")?.string()?.i64()?
      let next = match event
        | "increment" => current + 1
        | "decrement" => current - 1
        else current
        end
      socket.assign("count", next.string())
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
