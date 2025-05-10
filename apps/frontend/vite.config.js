import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

// https://vite.dev/config/
export default defineConfig({
  plugins: [svelte()],
  server: {
    proxy: {
      // Proxy /socket WebSocket requests to Phoenix backend
      '/socket': {
        target: 'ws://localhost:4000', // Your Phoenix backend URL for WebSockets
        ws: true, // Enable WebSocket proxying
      },
      // Add a proxy for HTTP API requests
      '/api': {
        target: 'http://localhost:4000', // Your Phoenix backend URL for HTTP
        changeOrigin: true, // Recommended for most cases
        // If you encounter issues, you might need to rewrite the path if your backend
        // expects requests at the root (e.g., /stocks instead of /api/stocks).
        // However, your Phoenix router is set up for /api/stocks, so no rewrite is needed here.
      }
    }
  }
})
