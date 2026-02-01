# SPDX-FileCopyrightText: 2025 ash_rate_limiter contributors <https://github.com/ash-project/ash_rate_limiter/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshRateLimiter.Preparation do
  @moduledoc """
  A resource preparation which implements rate limiting.

  Supports both read actions (via `Ash.Query`) and generic actions (via `Ash.ActionInput`).
  """

  use Ash.Resource.Preparation
  alias Ash.{ActionInput, Query}
  alias AshRateLimiter.{Info, LimitExceeded}
  alias Spark.Options

  @option_schema Options.new!(
                   action: [
                     type: {:or, [nil, :atom]},
                     required: false,
                     default: nil,
                     doc:
                       "If provided, then only queries/inputs matching the provided action name will be limited, otherwise all actions are."
                   ],
                   limit: [
                     type: :pos_integer,
                     required: true,
                     doc: "The maximum number of events allowed within the given scale"
                   ],
                   per: [
                     type: :pos_integer,
                     required: true,
                     doc: "The time period (in milliseconds) for in which events are counted"
                   ],
                   key: [
                     type: {:or, [:string, {:fun, 1}, {:fun, 2}]},
                     required: false,
                     default: &AshRateLimiter.key_for_action/2,
                     doc:
                       "The key used to identify the event. See the docs for `AshRateLimiter.key_for_action/2`."
                   ]
                 )

  @doc false
  @impl true
  def init(options), do: Options.validate(options, @option_schema)

  @doc false
  @impl true
  def supports(_opts), do: [Ash.Query, Ash.ActionInput]

  @doc false
  @impl true
  def prepare(query_or_input, opts, context)

  def prepare(%Query{} = query, opts, context) do
    if is_nil(opts[:action]) or opts[:action] == query.action.name do
      query
      |> Query.before_action(fn query ->
        context =
          context
          |> Map.from_struct()
          |> Map.merge(query.context)

        with {:ok, key} <- get_key(query, opts, context),
             :ok <- hammer_it(query, Keyword.put(opts, :key, key)) do
          query
        else
          {:error, reason} -> Query.add_error(query, reason)
        end
      end)
    else
      query
    end
  end

  def prepare(%ActionInput{} = input, opts, context) do
    if is_nil(opts[:action]) or opts[:action] == input.action.name do
      input
      |> ActionInput.before_action(fn input ->
        context =
          context
          |> Map.from_struct()
          |> Map.merge(input.context)

        with {:ok, key} <- get_key(input, opts, context),
             :ok <- hammer_it(input, Keyword.put(opts, :key, key)) do
          input
        else
          {:error, reason} -> {:error, reason}
        end
      end)
    else
      input
    end
  end

  defp hammer_it(query_or_input, opts) do
    hammer = Info.rate_limit_hammer!(query_or_input.resource)

    case hammer.hit(opts[:key], opts[:per], opts[:limit]) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, LimitExceeded.exception([{:hammer, hammer} | opts])}
    end
  end

  defp get_key(query_or_input, opts, context) do
    case opts[:key] do
      key when is_binary(key) and byte_size(key) > 0 ->
        {:ok, key}

      keyfun when is_function(keyfun, 1) ->
        query_or_input
        |> keyfun.()
        |> handle_keyfun_result()

      keyfun when is_function(keyfun, 2) ->
        query_or_input
        |> keyfun.(context)
        |> handle_keyfun_result()

      key ->
        {:error, "Invalid key: `#{inspect(key)}`"}
    end
  end

  defp handle_keyfun_result(key) when is_binary(key) and byte_size(key) > 0, do: {:ok, key}
  defp handle_keyfun_result(key), do: {:error, "Invalid key: `#{inspect(key)}`"}
end
