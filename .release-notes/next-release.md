## Fix crash when a WebSocket connection is disposed before initialization completes

Calling `dispose()` on a WebSocket connection before its initialization completed could crash. The race was unlikely but was observed on macOS arm64.

