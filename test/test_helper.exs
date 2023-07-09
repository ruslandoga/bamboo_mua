Application.put_env(:bamboo_mua_test, TestMailer, adapter: Bamboo.Mua)

defmodule TestMailer do
  use Bamboo.Mailer, otp_app: :bamboo_mua_test
end

ExUnit.start(exclude: [:integration])
