use "pony_test"
use "pony_check"
use templates = "templates"
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
    // PubSub tests
    test(_TestPubSubDeliver)
    test(_TestPubSubNoSubscribers)
    test(_TestPubSubUnsubscribe)
    test(_TestPubSubUnsubscribeAll)
    test(_TestPubSubMultipleSubscribers)
    // Socket connected tests
    test(_TestSocketConnectedTrue)
    test(_TestSocketConnectedFalse)
    test(_TestSocketDisconnectedSubscribeNoop)
    // PageRenderer tests
    test(_TestPageRendererSuccess)
    test(_TestPageRendererFactoryFailed)
    test(_TestPageRendererRenderFailed)
    test(_TestPageRendererDisconnectedSocket)
    test(_TestPageRendererWithComponents)
    // Socket + PubSub integration tests
    test(_TestSocketSubscribeDeliver)
    // ComponentSocket tests
    test(_TestComponentSocketAssignRoundtrip)
    test(_TestComponentSocketPushEvent)
    // Component registry tests
    test(_TestRegistryRegisterAndLookup)
    test(_TestRegistryMaxComponents)
    test(_TestRegistryUnregister)
    test(_TestRegistryDuplicateIdReplace)
    test(_TestRegistryDuplicateIdAtCapacity)
    test(_TestRegistryRegisterAfterUnregister)
    // Component event routing tests
    test(_TestRegistryHandleEventFound)
    test(_TestRegistryHandleEventNotFound)
    // Component rendering tests
    test(_TestRegistryRenderChanged)
    test(_TestRegistryRenderUnchangedCached)
    test(_TestRegistryRenderFailure)
    test(_TestRegistryPopulateComponentHtml)
    // Wire protocol component target tests
    test(_TestDecodeEventWithTarget)
    test(_TestDecodeEventWithoutTarget)
    test(_TestDecodeEventNonStringTarget)
    // Assigns component HTML tests
    test(_TestAssignsComponentHtml)
    test(_TestAssignsComponentHtmlUnknown)
    test(_TestAssignsClearComponentHtml)
    test(_TestAssignsComponentHtmlSeparateNamespace)
    test(_TestAssignsRenderValues)
    // Security tests
    test(_TestRegistryEmptyStringTarget)
    test(_TestRegistryLongTarget)
    test(_TestComponentIsolation)

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

actor \nodoc\ _TestInfoReceiver is InfoReceiver
  """
  Test helper that completes the test on first message received.
  """
  let _h: TestHelper

  new create(h: TestHelper) =>
    _h = h

  be info(message: Any val) =>
    _h.complete(true)

actor \nodoc\ _SentinelInfoReceiver is InfoReceiver
  """
  Test helper for negative tests. When it receives a message, it checks
  that the guarded receiver was NOT called, then completes the test.
  """
  let _h: TestHelper
  let _guarded: _GuardedInfoReceiver tag

  new create(h: TestHelper, guarded: _GuardedInfoReceiver tag) =>
    _h = h
    _guarded = guarded

  be info(message: Any val) =>
    _guarded.check_not_called(_h)

actor \nodoc\ _GuardedInfoReceiver is InfoReceiver
  """
  Test helper that tracks whether info was called. Used with
  _SentinelInfoReceiver for negative delivery tests.
  """
  var _called: Bool = false

  new create() => None

  be info(message: Any val) =>
    _called = true

  be check_not_called(h: TestHelper) =>
    h.assert_false(_called, "guarded receiver should not have been called")
    h.complete(true)

actor \nodoc\ _DummyInfoReceiver is InfoReceiver
  """
  No-op receiver for tests that need a placeholder InfoReceiver.
  """
  new create() => None
  be info(message: Any val) => None

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
    let components = _ComponentRegistry(pending)
    let socket = Socket(assigns, pending, _DummyInfoReceiver, PubSub,
      components)
    socket.push_event("test_event", "payload_value")

    h.assert_eq[USize](1, pending.size())
    (let event, _) = pending(0)?
    h.assert_eq[String val]("test_event", event)

// --- PubSub tests ---

