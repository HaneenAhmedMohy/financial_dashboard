import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

// https://vite.dev/config/
export default defineConfig({
  plugins: [svelte()],
  server: {
    proxy: {
      // Proxy /socket WebSocket requests to Phoenix backend
      '/socket': {
        target: 'ws://localhost:4000', // Your Phoenix backend URL
        ws: true, // Enable WebSocket proxying
      },
    }
  }
})
