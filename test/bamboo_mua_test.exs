defmodule Bamboo.MuaTest do
  use ExUnit.Case

  @tag :integration
  test "it works" do
    email =
      Bamboo.Email.new_email(
        from: {"Ruslan", "hey@copycat.fun"},
        to: {"Ruslan", "dogaruslan@gmail.com"},
        subject: "how are you?",
        text_body: "I'm fine",
        html_body: "I'm <i>fine</i>"
      )

    assert {:ok, _email} = TestMailer.deliver_now(email)
  end
end
