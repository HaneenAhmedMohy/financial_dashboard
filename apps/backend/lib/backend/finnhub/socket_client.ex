defmodule Backend.Finnhub.SocketClient do
  use WebSockex # This module will handle WebSockex callbacks

  require Logger

  @finnhub_ws_url "wss://ws.finnhub.io"
  @name __MODULE__ # Name for the WebSockex process registration
  @reconnect_delay_ms 5000 # Default reconnect delay in milliseconds

  # List of substrings in error messages that indicate a permanent/critical error
  @critical_error_substrings [
    "unauthorized",
    "auth",
    "token", # e.g., "invalid token"
    "forbidden",
    "rate limit", # e.g., "rate limit exceeded"
    "too many requests",
    "subscription limit"
  ]

  # Called by the Application supervisor
  def start_link(opts \\ []) do
    # Check if the process is already registered by this name
    case Process.whereis(@name) do
      nil ->
        # Process not running, proceed to start
        initial_callback_state = %{
          finnhub_conn_ref: nil, # Will be set by WebSockex in handle_connect
          api_key: nil,          # Will be set if API key is found or explicitly passed in opts
          subscriptions: MapSet.new(), # Initialize subscriptions
          permanent_error: false # Flag to indicate if a permanent error has occurred
        }

        # Merge opts into the initial state. If opts contains :api_key, it will be used.
        # Otherwise, it remains nil from initial_callback_state.
        current_initial_state = Map.merge(initial_callback_state, Map.new(opts))

        # Determine URL and update state based on API key presence
        {websocket_url, state_for_websockex} =
          case Backend.Finnhub.Auth.get_api_key() do
            {:ok, api_key_from_env} ->
              Logger.info("Finnhub.SocketClient: FINNHUB_API_KEY found. Attempting to connect to Finnhub WebSocket with API key.")
              {@finnhub_ws_url <> "?token=" <> api_key_from_env, %{current_initial_state | api_key: api_key_from_env}}
            {:error, :api_key_missing} ->
              Logger.warning(
                "Finnhub.SocketClient: FINNHUB_API_KEY not found. Attempting to connect to Finnhub WebSocket without an API key. " <>
                "Functionality may be limited or connection may fail."
              )
              {@finnhub_ws_url, current_initial_state}
          end

        # Attempt to start the WebSockex client
        case WebSockex.start_link(websocket_url, __MODULE__, state_for_websockex, name: @name) do
          {:ok, pid} ->
            {:ok, pid}
          {:error, {:already_started, pid}} ->
            Logger.warning("Finnhub.SocketClient: Attempted to start but process #{@name} was already started (race condition during WebSockex.start_link). PID: #{inspect(pid)}. Considering it running.")
            {:ignore, pid} # Treat as already running, similar to Process.whereis check
          other_error ->
            # Propagate other errors (e.g., connection failure if WebSockex tries to connect synchronously)
            other_error
        end

      pid when is_pid(pid) ->
        # Process already running
        Logger.info("Finnhub.SocketClient: Process already started with PID #{inspect(pid)}. Ignoring duplicate start request.")
        {:ignore}
    end
  end

  # Public API: Subscribe to a stock symbol
  # This sends a message to the named WebSockex process.
  def subscribe(symbol) when is_binary(symbol) do
    GenServer.cast(@name, {:subscribe, symbol})
  end

  # Public API: Unsubscribe from a stock symbol
  def unsubscribe(symbol) when is_binary(symbol) do
    GenServer.cast(@name, {:unsubscribe, symbol})
  end

  # WebSockex Callbacks
  # `state` is the state of this WebSockex callback module.
  # It's initialized by the 3rd argument to WebSockex.start_link.

  @impl WebSockex
  def handle_connect(conn_ref, state) do
    # state here is %{..., permanent_error: boolean}
    Logger.info("Successfully connected to Finnhub WebSocket. Conn Ref: #{inspect(conn_ref)}")
    # Reset permanent_error flag on successful connection, in case it was a transient issue
    # that somehow resolved, or if the state is reused across WebSockex's internal retries
    # before hitting our handle_disconnect.
    new_state_with_conn_ref = %{state | finnhub_conn_ref: conn_ref, permanent_error: false}

    # The all_symbols_to_subscribe logic and related variable assignments
    # were part of a previous approach and are no longer needed here as
    # subscriptions are handled by the :send_initial_subscriptions message.

    final_state = %{new_state_with_conn_ref | subscriptions: state.subscriptions} # Keep existing subscriptions

    # Schedule sending initial subscriptions immediately after connection is confirmed.
    Process.send_after(self(), :send_initial_subscriptions, 0)

    Logger.info("Finnhub.SocketClient: handle_connect successful, scheduled :send_initial_subscriptions.")
    {:ok, final_state}
  end

  # WebSockex callback for messages cast to its process (e.g., from our public API)
  @impl WebSockex
  def handle_cast({:subscribe, symbol}, state = %{finnhub_conn_ref: conn_ref, subscriptions: subs}) when not is_nil(conn_ref) do
    if MapSet.member?(subs, symbol) do
      Logger.info("Finnhub.SocketClient: Already subscribed to #{symbol}.")
      {:ok, state}
    else
      case send_subscribe_frame(conn_ref, symbol) do
        :ok ->
          new_subs = MapSet.put(subs, symbol)
          {:ok, %{state | subscriptions: new_subs}}
        {:error, reason} ->
          Logger.error("Finnhub.SocketClient: Failed to send subscribe frame for #{symbol}: #{inspect(reason)}")
          {:ok, state} # Remain in current state, or handle error differently
      end
    end
  end
  def handle_cast({:subscribe, symbol}, state) do # Not connected or conn_ref is nil
    Logger.warning("Finnhub.SocketClient: Cannot subscribe to #{symbol} yet: Finnhub WebSocket not connected. Will add to pending subscriptions.")
    new_subs = MapSet.put(state.subscriptions, symbol) # Add to subscriptions, will be picked up by handle_connect
    {:ok, %{state | subscriptions: new_subs}}
  end

  @impl WebSockex
  def handle_cast({:unsubscribe, symbol}, state = %{finnhub_conn_ref: conn_ref, subscriptions: subs}) when not is_nil(conn_ref) do
    if MapSet.member?(subs, symbol) do
      case send_unsubscribe_frame(conn_ref, symbol) do
        :ok ->
          new_subs = MapSet.delete(subs, symbol)
          {:ok, %{state | subscriptions: new_subs}}
        {:error, reason} ->
          Logger.error("Finnhub.SocketClient: Failed to send unsubscribe frame for #{symbol}: #{inspect(reason)}")
          {:ok, state}
      end
    else
      Logger.info("Finnhub.SocketClient: Not currently subscribed to #{symbol}.")
      {:ok, state}
    end
  end
  def handle_cast({:unsubscribe, symbol}, state) do # Not connected or conn_ref is nil
    Logger.warning("Finnhub.SocketClient: Removing #{symbol} from pending subscriptions as Finnhub WebSocket not connected.")
    new_subs = MapSet.delete(state.subscriptions, symbol)
    {:ok, %{state | subscriptions: new_subs}}
  end

  @impl WebSockex
  def handle_frame({:text, msg}, state) do
  case Jason.decode(msg) do
    {:ok, %{"type" => "trade", "data" => trades}} ->
      process_trades(trades)
      {:ok, state}
      
    {:ok, %{"type" => "error", "msg" => error_msg}} ->
        Logger.error("Finnhub error message received: #{error_msg}")
        # Check if this error message indicates a permanent issue
        if Enum.any?(@critical_error_substrings, &String.contains?(String.downcase(error_msg), &1)) do
          Logger.error("Critical error detected from Finnhub message: #{error_msg}. Marking for no reconnect.")
          {:ok, %{state | permanent_error: true}} # Set flag, connection might be closed by server shortly
        else
          {:ok, state} # Non-critical error, just log and continue
        end
      
    {:ok, unexpected} ->
      Logger.warning("Unhandled message format from Finnhub: #{inspect(unexpected)}")
      {:ok, state}
      
    {:error, decode_error} ->
      Logger.error("JSON decode failed for message from Finnhub: #{inspect(decode_error)}. Message: #{msg}")
      {:ok, state}
  end
