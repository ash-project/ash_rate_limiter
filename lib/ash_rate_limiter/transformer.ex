defmodule AshRateLimiter.Transformer do
  @moduledoc """
  A Spark DSL transformer for rate limiting.
  """
  use Spark.Dsl.Transformer
  import Spark.Dsl.Transformer
  alias Ash.Resource.{Dsl, Info}
  alias AshRateLimiter.{Change, Preparation}
  alias Spark.Error.DslError

  @doc false
  @impl true
  def after?(_), do: true

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
    with {:ok, action} <- validate_action(entity, dsl) do
      add_change_or_preparation(entity, action, dsl)
    end
  end

  defp validate_action(entity, dsl) do
    case Info.action(dsl, entity.action) do
      nil ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:rate_limit, :action, entity.action, :action],
           message: """
           Action #{entity.action} not found.
           """
         )}

      action when action.type in [:create, :read, :update, :destroy] ->
        {:ok, action}

      action when action.type == :action ->
        {:error,
         DslError.exception(
           module: get_persisted(dsl, :module),
           path: [:rate_limit, :action, entity.action, :action],
           message: """
           Generic actions are not supported by the rate limiter DSL, instead you should add a call to your hammer module directly inside your action implementation.
           """
         )}
    end
  end

  defp add_change_or_preparation(entity, action, dsl) when action.type == :read,
    do: add_preparation(entity, dsl)

  defp add_change_or_preparation(entity, _action, dsl), do: add_change(entity, dsl)

  defp add_preparation(entity, dsl) do
    with {:ok, preparation} <-
           build_entity(Dsl, [:preparations], :prepare,
             preparation:
               {Preparation,
                action: entity.action, limit: entity.limit, per: entity.per, key: entity.key}
           ) do
      {:ok, add_entity(dsl, [:preparations], preparation)}
    end
  end

  defp add_change(entity, dsl) do
    with {:ok, change} <-
           build_entity(Dsl, [:changes], :change,
             change:
               {Change,
                action: entity.action, limit: entity.limit, per: entity.per, key: entity.key}
           ) do
      {:ok, add_entity(dsl, [:changes], change)}
    end
  end
end
