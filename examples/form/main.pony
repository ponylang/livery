use "templates"
use "json"
use lori = "lori"
use "../../livery"

class FormView is LiveView
  """
  A LiveView that demonstrates form handling with live validation.

  Uses `lv-change` for real-time field validation as the user types and
  `lv-submit` for full form validation on submit. Field values and error
  messages are stored as assigns and rendered via the template.
  """
  let _template: HtmlTemplate val

  new create() ? =>
    _template = HtmlTemplate.parse(
      """
      <div>
        <h1>Register</h1>
        <form lv-change="validate" lv-submit="register">
          <div>
            <label>Username</label>
            <input type="text" name="username" value="{{ username }}" />
            <span style="color:red">{{ username_error }}</span>
          </div>
          <div>
            <label>Email</label>
            <input type="text" name="email" value="{{ email }}" />
            <span style="color:red">{{ email_error }}</span>
          </div>
          <div>
            <label>Password</label>
            <input type="password" name="password" value="{{ password }}" />
            <span style="color:red">{{ password_error }}</span>
          </div>
          <button type="submit">Register</button>
        </form>
        <p style="color:green">{{ result }}</p>
      </div>
      """)?

  fun ref mount(socket: Socket ref) =>
    socket.assign("username", "")
    socket.assign("email", "")
    socket.assign("password", "")
    socket.assign("username_error", "")
    socket.assign("email_error", "")
    socket.assign("password_error", "")
    socket.assign("result", "")

  fun ref handle_event(event: String val, payload: JsonValue,
    socket: Socket ref)
  =>
    let nav = JsonNav(payload)
    try
      let username = nav("username").as_string()?
      let email = nav("email").as_string()?
      let password = nav("password").as_string()?

      socket.assign("username", username)
      socket.assign("email", email)
      socket.assign("password", password)

      match event
      | "validate" =>
        // Only validate non-empty fields during typing
        socket.assign("username_error",
          if (username.size() > 0) and (username.size() < 3) then
            "Username must be at least 3 characters"
          else "" end)
        socket.assign("email_error",
          if (email.size() > 0) and (not email.contains("@")) then
            "Email must contain @"
          else "" end)
        socket.assign("password_error",
          if (password.size() > 0) and (password.size() < 8) then
            "Password must be at least 8 characters"
          else "" end)
        socket.assign("result", "")
      | "register" =>
        // Validate all fields including required checks
        let username_err =
          if username.size() == 0 then "Username is required"
          elseif username.size() < 3 then
            "Username must be at least 3 characters"
          else "" end
        let email_err =
          if email.size() == 0 then "Email is required"
          elseif not email.contains("@") then "Email must contain @"
          else "" end
        let password_err =
          if password.size() == 0 then "Password is required"
          elseif password.size() < 8 then
            "Password must be at least 8 characters"
          else "" end

        socket.assign("username_error", username_err)
        socket.assign("email_error", email_err)
        socket.assign("password_error", password_err)

        if (username_err == "") and (email_err == "")
          and (password_err == "")
        then
          socket.assign("result",
            "Registration successful for " + username + "!")
        else
          socket.assign("result", "")
        end
      end
    end

  fun box render(assigns: Assigns box): String ? =>
    _template.render(assigns.template_values())?

  fun box render_parts(assigns: Assigns box,
    sink: TemplateSink ref): Bool
  =>
    try
      _template.render_to(sink, assigns.template_values())?
      true
    else
      false
    end

actor Main
  new create(env: Env) =>
    let router = Router
    router.route("/form",
      {(): LiveView ref^ ? => FormView.create()?} val)

    Listener(lori.TCPListenAuth(env.root), "0.0.0.0", "8083",
      router.build(), PubSub, env.err)
