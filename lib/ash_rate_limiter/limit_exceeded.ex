defmodule AshRateLimiter.LimitExceeded do
  @moduledoc """
  An exception which is raised or returned when an action invocation exceeds the defined limits.
  """
  use Splode.Error, fields: [:action, :hammer, :limit, :per, :key], class: :forbidden

  def message(_) do
    "Rate limit exceeded"
  end

  if Code.loaded?(Plug.Exception) do
    defimpl Plug.Exception do
      @doc false
      @impl true
      def actions(_), do: []

      @doc false
      @impl true
      def status(_), do: 429
    end
  end
end
