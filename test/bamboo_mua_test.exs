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

  describe "render/1" do
    test "with address sender/recipient" do
      assert Bamboo.Email.new_email()
             |> Bamboo.Email.from("hey@copycat.fun")
             |> Bamboo.Email.to("dogaruslan@gmail.com")
             |> Bamboo.Email.cc(["doga.ruslan@gmail.com"])
             |> Bamboo.Mua.render()
    end

    test "with full recipient" do
      assert Bamboo.Email.new_email()
             |> Bamboo.Email.from("Ruslan <hey@copycat.fun>")
             |> Bamboo.Email.to("Ruslan <dogaruslan@gmail.com>")
             |> Bamboo.Email.cc(["Ruslan <doga.ruslan@gmail.com>"])
             |> Bamboo.Mua.render()
    end

    test "with tuple recipient" do
      assert Bamboo.Email.new_email()
             |> Bamboo.Email.from({nil, "hey@copycat.fun"})
             |> Bamboo.Email.to({nil, "dogaruslan@gmail.com"})
             |> Bamboo.Email.cc([{nil, "doga.ruslan@gmail.com"}])
             |> Bamboo.Mua.render()

      assert Bamboo.Email.new_email()
             |> Bamboo.Email.from({"Ruslan", "hey@copycat.fun"})
             |> Bamboo.Email.to({"Ruslan", "dogaruslan@gmail.com"})
             |> Bamboo.Email.cc([{"Ruslan", "doga.ruslan@gmail.com"}])
             |> Bamboo.Mua.render()
    end
  end
end