class \nodoc\ _TestPubSubDeliver is UnitTest
  fun name(): String => "pub_sub/deliver"

  fun apply(h: TestHelper) =>
    h.long_test(2_000_000_000)
    let receiver = _TestInfoReceiver(h)
    let pub_sub = PubSub
    pub_sub.subscribe("topic", receiver)
    pub_sub.publish("topic", "hello")

class \nodoc\ _TestPubSubNoSubscribers is UnitTest
  fun name(): String => "pub_sub/no_subscribers"

  fun apply(h: TestHelper) =>
    h.long_test(2_000_000_000)
    let pub_sub = PubSub
    // Publishing to an empty topic should not crash
    pub_sub.publish("empty_topic", "hello")
    // Use a sentinel to prove the publish was processed
    let receiver = _TestInfoReceiver(h)
    pub_sub.subscribe("proof", receiver)
    pub_sub.publish("proof", "done")

class \nodoc\ _TestPubSubUnsubscribe is UnitTest
  fun name(): String => "pub_sub/unsubscribe"

  fun apply(h: TestHelper) =>
    h.long_test(2_000_000_000)
    let guarded = _GuardedInfoReceiver
    let sentinel = _SentinelInfoReceiver(h, guarded)
    let pub_sub = PubSub
    pub_sub.subscribe("topic", guarded)
    pub_sub.subscribe("topic", sentinel)
    pub_sub.unsubscribe("topic", guarded)
    pub_sub.publish("topic", "after_unsub")

class \nodoc\ _TestPubSubUnsubscribeAll is UnitTest
  fun name(): String => "pub_sub/unsubscribe_all"

  fun apply(h: TestHelper) =>
    h.long_test(2_000_000_000)
    let guarded = _GuardedInfoReceiver
    let sentinel = _SentinelInfoReceiver(h, guarded)
    let pub_sub = PubSub
    pub_sub.subscribe("topic_a", guarded)
    pub_sub.subscribe("topic_b", guarded)
    pub_sub.subscribe("topic_a", sentinel)
    pub_sub.unsubscribe_all(guarded)
    pub_sub.publish("topic_a", "after_unsub_all")

class \nodoc\ _TestPubSubMultipleSubscribers is UnitTest
  fun name(): String => "pub_sub/multiple_subscribers"

  fun apply(h: TestHelper) =>
    h.long_test(2_000_000_000)
    let pub_sub = PubSub
    let counter = _CountingInfoReceiver(h, 3)
    // Subscribe three separate receivers; all should fire
    let r1 = _ForwardingInfoReceiver(counter)
    let r2 = _ForwardingInfoReceiver(counter)
    let r3 = _ForwardingInfoReceiver(counter)
    pub_sub.subscribe("topic", r1)
    pub_sub.subscribe("topic", r2)
    pub_sub.subscribe("topic", r3)
    pub_sub.publish("topic", "broadcast")

actor \nodoc\ _CountingInfoReceiver
  """
  Completes the test after receiving an expected number of forwarded
  messages.
  """
  let _h: TestHelper
  let _expected: USize
  var _count: USize = 0

  new create(h: TestHelper, expected: USize) =>
    _h = h
    _expected = expected

  be received() =>
    _count = _count + 1
    if _count == _expected then
      _h.complete(true)
    end

actor \nodoc\ _ForwardingInfoReceiver is InfoReceiver
  """
  Forwards each info message to a CountingInfoReceiver.
  """
  let _counter: _CountingInfoReceiver tag

  new create(counter: _CountingInfoReceiver tag) =>
    _counter = counter

  be info(message: Any val) =>
    _counter.received()

// --- Socket connected tests ---

class \nodoc\ _TestSocketConnectedTrue is UnitTest
  fun name(): String => "socket/connected_true"

  fun apply(h: TestHelper) =>
    let assigns = Assigns
    let pending = Array[(String val, json.JsonValue)]
    let components = _ComponentRegistry(pending)
    let socket = Socket(assigns, pending, _DummyInfoReceiver, PubSub,
      components)
    h.assert_true(socket.connected(),
      "socket created via create should be connected")

