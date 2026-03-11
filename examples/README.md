# Examples

Each subdirectory is a self-contained Pony program demonstrating a different part of the livery library.

## [counter](counter/)

Implements a simple increment/decrement counter as a `LiveView`. Registers a single route, parses a template with `HtmlTemplate`, and updates an integer assign in response to `"increment"` and `"decrement"` click events. Demonstrates the core lifecycle: `mount`, `handle_event`, and `render` with the `Router`/`Listener` setup. Start here if you're new to the library.
