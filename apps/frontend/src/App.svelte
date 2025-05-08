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
    <div>
      <h2>Latest Data (Timestamp: {new Date(stockData.timestamp).toLocaleString()}):</h2>
      <ul>
        {#each Object.entries(stockData) as [key, value]}
          {#if key !== 'timestamp'}
            <li><strong>{key}:</strong> {value}</li>
          {/if}
        {/each}
      </ul>
    </div>
  {:else if connectionStatus.startsWith("Joined channel")}
    <p>Waiting for the first data push from the server...</p>
  {/if}
</main>

<style>
  main {
    font-family: sans-serif;
    padding: 1em;
    max-width: 600px;
    margin: auto;
    color: #333;
  }
  h1 {
    color: #1a1a1a;
    text-align: center;
  }
  p {
    text-align: center;
    margin-bottom: 1.5em;
  }
  ul {
    list-style-type: none;
    padding: 0;
  }
  li {
    background-color: #f9f9f9;
    border: 1px solid #eee;
    margin-bottom: 8px;
    padding: 12px 15px;
    border-radius: 4px;
    display: flex;
    justify-content: space-between;
  }
  li strong {
    color: #555;
  }
</style>
