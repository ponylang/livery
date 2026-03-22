## Fix WebSocket connections hanging on shutdown when client disconnects

On POSIX systems, there was a narrow timing window where a client disconnecting could leave the server-side connection stuck in a half-closed state, preventing the Pony runtime from exiting. A livery server that lost a client connection at an unlucky moment would hang indefinitely on shutdown. Disposal now performs an unconditional hard close, preventing the hang.

## Fix idle timeout firing prematurely on TLS WebSocket connections

When using TLS-secured WebSocket connections with an idle timeout configured, the timeout could fire during the TLS handshake before the connection was fully established. Additionally, configuring an idle timeout during the handshake could leak an internal timer resource. Plain (non-TLS) connections were not affected.
