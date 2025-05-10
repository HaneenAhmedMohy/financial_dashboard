defmodule BackendWeb.StockChannel do
  use Phoenix.Channel
  require Logger
  alias Backend.StockData.Store # Alias for convenience

  @impl true
  def join("stock:lobby", _payload, socket) do
    Logger.info("Client joined stock:lobby on socket #{inspect(socket.id)}")

    # Subscribe to stock updates from PubSub
    Phoenix.PubSub.subscribe(Backend.PubSub, "stock_updates")

    # Send current stock data to the joining client
    initial_stock_data_list = Store.get_all_stock_data()
    # Convert [{symbol, data_map}, ...] to %{symbol => data_map}
    initial_stock_data_map = Enum.into(initial_stock_data_list, %{})

    push(socket, "initial_stocks", initial_stock_data_map)

    {:ok, socket}
  end

  # This new handle_info callback handles messages broadcasted by PubSub
  @impl true
  def handle_info({:stock_trade, payload}, socket) do
    # payload is %{symbol: symbol, price: price, timestamp: timestamp, volume: volume}
    # Push the new trade data to the client
    push(socket, "stock_update", payload)
    {:noreply, socket}
  end

  # This handle_info is for other messages, can be kept or removed if not used
  @impl true
  def handle_info(msg, socket) do
    Logger.debug("StockChannel received unhandled message: #{inspect(msg)}")
    {:noreply, socket}
  end

  @impl true
  def terminate(reason, socket) do
    Logger.info("Client left stock:lobby (socket #{inspect(socket.id)}), reason: #{inspect(reason)}")
    :ok
  end
end
