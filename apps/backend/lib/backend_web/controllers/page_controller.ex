defmodule BackendWeb.PageController do
  use BackendWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok", message: "Backend API is running."})
  end
end
