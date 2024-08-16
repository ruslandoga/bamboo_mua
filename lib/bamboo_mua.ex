defmodule Bamboo.Mua do
  @moduledoc """
  Bamboo adapter for [Mua.](https://github.com/ruslandoga/mua)

  For supported configuration options, please see [`option()`](#t:option/0)
  """

  @behaviour Bamboo.Adapter

  defmodule MultihostError do
    @moduledoc """
    Raised when no relay is used and recipients contain addresses across multiple hosts.

    For example:

        email =
          Bamboo.Email.new_email(
            to: {"Mua", "mua@github.com"},
            cc: [{"Bamboo", "mua@bamboo.github.com"}]
          )

        Bamboo.Mua.deliver(email, _no_relay_config = %{})

    Fields:

      - `:hosts` - the hosts for the recipients, `["github.com", "bamboo.github.com"]` in the example above

    """

    @type t :: %__MODULE__{hosts: [Mua.host()]}
    defexception [:hosts]

    def message(%__MODULE__{hosts: hosts}) do
      "expected all recipients to be on the same host, got: " <> Enum.join(hosts, ", ")
    end
  end

  @type option :: Mua.option() | {:relay, Mua.host()}

  @impl true
  def deliver(email, config) do
    recipients = recipients(email)
    relay = Map.get(config, :relay)

    recipients_by_host =
      if relay do
        [{relay, recipients}]
      else
        recipients
        |> Enum.group_by(&recipient_host/1)
        |> Map.to_list()
      end

    case recipients_by_host do
      [{host, recipients}] ->
        sender = address(email.from)
        message = render(email)
        opts = Map.to_list(config)

        # we don't perform MX lookup when relay is used
        # https://github.com/ruslandoga/bamboo_mua/issues/47
        opts =
          if relay do
            Keyword.put_new(opts, :mx, false)
          else
            opts
          end

        with {:ok, _receipt} <- Mua.easy_send(host, sender, recipients, message, opts) do
          {:ok, email}
        end

      [_ | _] = multihost ->
        {:error, MultihostError.exception(hosts: :proplists.get_keys(multihost))}
    end
  end

  @impl true
  def handle_config(config) when is_map(config), do: config

  @impl true
  def supports_attachments?, do: true

  defp address({_, address}) when is_binary(address), do: address
  defp address(address) when is_binary(address), do: address

  defp recipient_host(address) do
    [_username, host] = String.split(address, "@")
    host
  end

  defp recipients(%Bamboo.Email{to: to, cc: cc, bcc: bcc}) do
    (List.wrap(to) ++ List.wrap(cc) ++ List.wrap(bcc))
    |> Enum.map(&address/1)
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
    |> maybe(&put_headers/2, email.headers)
    |> maybe(&put_attachments/2, email.attachments)
    |> Mail.render()
  end

  defp maybe(mail, _fun, empty) when empty in [nil, [], %{}], do: mail
  defp maybe(mail, fun, value), do: fun.(mail, value)

  defp prepare_recipients({nil, address}), do: address

  defp prepare_recipients([recipient | recipients]) do
    [prepare_recipients(recipient) | prepare_recipients(recipients)]
  end

  defp prepare_recipients(other), do: other

  defp put_attachments(mail, attachments) do
    Enum.reduce(attachments, mail, fn attachment, mail ->
      %Bamboo.Attachment{filename: filename, content_type: content_type, data: data} = attachment
      Mail.put_attachment(mail, {filename, data}, headers: [content_type: content_type])
    end)
  end

  defp put_headers(mail, headers) do
    # https://github.com/ruslandoga/bamboo_mua/issues/53
    headers =
      headers
      |> Map.put_new_lazy("Message-ID", &__MODULE__.message_id/0)
      |> Map.put_new_lazy("Date", &DateTime.utc_now/0)

    Enum.reduce(headers, mail, fn {key, value}, mail ->
      Mail.Message.put_header(mail, key, value)
    end)
  end

  @doc false
  def message_id do
    Base.hex_encode32(
      <<
        System.system_time(:nanosecond)::64,
        :erlang.phash2({node(), self()}, 16_777_216)::24,
        :erlang.unique_integer()::32
      >>,
      case: :lower
    )
  end
end
