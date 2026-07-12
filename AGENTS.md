# Livery

A server-side Pony library for building interactive LiveView UIs over WebSocket. It renders in one of two modes: full HTML on each state change (the default), or split rendering that sends the static template parts once and then only the changed dynamic values. The JavaScript client (in `client/`) patches the DOM with morphdom.

<!-- contributor-only -->
## Contributing with an AI assistant

This is a Pony project. The ponylang org maintains a set of LLM coding skills. Get set up with them before contributing:

- **Not set up yet?** Install them once:

  ```bash
  git clone https://github.com/ponylang/llm-skills.git
  cd llm-skills
  python install.py
  ```

- **Already set up?** Make sure you're on the latest. If you installed with the script above, `git pull` in the directory where you cloned `llm-skills` and the symlinked skills update automatically — if you set them up another way, refresh them however that setup expects.

See the [llm-skills README](https://github.com/ponylang/llm-skills) for details and other harnesses.

When you start working on this project, load the `pony-skills` skill — it tells your assistant which Pony skill to use for each task.

Read [CONTRIBUTING.md](CONTRIBUTING.md).
<!-- /contributor-only -->

## Building and testing

```
make test ssl=openssl_3.0.x                # build + run tests + build examples (test is default)
make unit-tests ssl=openssl_3.0.x          # tests only
make test-one t=TestName ssl=openssl_3.0.x # run a single test by name
make examples ssl=openssl_3.0.x            # examples only
make clean
make client-test                           # JS client tests (Docker, no local Node needed)
make client-build                          # JS client bundles (Docker)
```

`ssl=` is required because mare (the WebSocket transport) pulls in `ssl`; on OpenSSL 3.x use `ssl=openssl_3.0.x`. The JS client can also be built directly: `cd client && npm install && npm test`, then `npm run build`.

## Wire protocol

The server and the JS client talk JSON over WebSocket. `client/src/wire.js` mirrors `_wire_protocol.pony` — a change to the wire format has to land in both.

## Conventions

- Prefer qualified imports in library code: `use json = "json"`, `use mare = "mare"`, and so on.
- Add new tests to the single runner `livery/_test.pony`; don't create a second `TestList`.
- `\nodoc\` on all test types.
