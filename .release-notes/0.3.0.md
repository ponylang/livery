## Require ponyc 0.64.0 or later

livery now requires ponyc 0.64.0 or later. The previous minimum was 0.63.1.

This is driven by updates to mare 0.4.0 and hobby 0.8.0, which transitively require ponyc 0.64.0 via lori 0.15.0 for changes to FFI declaration syntax and the runtime socket API. Older ponyc versions will fail to compile livery.

