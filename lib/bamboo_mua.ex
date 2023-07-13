defmodule Bamboo.Mua do
  @moduledoc """
  Bamboo adapter for [Mua.](https://github.com/ruslandoga/mua)
  """

  @behaviour Bamboo.Adapter

  @impl true
  def deliver(email, config) do
    sender = address(email.from)
    message = render(email)
    opts = Map.to_list(config)

    recipients(email)
    |> Enum.group_by(&__MODULE__.recipient_host/1)
    |> Map.to_list()
    |> case do
      [{host, recipients}] ->
        Mua.easy_send(host, sender, recipients, message, opts)

      [_ | _] = multihost ->
        {:error, "expected all recipients to be on the same host, got: #{inspect(multihost)}"}
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

  @doc false
  def render(email) do
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
    Enum.reduce(attachments, mail, fn %Bamboo.Attachment{filename: filename, data: data}, mail ->
      attachment =
        Mail.Message.build_attachment({filename, data})
        |> Mail.Message.put_header(:content_type, "application/octet-stream")
        |> Mail.Message.put_header(:content_length, byte_size(data))

      Mail.Message.put_part(mail, attachment)
    end)
  end

  @doc false
  def put_headers(mail, headers) do
    Enum.reduce(headers, mail, fn {key, value}, mail ->
      Mail.Message.put_header(mail, key, value)
    end)
  end
end
