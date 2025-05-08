defmodule BackendWeb.StockChannel do
  use Phoenix.Channel
  require Logger

  # Called when a client joins the "stock:lobby" topic
  def join("stock:lobby", _payload, socket) do
    Logger.info("Client joined stock:lobby on socket #{inspect(socket.id)}")
    # Start sending periodic updates for this client
    send(self(), :send_simulated_data)
    {:ok, socket}
  end

  # Internal message handler to periodically send data
  def handle_info(:send_simulated_data, socket) do
    # Simulate Finnhub data
    data = %{
      "Technology" => %{
        "AAPL" => Enum.random(150..200) + :rand.uniform() |> Float.round(2),
        "MSFT" => Enum.random(300..350) + :rand.uniform() |> Float.round(2),
        "NVDA" => Enum.random(800..900) + :rand.uniform() |> Float.round(2),
        "GOOGL" => Enum.random(170..180) + :rand.uniform() |> Float.round(2)
      },
      "Finance" => %{
        "JPM" => Enum.random(180..220) + :rand.uniform() |> Float.round(2),
        "BAC" => Enum.random(30..40) + :rand.uniform() |> Float.round(2),
        "V" => Enum.random(250..300) + :rand.uniform() |> Float.round(2)
      },
      "Consumer" => %{
        "AMZN" => Enum.random(170..200) + :rand.uniform() |> Float.round(2),
        "WMT" => Enum.random(50..70) + :rand.uniform() |> Float.round(2),
        "MCD" => Enum.random(280..320) + :rand.uniform() |> Float.round(2)
      },
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Push the data to the client on the "stock_update" event
    push(socket, "stock_update", %{body: data})

    # Schedule the next update after 3 seconds (3000 milliseconds)
    Process.send_after(self(), :send_simulated_data, 3000)
    {:noreply, socket}
  end

  # Called when the channel process terminates
  def terminate(reason, socket) do
    Logger.info("Client left stock:lobby (socket #{inspect(socket.id)}), reason: #{inspect(reason)}")
    :ok
  end
end