class \nodoc\ _TestSocketConnectedFalse is UnitTest
  fun name(): String => "socket/connected_false"

  fun apply(h: TestHelper) =>
    let assigns = Assigns
    let pending = Array[(String val, json.JsonValue)]
    let socket = Socket._for_render(assigns, pending)
    h.assert_false(socket.connected(),
      "socket created via _for_render should not be connected")

class \nodoc\ _TestSocketDisconnectedSubscribeNoop is UnitTest
  fun name(): String => "socket/disconnected_subscribe_noop"

  fun apply(h: TestHelper) =>
    let assigns = Assigns
    let pending = Array[(String val, json.JsonValue)]
    let socket = Socket._for_render(assigns, pending)
    // These should not crash — they no-op when PubSub is None
    socket.subscribe("topic")
    socket.unsubscribe("topic")

// --- PageRenderer tests ---

class \nodoc\ _RenderTestView is LiveView
  new create() => None
  fun ref mount(socket: Socket ref) =>
    socket.assign("greeting", "hello")

  fun ref handle_event(event: String val, payload: json.JsonValue,
    socket: Socket ref)
  =>
    None

  fun box render(assigns: Assigns box): String =>
    try
      assigns("greeting")?.string()?
    else
      ""
    end

class \nodoc\ _FailRenderView is LiveView
  new create() => None
  fun ref mount(socket: Socket ref) => None

  fun ref handle_event(event: String val, payload: json.JsonValue,
    socket: Socket ref)
  =>
    None

  fun box render(assigns: Assigns box): String ? =>
    error

class \nodoc\ _TestPageRendererSuccess is UnitTest
  fun name(): String => "page_renderer/success"

  fun apply(h: TestHelper) =>
    let factory: Factory =
      {(): LiveView ref^ => _RenderTestView} val
    match PageRenderer.render(factory)
    | let html: String val =>
      h.assert_eq[String]("hello", html)
    | let err: PageRenderError =>
      h.fail("expected success, got error")
    end

class \nodoc\ _TestPageRendererFactoryFailed is UnitTest
  fun name(): String => "page_renderer/factory_failed"

  fun apply(h: TestHelper) =>
    let factory: Factory =
      {(): LiveView ref^ ? => error} val
    match PageRenderer.render(factory)
    | let _: String val =>
      h.fail("expected PageRenderFactoryFailed, got HTML")
    | let _: PageRenderFactoryFailed => None
    | let _: PageRenderFailed =>
      h.fail("expected PageRenderFactoryFailed, got PageRenderFailed")
    end

class \nodoc\ _TestPageRendererRenderFailed is UnitTest
  fun name(): String => "page_renderer/render_failed"

  fun apply(h: TestHelper) =>
    let factory: Factory =
      {(): LiveView ref^ => _FailRenderView} val
    match PageRenderer.render(factory)
    | let _: String val =>
      h.fail("expected PageRenderFailed, got HTML")
    | let _: PageRenderFactoryFailed =>
      h.fail("expected PageRenderFailed, got PageRenderFactoryFailed")
    | let _: PageRenderFailed => None
    end

class \nodoc\ _ConnectedBranchView is LiveView
  new create() => None

  fun ref mount(socket: Socket ref) =>
    if socket.connected() then
      socket.assign("mode", "live")
    else
      socket.assign("mode", "static")
    end

  fun ref handle_event(event: String val, payload: json.JsonValue,
    socket: Socket ref)
  =>
    None

  fun box render(assigns: Assigns box): String =>
    try
      assigns("mode")?.string()?
    else
      ""
    end

class \nodoc\ _TestPageRendererDisconnectedSocket is UnitTest
  fun name(): String => "page_renderer/disconnected_socket"

  fun apply(h: TestHelper) =>
    let factory: Factory =
      {(): LiveView ref^ => _ConnectedBranchView} val
    match PageRenderer.render(factory)
    | let html: String val =>
      h.assert_eq[String]("static", html)
    | let err: PageRenderError =>
      h.fail("expected success, got error")
    end

