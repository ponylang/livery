use "pony_test"
use "pony_check"
use json = "json"

actor \nodoc\ Main is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None

  fun tag tests(test: PonyTest) =>
    // Assigns property tests
    test(Property1UnitTest[String](_AssignsDirtyTracking))
    test(Property1UnitTest[String](_AssignsValueRoundtrip))
    test(Property1UnitTest[String](_AssignsTemplateBridge))
    // Wire protocol encode tests
    test(_TestEncodeRender)
    test(_TestEncodeHeartbeatAck)
    test(_TestEncodePushEvent)
    test(_TestEncodeError)
    // Wire protocol decode tests
    test(_TestDecodeEvent)
    test(_TestDecodeHeartbeat)
    test(_TestDecodeInvalidJson)
    test(_TestDecodeMissingType)
    test(_TestDecodeUnknownType)
    // Router tests
    test(_TestRouterExactMatch)
    test(_TestRouterNoMatch)
    test(_TestRouterEmpty)
    test(_TestRouterQueryStrip)
    // Socket tests
    test(_TestSocketPushEvent)

// --- Test helpers ---

class \nodoc\ _DummyView is LiveView
  new create() => None
  fun ref mount(socket: Socket ref) => None

  fun ref handle_event(event: String val, payload: json.JsonValue,
    socket: Socket ref)
  =>
    None

  fun box render(assigns: Assigns box): String =>
    ""

// --- Assigns property tests ---

class \nodoc\ _AssignsDirtyTracking is Property1[String]
  fun name(): String => "assigns/dirty_tracking"

  fun gen(): Generator[String] =>
    Generators.ascii_printable(1, 20)

  fun property(key: String, h: PropertyHelper) =>
    let assigns = Assigns
    h.assert_false(assigns.changed(), "fresh assigns should not be dirty")

    assigns.update(key, "value")
    h.assert_true(assigns.changed(), "update should make assigns dirty")

    assigns.clear_changes()
    h.assert_false(assigns.changed(),
      "clear_changes should reset dirty flag")

    assigns.update(key, "another")
    h.assert_true(assigns.changed(),
      "update after clear should make assigns dirty again")

class \nodoc\ _AssignsValueRoundtrip is Property1[String]
  fun name(): String => "assigns/value_roundtrip"

  fun gen(): Generator[String] =>
    Generators.ascii_printable(1, 50)

  fun property(value: String, h: PropertyHelper) ? =>
    let assigns = Assigns
    assigns.update("test_key", value)
    let retrieved = assigns("test_key")?.string()?
    h.assert_eq[String](value, retrieved)

class \nodoc\ _AssignsTemplateBridge is Property1[String]
  fun name(): String => "assigns/template_bridge"

  fun gen(): Generator[String] =>
    Generators.ascii_printable(1, 50)

  fun property(value: String, h: PropertyHelper) ? =>
    let assigns = Assigns
    assigns.update("key", value)
    let tv = assigns.template_values()
    let retrieved = tv("key")?.string()?
    h.assert_eq[String](value, retrieved)

// --- Wire protocol encode tests ---

class \nodoc\ _TestEncodeRender is UnitTest
  fun name(): String => "wire_protocol/encode_render"

  fun apply(h: TestHelper) ? =>
    let encoded = _WireProtocol.encode_render("<h1>hello</h1>")
    let obj = match json.JsonParser.parse(encoded)
      | let o: json.JsonObject => o
      else h.fail("expected JsonObject"); error
      end
    match obj("t")?
    | let t: String => h.assert_eq[String]("render", t)
    else h.fail("'t' should be a string")
    end
    match obj("html")?
    | let html: String => h.assert_eq[String]("<h1>hello</h1>", html)
    else h.fail("'html' should be a string")
    end

class \nodoc\ _TestEncodeHeartbeatAck is UnitTest
  fun name(): String => "wire_protocol/encode_heartbeat_ack"

  fun apply(h: TestHelper) ? =>
    let encoded = _WireProtocol.encode_heartbeat_ack()
    let obj = match json.JsonParser.parse(encoded)
      | let o: json.JsonObject => o
      else h.fail("expected JsonObject"); error
      end
    match obj("t")?
    | let t: String => h.assert_eq[String]("heartbeat_ack", t)
    else h.fail("'t' should be a string")
    end

class \nodoc\ _TestEncodePushEvent is UnitTest
  fun name(): String => "wire_protocol/encode_push_event"

  fun apply(h: TestHelper) ? =>
    let payload = json.JsonObject.update("key", "value")
    let encoded = _WireProtocol.encode_push_event("notify", payload)
    let obj = match json.JsonParser.parse(encoded)
      | let o: json.JsonObject => o
      else h.fail("expected JsonObject"); error
      end
    match obj("t")?
    | let t: String => h.assert_eq[String]("push", t)
    else h.fail("'t' should be a string")
    end
    match obj("e")?
    | let e: String => h.assert_eq[String]("notify", e)
    else h.fail("'e' should be a string")
    end

