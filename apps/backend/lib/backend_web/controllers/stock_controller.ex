defmodule BackendWeb.StockController do
  use BackendWeb, :controller

  alias Backend.StockData.Store

  def index(conn, _params) do
    stock_data_list = Backend.StockData.Store.get_all_stock_data()
    # Convert the list of {symbol, data_map} tuples into a map of symbol => data_map
    # for a more common JSON structure.
    stock_data_map = Enum.into(stock_data_list, %{})
    json(conn, stock_data_map)
  end
end
