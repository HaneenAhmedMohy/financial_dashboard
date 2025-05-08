# 💸 Finance App

This project is a real-time financial dashboard that leverages Elixir (Phoenix) for the backend and Svelte for the frontend, built in a monorepo structure. The application connects to the Finnhub WebSocket API to stream live stock market data for a selected portfolio of major companies across technology, finance, and consumer sectors. It displays current prices, daily percentage changes, and visual indicators for stocks like AAPL, MSFT, NVDA, GOOGL, JPM, BAC, V, AMZN, WMT, and MCD. This dashboard demonstrates the power of Elixir for managing WebSocket connections and Svelte’s reactivity for delivering a fast, user-friendly interface — all while using AI pair programming with Aider to guide progressive feature development and testing.

---

## 📦 Project Structure
├── apps/
│ ├── frontend/ # Svelte frontend
│ └── backend/ # Phoenix (Elixir) backend
├── .aider.conf.json # Aider configuration
├── .aider-history.md # Full Aider conversation history

### Prerequisites

- Svelte
- Elixir & Erlang

### 1. Clone the Repository

git clone git@github.com:HaneenAhmedMohy/financial_dashboard.git
cd apps

### 2.Backend Setup

cd apps/backend
mix deps.get
mix ecto.setup
mix phx.server

### 3. Frontend Setup
cd ../frontend
npm i
npm run dev


#### Screenshots

#### 1. milestone 1
![Alt Text](https://github.com/HaneenAhmedMohy/financial_dashboard/blob/main/apps/screenshots/milestone_1.png)
