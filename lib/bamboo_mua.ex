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
        |> Enum.group_by(&host/1)
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

  defp host(address) do
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
    |> put_headers(email)
    |> maybe(&Mail.put_from/2, email.from)
    |> maybe(&Mail.put_to/2, prepare_recipients(email.to))
    |> maybe(&Mail.put_cc/2, prepare_recipients(email.cc))
    |> maybe(&Mail.put_bcc/2, prepare_recipients(email.bcc))
    |> maybe(&Mail.put_subject/2, email.subject)
    |> maybe(&Mail.put_text/2, email.text_body)
    |> maybe(&Mail.put_html/2, email.html_body)
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

  defp put_headers(mail, bamboo_email) do
    %{from: from, headers: headers} = bamboo_email

    utc_now = DateTime.utc_now()
    keys = headers |> Map.keys() |> Enum.map(&String.downcase/1)

    has_date? = "date" in keys
    has_message_id? = "message-id" in keys

    headers = if has_date?, do: headers, else: Map.put(headers, "Date", utc_now)

    headers =
      if has_message_id? do
        headers
      else
        address = address(from)
        host = host(address)
        Map.put(headers, "Message-ID", message_id(host, utc_now))
      end

    Enum.reduce(headers, mail, fn {key, value}, mail ->
      Mail.Message.put_header(mail, key, value)
    end)
  end

  defp message_id(host, utc_now) do
    date = Calendar.strftime(utc_now, "%Y%m%d")
    time = DateTime.to_time(utc_now)
    {seconds_after_midnight, _ms} = Time.to_seconds_after_midnight(time)

    disambiguator =
      Base.hex_encode32(
        <<
          seconds_after_midnight::17,
          :erlang.phash2({node(), self()}, 8_388_608)::23,
          :erlang.unique_integer()::24
        >>,
        case: :lower,
        padding: false
      )

    # e.g. <20241211.7aqmq6bb022i8@example.com>
    "<#{date}.#{disambiguator}@#{host}>"
  end
end
