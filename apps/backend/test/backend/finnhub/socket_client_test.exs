defmodule Backend.Finnhub.SocketClientTest do
  use ExUnit.Case # Removed async: true

  alias Backend.Finnhub.SocketClient
  alias Backend.StockData.Store

  setup do
    # Ensure the StockData.Store is started (it should be by the application supervisor)
    # and clear any existing data from the ETS table for test isolation.
    # The table is :named_table and :public.
    :ets.delete_all_objects(:stock_data_table)
    :ok
  end

  describe "handle_frame/2 for trade messages" do
    test "correctly processes a valid trade message and stores data" do
      trade_data_json = """
      {
        "type": "trade",
        "data": [
          {"s": "AAPL", "p": 150.75, "t": 1678886400000, "v": 100},
          {"s": "MSFT", "p": 280.50, "t": 1678886401000, "v": 200}
        ]
      }
      """
      # Dummy state, only finnhub_conn_ref is used by the logger in the tested function path
      initial_state = %{finnhub_conn_ref: :dummy_conn_ref_for_test}

      {:ok, ^initial_state} = SocketClient.handle_frame({:text, trade_data_json}, initial_state)

      # Verify data for AAPL
      {:ok, aapl_data} = Store.get_stock_data("AAPL")
      assert aapl_data.price == 150.75
      assert aapl_data.timestamp == 1678886400000
      assert aapl_data.volume == 100

      # Verify data for MSFT
      {:ok, msft_data} = Store.get_stock_data("MSFT")
      assert msft_data.price == 280.50
      assert msft_data.timestamp == 1678886401000
      assert msft_data.volume == 200
    end

    test "skips trades with missing fields and logs a warning" do
      trade_data_json = """
      {
        "type": "trade",
        "data": [
          {"s": "GOOGL", "p": 2700.00}, 
          {"s": "AMZN", "p": 120.00, "t": 1678886402000, "v": 50}
        ]
      }
      """
      initial_state = %{finnhub_conn_ref: :dummy_conn_ref_for_test}

      # Capture log to verify warning for missing fields
      log_output = ExUnit.CaptureLog.capture_log(fn ->
        {:ok, ^initial_state} = SocketClient.handle_frame({:text, trade_data_json}, initial_state)
      end)

      assert log_output =~ "Skipping trade due to missing fields"
      
      # GOOGL data should not be stored due to missing t and v
      assert Store.get_stock_data("GOOGL") == {:error, :not_found}

      # AMZN data should be stored
      {:ok, amzn_data} = Store.get_stock_data("AMZN")
      assert amzn_data.price == 120.00
      assert amzn_data.timestamp == 1678886402000
      assert amzn_data.volume == 50
    end

    test "handles non-trade messages gracefully" do
      ping_message_json = """
      {"type":"ping"}
      """
      initial_state = %{finnhub_conn_ref: :dummy_conn_ref_for_test}
      
      {:ok, ^initial_state} = SocketClient.handle_frame({:text, ping_message_json}, initial_state)
      # No data should be written for non-trade messages
      assert Store.get_all_stock_data() == []
    end

    test "handles JSON decoding errors gracefully" do
      invalid_json = "this is not json"
      initial_state = %{finnhub_conn_ref: :dummy_conn_ref_for_test}

      log_output = ExUnit.CaptureLog.capture_log(fn ->
         {:ok, ^initial_state} = SocketClient.handle_frame({:text, invalid_json}, initial_state)
      end)

      assert log_output =~ "Failed to decode JSON from Finnhub"
      assert Store.get_all_stock_data() == []
    end
  end
end
