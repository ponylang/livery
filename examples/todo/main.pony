use "templates"
use "json"
use lori = "lori"
use "../../livery"

class TodoItem is LiveComponent
  """
  A single todo item component. Handles its own toggle event. Delete
  events route to the parent view (no lv-target on the delete button)
  because the parent manages component lifecycle.
  """
  let _template: HtmlTemplate val

  new create() ? =>
    _template = HtmlTemplate.parse(
      """
      <li>
        <span class="{{ css_class }}">{{ text }}</span>
        <button lv-click="toggle" lv-target="{{ id }}">
          {{ toggle_label }}
        </button>
        <button lv-click="delete" lv-value-id="{{ id }}">Delete</button>
      </li>
      """)?

  fun ref mount(socket: ComponentSocket ref) =>
    None

  fun ref update(socket: ComponentSocket ref) =>
    try
      let done = socket.get_assign("done")?.string()? == "true"
      socket.assign("css_class", if done then "done" else "" end)
      socket.assign("toggle_label", if done then "Undo" else "Done" end)
    end

  fun ref handle_event(event: String val, payload: JsonValue,
    socket: ComponentSocket ref)
  =>
    match event
    | "toggle" =>
      try
        let done = socket.get_assign("done")?.string()? == "true"
        socket.assign("done", if done then "false" else "true" end)
        socket.assign("css_class",
          if not done then "done" else "" end)
        socket.assign("toggle_label",
          if not done then "Undo" else "Done" end)
      end
    end

  fun box render(assigns: Assigns box): String ? =>
    _template.render(assigns.template_values())?


class TodoListView is LiveView
  """
  A LiveView that manages a list of todo items, each rendered as a
  stateful `TodoItem` component. Demonstrates:

  - Registering components with `socket.register_component`
  - Passing data to components with `socket.update_component`
  - Event targeting with `lv-target` (toggle goes to component)
  - Parent-handled events (delete goes to parent via `lv-value-id`)
  - Component HTML rendering via `assigns.component_html`
  """
  let _template: HtmlTemplate val
  var _next_id: USize = 1
  var _todo_ids: Array[String] ref = Array[String]

  new create() ? =>
    _template = HtmlTemplate.parse(
      """
      <div>
        <h1>Todo List</h1>
        <form lv-submit="add">
          <input type="text" name="text" placeholder="Add a todo..." />
          <button type="submit">Add</button>
        </form>
        <ul>{{ items_html }}</ul>
        <p>{{ count }} items</p>
      </div>
      """)?

  fun ref mount(socket: Socket ref) =>
    socket.assign("count", "0")

  fun ref handle_event(event: String val, payload: JsonValue,
    socket: Socket ref)
  =>
    match event
    | "add" =>
      let nav = JsonNav(payload)
      try
        let text = nav("text").as_string()?
        if text.size() > 0 then
          let id: String val = "todo-" + _next_id.string()
          _next_id = _next_id + 1

          let item = TodoItem.create()?
          if socket.register_component(id, item) then
            socket.update_component(id,
              recover val
                let data = Array[(String, (String | TemplateValue))]
                data.push(("id", id))
                data.push(("text", text))
                data.push(("done", "false"))
                data
              end)
            _todo_ids.push(id)
            socket.assign("count", _todo_ids.size().string())
          end
        end
      end
    | "delete" =>
      let nav = JsonNav(payload)
      try
        let id = nav("id").as_string()?
        socket.unregister_component(id)
        let new_ids = Array[String]
        for existing_id in _todo_ids.values() do
          if existing_id != id then
            new_ids.push(existing_id)
          end
        end
        _todo_ids = new_ids
        socket.assign("count", _todo_ids.size().string())
      end
    end

  fun box _prepare_values(assigns: Assigns box): TemplateValues =>
    let vals = assigns.render_values()
    var items = ""
    for id in _todo_ids.values() do
      try items = items + assigns.component_html(id)? end
    end
    vals.unescaped("items_html", items)
    vals

  fun box render(assigns: Assigns box): String ? =>
    _template.render(_prepare_values(assigns))?

  fun box render_parts(assigns: Assigns box,
    sink: TemplateSink ref): Bool
  =>
    try
      _template.render_to(sink, _prepare_values(assigns))?
      true
    else
      false
    end


actor Main
  new create(env: Env) =>
    let router = Router
    router.route("/todo",
      {(): LiveView ref^ ? => TodoListView.create()?} val)

    Listener(lori.TCPListenAuth(env.root), "0.0.0.0", "8086",
      router.build(), PubSub, env.err)
