defmodule BackendWeb.UserSocket do
  use Phoenix.Socket

  # Define the channel your Svelte app will connect to
  channel "stock:lobby", BackendWeb.StockChannel

  # Configure transports, WebSocket is primary for real-time
  transport :websocket, Phoenix.Transports.WebSocket
  # transport :longpoll, Phoenix.Transports.LongPoll # You can enable this as a fallback if needed

  # This function is called when a client attempts to connect.
  # `params` can be used for authentication in a real application.
  # For now, we'll allow all connections.
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  # `id` is used to identify the socket.
  # Returning nil means the socket is not uniquely identified.
  def id(_socket), do: nil
end
