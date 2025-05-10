defmodule Backend.StockData.Store do
  use GenServer
  require Logger

  @table_name :stock_data_table

  # Client API

  @doc """
  Starts the GenServer.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Updates the stock data for a given symbol in the ETS table.
  The data is expected to be a map with price, timestamp, and volume.
  Example: %{price: 150.00, timestamp: 1678886400000, volume: 1000}
  """
  def update_trade_data(symbol, price, timestamp, volume) when is_binary(symbol) do
    data_map = %{price: price, timestamp: timestamp, volume: volume}
    :ets.insert(@table_name, {symbol, data_map})
  end

  @doc """
  Retrieves all stock data from the ETS table.
  Returns a list of {symbol, data_map} tuples.
  """
  def get_all_stock_data do
    case :ets.lookup(@table_name, "AAPL") do
      [] -> [] # AAPL data not found, return empty list
      [{_symbol, _data_map} = aapl_data_tuple] ->
        [aapl_data_tuple] # Return as a list containing the single AAPL tuple
    end
  end

  @doc """
  Retrieves data for a specific stock symbol.
  """
  def get_stock_data(symbol) when is_binary(symbol) do
    case :ets.lookup(@table_name, symbol) do
      [{^symbol, data_map}] -> {:ok, data_map}
      [] -> {:error, :not_found}
    end
  end

  # GenServer callbacks

  @impl true
  def init(:ok) do
    Logger.info("Initializing StockData.Store. Ensuring ETS table #{@table_name} is ready.")
    # In development, the named table might persist across code reloads or iex restarts.
    # Delete it if it exists to ensure a clean start for :ets.new/2.
    if Mix.env() == :dev and :ets.whereis(@table_name) != :undefined do
      Logger.debug("ETS table #{@table_name} found from previous session. Deleting for a clean start.")
      :ets.delete(@table_name)
    end
    :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    Logger.info("ETS table #{@table_name} created successfully.")
    {:ok, %{table_name: @table_name}}
  end
end
