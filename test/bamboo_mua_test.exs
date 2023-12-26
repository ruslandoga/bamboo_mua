defmodule Bamboo.MuaTest do
  use ExUnit.Case, async: true

  @moduletag :capture_log

  test "supports_attachments?" do
    assert Bamboo.Mua.supports_attachments?()
  end

  test "multihost error" do
    email =
      Bamboo.Email.new_email(
        from: {"Mua", "mua@github.com"},
        to: {"to", "to@github.com"},
        cc: [{"cc1", "cc1@gmail.com"}]
      )

    assert {:error, %Bamboo.Mua.MultihostError{} = error} =
             TestMailer.deliver_now(email)

    assert Exception.message(error) ==
             "expected all recipients to be on the same host, got: github.com, gmail.com"
  end
end
