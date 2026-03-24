## Update hobby dependency to 0.4.0

hobby 0.4.0 redesigned its handler model from synchronous `Handler val` to actor-per-request with `HandlerFactory` lambdas and `RequestHandler`. If you use hobby alongside livery for server-rendered first paint (as shown in the SSR example), you'll need to migrate your handlers.

Before (hobby 0.3.x):

```pony
class val IndexHandler is hobby.Handler
  fun apply(ctx: hobby.Context ref) =>
    // build response
    ctx.respond(stallion.StatusOK, body)

// ...

hobby.Application
  .>get("/", IndexHandler(factory))
```

After (hobby 0.4.0):

```pony
hobby.Application
  .>get("/", {(ctx)(factory) =>
    let handler = hobby.RequestHandler(consume ctx)
    // build response
    handler.respond(stallion.StatusOK, body)
  } val)
```

See the updated `examples/ssr/` for a complete working example.
