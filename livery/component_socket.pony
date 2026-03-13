use templates = "templates"
use json = "json"

class ComponentSocket
  """
  API for LiveComponent lifecycle methods.

  Provides assign management and push events. Unlike `Socket`, does not
  provide PubSub subscription or `InfoReceiver` -- those are connection-level
  concerns managed by the parent view.
  """
  let _assigns: Assigns ref
  let _pending_events: Array[(String val, json.JsonValue)] ref

  new create(assigns: Assigns ref,
    pending_events: Array[(String val, json.JsonValue)] ref)
  =>
    _assigns = assigns
    _pending_events = pending_events

  fun ref assign(key: String,
    value: (String | templates.TemplateValue))
  =>
    """
    Set a component assign value. The framework re-renders after the
    current handler if any assigns changed.
    """
    _assigns.update(key, value)

  fun box get_assign(key: String): templates.TemplateValue ? =>
    """
    Read a component assign value.
    """
    _assigns(key)?

  fun ref push_event(event: String val, payload: json.JsonValue) =>
    """
    Push a server-initiated event to the client. Events are queued and
    flushed after the current render cycle, same as `Socket.push_event`.
    """
    _pending_events.push((event, payload))