class \nodoc\ _ComponentView is LiveView
  """
  View that registers a component during mount and renders its HTML.
  """
  new create() => None

  fun ref mount(socket: Socket ref) =>
    let comp = _TestComponent
    if socket.register_component("c1", comp) then
      socket.update_component("c1",
        recover val
          let d = Array[(String, (String | templates.TemplateValue))]
          d.push(("greeting", "from_component"))
          d
        end)
    end

  fun ref handle_event(event: String val, payload: json.JsonValue,
    socket: Socket ref)
  =>
    None

  fun box render(assigns: Assigns box): String ? =>
    assigns.component_html("c1")?

class \nodoc\ _TestPageRendererWithComponents is UnitTest
  fun name(): String => "page_renderer/with_components"

  fun apply(h: TestHelper) =>
    let factory: Factory =
      {(): LiveView ref^ => _ComponentView} val
    match PageRenderer.render(factory)
    | let html: String val =>
      h.assert_eq[String]("from_component", html)
    | let err: PageRenderError =>
      h.fail("expected success, got error")
    end

// --- Socket + PubSub integration tests ---

class \nodoc\ _TestSocketSubscribeDeliver is UnitTest
  fun name(): String => "socket/subscribe_deliver"

  fun apply(h: TestHelper) =>
    h.long_test(2_000_000_000)
    let assigns = Assigns
    let pending = Array[(String val, json.JsonValue)]
    let receiver = _TestInfoReceiver(h)
    let pub_sub = PubSub
    let components = _ComponentRegistry(pending)
    let socket = Socket(assigns, pending, receiver, pub_sub, components)
    socket.subscribe("test_topic")
    pub_sub.publish("test_topic", "hello")

// --- Component test helpers ---

class \nodoc\ _TestComponent is LiveComponent
  """
  Minimal test component that renders a greeting from its assigns.
  """
  var mount_called: Bool = false

  new create() => None

  fun ref mount(socket: ComponentSocket ref) =>
    mount_called = true

  fun ref handle_event(event: String val, payload: json.JsonValue,
    socket: ComponentSocket ref)
  =>
    match event
    | "set_value" =>
      try
        let nav = json.JsonNav(payload)
        let v = nav("v").as_string()?
        socket.assign("value", v)
      end
    end

  fun box render(assigns: Assigns box): String =>
    try
      assigns("greeting")?.string()?
    else
      ""
    end

class \nodoc\ _FailingComponent is LiveComponent
  """
  Component whose render always fails.
  """
  new create() => None

  fun ref mount(socket: ComponentSocket ref) => None

  fun ref handle_event(event: String val, payload: json.JsonValue,
    socket: ComponentSocket ref)
  =>
    None

  fun box render(assigns: Assigns box): String ? =>
    error

// --- ComponentSocket tests ---

class \nodoc\ _TestComponentSocketAssignRoundtrip is UnitTest
  fun name(): String => "component_socket/assign_roundtrip"

  fun apply(h: TestHelper) ? =>
    let assigns = Assigns
    let pending = Array[(String val, json.JsonValue)]
    let socket = ComponentSocket(assigns, pending)
    socket.assign("key", "value")
    let retrieved = socket.get_assign("key")?.string()?
    h.assert_eq[String]("value", retrieved)

class \nodoc\ _TestComponentSocketPushEvent is UnitTest
  fun name(): String => "component_socket/push_event"

  fun apply(h: TestHelper) ? =>
    let assigns = Assigns
    let pending = Array[(String val, json.JsonValue)]
    let socket = ComponentSocket(assigns, pending)
    socket.push_event("notify", "data")

    h.assert_eq[USize](1, pending.size())
    (let event, _) = pending(0)?
    h.assert_eq[String val]("notify", event)

// --- Component registry tests ---

class \nodoc\ _TestRegistryRegisterAndLookup is UnitTest
  fun name(): String => "registry/register_and_lookup"

  fun apply(h: TestHelper) =>
    let pending = Array[(String val, json.JsonValue)]
    let registry = _ComponentRegistry(pending)
    let component = _TestComponent
    component.mount_called = false
    h.assert_true(registry.register("c1", component))
    h.assert_true(registry.has("c1"))
    h.assert_eq[USize](1, registry.size())
    h.assert_true(component.mount_called,
      "mount should be called during registration")

