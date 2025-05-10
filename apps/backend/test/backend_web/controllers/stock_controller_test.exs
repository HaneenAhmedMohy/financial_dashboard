defmodule BackendWeb.StockControllerTest do
  use BackendWeb.ConnCase # Removed async: true

  alias Backend.StockData.Store

  setup %{conn: conn} do
    # Clear the ETS table before each test to ensure test isolation
    :ets.delete_all_objects(:stock_data_table)
    {:ok, conn: conn}
  end

  describe "GET /api/stocks" do
    test "returns an empty JSON object when no stocks are in ETS", %{conn: conn} do
      conn = get(conn, ~p"/api/stocks")
      assert response_data = json_response(conn, 200)
      assert response_data == %{}
    end

    test "returns all stock data from ETS as JSON", %{conn: conn} do
      # Populate ETS with some data
      Store.update_trade_data("AAPL", 150.0, 1678886400000, 100)
      Store.update_trade_data("MSFT", 280.5, 1678886401000, 200)

      conn = get(conn, ~p"/api/stocks")
      assert response_data = json_response(conn, 200)

      expected_response = %{
        "AAPL" => %{"price" => 150.0, "timestamp" => 1678886400000, "volume" => 100},
        "MSFT" => %{"price" => 280.5, "timestamp" => 1678886401000, "volume" => 200}
      }
      assert response_data == expected_response
    end

    test "returns correctly formatted data for a single stock", %{conn: conn} do
      Store.update_trade_data("TSLA", 180.25, 1678886402000, 150)

      conn = get(conn, ~p"/api/stocks")
      assert response_data = json_response(conn, 200)

      expected_response = %{
        "TSLA" => %{"price" => 180.25, "timestamp" => 1678886402000, "volume" => 150}
      }
      assert response_data == expected_response
    end
  end
end
