<script>
  import { onMount, onDestroy } from 'svelte';
  import { Socket } from 'phoenix'; // Import the Socket class

  let socket;
  let channel;
  let stockData = {};
  let connectionStatus = "Initializing...";

  onMount(() => {
    connectionStatus = "Connecting to WebSocket...";
    // The path "/socket" will be proxied by Vite dev server
    // to ws://localhost:4000/socket
    socket = new Socket("/socket", { params: { user_token: "guest" } }); // params are optional

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

    channel.on("stock_update", (payload) => {
      console.log("Received stock_update:", payload.body);
      stockData = payload.body; // The data is in payload.body as pushed from channel
      connectionStatus = `Last update: ${new Date().toLocaleTimeString()}`;
    });

    channel.join()
      .receive("ok", resp => {
        console.log("Joined stock:lobby successfully!", resp);
        connectionStatus = "Joined channel. Waiting for data...";
      })
      .receive("error", resp => {
        console.error("Unable to join stock:lobby", resp);
        connectionStatus = "Failed to join channel.";
      });

    // Cleanup on component destroy (when onMount returns a function)
    return () => {
      if (channel) {
        channel.leave()
          .receive("ok", () => console.log("Left channel successfully."))
          .receive("error", (err) => console.log("Failed to leave channel.", err));
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
    if (channel && (channel.state === "joined" || channel.state === "joining")) {
      channel.leave().receive("error", (err) => console.log("Error leaving channel on destroy", err));
    }
    if (socket && (socket.connectionState() === "open" || socket.connectionState() === "connecting")) {
      socket.disconnect();
    }
  });

</script>

<main>
  <h1>Real-time Stock Data (Simulated)</h1>
  <p><strong>Status:</strong> {connectionStatus}</p>
  
  {#if Object.keys(stockData).length > 0 && stockData.timestamp}
    <div class="stock-data-container">
      <h2>Latest Data (Timestamp: {new Date(stockData.timestamp).toLocaleString()})</h2>
      {#each Object.entries(stockData) as [category, stocks]}
        {#if category !== 'timestamp' && typeof stocks === 'object' && stocks !== null && Object.keys(stocks).length > 0}
          <div class="category-block">
            <h3>{category}</h3>
            <ul class="stock-list">
              {#each Object.entries(stocks) as [symbol, price]}
                <li><strong>{symbol}:</strong> {price}</li>
              {/each}
            </ul>
          </div>
        {/if}
      {/each}
    </div>
  {:else if connectionStatus.startsWith("Joined channel")}
    <p>Waiting for the first data push from the server...</p>
  {/if}
</main>

<style>
  main {
    font-family: sans-serif; /* Overrides :root if more specific, but generally inherits */
    padding: 1em;
    max-width: 700px; /* Wider for categorized content */
    margin: 0 auto; /* Center the main block within #app */
    text-align: left; /* Align text to the left within the main block */
    /* Color will be inherited from body via #app based on app.css */
  }
  h1 {
    text-align: center;
    margin-bottom: 1em;
    /* Color inherited from app.css */
  }
  h2 { /* For "Latest Data..." heading */
    text-align: center;
    font-size: 1.4em;
    margin-bottom: 0.5em;
    /* Color inherited */
  }
  h3 { /* For Category headings */
    font-size: 1.2em;
    margin-top: 1.5em; /* Space above category name */
    margin-bottom: 0.75em;
    padding-bottom: 0.25em;
    border-bottom: 1px solid #ccc; /* Neutral border color */
    /* Color inherited */
  }
  p { /* For status message */
    text-align: center;
    margin-bottom: 1.5em;
    /* Color inherited */
  }
  .stock-data-container {
    margin-top: 1em;
  }
  .category-block {
    margin-bottom: 1.5em; /* Space between category blocks */
    padding: 1em;
    border: 1px solid #ddd; /* Light border for the block */
    border-radius: 8px;
    /* Background will be transparent to main's background (body background) */
  }
  .stock-list {
    list-style-type: none;
    padding: 0;
  }
  .stock-list li {
    background-color: rgba(0,0,0,0.02); /* Subtle background, works on light/dark */
    border: 1px solid rgba(0,0,0,0.05); /* Subtle border */
    margin-bottom: 8px;
    padding: 10px 15px;
    border-radius: 4px;
    display: flex;
    justify-content: space-between;
    transition: background-color 0.2s ease-in-out;
  }
  .stock-list li:hover {
    background-color: rgba(0,0,0,0.04); /* Slightly darker on hover */
  }
  .stock-list li strong {
    color: #007bff; /* A common blue, generally visible on light/dark themes */
    margin-right: 8px; /* Space between symbol and price */
  }
</style>