class \nodoc\ _TestRegistryMaxComponents is UnitTest
  fun name(): String => "registry/max_components"

  fun apply(h: TestHelper) =>
    let pending = Array[(String val, json.JsonValue)]
    let registry = _ComponentRegistry(pending where max_components = 2)
    h.assert_true(registry.register("c1", _TestComponent))
    h.assert_true(registry.register("c2", _TestComponent))
    h.assert_false(registry.register("c3", _TestComponent),
      "should reject registration at capacity")
    h.assert_eq[USize](2, registry.size())

class \nodoc\ _TestRegistryUnregister is UnitTest
  fun name(): String => "registry/unregister"

  fun apply(h: TestHelper) =>
    let pending = Array[(String val, json.JsonValue)]
    let registry = _ComponentRegistry(pending)
    registry.register("c1", _TestComponent)
    registry.unregister("c1")
    h.assert_false(registry.has("c1"))
    h.assert_eq[USize](0, registry.size())

class \nodoc\ _TestRegistryDuplicateIdReplace is UnitTest
  fun name(): String => "registry/duplicate_id_replace"

  fun apply(h: TestHelper) ? =>
    let pending = Array[(String val, json.JsonValue)]
    let registry = _ComponentRegistry(pending)
    let c1 = _TestComponent
    let c2 = _TestComponent
    registry.register("same", c1)
    registry.register("same", c2)
    h.assert_eq[USize](1, registry.size())
    // The new component should be active — verify by checking its render
    // output (c2's assigns are fresh, so render returns "")
    let html = registry.component_html("same")?
    h.assert_eq[String]("", html)

class \nodoc\ _TestRegistryDuplicateIdAtCapacity is UnitTest
  fun name(): String => "registry/duplicate_id_at_capacity"

  fun apply(h: TestHelper) =>
    let pending = Array[(String val, json.JsonValue)]
    let registry = _ComponentRegistry(pending where max_components = 1)
    registry.register("c1", _TestComponent)
    // Re-registering existing ID at capacity should succeed (replacement)
    h.assert_true(registry.register("c1", _TestComponent),
      "replacing existing ID at capacity should succeed")
    h.assert_eq[USize](1, registry.size())

class \nodoc\ _TestRegistryRegisterAfterUnregister is UnitTest
  fun name(): String => "registry/register_after_unregister"

  fun apply(h: TestHelper) =>
    let pending = Array[(String val, json.JsonValue)]
    let registry = _ComponentRegistry(pending where max_components = 1)
    registry.register("c1", _TestComponent)
    registry.unregister("c1")
    h.assert_true(registry.register("c2", _TestComponent),
      "slot should be freed after unregister")

// --- Component event routing tests ---

class \nodoc\ _TestRegistryHandleEventFound is UnitTest
  fun name(): String => "registry/handle_event_found"

  fun apply(h: TestHelper) =>
    let pending = Array[(String val, json.JsonValue)]
    let registry = _ComponentRegistry(pending)
    registry.register("c1", _TestComponent)
    let payload = json.JsonObject.update("v", "updated")
    h.assert_true(registry.handle_event("c1", "set_value", payload))

class \nodoc\ _TestRegistryHandleEventNotFound is UnitTest
  fun name(): String => "registry/handle_event_not_found"

  fun apply(h: TestHelper) =>
    let pending = Array[(String val, json.JsonValue)]
    let registry = _ComponentRegistry(pending)
    h.assert_false(registry.handle_event("nonexistent", "click", None))

// --- Component rendering tests ---

class \nodoc\ _TestRegistryRenderChanged is UnitTest
  fun name(): String => "registry/render_changed"

  fun apply(h: TestHelper) ? =>
    let pending = Array[(String val, json.JsonValue)]
    let registry = _ComponentRegistry(pending)
    let component = _TestComponent
    registry.register("c1", component)

    // Update assigns to trigger change
    let data: Array[(String, (String | templates.TemplateValue))] val =
      recover val
        let d = Array[(String, (String | templates.TemplateValue))]
        d.push(("greeting", "hello"))
        d
      end
    registry.update("c1", data)

    let changed = registry.render_all()
    h.assert_true(changed, "render_all should report changes")
    let html = registry.component_html("c1")?
    h.assert_eq[String]("hello", html)

