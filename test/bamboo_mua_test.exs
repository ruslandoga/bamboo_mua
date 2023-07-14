defmodule Bamboo.MuaTest do
  use ExUnit.Case

  describe "deliver_now/1" do
    @describetag :mailhog
    @describetag :capture_log

    setup do
      base_email =
        Bamboo.Email.new_email(
          from: {"Ruslan", "hey@copycat.fun"},
          to: {"Ruslan", "dogaruslan@gmail.com"},
          subject: "how are you?",
          text_body: "I'm fine",
          html_body: "I'm <i>fine</i>"
        )

      {:ok, base_email: base_email}
    end

    test "base_email", %{base_email: base_email} do
      assert {:ok, _email} = mailhog(base_email)
    end

    test "with address sender/recipient", %{base_email: base_email} do
      assert {:ok, _email} =
               base_email
               |> Bamboo.Email.from("hey@copycat.fun")
               |> Bamboo.Email.to("dogaruslan@gmail.com")
               |> Bamboo.Email.cc(["doga.ruslan@gmail.com"])
               |> mailhog()
    end

    test "with tuple recipient", %{base_email: base_email} do
      assert {:ok, _email} =
               base_email
               |> Bamboo.Email.from({nil, "hey@copycat.fun"})
               |> Bamboo.Email.to({nil, "dogaruslan@gmail.com"})
               |> Bamboo.Email.cc([{nil, "doga.ruslan@gmail.com"}])
               |> mailhog()

      assert {:ok, _email} =
               base_email
               |> Bamboo.Email.from({"Ruslan", "hey@copycat.fun"})
               |> Bamboo.Email.to({"Ruslan", "dogaruslan@gmail.com"})
               |> Bamboo.Email.cc([{"Ruslan", "doga.ruslan@gmail.com"}])
               |> mailhog()
    end

    # TODO
    test "without relay, all recipients on the same host", %{base_email: base_email} do
      assert {:error, %Mua.SMTPError{}} =
               TestMailer.deliver_now(base_email, config: %{timeout: :timer.seconds(3)})
    end

    test "multihost error", %{base_email: base_email} do
      assert {:error, %Bamboo.Mua.MultihostError{} = error} =
               base_email
               |> Bamboo.Email.to("dogaruslan@gmail.com")
               |> Bamboo.Email.cc(["ruslan.doga@ya.ru"])
               |> TestMailer.deliver_now()

      assert Exception.message(error) ==
               "expected all recipients to be on the same host, got: gmail.com, ya.ru"
    end

    test "with headers", %{base_email: base_email} do
      message_id = "#{System.unique_integer([:positive])}@copycat.fun"

      assert {:ok, _email} =
               base_email
               |> Bamboo.Email.put_header("message-id", message_id)
               |> mailhog()
    end

    test "with attachments", %{base_email: base_email} do
      attachment = Bamboo.Attachment.new("test/priv/attachment.txt")

      assert {:ok, _email} =
               base_email
               |> Bamboo.Email.put_attachment(attachment)
               |> mailhog()
    end
  end

  test "supports_attachments?" do
    assert Bamboo.Mua.supports_attachments?()
  end

  defp mailhog(email) do
    config = %{relay: "localhost", port: 1025, timeout: :timer.seconds(1)}
    TestMailer.deliver_now(email, config: config)
  end
end
