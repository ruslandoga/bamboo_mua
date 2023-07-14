defmodule Bamboo.Mua do
  @moduledoc """
  Bamboo adapter for [Mua.](https://github.com/ruslandoga/mua)
  """

  @behaviour Bamboo.Adapter

  defmodule MultihostError do
    @moduledoc """
    Raised when no relay is used and recipients contain addresses across multiple hosts.

    For example:

        Bamboo.Email.new_email(
          to: {"Ruslan", "dogaruslan@gmail.com"},
          cc: [{"Another Ruslan", "ruslandoga@ya.ru"}]
        )

    Fields:

      - `:hosts` - the hosts for the recipients, `["gmail.com", "ya.ru"]` in the example above

    """

    defexception [:hosts]

    def message(%__MODULE__{hosts: hosts}) do
      "expected all recipients to be on the same host, got: " <> Enum.join(hosts, ", ")
    end
  end

  @impl true
  def deliver(email, config) do
    recipients = recipients(email)

    recipients_by_host =
      if relay = config[:relay] do
        [{relay, recipients}]
      else
        recipients
        |> Enum.group_by(&__MODULE__.recipient_host/1)
        |> Map.to_list()
      end

    case recipients_by_host do
      [{host, recipients}] ->
        sender = address(email.from)
        message = render(email)
        opts = Map.to_list(config)

        with {:ok, _receipt} <- Mua.easy_send(host, sender, recipients, message, opts) do
          {:ok, email}
        end

      [_ | _] = multihost ->
        {:error, MultihostError.exception(hosts: :proplists.get_keys(multihost))}
    end
  end

  @impl true
  def handle_config(config), do: config

  @impl true
  def supports_attachments?, do: true

  @doc false
  def address({_, address}) when is_binary(address), do: address
  def address(address) when is_binary(address), do: address

  @doc false
  def recipient_host(address) do
    [_username, host] = String.split(address, "@")
    host
  end

  defp recipients(%Bamboo.Email{to: to, cc: cc, bcc: bcc}) do
    (List.wrap(to) ++ List.wrap(cc) ++ List.wrap(bcc))
    |> Enum.map(&__MODULE__.address/1)
    |> Enum.uniq()
  end

  defp render(email) do
    Mail.build_multipart()
    |> maybe(&Mail.put_from/2, email.from)
    |> maybe(&Mail.put_to/2, prepare_recipients(email.to))
    |> maybe(&Mail.put_cc/2, prepare_recipients(email.cc))
    |> maybe(&Mail.put_bcc/2, prepare_recipients(email.bcc))
    |> maybe(&Mail.put_subject/2, email.subject)
    |> maybe(&Mail.put_text/2, email.text_body)
    |> maybe(&Mail.put_html/2, email.html_body)
    |> maybe(&__MODULE__.put_headers/2, email.headers)
    |> maybe(&__MODULE__.put_attachments/2, email.attachments)
    |> Mail.render()
  end

  defp maybe(mail, _fun, empty) when empty in [nil, [], %{}], do: mail
  defp maybe(mail, fun, value), do: fun.(mail, value)

  defp prepare_recipients({nil, address}), do: address

  defp prepare_recipients([recipient | recipients]) do
    [prepare_recipients(recipient) | prepare_recipients(recipients)]
  end

  defp prepare_recipients(other), do: other

  @doc false
  def put_attachments(mail, attachments) do
    Enum.reduce(attachments, mail, fn attachment, mail ->
      %Bamboo.Attachment{filename: filename, content_type: content_type, data: data} = attachment
      headers = [content_type: content_type, content_length: Integer.to_string(byte_size(data))]
      Mail.put_attachment(mail, {filename, data}, headers: headers)
    end)
  end

  @doc false
  def put_headers(mail, headers) do
    Enum.reduce(headers, mail, fn {key, value}, mail ->
      Mail.Message.put_header(mail, key, value)
    end)
  end
end
