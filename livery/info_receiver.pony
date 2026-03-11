interface tag InfoReceiver
  """
  A handle for sending messages to a LiveView connection.

  External actors use this to deliver messages that arrive via
  `LiveView.handle_info`. Obtain a reference by calling `Socket.self()`
  inside a lifecycle method.
  """
  be info(message: Any val)
