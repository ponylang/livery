## Fix connections going silent or truncating output under load

Several connection-reliability problems are fixed. A WebSocket connection could stop receiving client messages after the server pushed a large update; an HTTP connection could stop handling further requests after a large response; and a streamed HTTP response to a slow client could be truncated. In each case no error was raised — the connection simply went quiet or cut its output short, even while the peer was still active. Connections now keep delivering data reliably under these conditions.
