defmodule Backend.Finnhub.Auth do
  @moduledoc """
  Handles retrieval of the Finnhub API key.
  """

  @doc """
  Retrieves the Finnhub API key from the FINNHUB_API_KEY environment variable.

  Returns:
    * `{:ok, api_key}` if the key is found and is a non-empty string.
    * `{:error, :api_key_missing}` if the FINNHUB_API_KEY environment variable is not set or is an empty string.
  """
  def get_api_key do
    case System.get_env("FINNHUB_API_KEY") do
      nil ->
        {:error, :api_key_missing}
      "" ->
        # Treat empty string as missing as well
        {:error, :api_key_missing}
      api_key when is_binary(api_key) ->
        {:ok, api_key}
    end
  end
end
