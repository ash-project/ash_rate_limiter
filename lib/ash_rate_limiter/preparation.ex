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
                   ],
                   on: [
                     type: {:one_of, [:before_action, :before_transaction]},
                     required: false,
                     default: :before_action,
                     doc:
                       "The lifecycle hook to use for rate limiting. `:before_action` runs inside the transaction; `:before_transaction` runs outside the transaction, after validations."
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
      case opts[:on] do
        :before_transaction ->
          Query.before_transaction(query, &apply_rate_limit(&1, opts, context))

        :before_action ->
          Query.before_action(query, &apply_rate_limit(&1, opts, context))
      end
    else
      query
    end
  end

  def prepare(%ActionInput{} = input, opts, context) do
    if is_nil(opts[:action]) or opts[:action] == input.action.name do
      case opts[:on] do
        :before_transaction ->
          ActionInput.before_transaction(input, &apply_rate_limit(&1, opts, context))

        :before_action ->
          ActionInput.before_action(input, &apply_rate_limit(&1, opts, context))
      end
    else
      input
    end
  end

  defp apply_rate_limit(%Query{} = query, opts, context) do
    context =
      context
      |> Map.from_struct()
      |> Map.merge(query.context)

    with {:ok, key} <- get_key(query, opts, context),
         :ok <- check_rate_limit(query, Keyword.put(opts, :key, key)) do
      query
    else
      {:error, reason} -> Query.add_error(query, reason)
    end
  end

  defp apply_rate_limit(%ActionInput{} = input, opts, context) do
    context =
      context
      |> Map.from_struct()
      |> Map.merge(input.context)

    with {:ok, key} <- get_key(input, opts, context),
         :ok <- check_rate_limit(input, Keyword.put(opts, :key, key)) do
      input
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_rate_limit(query_or_input, opts) do
    backend = Info.rate_limit_backend!(query_or_input.resource)

    case backend.hit(opts[:key], opts[:per], opts[:limit]) do
      {:allow, _} ->
        :ok

      {:deny, _} ->
        error_opts = opts |> Keyword.drop([:on]) |> Keyword.put(:backend, backend)
        {:error, LimitExceeded.exception(error_opts)}
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
