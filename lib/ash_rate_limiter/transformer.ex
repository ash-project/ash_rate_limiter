defmodule AshRateLimiter.Transformer do
  @moduledoc """
  A Spark DSL transformer for rate limiting.
  """
  use Spark.Dsl.Transformer
  import Spark.Dsl.Transformer
  alias Ash.Resource.Info
  alias Spark.Error.DslError

  @doc false
  @impl true
  def transform(dsl) do
    dsl
    |> get_entities([:rate_limit])
    |> Enum.reduce_while({:ok, dsl}, fn entity, {:ok, dsl} ->
      case transform_entity(entity, dsl) do
        {:ok, dsl} -> {:cont, {:ok, dsl}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp transform_entity(entity, dsl) do
    with {:ok, entity} <- get_action(entity, dsl),
         :ok <- validate_limit(entity, dsl),
         :ok <- validate_scale(entity, dsl),
         {:ok, entity} <- validate_key(entity, dsl) do
      {:ok, replace_entity(dsl, [:rate_limit], entity)}
    end
  end

  defp get_action(entity, dsl) do
    case Info.action(dsl, entity.action) do
      nil ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:rate_limit, :limit, entity.name, :action],
           message: """
           Action #{entity.action} not found.
           """
         )}

      action ->
        {:ok, %{entity | action: action}}
    end
  end

  defp validate_limit(entity, dsl) do
    case entity.limit do
      i when is_integer(i) and i > 0 ->
        :ok

      _ ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:rate_limit, :limit, entity.name, :limit],
           message: """
           Limit must be an integer value greater than 0.
           """
         )}
    end
  end

  defp validate_scale(entity, dsl) do
    case entity.scale do
      i when is_integer(i) and i >= 0 ->
        :ok

      _ ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:rate_limit, :limit, entity.name, :limit],
           message: """
           Limit must be an integer value greater than 0 or a `Duration`.
           """
         )}
    end
  end

  defp validate_key(entity, _dsl) when is_binary(entity.key), do: {:ok, entity}

  defp validate_key(entity, dsl) do
    key = "#{inspect(get_persisted(dsl, :module))}:#{entity.action.name}"
    {:ok, %{entity | key: key}}
  end
end
