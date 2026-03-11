class Router
  """
  Mutable builder for registering LiveView routes.

  Register paths with their factories, then call `build()` to freeze the
  route table into an immutable `Routes` value that can be shared across
  actors.
  """
  let _routes: Array[(String, Factory)]

  new create() =>
    _routes = Array[(String, Factory)]

  fun ref route(path: String, factory: Factory) =>
    """
    Register a path with a factory that creates the LiveView for that route.
    """
    _routes.push((path, factory))

  fun ref build(): Routes val =>
    """
    Freeze the route table into an immutable `Routes` value.
    """
    let size = _routes.size()
    let r: Array[(String, Factory)] iso =
      recover iso Array[(String, Factory)](size) end
    for (p, f) in _routes.values() do
      r.push((p, f))
    end
    Routes(consume r)

class val Routes
  """
  Immutable route table mapping paths to LiveView factories.

  Created by `Router.build()`. Strips query strings before matching, so a
  route registered as `"/path"` matches requests to `"/path?foo=bar"`.
  """
  let _routes: Array[(String, Factory)] val

  new val create(routes: Array[(String, Factory)] val) =>
    _routes = routes

  fun apply(path: String): (Factory | None) =>
    """
    Look up a factory for the given path, stripping any query string first.
    """
    let clean: String val =
      try
        path.substring(0, path.find("?")?)
      else
        path
      end
    for (route_path, factory) in _routes.values() do
      if route_path == clean then
        return factory
      end
    end
    None
