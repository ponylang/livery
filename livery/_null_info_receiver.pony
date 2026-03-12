actor _NullInfoReceiver is InfoReceiver
  """
  No-op InfoReceiver for disconnected sockets. Messages sent to this actor
  are silently discarded. Used by PageRenderer to satisfy Socket's
  InfoReceiver field without a real connection.
  """
  new create() => None
  be info(message: Any val) => None
