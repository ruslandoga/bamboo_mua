> [!WARNING]
> Please consider switching to https://github.com/swoosh/swoosh

---

# Bamboo.Mua

[![Hex Package](https://img.shields.io/hexpm/v/bamboo_mua.svg)](https://hex.pm/packages/bamboo_mua)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/bamboo_mua)

[Bamboo](https://github.com/thoughtbot/bamboo) adapter for [Mua.](https://github.com/ruslandoga/mua)

## Installation

```elixir
defp deps do
  [
    {:bamboo_mua, "~> 0.2.0"},
    {:castore, "~> 1.0"}
  ]
end
```

## Usage

```elixir
# for supported configuration, please see https://hexdocs.pm/bamboo_mua/Bamboo.Mua.html#t:option/0
Application.put_env(:example, Mailer, adapter: Bamboo.Mua)

defmodule Mailer do
  use Bamboo.Mailer, otp_app: :example
end

email =
  Bamboo.Email.new_email(
    from: {"Mua", "mua@github.com"},
    to: {"Receiver", "receiver@mailpit.example"},
    subject: "how are you?",
    text_body: "I'm fine",
    html_body: "I'm <i>fine</i>"
  )

Mailer.deliver_now(email)
```
