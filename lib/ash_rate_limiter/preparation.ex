defmodule AshRateLimiter.Preparation do
  @moduledoc """
  A resource preparation which implements rate limiting.
  """

  use Ash.Resource.Preparation
  alias Ash.Query
  alias AshRateLimiter.{Info, LimitExceeded}
  alias Spark.Options

  @option_schema Options.new!(
                   action: [
                     type: {:or, [nil, :atom]},
                     required: false,
                     default: nil,
                     doc:
                       "If provided, then only queries matching the provided action name will be limited, otherwise all actions are."
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
  def prepare(query, opts, context) do
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

  defp hammer_it(query, opts) do
    hammer = Info.rate_limit_hammer!(query.resource)

    case hammer.hit(opts[:key], opts[:per], opts[:limit]) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, LimitExceeded.exception([{:hammer, hammer} | opts])}
    end
  end

  defp get_key(query, opts, context) do
    case opts[:key] do
      key when is_binary(key) and byte_size(key) > 0 ->
        {:ok, key}

      keyfun when is_function(keyfun, 1) ->
        query
        |> keyfun.()
        |> handle_keyfun_result()

      keyfun when is_function(keyfun, 2) ->
        query
        |> keyfun.(context)
        |> handle_keyfun_result()

      key ->
        {:error, "Invalid key: `#{inspect(key)}`"}
    end
  end

  defp handle_keyfun_result(key) when is_binary(key) and byte_size(key) > 0, do: {:ok, key}
  defp handle_keyfun_result(key), do: {:error, "Invalid key: `#{inspect(key)}`"}
end
