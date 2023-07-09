Bamboo adapter for [Mua.](https://github.com/ruslandoga/mua)

```elixir
Application.put_env(:example, Mailer, adapter: Bamboo.Mua)

defmodule Mailer do
  use Bamboo.Mailer, otp_app: :example
end

email =
  Bamboo.Email.new_email(
    from: {"Ruslan", "hey@copycat.fun"},
    to: {"Ruslan", "dogaruslan@gmail.com"},
    subject: "how are you?",
    text_body: "I'm fine",
    html_body: "I'm <i>fine</i>"
  )

Mailer.deliver_now(email)
```
