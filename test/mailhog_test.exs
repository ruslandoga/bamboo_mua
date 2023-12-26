defmodule Bamboo.MailHogTest do
  use ExUnit.Case, async: true

  @moduletag :mailhog
  @moduletag :capture_log

  # uses https://github.com/mailhog/MailHog
  # docker run -d --rm -p 1025:1025 -p 8025:8025 --name mailhog mailhog/mailhog

  describe "deliver_now/2" do
    setup do
      message_id = "#{System.system_time()}.#{System.unique_integer([:positive])}.mua@localhost"

      base_email =
        Bamboo.Email.new_email(
          from: {"Mua", "mua@github.com"},
          to: {"Recipient", "recipient@mailhog.example"},
          subject: "how are you? 😋",
          text_body: "I'm fine 😌",
          html_body: "I'm <i>fine</i> 😌",
          headers: %{"Message-ID" => message_id}
        )

      {:ok, email: base_email}
    end

    test "base mail", %{email: email} do
      assert {:ok, email} = mailhog_deliver(email)

      assert %{
               "items" => [
                 %{
                   "Content" => %{
                     "Headers" => %{
                       "From" => ["\"Mua\" <mua@github.com>"],
                       "Message-Id" => [_message_id],
                       "Mime-Version" => ["1.0"],
                       "Return-Path" => ["<mua@github.com>"],
                       "Subject" => ["=?UTF-8?Q?how are you=3F =F0=9F=98=8B?="],
                       "To" => ["\"Recipient\" <recipient@mailhog.example>"]
                     }
                   },
                   "MIME" => %{
                     "Parts" => [
                       %{
                         "Body" => "I'm fine =F0=9F=98=8C",
                         "Headers" => %{
                           "Content-Transfer-Encoding" => ["quoted-printable"],
                           "Content-Type" => ["text/plain"]
                         }
                       },
                       %{
                         "Body" => "I'm <i>fine</i> =F0=9F=98=8C",
                         "Headers" => %{
                           "Content-Transfer-Encoding" => ["quoted-printable"],
                           "Content-Type" => ["text/html"]
                         }
                       },
                       %{"Body" => "--", "Headers" => %{}}
                     ]
                   },
                   "Raw" => %{
                     "From" => "mua@github.com",
                     "Helo" => "github.com",
                     "To" => ["recipient@mailhog.example"]
                   }
                 }
               ]
             } = mailhog_search(email)
    end

    test "with address sender/recipient", %{email: email} do
      assert {:ok, email} =
               email
               |> Bamboo.Email.from("mua@github.com")
               |> Bamboo.Email.to("to@mailhog.example")
               |> Bamboo.Email.cc(["cc1@mailhog.examile", "cc2@mailhog.example"])
               |> Bamboo.Email.bcc(["bcc1@mailhog.examile", "bcc2@mailhog.example"])
               |> mailhog_deliver()

      assert %{
               "items" => [
                 %{
                   "Content" => %{
                     "Headers" => %{
                       "Cc" => ["cc1@mailhog.examile, cc2@mailhog.example"],
                       "From" => ["\"\" <mua@github.com>"],
                       "To" => ["to@mailhog.example"]
                     }
                   },
                   "Raw" => %{
                     "From" => "mua@github.com",
                     "Helo" => "github.com",
                     "To" => [
                       "to@mailhog.example",
                       "cc1@mailhog.examile",
                       "cc2@mailhog.example",
                       "bcc1@mailhog.examile",
                       "bcc2@mailhog.example"
                     ]
                   }
                 }
               ]
             } = mailhog_search(email)
    end

    test "with tuple recipient (empty name)", %{email: email} do
      assert {:ok, email} =
               email
               |> Bamboo.Email.from({nil, "mua@github.com"})
               |> Bamboo.Email.to({nil, "to@mailhog.example"})
               |> Bamboo.Email.cc([{nil, "cc1@mailhog.examile"}, {nil, "cc2@mailhog.example"}])
               |> Bamboo.Email.bcc([{nil, "bcc1@mailhog.examile"}, {nil, "bcc2@mailhog.example"}])
               |> mailhog_deliver()

      assert %{
               "items" => [
                 %{
                   "Content" => %{
                     "Headers" => %{
                       "Cc" => ["cc1@mailhog.examile, cc2@mailhog.example"],
                       "From" => ["\"\" <mua@github.com>"],
                       "To" => ["to@mailhog.example"]
                     }
                   },
                   "Raw" => %{
                     "From" => "mua@github.com",
                     "Helo" => "github.com",
                     "To" => [
                       "to@mailhog.example",
                       "cc1@mailhog.examile",
                       "cc2@mailhog.example",
                       "bcc1@mailhog.examile",
                       "bcc2@mailhog.example"
                     ]
                   }
                 }
               ]
             } = mailhog_search(email)
    end

    test "with cc and bcc", %{email: email} do
      assert {:ok, email} =
               email
               |> Bamboo.Email.cc([{"CC1", "cc1@mailhog.example"}, {"CC2", "cc2@mailhog.example"}])
               |> Bamboo.Email.bcc([
                 {"BCC1", "bcc1@mailhog.example"},
                 {"BCC2", "bcc2@mailhog.example"}
               ])
               |> mailhog_deliver()

      assert %{
               "items" => [
                 %{
                   "Content" => %{
                     "Headers" => %{
                       "Cc" => [
                         "\"CC1\" <cc1@mailhog.example>, \"CC2\" <cc2@mailhog.example>"
                       ]
                     }
                   },
                   "Raw" => %{
                     "To" => [
                       "recipient@mailhog.example",
                       "cc1@mailhog.example",
                       "cc2@mailhog.example",
                       "bcc1@mailhog.example",
                       "bcc2@mailhog.example"
                     ]
                   }
                 }
               ]
             } = mailhog_search(email)
    end

    test "without relay, all recipients on the same host", %{email: email} do
      {:ok, local_hostname} = Mua.guess_sender_hostname()

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
               "items" => [
                 %{
                   "Raw" => %{
                     "From" => "mua@github.com",
                     "Helo" => "github.com",
                     "To" => rcpts
                   }
                 }
               ]
             } = mailhog_search(email)

      assert Enum.all?(rcpts, fn rcpt -> String.ends_with?(rcpt, "@#{local_hostname}") end)
    end

    test "with attachments", %{email: email} do
      attachment = Bamboo.Attachment.new("test/priv/attachment.txt")

      assert {:ok, email} =
               email
               |> Bamboo.Email.put_attachment(attachment)
               |> mailhog_deliver()

      assert %{
               "items" => [
                 %{
                   "MIME" => %{
                     "Parts" => [
                       %{
                         "MIME" => %{
                           "Parts" => [
                             %{
                               "Body" => body,
                               "Headers" => %{
                                 "Content-Disposition" => ["attachment; filename=attachment.txt"],
                                 "Content-Length" => ["9"],
                                 "Content-Transfer-Encoding" => ["base64"],
                                 "Content-Type" => ["text/plain"]
                               }
                             },
                             %{
                               "Body" => "I'm fine =F0=9F=98=8C",
                               "Headers" => %{
                                 "Content-Transfer-Encoding" => ["quoted-printable"],
                                 "Content-Type" => ["text/plain"]
                               }
                             },
                             %{
                               "Body" => "I'm <i>fine</i> =F0=9F=98=8C",
                               "Headers" => %{
                                 "Content-Transfer-Encoding" => ["quoted-printable"],
                                 "Content-Type" => ["text/html"]
                               }
                             },
                             %{"Body" => "--", "Headers" => %{}}
                           ]
                         }
                       },
                       %{"Body" => "--", "Headers" => %{}}
                     ]
                   }
                 }
               ]
             } = mailhog_search(email)

      assert Base.decode64!(body) == "hello :)\n"
    end
  end

  defp mailhog_deliver(email) do
    config = %{relay: "localhost", port: 1025, timeout: :timer.seconds(1)}
    TestMailer.deliver_now(email, config: config)
  end

  defp mailhog_search(%Bamboo.Email{headers: %{"Message-ID" => message_id}}) do
    mailhog_search(%{"kind" => "containing", "query" => message_id})
  end

  defp mailhog_search(params) do
    Req.get!("http://localhost:8025/api/v2/search?" <> URI.encode_query(params)).body
  end
end