class \nodoc\ _TestEncodeError is UnitTest
  fun name(): String => "wire_protocol/encode_error"

  fun apply(h: TestHelper) ? =>
    let encoded = _WireProtocol.encode_error("render_failed")
    let obj = match json.JsonParser.parse(encoded)
      | let o: json.JsonObject => o
      else h.fail("expected JsonObject"); error
      end
    match obj("t")?
    | let t: String => h.assert_eq[String]("error", t)
    else h.fail("'t' should be a string")
    end
    match obj("reason")?
    | let r: String => h.assert_eq[String]("render_failed", r)
    else h.fail("'reason' should be a string")
    end

// --- Wire protocol decode tests ---

class \nodoc\ _TestDecodeEvent is UnitTest
  fun name(): String => "wire_protocol/decode_event"

  fun apply(h: TestHelper) =>
    let data = json.JsonObject
      .update("t", "event")
      .update("e", "increment")
      .update("p", json.JsonObject.update("value", "5"))
      .string()

    match _WireProtocol.decode_client_message(consume data)
    | let msg: _EventMessage =>
      h.assert_eq[String]("increment", msg.event)
      match msg.payload
      | let obj: json.JsonObject =>
        try
          match obj("value")?
          | let v: String => h.assert_eq[String]("5", v)
          else h.fail("payload 'value' should be a string")
          end
        else
          h.fail("payload missing 'value' key")
        end
      else
        h.fail("payload should be a JsonObject")
      end
    else
      h.fail("expected _EventMessage")
    end

class \nodoc\ _TestDecodeHeartbeat is UnitTest
  fun name(): String => "wire_protocol/decode_heartbeat"

  fun apply(h: TestHelper) =>
    let data = json.JsonObject
      .update("t", "heartbeat")
      .string()

    match _WireProtocol.decode_client_message(consume data)
    | _HeartbeatMessage => None
    else
      h.fail("expected _HeartbeatMessage")
    end

class \nodoc\ _TestDecodeInvalidJson is UnitTest
  fun name(): String => "wire_protocol/decode_invalid_json"

  fun apply(h: TestHelper) =>
    match _WireProtocol.decode_client_message("not json{{{")
    | let err: _WireError =>
      h.assert_true(err.reason.size() > 0)
    else
      h.fail("expected _WireError for invalid JSON")
    end

class \nodoc\ _TestDecodeMissingType is UnitTest
  fun name(): String => "wire_protocol/decode_missing_type"

  fun apply(h: TestHelper) =>
    let data = json.JsonObject
      .update("e", "increment")
      .string()

    match _WireProtocol.decode_client_message(consume data)
    | let err: _WireError =>
      h.assert_true(err.reason.contains("'t'"))
    else
      h.fail("expected _WireError for missing type field")
    end

class \nodoc\ _TestDecodeUnknownType is UnitTest
  fun name(): String => "wire_protocol/decode_unknown_type"

  fun apply(h: TestHelper) =>
    let data = json.JsonObject
      .update("t", "bogus")
      .string()

    match _WireProtocol.decode_client_message(consume data)
    | let err: _WireError =>
      h.assert_true(err.reason.contains("unknown"))
    else
      h.fail("expected _WireError for unknown type")
    end

// --- Router tests ---

class \nodoc\ _TestRouterExactMatch is UnitTest
  fun name(): String => "router/exact_match"

  fun apply(h: TestHelper) ? =>
    let router = Router
    router.route("/test", {(): LiveView ref^ => _DummyView} val)
    let routes = router.build()
    match routes("/test")
    | let f: Factory => f()?
    | None => h.fail("expected factory, got None"); error
    end

class \nodoc\ _TestRouterNoMatch is UnitTest
  fun name(): String => "router/no_match"

  fun apply(h: TestHelper) =>
    let router = Router
    router.route("/test", {(): LiveView ref^ => _DummyView} val)
    let routes = router.build()
    match routes("/other")
    | let _: Factory => h.fail("expected None, got factory")
    | None => None
    end

class \nodoc\ _TestRouterEmpty is UnitTest
  fun name(): String => "router/empty"

  fun apply(h: TestHelper) =>
    let router = Router
    let routes = router.build()
    match routes("/anything")
    | let _: Factory => h.fail("expected None from empty router")
    | None => None
    end

class \nodoc\ _TestRouterQueryStrip is UnitTest
  fun name(): String => "router/query_strip"

  fun apply(h: TestHelper) ? =>
    let router = Router
    router.route("/path", {(): LiveView ref^ => _DummyView} val)
    let routes = router.build()
    match routes("/path?foo=bar&baz=1")
    | let f: Factory => f()?
    | None => h.fail("expected factory after query strip"); error
    end

// --- Socket tests ---

class \nodoc\ _TestSocketPushEvent is UnitTest
  fun name(): String => "socket/push_event"

  fun apply(h: TestHelper) ? =>
    let assigns = Assigns
    let pending = Array[(String val, json.JsonValue)]
    let socket = Socket(assigns, pending)
    socket.push_event("test_event", "payload_value")

    h.assert_eq[USize](1, pending.size())
    (let event, _) = pending(0)?
    h.assert_eq[String val]("test_event", event)
