## Fix connections losing data when closed under backpressure

A connection could lose queued messages when the peer disconnected while write backpressure was applied. Data queued for delivery was discarded instead of being flushed before the connection closed.

## Fix connections hanging on close during message handling

Closing a connection while handling an incoming message could leave a stray read on the socket, blocking a scheduler thread. On a single-threaded runtime this hangs the program; on a multi-threaded runtime it loses one scheduler thread permanently.

## Fix connections stalling under sustained write load

A connection could stop making progress when the send buffer filled and the OS reused the file descriptor. Most likely on multi-threaded runtimes.

## Fix SSL/TLS connection bugs

Several SSL/TLS bugs could cause connection failures: handshake failures were misreported as authentication failures, large writes could silently drop data on encryption failure, and one connection's SSL error could close a different connection.

## Fix a macOS bug where connecting could close an unrelated connection

On macOS, setting up a new connection could close a file descriptor belonging to an unrelated connection, causing that connection to fail.

## Fix missing TLS close_notify on connection close

Closing a TLS-encrypted connection now sends `close_notify` before TCP shutdown. Without it, the peer could not distinguish a clean close from a truncated stream.

## Require ponyc 0.67.0 or later

The minimum ponyc version is now 0.67.0, up from 0.65.0 on non-Windows and 0.66.0 on Windows.
