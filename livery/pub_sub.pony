use collections = "collections"

actor PubSub
  """
  Topic-based publish-subscribe for delivering messages to LiveView
  connections.

  Create a PubSub instance and pass it to `Listener`. LiveViews subscribe
  via `Socket.subscribe(topic)`. External actors publish via
  `pub_sub.publish(topic, message)`, which delivers to all current
  subscribers via `InfoReceiver.info`.
  """
  let _topics: collections.Map[String, collections.SetIs[InfoReceiver tag]]

  new create() =>
    _topics = collections.Map[String, collections.SetIs[InfoReceiver tag]]

  be subscribe(topic: String, subscriber: InfoReceiver tag) =>
    """
    Add a subscriber to a topic. Idempotent — subscribing the same
    connection to the same topic twice has no additional effect.
    """
    let subs = try
      _topics(topic)?
    else
      let s = collections.SetIs[InfoReceiver tag]
      _topics(topic) = s
      s
    end
    subs.set(subscriber)

  be unsubscribe(topic: String, subscriber: InfoReceiver tag) =>
    """
    Remove a subscriber from a topic.
    """
    try _topics(topic)?.unset(subscriber) end

  be unsubscribe_all(subscriber: InfoReceiver tag) =>
    """
    Remove a subscriber from all topics. Called automatically by the
    connection actor when a WebSocket closes.
    """
    for subs in _topics.values() do
      subs.unset(subscriber)
    end

  be publish(topic: String, message: Any val) =>
    """
    Send a message to all subscribers of a topic.
    """
    try
      for subscriber in _topics(topic)?.values() do
        subscriber.info(message)
      end
    end
