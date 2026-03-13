use "files"
use "templates"
use "json"
use hobby = "hobby"
use lori = "lori"
use stallion = "stallion"
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

class val IndexHandler is hobby.Handler
  """
  Serves the initial HTML page with server-rendered content.

  Calls `PageRenderer.render` to produce the counter's HTML at request time,
  embeds it in a full page shell, and responds with `text/html`. The JS client
  takes over when the WebSocket connects — morphdom patches the pre-rendered
  DOM without a visible flash.
  """
  let _factory: Factory

  new val create(factory: Factory) =>
    _factory = factory

  fun apply(ctx: hobby.Context ref) =>
    let body = match PageRenderer.render(_factory)
    | let html: String val =>
      "<!DOCTYPE html>\n"
        + "<html>\n"
        + "<head><title>SSR Counter - Livery Example</title></head>\n"
        + "<body>\n"
        + "  <div id=\"lv-root\">" + html + "</div>\n"
        + "  <script src=\"/client/livery.iife.js\"></script>\n"
        + "  <script>\n"
        + "    new LiveView({\n"
        + "      url: \"ws://localhost:8084/ssr\",\n"
        + "      target: document.getElementById(\"lv-root\")\n"
        + "    }).connect();\n"
        + "  </script>\n"
        + "</body>\n"
        + "</html>"
    | let err: PageRenderError =>
      ctx.respond(stallion.StatusInternalServerError, err.string())
      return
    end
    let headers = recover val
      let h = stallion.Headers
      h.set("Content-Type", "text/html; charset=utf-8")
      h.set("Content-Length", body.size().string())
      h
    end
    ctx.respond_with_headers(stallion.StatusOK, headers, consume body)

actor Main
  new create(env: Env) =>
    let factory: Factory =
      {(): LiveView ref^ ? => CounterView.create()?} val

    // WebSocket server for live updates
    let router = Router
    router.route("/ssr", factory)
    Listener(lori.TCPListenAuth(env.root), "0.0.0.0", "8084",
      router.build(), PubSub, env.err)

    // HTTP server for initial page load and static assets
    let client_root = FilePath(FileAuth(env.root), "client/dist")
    hobby.Application
      .>get("/", IndexHandler(factory))
      .>get("/client/*filepath", hobby.ServeFiles(client_root))
      .serve(lori.TCPListenAuth(env.root), stallion.ServerConfig("0.0.0.0",
        "8085"), env.err)
