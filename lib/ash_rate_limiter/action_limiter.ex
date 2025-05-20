defmodule AshRateLimiter.ActionLimiter do
  @moduledoc """
  Implements both the `Ash.Resource.Change` and `Ash.Resource.Preparation` behaviours for the `AshRateLimiter` resource extension.
  """

  use Ash.Resource.Change
  use Ash.Resource.Preparation
  alias AshRateLimiter.LimitExceeded

  @option_schema Spark.Options.new!(
                   action: [
                     type: {:or, [nil, :atom]},
                     required: false,
                     default: nil,
                     doc:
                       "If provided, then only changesets/queries matching the provided action name will be limited, otherwise all actions are."
                   ],
                   limit: [
                     type: :pos_integer,
                     required: true,
                     doc: "The maximum number of events allowed within the given wcale"
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
  @impl Ash.Resource.Change
  def init(options) do
    Spark.Options.validate(options, @option_schema)
  end

  @doc false
  @impl true
  def change(changeset, opts, context) do
    if is_nil(opts[:action]) or opts[:action] == changeset.action do
      changeset
      |> Ash.Changeset.before_action(fn changeset ->
        with {:ok, key} <- get_key(changeset, opts, context),
             :ok <- hammer_it(changeset, Keyword.put(opts, :key, key)) do
          changeset
        else
          {:error, reason} -> Ash.Changeset.add_error(changeset, reason)
        end
      end)
    else
      changeset
    end
  end

  @doc false
  @impl true
  def prepare(query, opts, context) do
    if is_nil(opts[:action]) or opts[:action] == query.action do
      query
      |> Ash.Query.before_action(fn query ->
        with {:ok, key} <- get_key(query, opts, context),
             :ok <- hammer_it(query, Keyword.put(opts, :key, key)) do
          query
        else
          {:error, reason} -> Ash.Query.add_error(query, reason)
        end
      end)
    end
  end

  defp hammer_it(changeset_or_query, opts) do
    hammer = AshRateLimiter.Info.rate_limit_hammer!(changeset_or_query.resource)

    case hammer.hit(opts[:key], opts[:per], opts[:limit]) do
      {:allow, _} -> :ok
      {:deny, _} -> raise LimitExceeded, [{:hammer, hammer} | opts]
    end
  end

  defp get_key(changeset_or_query, opts, context) do
    case opts[:key] do
      key when is_binary(key) and byte_size(key) > 0 ->
        {:ok, key}

      keyfun when is_function(keyfun, 1) ->
        changeset_or_query
        |> keyfun.()
        |> handle_keyfun_result()

      keyfun when is_function(keyfun, 2) ->
        changeset_or_query
        |> keyfun.(context)
        |> handle_keyfun_result()

      key ->
        {:error, "Invalid key: `#{inspect(key)}`"}
    end
  end

  defp handle_keyfun_result(key) when is_binary(key) and byte_size(key), do: {:ok, key}
  defp handle_keyfun_result(key), do: {:error, "Invalid key: `#{inspect(key)}`"}
end
