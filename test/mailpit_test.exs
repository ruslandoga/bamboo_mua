defmodule Bamboo.Mua.MailpitTest do
  use ExUnit.Case, async: true

  @moduletag :mailpit
  @moduletag :capture_log

  describe "deliver_now/2" do
    setup do
      base_email =
        Bamboo.Email.new_email(
          from: {"Mua", "mua@github.com"},
          to: {"Recipient", "recipient@mailpit.example"},
          subject: "how are you? 😋",
          text_body: "I'm fine 😌",
          html_body: "I'm <i>fine</i> 😌"
        )

      {:ok, email: base_email}
    end

    test "base mail", %{email: email} do
      assert {:ok, _email} = mailpit_deliver(email)

      assert %{
               "From" => %{"Address" => "mua@github.com", "Name" => "Mua"},
               "To" => [%{"Address" => "recipient@mailpit.example", "Name" => "Recipient"}],
               "Subject" => "how are you? 😋",
               "HTML" => "I'm <i>fine</i> 😌",
               "Text" => "I'm fine 😌\r\n"
             } = mailpit_summary("latest")

      # https://github.com/ruslandoga/bamboo_mua/issues/53
      assert %{
               "Date" => [_has_date],
               "Message-Id" => [_has_message_id]
             } = mailpit_headers("latest")
    end

    test "with address sender/recipient", %{email: email} do
      assert {:ok, _email} =
               email
               |> Bamboo.Email.from("mua@github.com")
               |> Bamboo.Email.to("to@mailpit.example")
               |> Bamboo.Email.cc(["cc1@mailpit.examile", "cc2@mailpit.example"])
               |> Bamboo.Email.bcc(["bcc1@mailpit.examile", "bcc2@mailpit.example"])
               |> mailpit_deliver()

      assert %{
               "From" => %{"Address" => "mua@github.com", "Name" => ""},
               "To" => [%{"Address" => "to@mailpit.example", "Name" => ""}],
               "Bcc" => [
                 %{"Address" => "bcc1@mailpit.examile", "Name" => ""},
                 %{"Address" => "bcc2@mailpit.example", "Name" => ""}
               ],
               "Cc" => [
                 %{"Address" => "cc1@mailpit.examile", "Name" => ""},
                 %{"Address" => "cc2@mailpit.example", "Name" => ""}
               ]
             } = mailpit_summary("latest")
    end

    test "with tuple recipient (empty name)", %{email: email} do
      assert {:ok, _email} =
               email
               |> Bamboo.Email.from({nil, "mua@github.com"})
               |> Bamboo.Email.to({nil, "to@mailpit.example"})
               |> Bamboo.Email.cc([{nil, "cc1@mailpit.examile"}, {nil, "cc2@mailpit.example"}])
               |> Bamboo.Email.bcc([{nil, "bcc1@mailpit.examile"}, {nil, "bcc2@mailpit.example"}])
               |> mailpit_deliver()

      assert %{
               "From" => %{"Address" => "mua@github.com", "Name" => ""},
               "To" => [%{"Address" => "to@mailpit.example", "Name" => ""}],
               "Bcc" => [
                 %{"Address" => "bcc1@mailpit.examile", "Name" => ""},
                 %{"Address" => "bcc2@mailpit.example", "Name" => ""}
               ],
               "Cc" => [
                 %{"Address" => "cc1@mailpit.examile", "Name" => ""},
                 %{"Address" => "cc2@mailpit.example", "Name" => ""}
               ]
             } = mailpit_summary("latest")
    end

    test "with cc and bcc", %{email: email} do
      assert {:ok, _email} =
               email
               |> Bamboo.Email.cc([
                 {"CC1", "cc1@mailpit.example"},
                 {"CC2", "cc2@mailpit.example"}
               ])
               |> Bamboo.Email.bcc([
                 {"BCC1", "bcc1@mailpit.example"},
                 {"BCC2", "bcc2@mailpit.example"}
               ])
               |> mailpit_deliver()

      assert %{
               "Cc" => [
                 %{"Address" => "cc1@mailpit.example", "Name" => "CC1"},
                 %{"Address" => "cc2@mailpit.example", "Name" => "CC2"}
               ],
               "Bcc" => [
                 %{"Address" => "bcc1@mailpit.example", "Name" => ""},
                 %{"Address" => "bcc2@mailpit.example", "Name" => ""}
               ]
             } = mailpit_summary("latest")
    end

    test "without relay, all recipients on the same host", %{email: email} do
      {:ok, local_hostname} = guess_sender_hostname()

      # turns `mac3` into `mac3.local`
      local_hostname =
        case String.split(local_hostname, ".", trim: true) do
          [local_hostname] -> local_hostname <> ".local"
          _ -> local_hostname
        end

      assert {:ok, _email} =
               email
               |> Bamboo.Email.to({"Recipient", "recipient@#{local_hostname}"})
               |> Bamboo.Email.cc([
                 {"CC1", "cc1@#{local_hostname}"},
                 {"CC2", "cc2@#{local_hostname}"}
               ])
               |> TestMailer.deliver_now(config: %{port: 1025, timeout: :timer.seconds(3)})

      assert %{"To" => to, "Cc" => cc} = mailpit_summary("latest")
      rcpts = to ++ cc

      assert Enum.all?(rcpts, fn %{"Address" => address} ->
               String.ends_with?(address, "@#{local_hostname}")
             end)
    end

    test "with attachments", %{email: email} do
      attachment = Bamboo.Attachment.new("test/priv/attachment.txt")

      assert {:ok, _email} =
               email
               |> Bamboo.Email.put_attachment(attachment)
               |> mailpit_deliver()

      assert %{
               "ID" => message_id,
               "Attachments" => [
                 %{
                   "ContentType" => "text/plain",
                   "FileName" => "attachment.txt",
                   "PartID" => part_id,
                   "Size" => 9
                 }
               ]
             } = mailpit_summary("latest")

      assert mailpit_attachment(message_id, part_id) == "hello :)\n"
    end
  end

  defp mailpit_deliver(email) do
    config = %{relay: "localhost", port: 1025, timeout: :timer.seconds(1)}
    TestMailer.deliver_now(email, config: config)
  end

  defp mailpit_summary(message_id) do
    mailpit_api_request("http://localhost:8025/api/v1/message/#{message_id}")
  end

  defp mailpit_headers(message_id) do
    mailpit_api_request("http://localhost:8025/api/v1/message/#{message_id}/headers")
  end

  defp mailpit_attachment(message_id, part_id) do
    mailpit_api_request("http://localhost:8025/api/v1/message/#{message_id}/part/#{part_id}")
  end

  defp mailpit_api_request(url) do
    url = String.to_charlist(url)

    http_opts = [
      timeout: :timer.seconds(15),
      connect_timeout: :timer.seconds(15)
    ]

    opts = [
      body_format: :binary
    ]

    case :httpc.request(:get, {url, _headers = []}, http_opts, opts) do
      {:ok, {{_, status, _}, headers, body} = response} ->
        unless status == 200 do
          raise "failed GET #{url} with #{inspect(response)}"
        end

        case :proplists.get_value(~c"content-type", headers) do
          ~c"application/json" -> Jason.decode!(body)
          _ -> body
        end

      {:error, reason} ->
        raise "failed GET #{url} with #{inspect(reason)}"
    end
  end

  require Record
  Record.defrecordp(:hostent, Record.extract(:hostent, from_lib: "kernel/include/inet.hrl"))

  defp guess_sender_hostname do
    with {:ok, hostname} <- :inet.gethostname(),
         {:ok, hostent(h_name: hostname)} <- :inet.gethostbyname(hostname),
         do: {:ok, List.to_string(hostname)}
  end
end
