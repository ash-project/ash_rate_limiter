# SPDX-FileCopyrightText: 2025 ash_rate_limiter contributors <https://github.com/ash-project/ash_rate_limiter/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshRateLimiter.Change do
  @moduledoc """
  A resource change which implements rate limiting.
  """
  use Ash.Resource.Change
  alias Ash.Changeset
  alias AshRateLimiter.{Info, LimitExceeded}
  alias Spark.Options

  @option_schema Options.new!(
                   action: [
                     type: {:or, [nil, :atom]},
                     required: false,
                     default: nil,
                     doc:
                       "If provided, then only changesets matching the provided action name will be limited, otherwise all actions are."
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
                     doc: "The key used to identify the event. See above."
                   ]
                 )

  @doc false
  @impl true
  def init(options), do: Options.validate(options, @option_schema)

  @doc false
  @impl true
  def change(changeset, opts, context) do
    if is_nil(opts[:action]) or opts[:action] == changeset.action.name do
      Changeset.before_action(changeset, &apply_rate_limit(&1, opts, context))
    else
      changeset
    end
  end

  defp apply_rate_limit(changeset, opts, context) do
    context =
      context
      |> Map.from_struct()
      |> Map.merge(changeset.context)

    with {:ok, key} <- get_key(changeset, opts, context),
         :ok <- hammer_it(changeset, Keyword.put(opts, :key, key)) do
      changeset
    else
      {:error, reason} -> Changeset.add_error(changeset, reason)
    end
  end

  defp hammer_it(changeset, opts) do
    hammer = Info.rate_limit_hammer!(changeset.resource)

    case hammer.hit(opts[:key], opts[:per], opts[:limit]) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, LimitExceeded.exception([{:hammer, hammer} | opts])}
    end
  end

  defp get_key(changeset, opts, context) do
    case opts[:key] do
      key when is_binary(key) and byte_size(key) > 0 ->
        {:ok, key}

      keyfun when is_function(keyfun, 1) ->
        changeset
        |> keyfun.()
        |> handle_keyfun_result()

      keyfun when is_function(keyfun, 2) ->
        changeset
        |> keyfun.(context)
        |> handle_keyfun_result()

      key ->
        {:error, "Invalid key: `#{inspect(key)}`"}
    end
  end

  defp handle_keyfun_result(key) when is_binary(key) and byte_size(key) > 0, do: {:ok, key}
  defp handle_keyfun_result(key), do: {:error, "Invalid key: `#{inspect(key)}`"}
end