class \nodoc\ _TestRegistryRenderUnchangedCached is UnitTest
  fun name(): String => "registry/render_unchanged_cached"

  fun apply(h: TestHelper) ? =>
    let pending = Array[(String val, json.JsonValue)]
    let registry = _ComponentRegistry(pending)
    registry.register("c1", _TestComponent)

    // Set greeting and render
    let data: Array[(String, (String | templates.TemplateValue))] val =
      recover val
        let d = Array[(String, (String | templates.TemplateValue))]
        d.push(("greeting", "cached"))
        d
      end
    registry.update("c1", data)
    registry.render_all()

    // Second render_all with no changes should return false
    let changed = registry.render_all()
    h.assert_false(changed, "render_all should report no changes")
    // Cached HTML should still be there
    let html = registry.component_html("c1")?
    h.assert_eq[String]("cached", html)

class \nodoc\ _TestRegistryRenderFailure is UnitTest
  fun name(): String => "registry/render_failure"

  fun apply(h: TestHelper) =>
    let pending = Array[(String val, json.JsonValue)]
    let registry = _ComponentRegistry(pending)
    registry.register("fail", _FailingComponent)
    let errors = registry.flush_render_errors()
    h.assert_eq[USize](1, errors.size(),
      "initial render failure should produce an error")
    try
      h.assert_true(errors(0)?.contains("fail"))
    end

class \nodoc\ _TestRegistryPopulateComponentHtml is UnitTest
  fun name(): String => "registry/populate_component_html"

  fun apply(h: TestHelper) ? =>
    let pending = Array[(String val, json.JsonValue)]
    let registry = _ComponentRegistry(pending)
    registry.register("c1", _TestComponent)

    let data: Array[(String, (String | templates.TemplateValue))] val =
      recover val
        let d = Array[(String, (String | templates.TemplateValue))]
        d.push(("greeting", "world"))
        d
      end
    registry.update("c1", data)
    registry.render_all()

    let assigns = Assigns
    registry.populate_component_html(assigns)
    let html = assigns.component_html("c1")?
    h.assert_eq[String]("world", html)

// --- Wire protocol component target tests ---

class \nodoc\ _TestDecodeEventWithTarget is UnitTest
  fun name(): String => "wire_protocol/decode_event_with_target"

  fun apply(h: TestHelper) =>
    let data = json.JsonObject
      .update("t", "event")
      .update("e", "toggle")
      .update("p", json.JsonObject.update("id", "3"))
      .update("c", "todo-3")
      .string()

    match _WireProtocol.decode_client_message(consume data)
    | let msg: _EventMessage =>
      h.assert_eq[String]("toggle", msg.event)
      match msg.target
      | let t: String => h.assert_eq[String]("todo-3", t)
      | None => h.fail("expected target, got None")
      end
    else
      h.fail("expected _EventMessage")
    end

class \nodoc\ _TestDecodeEventWithoutTarget is UnitTest
  fun name(): String => "wire_protocol/decode_event_without_target"

  fun apply(h: TestHelper) =>
    let data = json.JsonObject
      .update("t", "event")
      .update("e", "click")
      .update("p", None)
      .string()

    match _WireProtocol.decode_client_message(consume data)
    | let msg: _EventMessage =>
      h.assert_eq[String]("click", msg.event)
      match msg.target
      | let _: String => h.fail("expected None target")
      | None => None
      end
    else
      h.fail("expected _EventMessage")
    end

class \nodoc\ _TestDecodeEventNonStringTarget is UnitTest
  fun name(): String => "wire_protocol/decode_event_non_string_target"

  fun apply(h: TestHelper) =>
    let data = json.JsonObject
      .update("t", "event")
      .update("e", "click")
      .update("p", None)
      .update("c", I64(42))
      .string()

    match _WireProtocol.decode_client_message(consume data)
    | let err: _WireError =>
      h.assert_true(err.reason.contains("'c'"),
        "error should mention 'c' field")
    else
      h.fail("expected _WireError for non-string 'c'")
    end

