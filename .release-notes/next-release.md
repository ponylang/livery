## Fix compilation against ponyc 0.65.0

livery now requires ponyc 0.65.0 or later. The previous minimum was 0.64.0.

ponyc 0.65.0 includes breaking changes to the standard library's json package that livery uses to encode and decode the WebSocket wire protocol. livery has been updated for the new json API; older ponyc versions will fail to compile livery.

