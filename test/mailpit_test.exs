defmodule Bamboo.Mua.MailpitTest do
  use ExUnit.Case, async: true

  @moduletag :mailpit
  @moduletag :capture_log

  describe "deliver_now/2" do
    setup do
      message_id = "#{System.system_time()}.#{System.unique_integer([:positive])}.mua@localhost"

      base_email =
        Bamboo.Email.new_email(
          from: {"Mua", "mua@github.com"},
          to: {"Recipient", "recipient@mailpit.example"},
          subject: "how are you? 😋",
          text_body: "I'm fine 😌",
          html_body: "I'm <i>fine</i> 😌",
          headers: %{"Message-ID" => message_id}
        )

      {:ok, email: base_email}
    end

    test "base mail", %{email: email} do
      assert {:ok, email} = mailpit_deliver(email)

      assert %{
               "messages" => [
                 %{
                   "Bcc" => [],
                   "Cc" => [],
                   "From" => %{"Address" => "mua@github.com", "Name" => "Mua"},
                   "Snippet" => "I'm fine 😌",
                   "Subject" => "how are you? 😋",
                   "To" => [%{"Address" => "recipient@mailpit.example", "Name" => "Recipient"}]
                 }
               ]
             } = mailpit_search(email)
    end

    test "with address sender/recipient", %{email: email} do
      assert {:ok, email} =
               email
               |> Bamboo.Email.from("mua@github.com")
               |> Bamboo.Email.to("to@mailpit.example")
               |> Bamboo.Email.cc(["cc1@mailpit.examile", "cc2@mailpit.example"])
               |> Bamboo.Email.bcc(["bcc1@mailpit.examile", "bcc2@mailpit.example"])
               |> mailpit_deliver()

      assert %{
               "messages" => [
                 %{
                   "Bcc" => [
                     %{"Address" => "bcc1@mailpit.examile", "Name" => ""},
                     %{"Address" => "bcc2@mailpit.example", "Name" => ""}
                   ],
                   "Cc" => [
                     %{"Address" => "cc1@mailpit.examile", "Name" => ""},
                     %{"Address" => "cc2@mailpit.example", "Name" => ""}
                   ],
                   "From" => %{"Address" => "mua@github.com", "Name" => ""},
                   "Snippet" => "I'm fine 😌",
                   "Subject" => "how are you? 😋",
                   "To" => [%{"Address" => "to@mailpit.example", "Name" => ""}]
                 }
               ]
             } = mailpit_search(email)
    end

    test "with tuple recipient (empty name)", %{email: email} do
      assert {:ok, email} =
               email
               |> Bamboo.Email.from({nil, "mua@github.com"})
               |> Bamboo.Email.to({nil, "to@mailpit.example"})
               |> Bamboo.Email.cc([{nil, "cc1@mailpit.examile"}, {nil, "cc2@mailpit.example"}])
               |> Bamboo.Email.bcc([{nil, "bcc1@mailpit.examile"}, {nil, "bcc2@mailpit.example"}])
               |> mailpit_deliver()

      assert %{
               "messages" => [
                 %{
                   "Bcc" => [
                     %{"Address" => "bcc1@mailpit.examile", "Name" => ""},
                     %{"Address" => "bcc2@mailpit.example", "Name" => ""}
                   ],
                   "Cc" => [
                     %{"Address" => "cc1@mailpit.examile", "Name" => ""},
                     %{"Address" => "cc2@mailpit.example", "Name" => ""}
                   ],
                   "Snippet" => "I'm fine 😌",
                   "Subject" => "how are you? 😋",
                   "To" => [%{"Address" => "to@mailpit.example", "Name" => ""}]
                 }
               ]
             } = mailpit_search(email)
    end

    test "with cc and bcc", %{email: email} do
      assert {:ok, email} =
               email
               |> Bamboo.Email.cc([{"CC1", "cc1@mailpit.example"}, {"CC2", "cc2@mailpit.example"}])
               |> Bamboo.Email.bcc([
                 {"BCC1", "bcc1@mailpit.example"},
                 {"BCC2", "bcc2@mailpit.example"}
               ])
               |> mailpit_deliver()

      assert %{
               "messages" => [
                 %{
                   "Bcc" => [
                     %{"Address" => "bcc1@mailpit.example", "Name" => ""},
                     %{"Address" => "bcc2@mailpit.example", "Name" => ""}
                   ],
                   "Cc" => [
                     %{"Address" => "cc1@mailpit.example", "Name" => "CC1"},
                     %{"Address" => "cc2@mailpit.example", "Name" => "CC2"}
                   ],
                   "From" => %{"Address" => "mua@github.com", "Name" => "Mua"},
                   "Snippet" => "I'm fine 😌",
                   "Subject" => "how are you? 😋",
                   "To" => [%{"Address" => "recipient@mailpit.example", "Name" => "Recipient"}]
                 }
               ]
             } = mailpit_search(email)
    end

    test "without relay, all recipients on the same host", %{email: email} do
      {:ok, local_hostname} = guess_sender_hostname()

      # turns `mac3` into `mac3.local`
      local_hostname =
        case String.split(local_hostname, ".", trim: true) do
          [local_hostname] -> local_hostname <> ".local"
          _ -> local_hostname
        end

      assert {:ok, email} =
               email
               |> Bamboo.Email.to({"Recipient", "recipient@#{local_hostname}"})
               |> Bamboo.Email.cc([
                 {"CC1", "cc1@#{local_hostname}"},
                 {"CC2", "cc2@#{local_hostname}"}
               ])
               |> TestMailer.deliver_now(config: %{port: 1025, timeout: :timer.seconds(3)})

      assert %{
               "messages" => [
                 %{
                   "Attachments" => 0,
                   "Bcc" => [],
                   "Cc" => cc,
                   "From" => %{"Address" => "mua@github.com", "Name" => "Mua"},
                   "Snippet" => "I'm fine 😌",
                   "Subject" => "how are you? 😋",
                   "To" => to
                 }
               ]
             } = mailpit_search(email)

      rcpts = to ++ cc

      assert Enum.all?(rcpts, fn %{"Address" => address} ->
               String.ends_with?(address, "@#{local_hostname}")
             end)
    end

    test "with attachments", %{email: email} do
      attachment = Bamboo.Attachment.new("test/priv/attachment.txt")

      assert {:ok, email} =
               email
               |> Bamboo.Email.put_attachment(attachment)
               |> mailpit_deliver()

      assert %{
               "messages" => [
                 %{
                   "Attachments" => 1,
                   "Bcc" => [],
                   "Cc" => [],
                   "From" => %{"Address" => "mua@github.com", "Name" => "Mua"},
                   "Snippet" => "I'm fine 😌",
                   "Subject" => "how are you? 😋",
                   "To" => [%{"Address" => "recipient@mailpit.example", "Name" => "Recipient"}]
                 }
               ]
             } = mailpit_search(email)

      # TODO
      # assert Base.decode64!(body) == "hello :)\n"
    end
  end

  defp mailpit_deliver(email) do
    config = %{relay: "localhost", port: 1025, timeout: :timer.seconds(1)}
    TestMailer.deliver_now(email, config: config)
  end

  defp mailpit_search(%Bamboo.Email{headers: %{"Message-ID" => message_id}}) do
    mailpit_search(%{"query" => "message-id:" <> message_id})
  end

  defp mailpit_search(params) do
    url = String.to_charlist("http://localhost:8025/api/v1/search?" <> URI.encode_query(params))

    http_opts = [
      timeout: :timer.seconds(15),
      connect_timeout: :timer.seconds(15)
    ]

    opts = [
      body_format: :binary
    ]

    case :httpc.request(:get, {url, _headers = []}, http_opts, opts) do
      {:ok, {{_, status, _}, _headers, body} = response} ->
        unless status == 200 do
          raise "failed GET #{url} with #{inspect(response)}"
        end

        Jason.decode!(body)

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