// --- Assigns component HTML tests ---

class \nodoc\ _TestAssignsComponentHtml is UnitTest
  fun name(): String => "assigns/component_html"

  fun apply(h: TestHelper) ? =>
    let assigns = Assigns
    assigns._set_component_html("c1", "<li>item</li>")
    let html = assigns.component_html("c1")?
    h.assert_eq[String]("<li>item</li>", html)

class \nodoc\ _TestAssignsComponentHtmlUnknown is UnitTest
  fun name(): String => "assigns/component_html_unknown"

  fun apply(h: TestHelper) =>
    let assigns = Assigns
    let found = try
        assigns.component_html("nonexistent")?
        true
      else
        false
      end
    h.assert_false(found, "should error for unknown component ID")

class \nodoc\ _TestAssignsClearComponentHtml is UnitTest
  fun name(): String => "assigns/clear_component_html"

  fun apply(h: TestHelper) =>
    let assigns = Assigns
    assigns._set_component_html("c1", "<li>item</li>")
    assigns._clear_component_html()
    let found = try
        assigns.component_html("c1")?
        true
      else
        false
      end
    h.assert_false(found, "should be empty after clear")

class \nodoc\ _TestAssignsComponentHtmlSeparateNamespace is UnitTest
  fun name(): String => "assigns/component_html_separate_namespace"

  fun apply(h: TestHelper) ? =>
    let assigns = Assigns
    assigns.update("c1", "user_value")
    assigns._set_component_html("c1", "<div>component</div>")
    // User assign and component HTML should not collide
    let user_val = assigns("c1")?.string()?
    let comp_html = assigns.component_html("c1")?
    h.assert_eq[String]("user_value", user_val)
    h.assert_eq[String]("<div>component</div>", comp_html)

class \nodoc\ _TestAssignsRenderValues is UnitTest
  fun name(): String => "assigns/render_values"

  fun apply(h: TestHelper) ? =>
    let assigns = Assigns
    assigns.update("greeting", "hello")
    let child = assigns.render_values()
    // Child can read parent values
    let parent_val = child("greeting")?.string()?
    h.assert_eq[String]("hello", parent_val)
    // Child can write new values without affecting parent
    child("extra") = "world"
    let child_val = child("extra")?.string()?
    h.assert_eq[String]("world", child_val)

// --- Security tests ---

class \nodoc\ _TestRegistryEmptyStringTarget is UnitTest
  fun name(): String => "registry/empty_string_target"

  fun apply(h: TestHelper) =>
    let pending = Array[(String val, json.JsonValue)]
    let registry = _ComponentRegistry(pending)
    h.assert_false(registry.handle_event("", "click", None),
      "empty string target should fail when no component registered with " +
      "that ID")

class \nodoc\ _TestRegistryLongTarget is UnitTest
  fun name(): String => "registry/long_target"

  fun apply(h: TestHelper) =>
    let pending = Array[(String val, json.JsonValue)]
    let registry = _ComponentRegistry(pending)
    let long_id = recover val
      String(10000).>append("a" * 10000)
    end
    h.assert_false(registry.handle_event(long_id, "click", None),
      "very long target should fail without crashing")

class \nodoc\ _TestComponentIsolation is UnitTest
  fun name(): String => "registry/component_isolation"

  fun apply(h: TestHelper) ? =>
    let pending = Array[(String val, json.JsonValue)]
    let registry = _ComponentRegistry(pending)
    registry.register("a", _TestComponent)
    registry.register("b", _TestComponent)

    let data_a: Array[(String, (String | templates.TemplateValue))] val =
      recover val
        let d = Array[(String, (String | templates.TemplateValue))]
        d.push(("greeting", "alpha"))
        d
      end
    registry.update("a", data_a)

    let data_b: Array[(String, (String | templates.TemplateValue))] val =
      recover val
        let d = Array[(String, (String | templates.TemplateValue))]
        d.push(("greeting", "beta"))
        d
      end
    registry.update("b", data_b)

    registry.render_all()
    h.assert_eq[String]("alpha", registry.component_html("a")?)
    h.assert_eq[String]("beta", registry.component_html("b")?)
