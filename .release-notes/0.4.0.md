## Fix compilation against ponyc 0.65.0

livery now requires ponyc 0.65.0 or later. The previous minimum was 0.64.0.

ponyc 0.65.0 includes breaking changes to the standard library's json package that livery uses to encode and decode the WebSocket wire protocol. livery has been updated for the new json API; older ponyc versions will fail to compile livery.

## Fix connections going silent or truncating output under load

Several connection-reliability problems are fixed. A WebSocket connection could stop receiving client messages after the server pushed a large update; an HTTP connection could stop handling further requests after a large response; and a streamed HTTP response to a slow client could be truncated. In each case no error was raised — the connection simply went quiet or cut its output short, even while the peer was still active. Connections now keep delivering data reliably under these conditions.

