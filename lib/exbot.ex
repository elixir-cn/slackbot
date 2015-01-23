defmodule Exbot do

  defp start!(token) do
    {:ok, response} = HTTPoison.get "https://slack.com/api/rtm.start?token=" <> token, [], timeout: 10000
    response
  end

  defp parse(response) do
    {:ok, json} = response.body
    |> Poison.Parser.parse
    json
  end

  defp get_config(json) do
    <<bot_id::size(72)>> = json["self"]["id"]
    %{url: json["url"], bot_id: bot_id}
  end

  defp connect(%{url: url} = state) do
    uri = URI.parse url
    {:ok, socket} = Socket.Web.connect uri.host, path: uri.path, secure: true
    state
    |> Map.put(:socket, socket)
    |> Map.put(:msg_id, 1)
  end

  defp send_text(socket, id, channel, text) do
    socket
    |> Socket.Web.send! {:text, """
    {
      "id": #{id},
      "type": "message",
      "channel": "#{channel}",
      "text": "#{text}"
    }
    """
    }
  end

  defp handle(state) do
    state.socket
    |> Socket.Web.recv!
    |> process(state)
  end

  defp process({:text, raw_json}, state) do
    raw_json
    |> Poison.Parser.parse!
    |> log
    |> do_process(state)
    |> handle
  end

  defp log(msg) do
    IO.inspect(msg)
    msg
  end

  defp process(_msg, state) do
    handle(state)
  end

  defp do_process(%{
    "type" => "message",
    "channel" => channel,
    "user" => user,
    "text" => << ?<, ?@, bot_id::size(72), ?>, ?: >> <> text},
    %{socket: socket, bot_id: bot_id, msg_id: msg_id} = state) do
    send_text(socket, msg_id, channel, "<@#{user}>:#{text}")
    %{state | msg_id: msg_id+1}
  end

  defp do_process(_json, state) do
    state
  end

  def run(token) do
    token
    |> start!
    |> parse
    |> get_config
    |> connect
    |> handle
  end

end
