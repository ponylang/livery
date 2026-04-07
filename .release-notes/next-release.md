## Fix connection stall after large message with backpressure

WebSocket connections could stop processing incoming data after completing a large write that triggered backpressure, causing the connection to appear frozen.

