use json = "json"

primitive _WireProtocol
  """
  JSON wire protocol encoding and decoding for client-server communication.
  """
  fun encode_render(html: String val): String val =>
    """
    Encode a rendered HTML update for the client.
    """
    json.JsonObject
      .update("t", "render")
      .update("html", html)
      .string()

  fun encode_heartbeat_ack(): String val =>
    """
    Encode a heartbeat acknowledgment.
    """
    json.JsonObject
      .update("t", "heartbeat_ack")
      .string()

  fun encode_push_event(event: String val, payload: json.JsonValue)
    : String val
  =>
    """
    Encode a server-pushed event.
    """
    json.JsonObject
      .update("t", "push")
      .update("e", event)
      .update("p", payload)
      .string()

  fun encode_error(reason: String val): String val =>
    """
    Encode an error message.
    """
    json.JsonObject
      .update("t", "error")
      .update("reason", reason)
      .string()

  fun decode_client_message(data: String val)
    : (_ClientMessage | _WireError)
  =>
    """
    Decode a client message from JSON.
    """
    let obj = match json.JsonParser.parse(data)
      | let o: json.JsonObject => o
      else return _WireError("invalid JSON or not an object")
      end

    let msg_type: json.JsonValue =
      try obj("t")?
      else return _WireError("missing 't' field")
      end

    match msg_type
    | let t: String =>
      match t
      | "event" => _decode_event(obj)
      | "heartbeat" => _HeartbeatMessage
      else
        _WireError("unknown message type: " + t)
      end
    else
      _WireError("'t' field is not a string")
    end

  fun _decode_event(obj: json.JsonObject): (_EventMessage | _WireError) =>
    let event_name: json.JsonValue =
      try obj("e")?
      else return _WireError("event missing 'e' field")
      end

    match event_name
    | let e: String =>
      let p: json.JsonValue = try obj("p")? else None end
      let target: (String val | None) =
        try
          match obj("c")?
          | let c: String => c
          else return _WireError("event 'c' field is not a string")
          end
        else
          None
        end
      _EventMessage(e, p, target)
    else
      _WireError("event 'e' field is not a string")
    end

type _ClientMessage is (_EventMessage | _HeartbeatMessage)

class val _EventMessage
  """
  A client event message (e.g., button click). Optionally targets a
  specific component via the `target` field.
  """
  let event: String val
  let payload: json.JsonValue
  let target: (String val | None)

  new val create(event': String val, payload': json.JsonValue,
    target': (String val | None) = None)
  =>
    event = event'
    payload = payload'
    target = target'

primitive _HeartbeatMessage
  """
  A client heartbeat message.
  """

class val _WireError
  """
  A wire protocol decoding error.
  """
  let reason: String val

  new val create(reason': String val) =>
    reason = reason'
