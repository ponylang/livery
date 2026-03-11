interface val Factory
  """
  Creates a new `LiveView` instance for an incoming connection.

  Partial because constructors may fail (e.g., template parsing). The
  connection actor closes the WebSocket with an error if the factory fails.

  Structural typing allows lambdas as factories:

  ```pony
  {(): LiveView ref^ ? => MyView?} val
  ```
  """
  fun apply(): LiveView ref^ ?
