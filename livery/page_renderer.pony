use json = "json"

type PageRenderError is (PageRenderFactoryFailed | PageRenderFailed)

primitive PageRenderFactoryFailed
  """
  The Factory failed to create a LiveView instance.
  """
  fun string(): String iso^ => "factory_failed".clone()

primitive PageRenderFailed
  """
  The LiveView's render method failed.
  """
  fun string(): String iso^ => "render_failed".clone()

primitive PageRenderer
  """
  Render a LiveView to HTML without a WebSocket connection.

  Creates a temporary view, mounts it with a disconnected socket, and calls
  render. Use this for server-rendered first paint: generate HTML at HTTP
  request time, embed it in the page, and let the JS client take over when
  the WebSocket connects.

  The view is mounted with a disconnected socket — `connected()` returns
  false, PubSub operations are no-ops, and push events are silently dropped.
  LiveViews that need different behavior during HTTP render vs WebSocket can
  check `socket.connected()` in mount.
  """

  fun render(factory: Factory): (String val | PageRenderError) =>
    """
    Create a view from the factory, mount it, and render to HTML.

    Returns the rendered HTML string on success, or a specific error
    indicating whether the factory or the render failed.
    """
    let view = try factory()?
      else return PageRenderFactoryFailed
      end
    let assigns = Assigns
    let pending_events = Array[(String val, json.JsonValue)]
    let socket = Socket._for_render(assigns, pending_events)
    view.mount(socket)
    try
      view.render(assigns)?
    else
      PageRenderFailed
    end