end

  @impl WebSockex
  def handle_frame({:ping, _payload}, state) do
    # WebSockex handles PING/PONG automatically by default.
    # This callback is for logging or custom handling if `handle_pings: false`.
    Logger.debug("Received PING from Finnhub. Auto-replying with PONG.")
    {:ok, state}
  end

  @impl WebSockex
  def handle_frame({:pong, _payload}, state) do
    Logger.debug("Received PONG from Finnhub.")
    {:ok, state}
  end

  @impl WebSockex
  def handle_frame(frame, state) do
    # Handles other frame types like :binary, :close if necessary
    Logger.warning("Received unexpected frame from Finnhub: #{inspect(frame)}")
    {:ok, state}
  end

  @impl WebSockex
  def handle_disconnect(disconnect_details, state) do
    # Always reset finnhub_conn_ref in the state that will be used or returned
    current_state_after_disconnect = %{state | finnhub_conn_ref: nil}

    cond do
      state.api_key == nil ->
        Logger.error("Finnhub.SocketClient: API key is missing. Stopping connection attempts to prevent loop.")
        {:stop, :shutdown, current_state_after_disconnect}

      state.permanent_error == true ->
        Logger.error("Finnhub.SocketClient: A permanent error was indicated. Stopping connection attempts.")
        {:stop, :shutdown, %{current_state_after_disconnect | permanent_error: true}} # Keep flag

      true ->
        Logger.warning("Finnhub.SocketClient: Disconnected from Finnhub WebSocket: #{inspect(disconnect_details)}")
        Logger.info("Finnhub.SocketClient: Will attempt to reconnect in #{div(@reconnect_delay_ms, 1000)} seconds.")
        {:reconnect, @reconnect_delay_ms, current_state_after_disconnect}
    end
  end

  # Helper functions
  defp send_subscribe_frame(conn_ref, symbol) do
    frame_content = Jason.encode!(%{type: "subscribe", symbol: symbol})
    Logger.info("Sending Finnhub subscribe for #{symbol} via #{inspect(conn_ref)}")
    WebSockex.send_frame(conn_ref, {:text, frame_content})
  end

  defp send_unsubscribe_frame(conn_ref, symbol) do
    frame_content = Jason.encode!(%{type: "unsubscribe", symbol: symbol})
    Logger.info("Sending Finnhub unsubscribe for #{symbol} via #{inspect(conn_ref)}")
    WebSockex.send_frame(conn_ref, {:text, frame_content})
  end

  defp process_trades(trades) when is_list(trades) do
    Enum.each(trades, fn trade ->
      try do
        # Ensure all necessary fields are present
        # Finnhub trade data:
        # "p": Last price
        # "s": Symbol
        # "t": UNIX milliseconds timestamp
        # "v": Volume
        with %{"s" => symbol, "p" => price, "t" => timestamp, "v" => volume} <- trade do
          # Update the ETS store
          Backend.StockData.Store.update_trade_data(symbol, price, timestamp, volume)

          # Broadcast the trade data
          payload = %{
            symbol: symbol,
            price: price,
            timestamp: timestamp,
            volume: volume
          }
          Phoenix.PubSub.broadcast(Backend.PubSub, "stock_updates", {:stock_trade, payload})

          Logger.debug("Processed and broadcasted trade for #{symbol}: P=#{price}, V=#{volume}, T=#{timestamp}")
        else
          _ ->
            # Log if any trade data is missing expected fields
            Logger.warning("Skipping trade due to missing fields: #{inspect(trade)}")
        end
      rescue
        e ->
          Logger.error("""
          Error processing trade data: #{inspect(trade)}
          Exception: #{inspect(e)}
          Stacktrace: #{inspect(System.stacktrace())}
          """)
      end
    end)
  end

  defp default_stock_symbols do
    [
      "AAPL",
      "MSFT",
      "NVDA",
      "GOOGL",
      "JPM",
      "BAC",
      "V",
      "AMZN",
      "WMT",
      "MCD"
      # Add other default symbols here if needed
    ]
  end

  # Removed GenServer handle_info(:reconnect, ...) as WebSockex handles reconnection
  # via handle_disconnect returning {:reconnect, ...}
  # Also, WebSockex callback modules can implement handle_info/2 for messages sent to its process.

  @impl WebSockex
  def handle_info(:send_initial_subscriptions, state = %{finnhub_conn_ref: conn_ref}) when not is_nil(conn_ref) do
    Logger.info("Finnhub.SocketClient: handle_info(:send_initial_subscriptions) received.")

    # Symbols that might have been added via subscribe() calls before connection
    pending_subscriptions = state.subscriptions

    # Combine default symbols with any existing (pending) subscriptions
    all_symbols_to_subscribe =
      MapSet.union(
        MapSet.new(default_stock_symbols()),
        pending_subscriptions
      )

    # Attempt to subscribe to all unique symbols
    updated_subs =
      Enum.reduce(all_symbols_to_subscribe, MapSet.new(), fn symbol, acc_subs ->
        case send_subscribe_frame(conn_ref, symbol) do
          :ok -> MapSet.put(acc_subs, symbol) # Add to successfully subscribed set
          {:error, _reason} -> acc_subs # Keep accumulated, failed to send this one
        end
      end)

    {:ok, %{state | subscriptions: updated_subs}}
  end

  def handle_info(:send_initial_subscriptions, state) do # finnhub_conn_ref is nil
    Logger.error("Finnhub.SocketClient: Cannot send initial subscriptions, Finnhub WebSocket not connected (conn_ref is nil).")
    # Optionally, reschedule or log that subscriptions will be attempted on next successful connect.
    # For now, do nothing, handle_connect will trigger this again upon successful reconnection.
    {:ok, state}
  end

  # Catch-all for other info messages, if any (optional)
  @impl WebSockex
  def handle_info(msg, state) do
    Logger.debug("Finnhub.SocketClient: Received unhandled info message: #{inspect(msg)}")
    {:ok, state}
  end
end


