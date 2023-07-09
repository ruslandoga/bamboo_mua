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
    Enum.map(List.wrap(to) ++ List.wrap(cc) ++ List.wrap(bcc), &__MODULE__.address/1)
  end

  defp render(email) do
    Mail.build_multipart()
    |> Mail.put_to(email.to)
    |> Mail.put_cc(email.cc)
    |> Mail.put_bcc(email.bcc)
    |> Mail.put_from(email.from)
    |> Mail.put_subject(email.subject)
    |> maybe_put_text(email.text_body)
    |> maybe_put_html(email.html_body)
    |> put_attachments(email.attachments)
    |> Mail.render()
  end

  defp maybe_put_text(mail, nil), do: mail
  defp maybe_put_text(mail, text), do: Mail.put_text(mail, text)

  defp maybe_put_html(mail, nil), do: mail
  defp maybe_put_html(mail, html), do: Mail.put_html(mail, html)

  defp put_attachments(mail, [%Bamboo.Attachment{filename: filename, data: data} | attachments]) do
    attachment =
      Mail.Message.build_attachment({filename, data})
      |> Mail.Message.put_header(:content_type, "application/octet-stream")
      |> Mail.Message.put_header(:content_length, byte_size(data))

    mail
    |> Mail.Message.put_part(attachment)
    |> put_attachments(attachments)
  end

  defp put_attachments(mail, []), do: mail
  defp put_attachments(mail, nil), do: mail
end
