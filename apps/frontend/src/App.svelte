<script>
  import { onMount, onDestroy } from "svelte";
  import { Socket } from "phoenix";

  let socket;
  let channel;
  let stockData = {}; // This will store data like: { "AAPL": {price: ..., volume: ..., timestamp: ...}, ... }
  let connectionStatus = "Initializing...";

  onMount(() => {
    connectionStatus = "Connecting to WebSocket...";
    // The path "/socket" will be proxied by Vite dev server
    // to ws://localhost:4000/socket
    socket = new Socket("ws://localhost:4000/socket", {
      // Direct Phoenix connection
    }); // params are optional

    socket.onOpen(() => {
      connectionStatus = "Socket connection open.";
      console.log("Phoenix socket connected!");
    });

    socket.onError((error) => {
      connectionStatus = "Socket connection error.";
      console.error("Phoenix socket error:", error);
    });

    socket.onClose(() => {
      connectionStatus = "Socket connection closed.";
      console.log("Phoenix socket closed.");
    });

    socket.connect();

    // Join the "stock:lobby" channel
    channel = socket.channel("stock:lobby", {}); // Second arg is payload for join

    // Handler for initial batch of stock data
    channel.on("initial_stocks", (payload) => {
      console.log("Received initial_stocks:", payload);
      stockData = payload; // payload is { SYMBOL: {price, timestamp, volume}, ... }
      connectionStatus = "Initial stock data loaded.";
    });

    // Handler for individual stock updates
    channel.on("stock_update", (payload) => {
      // payload is {symbol, price, timestamp, volume}
      console.log("Received stock_update:", payload);
      // Update the specific stock's data in our stockData map
      stockData = {
        ...stockData,
        [payload.symbol]: {
          price: payload.price,
          timestamp: payload.timestamp,
          volume: payload.volume,
        },
      };
      connectionStatus = `Last update for ${payload.symbol}: ${new Date().toLocaleTimeString()}`;
    });

    channel
      .join()
      .receive("ok", (resp) => {
        console.log("Joined stock:lobby successfully!", resp);
        connectionStatus = "Joined channel. Waiting for initial data...";
      })
      .receive("error", (resp) => {
        console.error("Unable to join stock:lobby", resp);
        connectionStatus = "Failed to join channel.";
      });

    // Cleanup on component destroy (when onMount returns a function)
    return () => {
      if (channel) {
        channel
          .leave()
          .receive("ok", () => console.log("Left channel successfully."))
          .receive("error", (err) =>
            console.log("Failed to leave channel.", err)
          );
      }
      if (socket) {
        socket.disconnect(() => console.log("Socket disconnected."));
      }
    };
  });

  // onDestroy is also called for cleanup.
  // The onMount return function is generally preferred for onMount-specific cleanup.
  // This is here for completeness or if you had other non-onMount related cleanup.
  onDestroy(() => {
    // Ensure cleanup if not already handled by onMount's return
    if (
      channel &&
      (channel.state === "joined" || channel.state === "joining")
    ) {
      channel
        .leave()
        .receive("error", (err) =>
          console.log("Error leaving channel on destroy", err)
        );
    }
    if (
      socket &&
      (socket.connectionState() === "open" ||
        socket.connectionState() === "connecting")
    ) {
      socket.disconnect();
    }
  });
</script>

<main>
  <h1>Real-time Stock Data (Simulated)</h1>
  <p><strong>Status:</strong> {connectionStatus}</p>

  {#if Object.keys(stockData).length > 0}
    <div class="stock-data-container">
      <h2>Current Stock Data</h2>
      {#each Object.entries(stockData) as [symbol, data] (symbol)}
        <div class="stock-block">
          <h3>{symbol}</h3>
          <ul class="stock-list">
            <li>
              <strong>Price:</strong>
              <span class="price-value">{data.price}</span>
            </li>
            <li><strong>Volume:</strong> {data.volume}</li>
            <li>
              <strong>Last Update:</strong>
              {new Date(data.timestamp).toLocaleString()}
            </li>
          </ul>
        </div>
      {/each}
    </div>
  {:else if connectionStatus.startsWith("Joined channel") || connectionStatus.startsWith("Initial stock data loaded")}
    <p>Waiting for data or first update from the server...</p>
  {/if}
</main>

<style>
  main {
    font-family: sans-serif;
    padding: 1em;
    max-width: 700px;
    margin: 0 auto;
    text-align: left;
  }
  h1 {
    text-align: center;
    margin-bottom: 1em;
  }
  h2 {
    text-align: center;
    font-size: 1.4em;
    margin-bottom: 0.5em;
  }
  h3 {
    font-size: 1.2em;
    margin-top: 1.5em;
    margin-bottom: 0.75em;
    padding-bottom: 0.25em;
    border-bottom: 1px solid #ccc;
  }
  p {
    text-align: center;
    margin-bottom: 1.5em;
  }
  .stock-data-container {
    margin-top: 1em;
  }
  .stock-block {
    margin-bottom: 1.5em;
    padding: 1em;
    border: 1px solid #ddd;
    border-radius: 8px;
  }
  .stock-list {
    list-style-type: none;
    padding: 0;
  }
  .stock-list li {
    background-color: rgba(0, 0, 0, 0.02);
    border: 1px solid rgba(0, 0, 0, 0.05);
    margin-bottom: 8px;
    padding: 10px 15px;
    border-radius: 4px;
    display: flex;
    justify-content: space-between;
    transition: background-color 0.2s ease-in-out;
  }
  .stock-list li:hover {
    background-color: rgba(0, 0, 0, 0.04);
  }
  .stock-list li strong {
    color: #007bff;
    margin-right: 8px;
  }
  .price-value {
    font-weight: bold;
    font-size: 1.05em;
    color: #2ecc71; /* A shade of green */
  }
  /* You could add more specific styling for price up/down if you track previous price */
</style>
