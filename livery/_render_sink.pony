use templates = "templates"

type _RenderDiff is (_FullRender | _SlotDiff | _NoChange)

class val _FullRender
  """
  First render or template change -- send statics + all dynamics.
  """
  let statics: Array[String] val
  let dynamics: Array[String] val

  new val create(statics': Array[String] val,
    dynamics': Array[String] val)
  =>
    statics = statics'
    dynamics = dynamics'

class val _SlotDiff
  """
  Only some dynamic slots changed -- send changed indices and values.
  """
  let changes: Array[(USize, String)] val

  new val create(changes': Array[(USize, String)] val) =>
    changes = changes'

primitive _NoChange
  """
  All dynamic slots match the previous render -- send nothing.
  """

class _RenderSink is templates.TemplateSink
  """
  Persistent per-connection sink that collects template output, caches
  statics, and computes incremental diffs between successive renders.

  Transaction lifecycle: begin() -> literal/dynamic_value calls -> result().
  On render failure: begin() -> abandon().
  On fallback to full-HTML: clear() discards all cached state.
  """
  // Cached state from previous render
  var _cached_statics: (Array[String] val | None) = None
  var _prev_dynamics: (Array[String] val | None) = None

  // Transient state for the current render
  var _temp_statics: Array[String] iso = recover iso Array[String] end
  var _temp_dynamics: Array[String] iso = recover iso Array[String] end
  var _temp_changes: Array[(USize, String)] iso =
    recover iso Array[(USize, String)] end
  var _dynamic_index: USize = 0
  var _statics_mismatch: Bool = false

  fun ref begin() =>
    """
    Start a new render transaction. Resets transient state while preserving
    cached statics and previous dynamics.
    """
    _temp_statics = recover iso Array[String] end
    _temp_dynamics = recover iso Array[String] end
    _temp_changes = recover iso Array[(USize, String)] end
    _dynamic_index = 0
    _statics_mismatch = false

  fun ref literal(text: String) =>
    """
    Receive a static template segment. On subsequent renders, verifies the
    segment matches the cached statics at the same position via content
    comparison.
    """
    match _cached_statics
    | let cached: Array[String] val =>
      try
        if cached(_temp_statics.size())? != text then
          _statics_mismatch = true
        end
      else
        // More statics than cached -- template changed
        _statics_mismatch = true
      end
    end
    _temp_statics.push(text)

  fun ref dynamic_value(value: String) =>
    """
    Receive a dynamic value. Simultaneously stores the value and compares
    against the previous dynamics at the same index, building the changes
    list inline.
    """
    let idx = _dynamic_index
    _dynamic_index = _dynamic_index + 1
    _temp_dynamics.push(value)

    match _prev_dynamics
    | let prev: Array[String] val =>
      try
        if prev(idx)? != value then
          _temp_changes.push((idx, value))
        end
      else
        // More dynamics than before -- new slot
        _temp_changes.push((idx, value))
      end
    else
      // First render -- all dynamics are "changes"
      _temp_changes.push((idx, value))
    end

  fun ref result(): _RenderDiff =>
    """
    Finalize the current render and return the diff.

    Destructively reads the transient arrays, converting them to val.
    Updates cached statics and previous dynamics.
    """
    let new_statics: Array[String] val =
      _temp_statics = recover iso Array[String] end
    let new_dynamics: Array[String] val =
      _temp_dynamics = recover iso Array[String] end
    let changes: Array[(USize, String)] val =
      _temp_changes = recover iso Array[(USize, String)] end

    // Check for statics mismatch (count or content)
    let statics_changed = _statics_mismatch
      or match _cached_statics
        | let cached: Array[String] val =>
          cached.size() != new_statics.size()
        | None => true
        end

    // Update cached state
    _cached_statics = new_statics
    _prev_dynamics = new_dynamics

    if statics_changed then
      _FullRender(new_statics, new_dynamics)
    elseif changes.size() == 0 then
      _NoChange
    else
      _SlotDiff(changes)
    end

  fun ref abandon() =>
    """
    Discard the current render's transient state without updating caches.
    Used when the view's render_parts() returns false.
    """
    _temp_statics = recover iso Array[String] end
    _temp_dynamics = recover iso Array[String] end
    _temp_changes = recover iso Array[(USize, String)] end
    _dynamic_index = 0
    _statics_mismatch = false

  fun ref clear() =>
    """
    Discard all state -- cached and transient. Used when a view falls back
    from split rendering to full-HTML rendering, so stale state doesn't
    persist across the transition.
    """
    _cached_statics = None
    _prev_dynamics = None
    abandon()

  fun full_html(): String val =>
    """
    Reconstruct the full HTML from the most recent render's statics and
    dynamics. Used by _Connection to update _last_html for error recovery.
    """
    match (_cached_statics, _prev_dynamics)
    | (let s: Array[String] val, let d: Array[String] val) =>
      var total: USize = 0
      for str in s.values() do total = total + str.size() end
      for str in d.values() do total = total + str.size() end
      recover val
        let out = String(total)
        var i: USize = 0
        try
          while i < d.size() do
            out.append(s(i)?)
            out.append(d(i)?)
            i = i + 1
          end
          out.append(s(i)?)
        else
          _Unreachable()
        end
        out
      end
    else
      ""
    end
